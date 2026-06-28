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

For each module, launch **one subagent** (equipped with the `find-doc` skill to look up official specs and contracts). Give it:

```
Module:     <name>
Files:      <list of every source file in the module>
Branch:     opt/<module>-deep  (create from main)
Skills:     find-doc  (MUST be loaded for specifications lookup)

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

For each selected optimization candidate, delegate validation to a specialized subagent equipped with the **`perf-validator`** and **`find-doc`** skills.

Give the subagent the following instructions:
```
Candidate:  <fix-slug>
Skills:     perf-validator, find-doc  (BOTH must be active for safety audits and metrics profiling)

Task:
  Execute the full five-stage validation pipeline:
  1. Semantic Isolation & Diff Normalization (Gate 1)
  2. Conformational Equivalence Verification (Gate 2)
  3. Empirical Statistical Metric Validation (Gate 3)
  4. Memory Model & Lifetimes Safety Auditing (Gate 4)
  5. Call Graph Blast Radius Impact Analysis (Gate 5)

  Locate and verify all systems contracts or thread safety claims using system 'man' pages or official specs via the 'find-doc' skill. Output a structured validation report verifying the candidate's safety, correctness, and performance delta.
```

Launch subagents in parallel execution contexts across candidates. Wait for their reports before proceeding to Phase 5.

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
