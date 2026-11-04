# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-11-05

First release.

### Added

- `skills/gohead/SKILL.md` — the gohead skill, 4415 bytes: understand the task,
  inspect the codebase, keep changes inside the task's scope, make the smallest
  change that meets it, verify before claiming done. Fixed report formats:
  `Blocker / Impact / Checked / Needed` when blocked, `Status / Changes /
  Checks / Blockers` in the final response.
- `.claude-plugin/marketplace.json` — Claude Code plugin manifest, so the repo
  installs with `/plugin marketplace add akufikri/gohead` and
  `/plugin install gohead@gohead`.
- `install.sh` — symlinks `skills/gohead` into `~/.claude/skills` and
  `~/.agents/skills`, or into explicit directories passed as arguments. A
  symlink keeps installed copies current across `git pull`.
- `tests/run.sh` — static contract checks, three behavioral cases through a
  headless agent, a stacked-cost case, plus `--static`, `--selftest`, and
  `--compare` modes.
- `README.md`, `LICENSE` (MIT).

### Verified

- `./tests/run.sh` — `PASS`, exit 0: `scope`, `already-done`, `blocker`, and
  `stack` all green; the decoy file with a pre-existing bug stayed untouched.
- `./tests/run.sh --selftest` — the assertions reject a dirty tree, a missing
  label, and mis-parsed token counts.
- `./tests/run.sh --static` — frontmatter keys, required section headings, no
  placeholder markers, valid plugin JSON, stack under budget.

### Measured

| Case | Result |
|---|---|
| Stack size | gohead 4415 B + caveman 4678 B + ponytail 3496 B = 12589 B (~3147 tokens) |
| `scope` | in-scope edit only, `Status:` / `Changes:` reported, 584-char final message |
| `stack` | scope held under compression, 4 of 4 report labels survived, 635-char final message |
| Control (no skill) | out-of-scope changes: none, report labels: none |

Token counts are whole-run totals and include the agent's own system context;
the skill's cost is the byte figure above.
