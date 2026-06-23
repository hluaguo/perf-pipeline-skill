---
name: perf-pipeline
description: Multi-agent performance optimization pipeline. Use ONLY when the user asks to optimize performance, profile code, find bottlenecks, or run a performance audit across a codebase. Decomposes the project into modules, launches subagents per module to find all optimizations, collates and ranks candidates, validates the top 1-3, and submits PR-ready branches. Not for general refactoring, feature work, or debugging.
---

# Performance Optimization Pipeline

You are the orchestrator. You never edit code directly. You decompose, launch
subagents, collate results, validate, and submit. Subagents do all the reading,
benchmarking, and code changes.

## Branch rules (non-negotiable)

```
main                          Orchestrator reads tree here. Source of truth.
 |
 |--- opt/<module>-deep       One per subagent. Created from main. Never shared.
 |
 |--- validate/<fix-slug>     One per top candidate. Created from main.
 |                            NEVER branch from opt/* — they carry unrelated diffs.
 |                            Push validate/* directly to fork for PR. No merge branches.

 TEMP: /var/folders/.../T/opencode/<fix-slug>/ for all throwaway artifacts.
       bench.swift, smoke.swift, report.md. Never committed. Delete after submit.
```

## Phase 1: ARCHITECT

Read `Sources/` and decompose into modules. One module = one build target
(has its own `Sources/<Name>/` and `Tests/<Name>Tests/`), ≤ ~20 files.

```
Output: module list with source paths and hot-path notes.

  Module:   ContainerXPC
  Target:   ContainerXPC
  Tests:    ContainerXPCTests
  Files:    Sources/ContainerXPC/XPCMessage.swift (every CLI command)
            Sources/ContainerXPC/XPCServer.swift  (daemon lifecycle)
            ...
```

Present the module list to the user for approval before launching subagents.

## Phase 2: INVESTIGATE

For each module, launch ONE `general` subagent:

```
Task:        Read every file in module <name>. Find ALL performance issues.
             Measure before/after for each. Report all findings (valid + invalid).
Branch:      opt/<module>-deep (create from main)
Return:      Structured report per module.

Agent prompt MUST include:

  "You are investigating <Module> at Sources/<Module>/*.swift.
   Branch: opt/<module>-deep from main.

   Read every file. For each file scan these patterns:

   PATTERN              SIGNAL
   lock contention      NSLock, os_unfair_lock, DispatchQueue.sync on hot paths
   repeated computation ProcessInfo.environment, Date(), UUID() as default params or in loops
   existential overhead protocol with ≤3 conformances used as [Protocol] or : Protocol
   allocation churn     .append() in loop without reserveCapacity, String += in hot paths
   deferred work        Logger() init, heavy setup in init() that could be lazy/static
   retain cycles        { [self] in ... } escaping closure where self owns the closure
   string interpolation "\\(expensive)" in tight loops
   JSON/codable cache   JSONEncoder()/JSONDecoder() created per call instead of reused

   For each hit:
   - Write a micro-benchmark (XCTest measureMetrics), measure old vs new
   - Estimate lines changed for the fix
   - Mark valid: true if improvement >10% AND lines <50, else valid: false

   Return structured JSON report:
   {
     module: "<name>",
     branch: "opt/<module>-deep",
     files_read: N,
     findings: [
       {
         pattern: "...",
         location: "File.swift:line",
         description: "...",
         fix_lines: ±N,
         before: "mean X us, stddev Y us, n=Z",
         after: "mean X us, stddev Y us, n=Z",
         delta: "-XX%",
         valid: true|false,
         risk: "what could break"
       }, ...
     ]
   }"

Launch all subagents in parallel. Wait for all to complete.
```

## Phase 3: COLLATE

Collect all agent reports. Stay on `main`.

```
1. DEDUPLICATE — same fix in multiple modules? merge into one candidate.
2. CLASSIFY    — group by pattern type (lock removal, enum conversion, caching, etc.)
3. SCORE       — Score = delta_% / sqrt(|lines_changed|). Drop if valid:false or score < threshold.
4. SELECT      — Top 1-3 by score.

Present the top candidates to the user with scores and rationale.
Ask which to validate (or validate all top 3).
```

## Phase 4: VALIDATE

For each selected candidate, run the five-stage gate. Use `task` subagents for
each validation — they can run in parallel.

```
Branch: validate/<fix-slug>  (MUST be created from main, NEVER from opt/*)

4a. ISOLATE   — Apply only the semantic change. Strip profilers, debug prints, comments.
                Gate: diff < 200 lines, < 5 files.

                Temp dir: /var/folders/.../T/opencode/<fix-slug>/
                All benchmarks, smoke tests, notes go there. Never committed.

4b. CORRECT   — swift build --target <Module>, swift test, release build, zero warnings.
                Pure function? → A/B smoke test: 100 random inputs, assert identical.
                Stateful change? → Test cold start and warm path separately.
                API changed? → grep ALL callers, fix every one, build every target.
                Lock removed? → Trace ownership, cite serialization guarantee.

4c. MEASURE   — Micro-benchmark in release mode, ≥10 iterations.
                Compare: (old-mean − new-mean) / old-stddev > 2 → significant.
                Report: before ± σ, after ± σ, delta%, p-value.
                FAIL if regression or p > 0.05. WARN if delta < 10% or σ > 30%.

4d. SAFETY    — Thread: cite source for every lock removal (man page, class doc).
                Memory: no new retain cycles, no unbounded caches, no UAF.
                Errors: propagation unchanged, no swallowed errors.
                API: internal = safe. Public = additive only, or document breaking change.

4e. SCOPE     — grep -r changed_symbol → list all callers.
                Build and test every caller's target.
                Categorize: same module (low), other internal (medium), public (high).
                WARN if any caller has zero test coverage.

Decision matrix:
  PASS:  4b✓ 4c✓ 4d✓ 4e✓  → AUDIT
  PASS:  4b✓ 4c⚠ 4d✓ 4e✓  → AUDIT (note weak delta)
  PASS:  4b✓ 4c✓ 4d✓ 4e⚠  → AUDIT (note coverage gap)
  FAIL:  any ✗              → Drop candidate
```

## Phase 5: AUDIT

Stay on `validate/<fix-slug>`.

```
- swift test (full suite)
- swift build (all targets)
- swift build -c release
- Final review: any leftover debug code? TODO/FIXME?
- Every claim in PR body has inline source citation (man page section, URL, commit hash)
- PR body is self-contained — maintainer needs no external docs
- Squash fixups into single clean commit: git rebase -i main
```

## Phase 6: SUBMIT

```
git push fork validate/<fix-slug>
→ Open PR to upstream main

PR body template:

  ## Type of Change
  - [x] Bug fix (performance)

  ## Motivation
  [What runs slowly and why. Inline source citation from official docs.]

  ## Changes
  - File1.swift: [one-line description]
  - File2.swift: [one-line description]

  ## Testing
  - [x] swift build (all targets)
  - [x] swift test (N tests pass)
  - [x] Zero warnings
  - [x] Release build succeeds

Delete /tmp/opencode/<fix-slug>/ after submission.
```

## Rules summary

| Rule | Reason |
|------|--------|
| One module per subagent | Deep focus, no cross-contamination |
| Module ≤ ~20 files | Subagent can read everything |
| Branch: opt/<module>-deep from main | Isolated workspace per agent |
| Subagent reports ALL findings (valid + invalid) | Invalid teaches pattern boundaries |
| Orchestrator on main | Clean comparison baseline |
| Score = Δ% / √lines | Reward small, high-impact diffs |
| Drop >5 file, >2 module changes | Architectural = separate process |
| Branch: validate/<fix-slug> from main | NEVER from opt/* |
| /tmp for all validation artifacts | Cannot leak into repo; self-documents as throwaway |
| Strip profiling artifacts from branch | Debug harness doesn't belong upstream |
| Release build only for measurement | Debug assertions skew results |
| Cite source for every lock removal | man page, class doc, or dispatch contract |
| grep + build every caller | Catch breakage before PR |
| PR body self-contained with inline citations | Maintainer needs no external docs |
| Push validate/<fix-slug> directly | Single clean commit, no merge branches |
| Delete /tmp artifacts after submit | No stale files |
