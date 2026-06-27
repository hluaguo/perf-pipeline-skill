# Performance Optimization & Review Skills

A suite of language-agnostic, agentic tools for automated performance auditing, optimization, and code review.

```
ARCHITECT ──> INVESTIGATE ──> COLLATE ──> VALIDATE ──> AUDIT & REVIEW ──> SUBMIT
```

This repository contains two core skills:

1. **`perf-pipeline`**: The orchestrator skill that decomposes a codebase, investigates bottlenecks, runs isolated micro-benchmarks, and validates candidates through correctness/safety gates.
2. **`perf-review`**: The companion auditing skill that reviews performance optimization PRs or branches (`validate/*`) for safety, math correctness, race conditions, memory bounds, and benchmark integrity before merging.

---

## Skills Directory Structure

```
skills/
├── perf-pipeline/
│   └── SKILL.md      # Orchestration, Benchmarking & Safety gates
└── perf-review/
    └── SKILL.md      # PR auditing, algebraic math checks & GPU sync review
```

---

## Installation

To load these skills into your coding agent workspace, clone this repository into your customizations root:

### For OpenCode / Gemini Customizations
Clone directly into your global configs:
```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git ~/.config/opencode/
```
Or place the subdirectories inside your active workspace's `.agents/skills/` folder:
```
<workspace-root>/.agents/skills/perf-pipeline/
<workspace-root>/.agents/skills/perf-review/
```

### For Claude Code / Codex
```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git ~/.claude/skills/perf-pipeline
```

---

## Skill Descriptions

### 1. `perf-pipeline`
* **Trigger words**: `optimize performance`, `profile the codebase`, `find bottlenecks`, `run a performance audit`
* **Workflow**:
  * **Architect**: Splitting the codebase into buildable targets.
  * **Investigate**: Scanning for 12 known patterns (lock contention, allocation churn, device-host sync barriers, JIT compiler churn, etc.).
  * **Collate**: Deduplicating and ranking using the Risk-Adjusted Scoring formula:
    $$\text{Score} = \left(\frac{\Delta\%}{\sqrt{|\text{lines\_changed}|}}\right) \times \text{RiskMultiplier}$$
  * **Validate**: Running correctness and performance gates (e.g. differential testing with $\ge$ 1,000 edge-case inputs).

### 2. `perf-review`
* **Trigger words**: `review performance PR`, `audit optimization branch`, `validate merge safety`
* **Workflow**:
  * **Isolate Diff**: Ensuring functional changes are $\le$ 200 lines and $\le$ 5 files.
  * **Semantics**: Catching silent error swallowing or optionality failures.
  * **Safety**: Verifying concurrency locks, weak reference loops, and cache eviction boundaries (to prevent OOMs).
  * **Hardware**: Spotting device-to-host readback bottlenecks and shader compile loops.
  * **Math**: Reviewing strength reductions and fast-math approximations.
  * **Benchmarks**: Checking compilation warmup runs and device queue synchronization.

---

## License

MIT
