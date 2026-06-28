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

### Automated Script (via curl)
Alternatively, run the interactive installer in your terminal:
```bash
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash
```

### Unattended / Scripted Install
Specify options to bypass interactive prompts when using the automated script:
```bash
# Examples:
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --gemini    # Install to Gemini only
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --project   # Install to local project
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --all       # Install to all global + project
```

#### Available CLI Options:
* `-g, --global` / `--gemini` / `--claude` / `--opencode`: Target specific global agent configurations.
* `-p, --project`: Install to the current project's local directory (`.agents/skills`).
* `-a, --all`: Install to both global environments and the local project.
* `-d, --path PATH`: Install to a custom directory.
* `-h, --help`: Show help instructions.

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

---

## License

MIT
