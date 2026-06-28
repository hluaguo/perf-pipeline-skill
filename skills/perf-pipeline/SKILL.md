---
name: Performance Optimization Pipeline
description: Orchestrates performance optimizations by statically analyzing AST codebase topology, running micro-benchmarks, and verifying equivalence invariants.
---

# Performance Optimization Pipeline

You are the orchestration runtime and concurrency controller. You never edit code directly. You statically analyze and partition the AST/codebase topology, launch specialized subagents, collate optimization reports, verify equivalence invariants via validation gates, and submit upstream pull requests. Subagents execute all code reading, high-precision profiling, micro-benchmarking, and compilation-unit editing.

---

## VCS Branch Invariants

```
main                              Source of truth. Read tree topology here.
 |
 |--- opt/<module>-deep           One per subagent execution context. Created from main. Never shared.
 |
 |--- validate/<fix-slug>         One per top candidate. Created from main.
 |                                NEVER branch from opt/* — they carry unrelated AST diffs.
 |                                Push validate/* directly for upstream PR. No merge branches.

 TEMP: /tmp/<fix-slug>/ for all ephemeral artifacts (compilation scripts, smoke tests,
        profiler outputs). Never committed. Purge after successful integration.
```

---

## Phase 1: AST TOPOLOGY PARTITIONING & DEPENDENCY DECOMPOSITION

Analyze the top-level source tree topology. Partition the codebase into decoupled **compilation units (modules)**. A module must represent an isolated dependency boundary: it compiles and tests independently, contains ≤ ~20 source files, and maps to a single coherent execution concern.

```
Output per compilation unit:
  - Name, source directories, test suite target
  - Build command:  <build-tool> build --scope <module>
  - Test command:   <build-tool> test --scope <module>
  - Execution hot-paths: execution hot-paths, high-throughput loop invariants, call graph centroids
```

Present modules to the user. Await explicit confirmation before launching subagents.

---

## Phase 2: MICRO-ARCHITECTURAL INVESTIGATION & PROFILING

For each module, launch **one subagent**. Give it:

```
Module:     <name>
Files:      <list of every source file in the module>
Branch:     opt/<module>-deep  (create from main)

Task:
  1. Read every file in the module.
  2. Scan for these micro-architectural anti-patterns and performance inhibitors in every file:

     PATTERN               SIGNAL / SPECIFIC RUNTIME INHIBITOR
     ───────               ───────────────────────────────────
     lock contention       Thread synchronization contention / cacheline bouncing / semaphore saturation on execution hot-path
     repeated computation  Idempotent computation redundancy / loop-invariant execution
     existential overhead  Vtable dispatch indirection / dynamic dispatch overhead / existential container box-allocation
     allocation churn      Heap allocation pressure / garbage collection pressure / memory fragmentation in a tight loop
     deferred work         Eager initialization of heavy objects preventing lazy/static/singleton resource sharing
     retain cycles/leaks   Reference count cyclic dependencies / object graph resource leaks via strong-capture closures
     string interpolation  Ephemeral string allocation churn / string heap copy semantics inside tight loop iterations
     reusable encoder      Ephemeral serialization instance footprint / encoder re-instantiation overhead per call
     device-host barrier   PCIe bus transfer synchronization bottlenecks / GPU pipeline stalls / host-device sync barriers
                           (e.g., calling .item(), .tolist(), .numpy(), cudaMemcpy, glReadPixels) in hot loops
     compiler/JIT churn    JIT compiler compilation de-optimization loops / trace invalidation churn inside tight loops
     invariant recreation  Loop-invariant resource allocation / hoisting failure of matrices, lookup tables, or constants
     strength reduction    Arithmetic strength reduction / instruction scheduling optimizations (e.g. replacing modulo with bitwise ops)
     approximate math      Using exact float calculations where lossy numerical approximation or SIMD fast-math approximations are acceptable
     simd/vectorization    SIMD register auto-vectorization inhibitors / loop vectorization failure (serial CPU loops)

  3. For each pattern found:
     - Construct a high-precision micro-benchmark. Measure baseline (on main) and optimized (on opt/*).
     - Estimate lines changed for a minimal, semantically isolated fix.
     - Mark valid: true if optimization delta > 10% AND estimated change < 50 lines.
     - Mark valid: false otherwise (document inhibitor: architectural, regression risk, high cost, etc.).

  4. Return a structured JSON report for the orchestrator:

     {
       "module": "<name>",
       "branch": "opt/<module>-deep",
       "files_read": N,
       "findings": [
         {
           "pattern": "<one of the patterns above>",
           "location": "<file>:<line> — <function/symbol name>",
           "description": "<detailed technical description of execution bottleneck>",
           "fix_lines": ±N,
           "before": "<mean> ± <stddev> (<n> runs)",
           "after":  "<mean> ± <stddev> (<n> runs)",
           "delta":  "-XX% (p < 0.0X)",
           "valid": true | false,
           "risk": "<concurrency, memory model, API compatibility, semantic correctness>"
         }
       ]
     }

Launch all subagents in parallel execution contexts. Wait for all to finish before continuing.
```

---

## Phase 3: COLLATION, DEDUPLICATION, & RISK-ADJUSTED PRIORITY HEURISTICS

Maintain execution context on `main`. Collect every agent's report.

```
1. DEDUPLICATE  — Resolve structural diff intersections. Merge duplicate optimization targets.

2. CLASSIFY     — Taxonomic classification of optimization vectors:
                   lock-removal, enum-conversion, capacity-hints, caching,
                   retain-cycle, loop-hoisting, deferred-init, encoder-reuse.

3. SCORE        — Compute Priority Score using the Risk-Adjusted Scoring heuristic:
                   Score = (delta_percent / sqrt(|lines changed|)) * RiskMultiplier
                   Where RiskMultiplier is defined as:
                     - 1.0 (Negligible Risk): Pure mathematical/compiler optimizations, dead code removal.
                     - 0.8 (Low Risk): Hoisting loops, static caches (lru_cache), local variables.
                     - 0.5 (Medium Risk): Internal data structure modifications, refactoring algorithms.
                     - 0.1 (High Risk): Removing locks/queues (concurrency), unsafe memory pointers, API-breaking changes.
                   Prune candidates where: valid = false, score < threshold,
                   or diff touches > 5 files across > 2 modules (architectural —
                   requires separate, deep architectural review).

4. SELECT       — Top 1–3 by priority score. Present to user with metrics and rationale.
                   Acknowledge target selection before initiating validation.
```

---

## Phase 4: EQUIVALENCE VERIFICATION & REGRESSION PREVENTION GATES

For each selected candidate, run the five-stage gate. Use subagents for each validation — they can run in parallel across candidates.

```
Branch: validate/<fix-slug>    (MUST be created from main. NEVER from opt/*.)
Temp:   /tmp/<fix-slug>/        All ephemeral profiling/validation outputs.
```

### 4a. SEMANTIC ISOLATION & DIFF NORMALIZATION

```
Apply ONLY the semantic changes to the validate branch. Remove:
  - Profiling hooks, benchmark harness code, debug print statements
  - Comments explaining the change (document rationale inside Git commit metadata)
  - Whitespace-only formatting or style churn

Verify: diff from main is < 200 lines, touches < 5 files.
Commit: <type>(<scope>): <imperative summary>

        Before: <baseline>
        After:  <result>
        How:    <mechanical description of the change>
```

### 4b. CONFORMATIONAL EQUIVALENCE VERIFICATION

```
□ Verify build system invariants (debug and release targets) — scope and full project
□ Test suite execution (target module and full suite integration)
□ Ensure compilation output generates zero new compiler warnings

□ Pure-function/Mathematical modifications → Property-based Differential Testing:
  - Lightweight functions: Generate 1,000+ test inputs spanning standard ranges and extreme edge cases.
  - Heavy ML/Inference workloads (e.g., PyTorch, MLX): Validate output tensor numerical equivalence (within tolerance ε)
    across representative input prompts and token sequence boundaries, rather than 1,000+ slow model runs.

□ Deep Learning / LLM Workloads → Architectural & Phase Equivalence:
  - Assert logical equivalence of KV cache retention, mask computations, and token output distributions.
  - Separately validate output parity for the Prefill Phase (context processing) and the Decode Phase (autoregressive generation loop).

□ Stateful optimizations (static/lazy/cache) → Verify cold start AND warm path execution states independently.
  Test cache reset/re-initialization mechanisms.

□ API surface modification → grep callers across the codebase topology. Resolve all references.
  Build and test all affected targets.

□ Thread synchronization / Lock removal → Trace object ownership and prove serialization:
  - Verify single-threaded confinement OR external serialization guarantees.
  - Cite specific guarantees: POSIX thread spec, language memory model, runtime event-loop contract.

□ Data representation updates (interface→enum, struct→class) → Verify:
  equivalence relation, hash code distribution, serialization round-trip, iteration order, thread-safety invariants.

FAIL if any equivalence invariant is violated.
```

### 4c. EMPIRICAL STATISTICAL METRIC VALIDATION

```
□ Enforce optimized release builds only (debug assertions skew micro-architectural paths).

□ Execution engine stabilization & warm-up convergence (JVM, V8, PyTorch, MLX, WebGL/WebGPU shaders):
  Warm up the execution pipeline (e.g., compile shaders, trigger JIT trace compilation, or perform initial tensor 
  evaluation passes) before starting the timer to eliminate compiler or trace generation overhead.
□ Hardware-accelerated execution synchronization & pipeline flushing (GPU, CUDA, OpenCL, Metal, Vulkan):
  Call explicit device/queue synchronization (e.g., mx.synchronize(), cudaDeviceSynchronize(), or Metal 
  commandBuffer.waitUntilCompleted()) before stopping the timer to capture real execution time instead of CPU dispatch latency.

□ LLM / Transformer-Specific Metrics:
  - Profile and report the Prefill Phase (compute-bound matrix multiplications, KV cache allocation/ingestion) 
    and the Decode Phase (memory-bandwidth bound token generation loops) separately.
  - Measure Time to First Token (TTFT) for prefill, and Tokens Per Second (TPS) for decode.
  - Track KV cache memory allocation efficiency and shape padding effects on GPU memory fragmentation.

□ High-precision benchmarking:
  - Lightweight functions: Run ≥ 10 runs or utilize statistical micro-benchmarking suites.
  - Heavy ML/Inference runs: Measure sufficient tokens/runs (e.g., 5-10 sequences) to achieve standard deviation convergence.
  Validate: (old_mean − new_mean) / old_stddev > 2 → statistically significant optimization.

□ End-to-end black-box benchmarking (if micro-benchmarks are inconclusive):
  Time the user-facing command that exercises this path. Warmup + ≥ 20 runs.
  hyperfine --warmup 5 --runs 20 '<command>'

□ Cold-start benchmark (caching changes only):
  Flush relevant caches between runs. Measure first-call latency.

Report format:
  Before:  12.3 µs ± 1.1 µs (50 runs)
  After:    4.7 µs ± 0.8 µs (50 runs)
  Delta:   −61.8% (p < 0.01)

WARN if delta < 10% or stddev > 30% of the mean.
FAIL if negative delta (regression) or p > 0.05.
```

### 4d. MEMORY MODEL & LIFETIMES SAFETY AUDITING

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
□ No reference count cycles / retain cycles.
□ No unbounded memory footprint growth: cache targets must enforce LRU eviction policies or fixed capacity limits.
  Static singletons must not lock large objects into heap memory for the full process lifetime.
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

### 4e. CALL GRAPH BLAST RADIUS IMPACT ANALYSIS

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

### Verification Decision Matrix

```
  4b (equivalence)   4c (delta)   4d (safety)   4e (blast radius)   →  Verdict
  ────────────────   ──────────   ───────────   ─────────────────
         ✓               ✓             ✓                ✓          →  PASS → AUDIT
         ✓               ⚠             ✓                ✓          →  PASS → AUDIT (note weak delta)
         ✓               ✓             ✓                ⚠          →  PASS → AUDIT (note coverage gap)
         ✗               -             -                -          →  DROP
         ✓               ✗             -                -          →  DROP
         ✓               ✓             ✗                -          →  DROP
```

---

## Phase 5: STATIC EVIDENCE AUDITING & PROOF VERIFICATION

Maintain execution context on `validate/<fix-slug>`.

```
□ Run full test suite on validate branch
□ Full project build (debug + release targets)
□ Final diff review: search for left-over profiling code, TODO comments, or style noise
□ Every optimization claim in the PR body has an inline citation:
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

## Phase 6: UPSTREAM INTEGRATION & VCS SUBMISSION

```
Push validate/<fix-slug> to the fork. Open a PR to upstream main.

PR body template:
  ──────────────────────────────────────
  ## Type of Change
  - [x] Bug fix (performance optimization)

  ## Motivation
  [What runs slowly and why. Include inline citation from official specification/docs.]

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

## Rule Topology Summary

| Rule | Reason |
|------|--------|
| One module per subagent | Focused investigation. No cross-contamination of AST changes. |
| Module ≤ ~20 files | Subagent can read and model entire compilation unit in memory. |
| Branch: opt/<module>-deep from main | Isolated workspace context. Agents never share branches. |
| Subagent reports ALL findings | Rejected optimization vectors inform the orchestrator runtime of inapplicable patterns. |
| Orchestrator stays on main during COLLATE | Prevent intermediate agent diff contamination on baseline. |
| Score = Δ% / √│lines│ | Reward high-impact, minimally invasive code changes. |
| Drop >5 files, >2 modules | Major architectural refactorings require separate design reviews. |
| validate/* branched from main ONLY | Avoid contamination from unrelated opt/* branches. |
| /tmp for all validation artifacts | Prevent local workspace dirtying. Self-documents as ephemeral. |
| Strip profilers before commit | Benchmark harnesses do not belong in production binaries. |
| Release-build benchmarks only | Debug assertions, bounds checking, and sanitizers distort execution profiles. |
| Cite spec for lock removal | Rely on formal specifications, not developer intuition. |
| grep + build + test every caller | Eliminate syntax/linking compilation errors before staging. |
| PR body self-contained with citations | Enable static approval with zero external context switching. |
| Push validate/* directly | Keep VCS history clean and linear with zero merge commits. |
| Delete /tmp after submission | Purge ephemeral directories. |
