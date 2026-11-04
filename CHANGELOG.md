# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.0] - 2026-11-05

### Added

- `docs/gohead-flow.workflow.json` and `docs/gohead-flow.html` — the skill's flow
  as an interactive Archify diagram: three gates, the "nothing to change" exit,
  the out-of-scope exit, the regression return, and the blocker report.
- `docs/gohead-impact.architecture.json` and `docs/gohead-impact.html` — the
  impact map: every gate next to the behavioral case in `tests/run.sh` that
  proves it, with the measured numbers in cards.
- `docs/assets/*.png` — the two diagrams as images, embedded in the README.
- `docs/*.delivery.json` — render receipts recording the spec and artifact
  hashes, so a diagram cannot silently drift from its JSON.

### Changed

- `README.md` gains "The flow", "What it changes" and "Diagrams" sections,
  including the baseline comparison and its honest limit.
- `tests/run.sh --static` now also checks `static-diagram-provenance`: each
  shipped HTML must hash-match its delivery receipt, and each receipt must
  hash-match the JSON it renders. Paths are derived from the receipt name, so
  the check also passes in a fresh clone.
- `tests/run.sh`: the `already-done` prompt now names the exact function and
  signature that already exists. The old wording ("add tag search") let the
  model justify a rewrite, which failed the case once; naming the signature
  removes the ambiguity the skill itself asks about.
- `tests/run.sh`: report-label presence on the `scope` case is now reported as
  an `info` rate instead of a hard gate. Sampled four times on the same fixture,
  the model produced the section labels in two runs and prose in two, so the
  gate was measuring model variance rather than scope discipline. Files remain
  the hard gate, and the `blocker` case still gates the Blocker / Impact /
  Checked / Needed format.

### Verified

- `./tests/run.sh` — `PASS`: static contract, provenance, and all four
  behavioral cases; `--compare` additionally reports the baseline.
- `./tests/run.sh --static` — `PASS`, including provenance, and it fires on a
  tampered HTML (`FAIL static-diagram-provenance`).
- No skill text changed in this release (still 4,415 bytes).

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
