# gohead

Scope-first coding workflow for AI coding agents: understand the task, inspect the codebase, change only what the task needs, report blockers plainly, verify the result.

One skill, one file: [`skills/gohead/SKILL.md`](skills/gohead/SKILL.md).

## Why gohead exists

Agents usually fail coding tasks in three repeatable ways:

1. They do not really read the context they were given — the goal, the constraints, the code around the change.
2. The adjustment lands outside the scope that was asked for: drive-by fixes, unrelated refactors, a workaround instead of the change.
3. After the adjustment nothing is re-checked, so "done" is claimed without evidence.

gohead exists to steer the agent back onto those four steps: **understand, analyse, execute, verify**. Understand the request and the code it touches; analyse what is actually in scope; execute the smallest change that meets it; then check the result before reporting.

## Install

    git clone https://github.com/akufikri/gohead.git
    cd gohead
    ./install.sh

`install.sh` symlinks `skills/gohead` into `~/.claude/skills/` and `~/.agents/skills/`, so `git pull` keeps the installed skill current. Start a new agent session afterwards so the skill is loaded.

Pass explicit directories if your agent reads skills from somewhere else:

    ./install.sh ~/.codex/skills

### Claude Code plugin

    /plugin marketplace add akufikri/gohead
    /plugin install gohead@gohead

## Use

Say `Gohead`, or ask for a scoped coding change. Invoked as a command it takes a task argument: `/gohead [coding task]`.

## What it enforces

- Understand goal, in-scope behavior and constraints before editing.
- Inspect existing code and conventions; reuse them instead of adding abstractions.
- Change only code the task needs — no drive-by fixes, cleanup, or refactors.
- Report blockers as **Blocker / Impact / Checked / Needed** instead of guessing.
- Verify, then report **Status / Changes / Checks / Blockers**.

## Tests

    ./tests/run.sh              # static contract + 4 behavioral cases
    ./tests/run.sh --static     # static only, no model calls
    ./tests/run.sh --selftest   # prove the assertions fire on planted violations
    ./tests/run.sh --compare    # extra control run without the skill

Each behavioral case runs a headless agent in a throwaway git repo and judges only observable results:

| Case | What is asserted |
|---|---|
| `scope` | The edit stays inside the asked-for file; the decoy file with a pre-existing bug is untouched; the report uses `Status:` / `Changes:`. |
| `already-done` | A task whose behavior already exists produces no file changes and says so. |
| `blocker` | Missing inputs are reported as `Blocker / Impact / Checked / Needed`, and nothing is invented. |
| `stack` | Loaded together with the installed `caveman` and `ponytail` skills, the edit still stays in scope and the final message stays under 1200 characters. |

The stacked case measures cost: it prints the skill-stack size in bytes and tokens, the run's token count, and how many of gohead's four report labels survived compression. Those numbers are informational — compression is allowed to change the wording, not the scope.

Requirements: `python3` with `yaml`, and either `omp` (default) or `claude` with `ANTHROPIC_API_KEY`. Override with `GOHEAD_AGENT=claude`, `GOHEAD_MODEL=<model>`, and `GOHEAD_EXTRA_SKILLS=path:path` to stack different skills.

## License

MIT
