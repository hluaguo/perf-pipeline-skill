# perf-pipeline

A language-agnostic, multi-agent performance optimization pipeline. An
orchestrator decomposes a codebase into modules, launches one subagent per
module to find every performance issue, collates and ranks candidates,
validates the top 1-3 through a five-stage correctness/safety/scope gate,
and produces PR-ready branches with inline citations from official sources.

```
ARCHITECT  ──>  INVESTIGATE  ──>  COLLATE  ──>  VALIDATE  ──>  AUDIT  ──>  SUBMIT
   (1)          (N agents)        (1)          (top 3)        (1)        (1)
```

## Use with any LLM orchestrator

Copy the contents of `SKILL.md` into the system prompt or agent instructions
of an LLM that can spawn subagents. The orchestrator reads the codebase tree,
delegates investigation to subagents, and follows the validation gates before
submitting.

Works with any language, build system, and VCS — the pipeline only assumes:

- A source tree decomposable into independently buildable modules (≤ ~20 files each)
- A build command per module
- A test command per module
- A version control system with branches

## Install as an opencode skill

```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git \
  ~/.config/opencode/skills/perf-pipeline
```

Restart opencode. The skill triggers when you ask to "optimize performance",
"profile the codebase", "find bottlenecks", or "run a performance audit".

## Install as a Claude Code / Codex skill

```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git \
  ~/.claude/skills/perf-pipeline
```

## Phases

### 1. ARCHITECT
Read the source tree. Split into modules (build targets, ≤ ~20 files each).
Present the decomposition to the user.

### 2. INVESTIGATE
Launch one subagent per module on its own branch (`opt/<module>-deep`).
Each subagent reads every file, flags 8 known performance patterns, benchmarks
before/after, and returns a structured report of all findings (valid + invalid).

### 3. COLLATE
Merge reports, deduplicate, classify by pattern, score by
`delta_percent / sqrt(|lines_changed|)`, and select the top 1-3 candidates.

### 4. VALIDATE
Five-stage gate per candidate (on `validate/<fix-slug>` from `main`):

| Stage | Question |
|-------|----------|
| 4a. ISOLATE | Is the diff clean and minimal? (< 200 lines, < 5 files) |
| 4b. CORRECT | Does optimized code produce identical output? |
| 4c. MEASURE | Is the improvement real and statistically significant? |
| 4d. SAFETY | Thread safety, memory, errors, API — any hidden hazards? |
| 4e. SCOPE | Do all callers still build, test, and behave correctly? |

Decision: PASS (proceed), WARN (proceed with caveat), or DROP.

### 5. AUDIT
Full regression suite. Every claim in the PR body backed by an inline citation
from an authoritative source (man page, language spec, framework docs).

### 6. SUBMIT
Push the validated branch. Open a self-contained PR.

## Rules

- One module per subagent — never share branches
- All throwaway artifacts to `/tmp/<fix-slug>/` — never committed
- Never validate on investigation branches — always branch from `main`
- Release-build benchmarks only
- Cite an authoritative source for every lock removal
- PR body must be self-contained — the maintainer reads one page

## License

MIT
