#!/bin/bash
# Path-based completeness check: every project .md in the pre-migration tree must
# exist somewhere under project/. Counting totals can balance by coincidence.
P="$1"; cd "$P" || exit 1
[ -d development-guidelines.pre-v2 ] || exit 0
MISSING=0
while IFS= read -r f; do
  b=$(basename "$f")
  case "$b" in
    CLAUDE.md|README.md|TEMPLATE.md|SESSION_SUMMARY_TEMPLATE.md|CAPABILITY_MAP_TEMPLATE.md) continue ;;
    DEVELOPMENT_WORKFLOW_TUTORIAL.md|playgroundFormat.md) continue ;;
  esac
  case "$f" in
    */00_CORE_RULES/*|*/.claude/*|*/.git/*|*/03_STRATEGIES_AND_FRAMEWORKS/*|*/templates/*|*/scripts/*) continue ;;
  esac
  find project -name "$b" -type f 2>/dev/null | grep -q . || { echo "    STRANDED: ${f#development-guidelines.pre-v2/}"; MISSING=$((MISSING+1)); }
done < <(find development-guidelines.pre-v2 -name '*.md' -not -path '*/.git/*')
[ "$MISSING" -gt 0 ] && echo "  $(basename "$P"): $MISSING stranded" || echo "  $(basename "$P"): complete"
