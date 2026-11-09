# Changelog

All notable changes to this project are documented here.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.1.4] - 2026-11-09

### Changed

- Ambiguity handling is now an explicit section instead of a sentence spread
  over two paragraphs. The skill splits it into two tiers decided before the
  first edit: material ambiguity (the reading changes the design, the files or
  an interface — stop and ask, naming the competing readings) and minor
  ambiguity (proceed on the most reasonable assumption and state it in the
  final response). Resolving ambiguity by widening the task stays forbidden,
  and a decision that blocks a safe change goes through the Blockers format.
- README's enforcement list states the same rule.
- `static-contract` asserts the `### Ambiguity` section exists, so the rule
  cannot disappear silently in a later edit.

## [1.1.3] - 2026-11-05

### Changed

- Dropped the skills.sh badge from the README. The badge endpoint answers
  `resource not found` for a repo the directory has not indexed yet, so it
  rendered as a broken image; the listing card and the install command stay.
- README states the actual state of distribution: the repo page, the audit and
  `npx skills add akufikri/gohead` work immediately, while search coverage on
  skills.sh follows install telemetry and lags behind. There is no submission
  step.
- `docs/assets/skills-sh.png` re-captured, now showing the first recorded
  install instead of zero.

### Verified

- `npx skills add akufikri/gohead --list` → `Found 1 skill: gohead`.
- `https://www.skills.sh/akufikri/gohead` → `1 skill`, `1 total installs`.
- `https://www.skills.sh/tele/audit?source=akufikri/gohead&skills=gohead` →
  `ath: safe`, `socket: 90`, `snyk: low`.
- `https://skills.sh/api/search?q=gohead` → `count 0` (index not caught up),
  and `https://skills.sh/b/akufikri/gohead` → `resource not found`, which is the
  same lag seen from the other side.

## [1.1.2] - 2026-11-05

### Added

- `docs/assets/skills-sh.png` — the repository's skills.sh listing, captured from
  the live page, embedded under Install so the directory entry is visible
  without leaving the README.

## [1.1.1] - 2026-11-05

### Added

- skills.sh distribution: the repo is installable with `npx skills add akufikri/gohead`
  and carries the skills.sh badge. There is no submission step in that
  directory — a public repo with `skills/SKILL.md` is installable immediately,
  and the listing follows from install telemetry.

### Fixed

- `docs/gohead-flow.workflow.json`: the `Smallest change` node now sets an
  explicit height, so its sublabel is no longer clipped by the node border.
  Diagram re-rendered and re-captured; `static-diagram-provenance` still passes.

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
