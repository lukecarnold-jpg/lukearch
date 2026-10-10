#!/usr/bin/env bash
# Regenerates the file tree in STRUCTURE.md from the tracked files.
# CI runs this script and fails if STRUCTURE.md changes, so run it after
# adding, moving, or removing tracked files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
STRUCTURE="$REPO_ROOT/STRUCTURE.md"
START_MARKER='<!-- tree:start -->'
END_MARKER='<!-- tree:end -->'

if ! grep -qF "$START_MARKER" "$STRUCTURE" || ! grep -qF "$END_MARKER" "$STRUCTURE"; then
  echo "Missing tree markers in $STRUCTURE" >&2
  exit 1
fi

tree_file="$(mktemp)"
trap 'rm -f "$tree_file" "$STRUCTURE.tmp"' EXIT

cd "$REPO_ROOT"

# The C locale keeps the sort order identical on every host.
LC_ALL=C git ls-files | LC_ALL=C sort | awk -F/ '
function indent(level,   s, j) {
  s = ""
  for (j = 1; j < level; j++) s = s "  "
  return s
}
{
  dirs = ""
  for (i = 1; i < NF; i++) {
    dirs = dirs $i "/"
    if (!(dirs in seen)) {
      seen[dirs] = 1
      printf "%s%s/\n", indent(i), $i
    }
  }
  printf "%s%s\n", indent(NF), $NF
}' > "$tree_file"

awk -v start="$START_MARKER" -v end="$END_MARKER" -v tree="$tree_file" '
index($0, start) {
  print
  print "```text"
  while ((getline line < tree) > 0) print line
  close(tree)
  print "```"
  skip = 1
  next
}
index($0, end) { skip = 0 }
!skip { print }
' "$STRUCTURE" > "$STRUCTURE.tmp"

mv "$STRUCTURE.tmp" "$STRUCTURE"
echo "Updated tree in STRUCTURE.md"
