# Performance Optimization & Review Skills

A suite of language-agnostic, agentic skills for automated performance auditing, optimization, and code review.

```
ARCHITECT ──> INVESTIGATE ──> COLLATE ──> VALIDATE ──> AUDIT & REVIEW ──> SUBMIT
```

---

## Installation

### Standard CLI Manager (Recommended)
You can install these skills directly using the standard `skills` CLI manager:
```bash
# Install locally to your active project workspace (.agents/skills)
npx skills add hluaguo/perf-pipeline-skill

# Install globally to all your agent environments (Gemini, Claude, OpenCode, etc.)
npx skills add hluaguo/perf-pipeline-skill -g
```

---

## Included Skills

### 1. `perf-pipeline`
* **Triggers**: `optimize performance`, `profile the codebase`, `find bottlenecks`, `run a performance audit`
* **Features**:
  * Decomposes and partitions codebase dependencies into compilation units.
  * Scans codebase for micro-architectural anti-patterns, JIT compilation churn, and synchronization barriers.
  * Computes priority scores and coordinates subagents using a risk-adjusted priority heuristic.

### 2. `perf-validator`
* **Triggers**: `validate candidate`, `run correctness gate`, `execute microbenchmarks`, `verify performance fix`
* **Features**:
  * Normalizes changes and isolates semantic optimization diffs.
  * Proves computational equivalence using property-based differential testing.
  * Runs statistical profiling benchmarks isolating prefill/decode or latency/throughput phases.
  * Performs memory model safety audits and blast radius call graph analyses.

### 3. `perf-review`
* **Triggers**: `review performance PR`, `audit optimization branch`, `validate merge safety`
* **Features**:
  * Audits performance PRs for memory safety, concurrency locks, cache eviction, and GPU host-readback bottlenecks.
  * Reviews strength reductions, fast-math approximations, and compilation warmups.

### 4. `find-doc`
* **Triggers**: `locate specification`, `find documentation`, `check POSIX contract`, `retrieve standard reference`
* **Features**:
  * Locates official specs, API manuals, and language memory model documents.
  * Details system manual (`man` page) lookup strategies and web search targets.
  * Provides proof validation and citation standards to back safety claims with authoritative quotes.

---

## License

MIT
