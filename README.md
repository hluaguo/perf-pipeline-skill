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

The easiest way to install these skills is to run the automated installation script. 

### Quick Install (via curl)
Run this command in your terminal to launch the interactive installation menu:
```bash
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash
```

### Unattended / Non-Interactive Install
If you are scripting or running in a CI/CD environment, you can pass arguments to the installer:
```bash
# Install globally to all detected agents (Gemini, Claude, OpenCode)
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --global

# Install globally to a specific agent only
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --gemini
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --claude
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --opencode

# Install locally to the current Git project (.agents/skills)
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --project

# Install to both global and local environments
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --all

# Install to a custom directory
curl -fsSL https://raw.githubusercontent.com/hluaguo/perf-pipeline-skill/main/install.sh | bash -s -- --path /path/to/custom/skills
```

### Manual Local Install
If you prefer to clone the repository and run the installer locally:
```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git
cd perf-pipeline-skill
./install.sh
```

#### Available CLI Options:
* `-g, --global`: Install to all detected global agent environments.
* `--gemini`: Install globally to Gemini only.
* `--claude`: Install globally to Claude Code only.
* `--opencode`: Install globally to OpenCode only.
* `-p, --project`: Install to the current project's local agent environment (`.agents/skills`).
* `-a, --all`: Install to both global and project directories.
* `-d, --path PATH`: Install to a custom directory path.
* `-h, --help`: Show the installer usage instructions.

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
