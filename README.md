# perf-pipeline

Multi-agent performance optimization pipeline for opencode.

Decomposes a codebase into modules, launches subagents per module to find all performance issues, collates and ranks candidates, validates the top 1-3, and submits PR-ready branches with inline source citations.

## Install

```bash
# Clone into opencode's skill directory
git clone https://github.com/hluaguo/perf-pipeline-skill.git \
  ~/.config/opencode/skills/perf-pipeline
```

Or add as a project skill:

```bash
git clone https://github.com/hluaguo/perf-pipeline-skill.git \
  .opencode/skills/perf-pipeline
```

Restart opencode after installing.

## Trigger

Ask opencode to "optimize performance", "profile this codebase", "find bottlenecks", or "run a performance audit".

## Pipeline

```
ARCHITECT -> INVESTIGATE -> COLLATE -> VALIDATE -> AUDIT -> SUBMIT
   (1)          (N agents)     (1)        (top 3)     (1)       (1)
```

## License

MIT
