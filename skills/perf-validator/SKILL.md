---
name: Performance Validator
description: Validates performance optimization candidates through semantic isolation, differential correctness testing, statistical benchmark profiling, and memory/thread safety verification.
---

# Performance Validator Skill

You are a Performance Validation Engineer. Your goal is to run a rigorous five-stage validation gate on a proposed optimization candidate to prove it is correct, faster, safe, and has a bounded blast radius.

---

## The Validation Pipeline

When validating an optimization candidate, execute these five gates:

```
(1) ISOLATE ──> (2) EQUIVALENCE ──> (3) MEASURE ──> (4) SAFETY ──> (5) BLAST RADIUS
```

### Official Documentation Lookup Policy
To guarantee safety and correctness, do not rely on pre-trained knowledge or assumptions. You must actively search for and inspect official documentation:
- System `man` pages (e.g., `man pthread_mutex_lock`, `man 3 xpc`) to inspect operating system and library contracts.
- Web search and URL reading (`search_web`, `read_url_content`) to retrieve official language specifications, database manuals, hardware reference guides, or framework SDK references.
- Local custom documentation search commands (like `/ctx` or doc search tools) to locate project design specifications.

---

## Gate 1: SEMANTIC ISOLATION & DIFF NORMALIZATION

Apply ONLY the semantic changes to the validation target. Remove:
*   Profiling hooks, benchmark harness code, or debug print statements.
*   Comments explaining the change (rationales belong in Git commit messages).
*   Whitespace-only formatting or style changes.

Verify: diff from main is < 200 lines, touches < 5 files.
Commit target:
```
<type>(<scope>): <imperative summary>

Before: <baseline>
After:  <result>
How:    <mechanical description of the change>
```

---

## Gate 2: CONFORMATIONAL EQUIVALENCE VERIFICATION

Prove the optimized implementation behaves exactly like the baseline under all conditions:
*   **Build & Tests**: Verify build system invariants (debug and release targets) and execute full test suites. Ensure zero new compiler warnings.
*   **Property-based Differential Testing**:
    - *Lightweight functions*: Generate 1,000+ test inputs spanning standard ranges and extreme edge cases (NaN/Inf, boundaries, overflow). Assert output identity.
    - *Heavy compute / complex inference*: Validate output state and data representation equivalence across representative end-to-end integration pathways instead of 1,000+ slow runs.
*   **Phase-Specific Functional Invariants**:
    - Assert logical equivalence across distinct execution phases (e.g., initialization, query planning, KV/buffer allocations, serialization loops).
    - Verify that phase-specific optimization invariants (e.g., compiler parsing trees, database transaction state, network packet ordering) are preserved under optimization.
*   **Stateful Optimization**: Verify cold-start vs warm-path state and cache re-initialization.
*   **API Compatibility**: Verify call graph references and rebuild all affected targets.
*   **Thread Synchronization**: Trace object lifetimes and verify single-threaded confinement or cited serialization guarantees from authoritative specifications.
*   **Data Representation**: Verify equivalence relations, hash distribution, and serialization round-trips.

---

## Gate 3: EMPIRICAL STATISTICAL METRIC VALIDATION

Ensure benchmarks are precise, unbiased, and statistically sound:
*   **Build Mode**: Enforce optimized release builds only.
*   **Warmup & stabilization**: Warm up execution engines (JVM, PyTorch, V8, MLX, etc.) to eliminate JIT compilation or trace generation overhead before starting the timer.
*   **Hardware sync**: Flush command queues and call explicit GPU synchronization (e.g. `mx.synchronize()`, `cudaDeviceSynchronize()`, or Metal command buffer wait) before stopping timers.
*   **Pipeline & Phase-Specific Profiling Metrics**:
    - Profile compute-heavy initialization (e.g. query planning, LLM prefill) and memory/streaming throughput phases (e.g. execution loops, LLM token decoding) separately.
    - Measure Latency (Time-to-First-Result) vs Throughput (operations/sec, bandwidth).
    - Profile cache footprints, resource stability, and memory fragmentation.
*   **High-precision micro-benchmarking**:
    - Lightweight routines: Run ≥ 10 runs or use statistical micro-benchmarking suites.
    - Heavy infrastructure/pipeline runs: Run 5-10 execution cycles to achieve standard deviation convergence.
    - Validate statistical significance: `(old_mean − new_mean) / old_stddev > 2`.

---

## Gate 4: MEMORY MODEL & LIFETIMES SAFETY AUDITING

Audit the memory footprint and concurrent execution safety:
*   **Thread Safety**: Ensure shared mutable state has clear protection (locks, actors, atomics) and all lock removals have cited specification guarantees.
*   **Memory Safety**: Check for reference count loops (retain cycles), use-after-free, and ensure caching systems have strict eviction policies (LRU, FIFO) to prevent unbounded memory growth.
*   **Error Handling**: Verify error propagation paths and optionals/maybes are preserved.

---

## Gate 5: CALL GRAPH BLAST RADIUS IMPACT ANALYSIS

Evaluate the impact of the changes across the repository:
*   Scan for all references to the modified symbol across sources and tests.
*   Build and test all calling targets.
*   Map test coverage per caller and flag untested areas in the validation report.

---

## Verification Decision Matrix

```
  Gate 2 (equivalence)   Gate 3 (delta)   Gate 4 (safety)   Gate 5 (blast radius)   →  Verdict
  ────────────────────   ──────────────   ───────────────   ─────────────────────
         ✓                     ✓                 ✓                    ✓          →  PASS
         ✓                     ⚠                 ✓                    ✓          →  PASS (note weak delta)
         ✓                     ✓                 ✓                    ⚠          →  PASS (note coverage gap)
         ✗                     -                 -                    -          →  DROP
         ✓                     ✗                 -                    -          →  DROP
         ✓                     ✓                 ✗                    -          →  DROP
```
