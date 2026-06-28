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
  * Scans codebase for lock contention, allocation churn, and sync barriers.
  * Ranks candidates using the Risk-Adjusted Scoring formula:
    $$\text{Score} = \left(\frac{\Delta\%}{\sqrt{|\text{lines changed}|}}\right) \times \text{RiskMultiplier}$$
  * Validates optimization candidates using automated differential testing with $\ge$ 1,000 inputs.

### 2. `perf-review`
* **Triggers**: `review performance PR`, `audit optimization branch`, `validate merge safety`
* **Features**:
  * Audits performance PRs for memory safety, concurrency locks, cache eviction, and GPU host-readback bottlenecks.
  * Reviews strength reductions, fast-math approximations, and compilation warmups.

### 3. `find-doc`
* **Triggers**: `locate specification`, `find documentation`, `check POSIX contract`, `retrieve standard reference`
* **Features**:
  * Locates official specs, API manuals, and language memory model documents.
  * Details system manual (`man` page) lookup strategies and web search targets.
  * Provides proof validation and citation standards to back safety claims with authoritative quotes.

---

## License

MIT
