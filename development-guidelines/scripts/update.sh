#!/bin/bash
# development-guidelines updater (v2)
#
# The framework is replaceable: this script removes development-guidelines/ and
# unpacks the requested version in its place. There is no allowlist and no merge,
# because the directory has exactly one owner.
#
# Project-owned state lives in project/ and is never touched.
#
# Usage:
#   ./development-guidelines/scripts/update.sh              # latest main
#   ./development-guidelines/scripts/update.sh --to v2.1.0  # a specific tag

set -euo pipefail

REPO_URL="git@github.com:jpurnell/development-guidelines.git"
DG_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_ROOT="$(dirname "$DG_DIR")"
TARGET="main"

while [ $# -gt 0 ]; do
    case "$1" in
        --to) TARGET="$2"; shift 2 ;;
        *) echo "unknown argument: $1" >&2; exit 2 ;;
    esac
done

TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

echo "=== development-guidelines updater ==="
if [ -f "$DG_DIR/.framework-version" ]; then
    echo "Current: $(grep '^version:' "$DG_DIR/.framework-version" | awk '{print $2}')"
fi
echo "Target:  $TARGET"

if ! git clone --quiet --depth 1 --branch "$TARGET" "$REPO_URL" "$TEMP_DIR/dg" 2>/dev/null; then
    git clone --quiet "$REPO_URL" "$TEMP_DIR/dg"
    git -C "$TEMP_DIR/dg" checkout --quiet "$TARGET"
fi

# --- refuse to clobber unknown content -------------------------------------
# A file here that upstream does not ship is either a local edit or a
# locally-authored rule. Both are worth keeping; neither may be silently deleted.
# This is the only mechanism that can detect such a file, because the directory
# is gitignored and so never appears in `git status`.
DIVERGED=0
while IFS= read -r -d '' f; do
    rel="${f#"$DG_DIR/"}"
    case "$rel" in .git/*|.framework-version|.DS_Store|*/.DS_Store) continue ;; esac
    if [ ! -e "$TEMP_DIR/dg/$rel" ]; then
        [ "$DIVERGED" -eq 0 ] && printf '\nLOCAL CONTENT NOT PRESENT UPSTREAM:\n'
        echo "  $rel"
        DIVERGED=1
    elif ! cmp -s "$f" "$TEMP_DIR/dg/$rel"; then
        [ "$DIVERGED" -eq 0 ] && printf '\nLOCAL CONTENT NOT PRESENT UPSTREAM:\n'
        echo "  $rel (modified)"
        DIVERGED=1
    fi
done < <(find "$DG_DIR" -type f -not -path "$DG_DIR/.git/*" -print0)

if [ "$DIVERGED" -eq 1 ]; then
    printf '\nRefusing to update: the above would be lost.\n'
    echo "Upstream them, or move them to project/, then re-run."
    exit 1
fi

# --- replace wholesale -----------------------------------------------------
SHA=$(git -C "$TEMP_DIR/dg" rev-parse --short HEAD)
rm -rf "$TEMP_DIR/dg/.git"
rm -rf "$DG_DIR"
mkdir -p "$DG_DIR"
cp -R "$TEMP_DIR/dg/." "$DG_DIR/"

cat > "$DG_DIR/.framework-version" <<EOF
version: $TARGET
commit:  $SHA
applied: $(date +%Y-%m-%d)
source:  jpurnell/development-guidelines
EOF

# --- reinstall skills where Claude Code discovers them ----------------------
# development-guidelines/skills/ is storage; .claude/skills/ is discovery.
# Framework skills are installed by name so project-authored skills survive.
if [ -d "$DG_DIR/skills" ]; then
    mkdir -p "$PROJECT_ROOT/.claude/skills"
    for s in "$DG_DIR"/skills/*/; do
        n=$(basename "$s")
        rm -rf "$PROJECT_ROOT/.claude/skills/$n"
        ln -s "../../development-guidelines/skills/$n" "$PROJECT_ROOT/.claude/skills/$n"
    done
fi

printf '\nUpdated to %s (%s).\n' "$TARGET" "$SHA"
echo "  rules:  $(ls "$DG_DIR"/rules/*.md 2>/dev/null | wc -l | tr -d ' ')"
echo "  skills: $(ls -d "$DG_DIR"/skills/*/ 2>/dev/null | wc -l | tr -d ' ')"
echo "  project/ untouched."
