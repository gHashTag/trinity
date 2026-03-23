#!/usr/bin/env bash
# Move stray Verilog (*.v) from repository root into hardware/rtl-root.
# If a file with the same name already exists there, goes to stray-from-root/.
# Run from repo root: npm run sweep-rtl   OR   bash scripts/move-root-rtl-to-fpga.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
primary="hardware/rtl-root"
fallback="$primary/stray-from-root"
mkdir -p "$primary" "$fallback"
shopt -s nullglob
moved=0
for f in *.v; do
  if [[ -e "$primary/$f" ]]; then
    echo "Target exists: $primary/$f → using $fallback/"
    dest="$fallback"
  else
    dest="$primary"
  fi
  echo "Moving $f -> $dest/"
  if git mv "$f" "$dest/" 2>/dev/null; then
    :
  else
    mv "$f" "$dest/"
  fi
  moved=$((moved + 1))
done
shopt -u nullglob
if [[ "$moved" -eq 0 ]]; then
  echo "No *.v files in repo root."
else
  echo "Done. Moved $moved file(s). Then: git add hardware/rtl-root && git status"
fi
