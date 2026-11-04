#!/usr/bin/env bash
# Symlink the gohead skill into agent skill directories.
#   ./install.sh                    # ~/.claude/skills and ~/.agents/skills
#   ./install.sh ~/.codex/skills    # explicit targets instead
set -euo pipefail

repo="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
targets=("$HOME/.claude/skills" "$HOME/.agents/skills")
[[ $# -gt 0 ]] && targets=("$@")

for dir in "${targets[@]}"; do
  mkdir -p "$dir"
  ln -sfn "$repo/skills/gohead" "$dir/gohead"
  echo "linked $dir/gohead -> $repo/skills/gohead"
done
