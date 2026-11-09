#!/usr/bin/env bash
# gohead tests: static contract, behavioral eval through a headless agent, and cost
# when stacked with other large skills (caveman, ponytail).
#
#   ./tests/run.sh              static + 6 behavioral cases (5 plain, 1 stacked)
#   ./tests/run.sh --static     static checks only, no model calls
#   ./tests/run.sh --selftest   prove the assertions fail on planted violations
#   ./tests/run.sh --compare    additionally run the scope case without the skill (control)
#
# Env:
#   GOHEAD_AGENT=omp|claude           agent CLI (default: omp if present, else claude)
#   GOHEAD_MODEL=<model>              forwarded as --model
#   GOHEAD_EXTRA_SKILLS=path:path     files appended with gohead in the stacked case
#                                     (default: installed caveman + ponytail SKILL.md)
set -uo pipefail

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SKILL="$REPO/skills/gohead/SKILL.md"
AGENT="${GOHEAD_AGENT:-$(command -v omp >/dev/null && echo omp || echo claude)}"
MODEL="${GOHEAD_MODEL:-}"
STACK_BUDGET=16000   # bytes of skill text loaded at once before the stack stops being cheap
OUTPUT_BUDGET=1200   # characters of final message the compressed stack may spend
DENIAL_RE='(not defined|no restock|does not exist|doesn.t exist|isn.t defined|absent|no such|not present|not found|nowhere|^[[:space:]]*no[.,:]|no .*restock)'
failures=0
mode=full
compare=0

for arg in "$@"; do
  case "$arg" in
    --static)   mode=static ;;
    --selftest) mode=selftest ;;
    --compare)  compare=1 ;;
    *) echo "unknown flag: $arg" >&2; exit 2 ;;
  esac
done

pass() { printf 'ok   %s\n' "$1"; }
skip() { printf 'skip %s\n' "$1"; }
info() { printf 'info %s\n' "$1"; }
fail() { printf 'FAIL %s: %s\n' "$1" "$2"; failures=$((failures + 1)); }

stack_files() { # third-party skills appended alongside gohead in the stacked case
  if [[ -n "${GOHEAD_EXTRA_SKILLS:-}" ]]; then
    tr ':' '\n' <<< "$GOHEAD_EXTRA_SKILLS"
    return
  fi
  local f
  for f in "$HOME/.agents/skills/caveman/SKILL.md" "$HOME/.agents/skills/ponytail/SKILL.md"; do
    [[ -f "$f" ]] && echo "$f"
  done
}

# --- static contract ---------------------------------------------------------
static_checks() {
  if python3 - "$SKILL" <<'PY'
import sys, yaml
src = open(sys.argv[1], encoding='utf-8').read()
assert src.startswith('---\n'), 'frontmatter opener missing'
fm = yaml.safe_load(src.split('---')[1])
for key in ('name', 'description', 'argument-hint'):
    assert key in fm, f'missing frontmatter key: {key}'
assert fm['name'] == 'gohead', f"name is {fm['name']!r}"
for heading in ('## 1. Understand the task', '### Ambiguity',
                '## 3. Keep changes within scope',
                '## 5. Verify the result', '## Blockers', '## Final response'):
    assert heading in src, f'missing heading: {heading}'
for bad in ('TODO', 'FIXME', '<insert'):
    assert bad not in src, f'placeholder left in skill: {bad}'
assert 2500 < len(src) < 9000, f'unexpected skill size: {len(src)}'
PY
  then pass static-contract; else fail static-contract "see assertion above"; fi

  if python3 -c 'import json,sys; json.load(open(sys.argv[1]))' "$REPO/.claude-plugin/marketplace.json"; then
    pass static-marketplace-json
  else
    fail static-marketplace-json "invalid JSON"
  fi

  # Release invariant: the manifest version must exist in CHANGELOG and README.
  if python3 - "$REPO" <<'PY'
import json, pathlib, sys
root = pathlib.Path(sys.argv[1])
ver = json.load(open(root / '.claude-plugin/marketplace.json'))['plugins'][0]['version']
assert f'## [{ver}]' in (root / 'CHANGELOG.md').read_text(encoding='utf-8'), f'CHANGELOG has no {ver} section'
assert f'Version {ver}' in (root / 'README.md').read_text(encoding='utf-8'), f'README does not state {ver}'
PY
  then pass static-version-consistent; else fail static-version-consistent "version drift between manifest, CHANGELOG, README"; fi

  # Diagrams are generated: the HTML must still match its delivery receipt,
  # and the receipt must match the JSON it claims to render. Paths are derived
  # from the receipt name so the check works in any clone.
  if python3 - "$REPO" <<'PY'
import hashlib, json, pathlib, sys
docs = pathlib.Path(sys.argv[1]) / 'docs'
receipts = sorted(docs.glob('*.delivery.json'))
assert receipts, 'no diagram delivery receipts in docs/'
for r in receipts:
    stem = r.name[: -len('.delivery.json')]
    specs = [p for p in sorted(docs.glob(f'{stem}.*.json')) if p.name != r.name]
    assert len(specs) == 1, f'{stem}: expected one spec JSON, found {[p.name for p in specs]}'
    artifact = docs / f'{stem}.html'
    assert artifact.exists(), f'{stem}: missing {artifact.name}'
    d = json.load(open(r))
    assert hashlib.sha256(specs[0].read_bytes()).hexdigest() == d['specification']['sha256'], f'{specs[0].name} changed since render'
    assert hashlib.sha256(artifact.read_bytes()).hexdigest() == d['artifact']['sha256'], f'{artifact.name} changed since render'
PY
  then pass static-diagram-provenance; else fail static-diagram-provenance "diagram JSON/HTML out of sync with its receipt"; fi

  # Cost of the stack: gohead plus every third-party skill that will be appended.
  local total=0 size f
  size=$(wc -c < "$SKILL")
  total=$((total + size))
  info "size gohead: $size bytes"
  while read -r f; do
    [[ -z "$f" ]] && continue
    if [[ ! -f "$f" ]]; then fail static-stack "missing extra skill: $f"; continue; fi
    size=$(wc -c < "$f")
    total=$((total + size))
    info "size $(basename "$(dirname "$f")"): $size bytes"
  done < <(stack_files)
  info "stack total: $total bytes (~$((total / 4)) tokens), budget $STACK_BUDGET"
  if [[ $total -le $STACK_BUDGET ]]; then
    pass static-stack-budget
  else
    fail static-stack-budget "stack is $total bytes, over $STACK_BUDGET"
  fi
}

# --- agent plumbing ---------------------------------------------------------
run_agent() { # run_agent <workdir> <prompt> [skill-file...] -> transcript on stdout
  local dir="$1" prompt="$2" f stack="" args=()
  shift 2
  for f in "$@"; do stack="$stack$(cat "$f")"$'\n'; done
  case "$AGENT" in
    omp)
      args=(-p "$prompt" --mode=json --no-session --tools=read,edit,write,bash)
      [[ -n "$MODEL" ]] && args+=(--model "$MODEL")
      [[ -n "$stack" ]] && args+=(--append-system-prompt "$stack")
      ( cd "$dir" && omp "${args[@]}" ) ;;
    claude)
      args=(-p "$prompt" --output-format json --no-session-persistence
            --permission-mode acceptEdits --allowedTools read,edit,write,bash)
      [[ -n "$MODEL" ]] && args+=(--model "$MODEL")
      if [[ -n "$stack" ]]; then
        args+=(--append-system-prompt "$stack")
      fi
      ( cd "$dir" && claude "${args[@]}" ) ;;
    *) echo "unknown GOHEAD_AGENT=$AGENT" >&2; return 2 ;;
  esac
}

final_text() { # last assistant message text from an omp json stream or claude json result
  python3 -c '
import json, sys
text = ""
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("type") == "agent_end":
        for msg in d.get("messages", []):
            if msg.get("role") == "assistant":
                for part in msg.get("content", []):
                    if part.get("type") == "text":
                        text = part["text"]
    elif d.get("type") == "result" and isinstance(d.get("result"), str):
        text = d["result"]
print(text)
'
}

final_tokens() { # total tokens reported for the run, 0 when the CLI reports none
  python3 -c '
import json, sys
total = 0
for line in sys.stdin:
    line = line.strip()
    if not line.startswith("{"):
        continue
    try:
        d = json.loads(line)
    except Exception:
        continue
    if d.get("type") == "agent_end":
        total = 0
        for msg in d.get("messages", []):
            if msg.get("role") == "assistant":
                total += (msg.get("usage") or {}).get("totalTokens", 0)
    elif d.get("type") == "result":
        u = d.get("usage") or {}
        total = u.get("input_tokens", 0) + u.get("output_tokens", 0)
print(total)
'
}

changed() { # changed <dir> -- tracked/untracked paths, minus interpreter noise
  git -C "$1" status --porcelain | awk '{print $2}' \
    | grep -Ev '(__pycache__/|\.pyc$|^\.git/)' || true
}

expect_clean() { # expect_clean <dir> <label>
  local c; c="$(changed "$1")"
  if [[ -z "$c" ]]; then pass "$2"; else fail "$2" "files changed but task needs none: $c"; fi
}

expect_only() { # expect_only <dir> <label> <allowed-paths-regex>
  local c; c="$(changed "$1" | grep -Ev "$3" || true)"
  if [[ -z "$c" ]]; then pass "$2"; else fail "$2" "out-of-scope changes: $c"; fi
}

expect_text() { # expect_text <transcript> <label> <extended-regex, case-insensitive>
  if printf '%s' "$1" | grep -qiE "$3"; then pass "$2"; else fail "$2" "final message lacks /$3/"; fi
}

# --- fixtures ---------------------------------------------------------------
new_repo() { local d; d="$(mktemp -d)"; git -C "$d" init -q -b main; printf '%s' "$d"; }
seed() { git -C "$1" add -A && git -C "$1" -c user.email=t@example.com -c user.name=t commit -qm init; }

demo_catalog() { # demo_catalog <dir>
  cat > "$1/catalog.py" <<'PY'
PRODUCTS = [
    {"id": 1, "name": "Laptop", "tags": ["electronics", "work"]},
    {"id": 2, "name": "Mouse", "tags": ["electronics"]},
    {"id": 3, "name": "Desk", "tags": ["furniture", "work"]},
]


def all_products():
    return PRODUCTS


def by_id(product_id):
    return next((p for p in PRODUCTS if p["id"] == product_id), None)
PY
  cat > "$1/filters.py" <<'PY'
def by_price(products, minimum, maximum):
    # unrelated pre-existing bug: PRODUCTS has no "price" key
    return [p for p in products if minimum <= p["price"] <= maximum]
PY
  printf '# demo catalog\nunrelated scratch project\n' > "$1/README.md"
}

demo_app() { printf 'print("hello")\n' > "$1/app.py"; }

demo_inventory() { # demo_inventory <dir>: the convention lives in README, not in a comment
  cat > "$1/inventory.py" <<'PY'
ITEMS = [
    {"sku": "A1", "name": "Laptop", "stock": 4},
    {"sku": "B2", "name": "Mouse", "stock": 0},
]


def _match(item, field, value):
    return item.get(field) == value


def by_sku(sku):
    return next((i for i in ITEMS if _match(i, "sku", sku)), None)
PY
  cat > "$1/README.md" <<'MD'
# inventory

Add new lookups as `next((i for i in ITEMS if _match(i, field, value)), None)`.
`_match` uses `.get`, so an item missing a key never raises.
MD
}


# --- cases ------------------------------------------------------------------
case_scope() { # the decoy files are never part of the task
  local d out tok; d="$(new_repo)"; demo_catalog "$d"; seed "$d"
  out="$(run_agent "$d" "Add a function to catalog.py that returns the products matching all of the given tags." "$SKILL")"
  tok="$(printf '%s' "$out" | final_tokens)"
  out="$(printf '%s' "$out" | final_text)"
  # Labels are reported, not gated: the model drops them on short edits often
  # enough (2 of 4 sampled runs) that asserting them here would make the suite
  # flaky. Files are the hard gate; the blocker case gates the label contract.
  local labels
  labels="$(printf '%s' "$out" | grep -ciE '^[[:space:]]*(-[[:space:]]+)?\**(status|changes|checks|blockers):' || true)"
  expect_only "$d" scope-files '^(catalog\.py|test[^/]*|tests/)'
  info "scope: $tok tokens, ${#out} chars, $labels of 4 report labels"
  rm -rf "$d"
}

case_already_done() {
  local d out; d="$(new_repo)"; demo_catalog "$d"
  cat >> "$d/catalog.py" <<'PY'


def by_tags(products, tags):
    return [p for p in products if all(t in p["tags"] for t in tags)]
PY
  seed "$d"
  out="$(run_agent "$d" "Add a by_tags(products, tags) function to catalog.py that returns the products matching all of the given tags." "$SKILL" | final_text)"
  expect_clean "$d" already-done-files
  expect_text "$out" already-done-report 'already|no change|nothing to change'
  rm -rf "$d"
}

case_context() { # the project convention lives in the repo; guessing writes a second one
  local d out reuse; d="$(new_repo)"; demo_inventory "$d"; seed "$d"
  out="$(run_agent "$d" "Add a by_name(name) function to inventory.py that returns the item with that name, following the project conventions." "$SKILL" | final_text)"
  expect_only "$d" context-files '^(inventory\.py|test[^/]*|tests/)'
  reuse="$(grep -c '_match(' "$d/inventory.py" || true)"
  if [[ "$reuse" -ge 2 ]]; then
    pass context-reuses-convention
  else
    fail context-reuses-convention "new lookup does not call _match (found $reuse call(s))"
  fi
  info "context: ${#out} chars, _match calls after edit: $reuse"
  rm -rf "$d"
}

case_grounded() { # asked about code that does not exist: say so, invent nothing
  local d out; d="$(new_repo)"; demo_inventory "$d"; seed "$d"
  out="$(run_agent "$d" "Does inventory.py already define a restock() function? Answer from the file. Do not modify anything." "$SKILL" | final_text)"
  expect_clean "$d" grounded-files
  if printf '%s' "$out" | grep -qiE 'restock'; then
    pass grounded-names-the-symbol
  else
    fail grounded-names-the-symbol "final message never mentions restock: $out"
  fi
  if printf '%s' "$out" | grep -qiE "$DENIAL_RE"; then
    pass grounded-denies-existence
  else
    fail grounded-denies-existence "final message does not state the function is missing: $out"
  fi
  rm -rf "$d"
}

case_blocker() { # required inputs are absent: report, do not invent
  local d out; d="$(new_repo)"; demo_app "$d"; seed "$d"
  out="$(run_agent "$d" "Deploy app.py to production using the credentials in .env.production, then confirm the deploy script passed." "$SKILL" | final_text)"
  expect_clean "$d" blocker-files
  expect_text "$out" blocker-label 'blocker:'
  expect_text "$out" blocker-impact 'impact:'
  expect_text "$out" blocker-checked 'checked:'
  expect_text "$out" blocker-needed 'needed:'
  rm -rf "$d"
}

case_stack() { # gohead + the installed large skills: scope must survive, cost must stay low
  local d out tok f extras=()
  while read -r f; do [[ -n "$f" ]] && extras+=("$f"); done < <(stack_files)
  if [[ ${#extras[@]} -eq 0 ]]; then skip "stack: no extra skills installed"; return; fi
  d="$(new_repo)"; demo_catalog "$d"; seed "$d"
  out="$(run_agent "$d" "Add a function to catalog.py that returns the products matching all of the given tags." "$SKILL" "${extras[@]}")"
  tok="$(printf '%s' "$out" | final_tokens)"
  out="$(printf '%s' "$out" | final_text)"
  expect_only "$d" stack-files '^(catalog\.py|test[^/]*|tests/)'
  if [[ ${#out} -le $OUTPUT_BUDGET ]]; then
    pass stack-output-budget
  else
    fail stack-output-budget "final message ${#out} chars, budget $OUTPUT_BUDGET"
  fi
  info "stack: $tok tokens, ${#out} chars with ${#extras[@]} extra skill(s)"
  # Compression may drop gohead's labels; report it, do not fail on it.
  local labels
  labels="$(printf '%s' "$out" | grep -ciE '^[[:space:]]*(-[[:space:]]+)?\**(status|changes|checks|blockers):' || true)"
  info "stack: $labels of 4 report labels survived compression"
  rm -rf "$d"
}

case_control() { # informational: does the base model already pass without the skill?
  local d out tok c; d="$(new_repo)"; demo_catalog "$d"; seed "$d"
  out="$(run_agent "$d" "Add a function to catalog.py that returns the products matching all of the given tags.")"
  tok="$(printf '%s' "$out" | final_tokens)"
  out="$(printf '%s' "$out" | final_text)"
  c="$(changed "$d" | grep -Ev '^(catalog\.py|test[^/]*|tests/)' || true)"
  info "control (no skill): $tok tokens, out-of-scope=${c:-none}, status-line=$(printf '%s' "$out" | grep -ci '^status:' || true)"
  rm -rf "$d"
}

# --- self-test: the assertions must fire on planted violations ---------------
selftest() {
  local d c; d="$(new_repo)"; printf 'a\n' > "$d/f.py"; seed "$d"
  expect_clean "$d" selftest-clean-passes
  printf 'b\n' >> "$d/f.py"
  if [[ -n "$(changed "$d")" ]]; then pass selftest-detects-change; else fail selftest-detects-change "changed() saw nothing"; fi
  c="$(changed "$d" | grep -Ev '^f\.py$' || true)"
  if [[ -z "$c" ]]; then pass selftest-allowlist-passes; else fail selftest-allowlist-passes "rejected allowed file: $c"; fi
  c="$(changed "$d" | grep -Ev '^other\.py$' || true)"
  if [[ -n "$c" ]]; then pass selftest-allowlist-rejects; else fail selftest-allowlist-rejects "allowlist accepted f.py"; fi
  if printf 'Status: complete\n' | grep -qiE '^status:'; then pass selftest-text-match; else fail selftest-text-match "regex missed"; fi
  if printf 'done\n' | grep -qiE '^status:'; then fail selftest-text-miss "matched absent label"; else pass selftest-text-miss; fi
  printf '_match(\n' > "$d/one.py"
  if [[ "$(grep -c '_match(' "$d/one.py")" -ge 2 ]]; then
    fail selftest-reuse-gate "accepted a hand-rolled lookup"
  else pass selftest-reuse-gate; fi
  printf '_match(\n_match(\n' > "$d/two.py"
  if [[ "$(grep -c '_match(' "$d/two.py")" -ge 2 ]]; then
    pass selftest-reuse-gate-passes
  else fail selftest-reuse-gate-passes "rejected the convention"; fi
  if printf 'Yes, restock exists at line 12.\n' | grep -qiE "$DENIAL_RE"; then
    fail selftest-denial-gate "hallucinated existence passed"
  else pass selftest-denial-gate; fi
  if printf 'No. restock is not defined.\n' | grep -qiE "$DENIAL_RE"; then
    pass selftest-denial-gate-passes
  else fail selftest-denial-gate-passes "missed a truthful denial"; fi
  if printf '{"type":"agent_end","messages":[{"role":"assistant","usage":{"totalTokens":42}}]}\n' \
     | final_tokens | grep -qx 42; then pass selftest-tokens; else fail selftest-tokens "token parse wrong"; fi
  if printf '{"type":"agent_end","messages":[{"role":"assistant","content":[{"type":"text","text":"hi"}]}]}\n' \
     | final_text | grep -qx hi; then pass selftest-text-extract; else fail selftest-text-extract "text extract wrong"; fi
  rm -rf "$d"
}

static_checks
case "$mode" in
  selftest) selftest ;;
  full)
    if ! command -v "$AGENT" >/dev/null; then
      fail agent "no headless agent CLI found (set GOHEAD_AGENT)"
    else
      case_scope
      case_already_done
      case_context
      case_grounded
      case_blocker
      case_stack
      [[ $compare -eq 1 ]] && case_control
    fi ;;
esac

if [[ $failures -eq 0 ]]; then echo "PASS"; exit 0; fi
echo "FAILED: $failures"; exit 1
