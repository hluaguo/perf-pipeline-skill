# Performance Optimization Pipeline

You are the orchestrator. You never edit code directly. You decompose the
codebase, launch subagents, collate results, validate findings, and submit
PRs. Subagents do all code reading, benchmarking, and editing.

---

## Branch rules

```
main                              Source of truth. Read tree here.
 |
 |--- opt/<module>-deep           One per subagent. Created from main. Never shared.
 |
 |--- validate/<fix-slug>         One per top candidate. Created from main.
 |                                NEVER branch from opt/* — they carry unrelated diffs.
 |                                Push validate/* directly for PR. No merge branches.

 TEMP: /tmp/<fix-slug>/ for all throwaway artifacts (benchmark scripts, smoke tests,
       notes). Never committed. Delete after successful submission.
```

---

## Phase 1: ARCHITECT

Read the top-level source tree. Decompose into **modules**. One module is a
self-contained unit: it compiles and tests independently, contains ≤ ~20
files, and maps to one coherent concern (a library, a service, a layer, a
build target).

```
Output per module:
  - Name, source directory, test directory
  - Build command:  <build-tool> build --scope <module>
  - Test command:   <build-tool> test --scope <module>
  - Hot-path notes: which files run on every request / command / event loop
```

Present modules to the user. Confirm before launching subagents.

---

## Phase 2: INVESTIGATE

For each module, launch **one subagent**. Give it:

```
Module:     <name>
Files:      <list of every source file in the module>
Branch:     opt/<module>-deep  (create from main)

Task:
  1. Read every file in the module.
  2. Scan for these patterns in every file:

     PATTERN               SIGNAL
     ───────               ──────
     lock contention       Lock/mutex/semaphore/queue.sync on a hot path
     repeated computation  Expensive call as default parameter or inside a loop
     existential overhead  Interface/trait/protocol with ≤ 3 implementors used as
                            array element or polymorphic parameter
     allocation churn      .append/.push in a loop without reserveCapacity/preallocation,
                            string concatenation in a tight loop
     deferred work         Eager init of heavy objects that could be lazy/static/singleton
     retain cycles/leaks   Strong-capture closure where the capturer owns the closure
     string interpolation  String building with expensive sub-expressions inside a hot loop
     reusable encoder      Serializer/deserializer created per call instead of cached
     GPU-CPU sync barrier  Calling .item(), .tolist(), or .numpy() inside a hot loop or
                            repeatedly on small tensors/arrays, causing blocking CPU stalls
     graph compiler churn  Wrapping basic CPU-native/scalar operations in GPU arrays (MLX/PyTorch),
                            causing constant compilation/graph execution overhead
     static recreation     Re-computing static window functions, mel filters, or lookup tables
                            in the inference path instead of pre-computing or caching them
     missing compilation   Pure functional math/array code running repeatedly without compiler
                            transforms like @mx.compile or torch.compile where applicable

  3. For each pattern found:
     - Write a standalone micro-benchmark. Measure BEFORE (on main) and AFTER (on opt/*).
     - Estimate lines changed for a minimal fix.
     - Mark valid: true if improvement > 10% AND estimated change < 50 lines.
     - Mark valid: false otherwise (note why — too large, no gain, unsafe, etc.).

  4. Return a structured report for the orchestrator:

     {
       module: "<name>",
       branch: "opt/<module>-deep",
       files_read: N,
       findings: [
         {
           pattern: "<one of the patterns above>",
           location: "<file>:<line> — <function/symbol name>",
           description: "<one-line description of what is slow and why>",
           fix_lines: ±N,
           before: "<mean> ± <stddev> (<n> runs)",
           after:  "<mean> ± <stddev> (<n> runs)",
           delta:  "-XX% (p < 0.0X)",
           valid: true | false,
           risk: "<what could break — threading, API, memory, semantics>"
         },
         ...
       ]
     }

Launch all subagents in parallel. Wait for all to finish before continuing.
```

---

## Phase 3: COLLATE

Stay on `main`. Collect every agent's report.

```
1. DEDUPLICATE  — Same fix appearing in multiple modules? Merge into one candidate.

2. CLASSIFY     — Group by pattern type:
                   lock-removal, enum-conversion, capacity-hints, caching,
                   retain-cycle, loop-hoisting, deferred-init, encoder-reuse.

3. SCORE        — Score = delta_percent / sqrt(|lines_changed|).
                  Drop candidates where: valid = false, score below threshold,
                  or fix touches > 5 files across > 2 modules (architectural —
                  needs a separate, deeper process).

4. SELECT       — Top 1–3 by score. Present to user with scores and rationale.
                  Ask which to proceed with (or validate all).
```

---

## Phase 4: VALIDATE

For each selected candidate, run the five-stage gate. Use subagents for each
validation — they can run in parallel across candidates.

```
Branch: validate/<fix-slug>    (MUST be created from main. NEVER from opt/*.)
Temp:   /tmp/<fix-slug>/        All throwaway files go here. Never committed.
```

### 4a. ISOLATE

```
Apply ONLY the semantic change to the validate branch. Remove:
  - Profiling timers, benchmark harness code, debug prints
  - Comments explaining the change (keepers go in commit messages)
  - Whitespace-only formatting

Verify: diff from main is < 200 lines, touches < 5 files.
Commit:  <type>(<scope>): <imperative summary>

         Before: <baseline>
         After:  <result>
         How:    <mechanical description of the change>
```

### 4b. CORRECTNESS — prove identical output

```
□ Build (debug and release) — target scope and full project
□ Test (module and full suite)
□ Zero new warnings

□ Pure-function change → Write an A/B smoke test:
  Generate 100 random inputs. Run old code and new code. Assert identical outputs.

□ Stateful change (static/lazy/cache) → Test cold start AND warm path separately.
  Test reset/re-init if applicable.

□ API surface changed → grep every caller across the entire codebase. Fix all.
  Build and test every affected target.

□ Lock/queue removed → Trace object ownership. Prove serialization:
  - Single-threaded access? OR externally serialized by contract?
  - Cite the guarantee: man page, language spec, framework doc, dispatch contract.

□ Data type changed (interface→enum, struct→class) → Verify:
  equality, hashing, serialization round-trip, iteration order, thread-safety.

FAIL if any check fails.
```

### 4c. MEASURE — confirm improvement is real

```
□ Use release builds only (debug assertions skew results).

□ ML/GPU workloads: Warm up the pipeline (run 5–10 iterations) before starting the timer
  to eliminate compilation/trace overhead from the measurements.
□ ML/GPU workloads: Call explicit synchronization (e.g., mx.synchronize() or torch.cuda.synchronize())
  before stopping the timer to ensure you measure actual execution time rather than just graph construction.

□ Micro-benchmark the isolated function:
  ≥ 10 iterations. Compute mean and stddev.
  Compare: (old_mean − new_mean) / old_stddev > 2 → statistically significant.

□ End-to-end benchmark (if micro is inconclusive):
  Time the user-facing command that exercises this path. Warmup + ≥ 20 runs.
  hyperfine --warmup 5 --runs 20 '<command>'

□ Cold-start benchmark (caching changes only):
  Flush relevant caches between runs. Measure first-call latency.

Report:
  Before:  12.3 µs ± 1.1 µs (50 runs)
  After:    4.7 µs ± 0.8 µs (50 runs)
  Delta:   −61.8% (p < 0.01)

WARN if delta < 10% or stddev > 30% of the mean.
FAIL if negative delta (regression) or p > 0.05.
```

### 4d. SAFETY — no hidden hazards

```
Thread safety:
□ Every lock/queue removal backed by a cited serialization guarantee.
  Examples:
    - POSIX: "All connection activity happens on an internal queue" (man page section)
    - Platform: main-thread-only by documented contract
    - Runtime: actor-serialized, run-loop-serialized, single-owner by construction
□ New shared mutable state? Must have clear protection (lock, actor, atomic, read-only).
□ No path accesses a resource outside the serial context.

Memory safety:
□ No new retain cycles / reference cycles.
□ No unbounded growth: caches have eviction or fixed capacity.
  Static singletons don't hold large objects for the full process lifetime.
□ No use-after-free / double-free. Unsafe pointer lifetimes unchanged.

Error handling:
□ Error propagation paths identical (throw, return null, panic unchanged).
□ No silently swallowed errors.
□ Optional/Maybe semantics preserved.

API compatibility:
□ Internal / private → safe.
□ Public / exported → additive changes only (new variant, new default).
  Removals or reorderings → document as breaking change with SemVer impact.

FAIL if serialization guarantee cannot be cited from an authoritative source.
FAIL if new mutable shared state has no protection.
FAIL if public API broken without documented justification.
```

### 4e. SCOPE — blast radius

```
□ grep the changed symbol across the entire codebase (sources + tests).
□ Build and test every calling target.
□ Categorize each caller:
  Same module  |  Internal caller (other module)  |  External/public API consumer
  ─────────────│──────────────────────────────────│──────────────────────────────
  Low risk     |  Medium risk (verify build)      |  High risk (must document)

□ Map test coverage per caller:
  Directly tested (strong)  |  Indirectly tested via caller (acceptable)  |  Untested (weak — flag in PR)

WARN if any caller has zero test coverage.
FAIL if any external caller breaks and is missed.
```

### Decision matrix

```
  4b (correct)   4c (faster)   4d (safe)   4e (bounded)   →  Verdict
  ────────────   ───────────   ─────────   ───────────
      ✓              ✓            ✓            ✓          →  PASS → AUDIT
      ✓              ⚠            ✓            ✓          →  PASS → AUDIT (note weak delta)
      ✓              ✓            ✓            ⚠          →  PASS → AUDIT (note coverage gap)
      ✗              -            -            -          →  DROP
      ✓              ✗            -            -          →  DROP
      ✓              ✓            ✗            -          →  DROP
```

---

## Phase 5: AUDIT

Stay on `validate/<fix-slug>`.

```
□ Full test suite against validate branch
□ Full project build (debug + release)
□ Final diff review: any leftover debug code, TODOs, stray comments?
□ Every claim in the PR body has an inline citation:
  - Man page:  "xpc_connection_create(3) states: ..."
  - Language spec: "Swift evaluates default parameter expressions at the call site."
  - Framework doc: URL or class-doc reference
  - Compiler output: godbolt.org link or assembly snippet
□ PR body is self-contained. A maintainer needs zero external documents to
  understand and approve this change.
□ Squash fixups into a single clean commit:
  git rebase -i main
```

---

## Phase 6: SUBMIT

```
Push validate/<fix-slug> to the fork. Open a PR to upstream main.

PR body template:
──────────────────────────────────────
## Type of Change
- [x] Bug fix (performance)

## Motivation
[What runs slowly and why. Include inline citation from official source.]

## Changes
- File1.swift: One-line description of the change
- File2.swift: One-line description of the change

## Testing
- [x] Build (debug + release)
- [x] Full test suite (N tests pass)
- [x] Zero warnings
──────────────────────────────────────

After submission, delete /tmp/<fix-slug>/.
```

---

## Rules summary

| Rule | Reason |
|------|--------|
| One module per subagent | Focused investigation. No cross-contamination. |
| Module ≤ ~20 files | Subagent can read and understand everything. |
| Branch: opt/<module>-deep from main | Isolated workspace. Agents never share branches. |
| Subagent reports ALL findings | Invalid ones teach the orchestrator what patterns don't apply. |
| Orchestrator stays on main during COLLATE | Clean baseline. No agent diffs leak in. |
| Score = Δ% / √│lines│ | Rewards small, high-impact changes. |
| Drop >5 files, >2 modules | Architectural changes need a separate, slower process. |
| validate/* branched from main ONLY | opt/* branches accumulate unrelated changes. |
| /tmp for all validation artifacts | Cannot leak into repo. Self-documents as throwaway. |
| Strip profilers before commit | Debug harness does not belong in production or PRs. |
| Release-build benchmarks only | Debug assertions, bounds checks, and sanitizers distort timing. |
| Cite authoritative source for every lock removal | Man page, language spec, framework docs — not vibes. |
| grep + build + test every caller | Catch breakage before the PR is opened. |
| PR body self-contained with inline citations | Maintainer reads one page, gets the full picture. |
| Push validate/* directly (no merge branch) | One clean commit, no internal history noise. |
| Delete /tmp after submission | No stale artifacts. |
