#!/bin/bash
# Migrate a project from the v1 development-guidelines layout to v2.
#
#   v1: development-guidelines/{00_CORE_RULES,01_ROADMAPS,...}  — framework and
#       project state intermixed, project state often gitignored and therefore
#       backed up nowhere.
#
#   v2: development-guidelines/  — framework only, gitignored, replaceable
#       project/                 — project-owned, tracked in THIS repo
#
# Nothing is deleted. The pre-migration tree is preserved as
# development-guidelines.pre-v2/ and removed only by an explicit later step.
#
# Usage: migrate-to-v2.sh <project-dir> [--framework <path-to-source-checkout>] [--dry-run]

set -euo pipefail

PROJECT=""; FRAMEWORK=""; DRY=0
while [ $# -gt 0 ]; do
    case "$1" in
        --framework) FRAMEWORK="$2"; shift 2 ;;
        --dry-run)   DRY=1; shift ;;
        *)           PROJECT="$1"; shift ;;
    esac
done
[ -n "$PROJECT" ] || { echo "usage: migrate-to-v2.sh <project-dir> [--framework <path>] [--dry-run]" >&2; exit 2; }
PROJECT="$(cd "$PROJECT" && pwd)"
DG="$PROJECT/development-guidelines"
[ -d "$DG" ] || { echo "no development-guidelines/ in $PROJECT" >&2; exit 1; }
[ -d "$PROJECT/project" ] && { echo "project/ already exists — already migrated?" >&2; exit 1; }

REPORT="$PROJECT/MIGRATION_REPORT.md"
say() { [ "$DRY" -eq 1 ] && echo "  [dry] $*" || echo "  $*"; }
run() { [ "$DRY" -eq 1 ] || eval "$@"; }

echo "=== migrate-to-v2: $(basename "$PROJECT") ==="

# ------------------------------------------------------------ submodule ------
# `git submodule deinit -f` deletes the whole working tree, untracked files
# included. On BusinessMathMarketData that destroyed 13 documents that existed
# only on disk — the submodule pointed at another project's commit, so they were
# untracked and in no repository anywhere. Copy the FILES first; backing up
# .git/modules preserves history that was never at risk and none of the content.
if [ -f "$PROJECT/.gitmodules" ] && grep -q 'development-guidelines' "$PROJECT/.gitmodules" 2>/dev/null; then
    SAFE="$PROJECT/development-guidelines.submodule-backup"
    say "submodule detected — copying working tree to $(basename "$SAFE") before deinit"
    if [ "$DRY" -eq 0 ]; then
        rm -rf "$SAFE"
        cp -R "$DG" "$SAFE"
        copied=$(find "$SAFE" -name '*.md' -not -path '*/.git/*' | wc -l | tr -d ' ')
        onDisk=$(find "$DG" -name '*.md' -not -path '*/.git/*' | wc -l | tr -d ' ')
        if [ "$copied" -ne "$onDisk" ]; then
            echo "  ABORT: backup copied $copied of $onDisk documents." >&2
            exit 1
        fi
        say "backed up $copied documents; deinit is now non-destructive"
        git -C "$PROJECT" submodule deinit -f development-guidelines >/dev/null 2>&1 || true
        git -C "$PROJECT" rm -q -f --cached development-guidelines 2>/dev/null || true
        git -C "$PROJECT" rm -q -f .gitmodules 2>/dev/null || true
        rm -rf "$PROJECT/.git/modules/development-guidelines"
        # deinit emptied the directory — restore the files it deleted
        rm -rf "$DG"
        cp -R "$SAFE" "$DG"
        rm -rf "$DG/.git"
        say "submodule removed; $(find "$DG" -name '*.md' | wc -l | tr -d ' ') documents restored from backup"
    fi
fi

# ---------------------------------------------------------------- inventory --
BEFORE=$(find "$DG" -type f -not -path '*/.git/*' -not -name '.DS_Store' | wc -l | tr -d ' ')
echo "  files before: $BEFORE"

# --------------------------------------------- classify framework divergence --
# Only meaningful when a source checkout is supplied. A file here that upstream
# does not ship is a local edit or a locally-authored rule — never discard it.
LOCAL_ONLY=""; MODIFIED=""; STALE=""
if [ -n "$FRAMEWORK" ] && [ -d "$FRAMEWORK" ]; then
    # Rules, plus any framework-level document sitting at the tree root — that is
    # where locally-authored guides accumulate (DEVELOPMENT_WORKFLOW_TUTORIAL.md
    # and friends), and they are invisible to a rules-only scan.
    # Classify by CONTENT, not by filename. Name-matching needs a v1->v2 rename
    # table that goes stale the moment upstream renames anything — it reported
    # CAPABILITY_MAP_TEMPLATE.md as local-only (it had merely been renamed) while
    # missing templates/CLAUDE.md (whose basename collided with the framework's
    # own root CLAUDE.md).
    #
    # The reliable question is simply: has upstream ever held this exact content?
    #   yes, and it matches HEAD  -> current, nothing to do
    #   yes, an older revision    -> stale, superseded by the install
    #   no                        -> local, and the only copy that exists
    while IFS= read -r -d '' f; do
        rel="${f#"$DG"/}"
        case "$rel" in
            00_CORE_RULES/00_MASTER_PLAN.md) continue ;;  # project state
            CLAUDE.md|README.md) continue ;;              # per-project by design
            .git/*|*/.DS_Store|.DS_Store) continue ;;
            # project-owned trees are repatriated, not classified
            0[1-7]_*/*|02_*/*|04_*/*|05_*/*|06_*/*|07_*/*) continue ;;
        esac
        blob=$(git hash-object "$f" 2>/dev/null || echo none)
        if git -C "$FRAMEWORK" cat-file -e "$blob" 2>/dev/null; then
            # upstream has held this content at some point
            base=$(basename "$f")
            if ! git -C "$FRAMEWORK" ls-tree -r HEAD --format='%(objectname)' 2>/dev/null | grep -q "^$blob$"; then
                STALE="$STALE $base"
            fi
        else
            LOCAL_ONLY="$LOCAL_ONLY $rel"
        fi
    done < <(find "$DG" -type f \( -name '*.md' -o -name '*.sh' -o -name '*.swift' -o -name '*.json' \) -not -path "$DG/.git/*" -print0)
fi

# ------------------------------------------------------------- repatriate ----
say "creating project/"
run "mkdir -p '$PROJECT/project'/{plans/{ideas,proposals,upcoming,completed,archive,migrations},checklists/{blocked,completed},summaries/{phases,fixes,archive},docs/{marketing,technical},decisions,roadmaps,release,library}"

# framework templates that must NOT be repatriated as project content
is_template() {
    case "$(basename "$1")" in
        TEMPLATE.md|SESSION_SUMMARY_TEMPLATE.md|CAPABILITY_MAP_TEMPLATE.md) return 0 ;;
        *) return 1 ;;
    esac
}

move_tree() {  # <src-rel> <dst-rel>
    local src="$DG/$1" dst="$PROJECT/project/$2"
    [ -d "$src" ] || return 0
    local n=0
    while IFS= read -r -d '' f; do
        is_template "$f" && continue
        run "mkdir -p '$dst'"
        run "cp -p '$f' '$dst/$(basename "$f")'"
        n=$((n+1))
    done < <(find "$src" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)
    [ "$n" -gt 0 ] && say "$1 -> project/$2 ($n)"
    return 0
}

# the master plan is project state misfiled under framework rules — the thing
# most easily lost, because its v1 home looks like a rule
MP_STATE="absent"
if [ -e "$DG/00_CORE_RULES/00_MASTER_PLAN.md" ]; then
    run "cp -p '$DG/00_CORE_RULES/00_MASTER_PLAN.md' '$PROJECT/project/master_plan.md'"
    # A plan left as the shipped template is worth reporting: it migrates fine,
    # but the project has no stated vision, and the status checker reads this file.
    # Count only bracketed prompts left by the template. Markdown checkboxes
    # ([ ] and [x]) and link labels are ordinary content in a filled-in plan —
    # Shelfmark's genuine plan contains 18 checkboxes and no placeholders at all.
    # `|| true` throughout: with pipefail, a grep that filters every line exits 1
    # and would abort the migration. A plan whose only brackets are checkboxes —
    # Shelfmark's — hits exactly that path.
    # Compare against the shipped template rather than guessing what a bracket
    # means. Heuristics misread both directions: Shelfmark's genuine plan is full
    # of markdown checkboxes, and quality-gate-swift's cites its own modules as
    # [BuildChecker], [QualityGateCore]. Counting bracket strings the template
    # actually contains is exact and needs no judgement.
    # The title is the one line anybody customises the moment they start filling
    # the plan in, and it survives template revisions — matching placeholder
    # strings against the *current* template fails for projects generated from an
    # older one. The mission line is the corroborating signal.
    MP_FILE="$DG/00_CORE_RULES/00_MASTER_PLAN.md"
    PH=0
    head -1 "$MP_FILE" 2>/dev/null | grep -q '\[' && PH=$((PH+5))
    { grep -A3 '^### Mission' "$MP_FILE" 2>/dev/null || true; } | grep -qE '^\[.*\]$' && PH=$((PH+5))
    if [ "$PH" -ge 5 ]; then
        MP_STATE="UNFILLED TEMPLATE ($PH placeholders)"
        say "00_CORE_RULES/00_MASTER_PLAN.md -> project/master_plan.md  [$MP_STATE]"
    else
        MP_STATE="filled"
        say "00_CORE_RULES/00_MASTER_PLAN.md -> project/master_plan.md"
    fi
fi

# Architecture decisions are project state that v1 filed under framework rules.
# A project that recorded its own ADRs there would lose them the first time the
# framework directory is replaced, so extract them before anything else runs.
ADR_SRC="$DG/00_CORE_RULES/06_ARCHITECTURE_DECISIONS.md"
if [ -e "$ADR_SRC" ]; then
    # v1 shipped the FRAMEWORK's own decision log inside this file, so a project
    # that never wrote an ADR still appears to have a dozen. Counting non-template
    # entries is therefore not enough — subtract the framework's own titles, and
    # extract only what this project actually authored. Writing out inherited
    # boilerplate under the project's name is worse than writing nothing: an
    # assistant reads it as this project's authoritative architecture.
    ADR_OWN=0
    if [ -n "$FRAMEWORK" ] && [ -f "$FRAMEWORK/project/decisions/architecture_decisions.md" ]; then
        ADR_OWN=$(comm -23 \
            <(grep '^title:' "$ADR_SRC" 2>/dev/null | grep -v '\[Brief title\]' | sort -u) \
            <(grep '^title:' "$FRAMEWORK/project/decisions/architecture_decisions.md" 2>/dev/null | grep -v '\[Brief title\]' | sort -u) \
            | wc -l | tr -d ' ')
    else
        ADR_OWN=$(grep '^title:' "$ADR_SRC" 2>/dev/null | grep -vc '\[Brief title\]' || echo 0)
    fi
    ADR_REAL="$ADR_OWN"
    if [ "$ADR_REAL" -gt 0 ]; then
        say "extracting $ADR_REAL project ADRs -> project/decisions/architecture_decisions.md"
        if [ "$DRY" -eq 0 ]; then
            mkdir -p "$PROJECT/project/decisions"
            {
                echo "# Architecture Decisions — $(basename "$PROJECT")"
                echo
                echo "This project's own decision log, extracted from the v1"
                echo "\`00_CORE_RULES/06_ARCHITECTURE_DECISIONS.md\` during the v2 migration."
                echo "The format is documented in \`development-guidelines/rules/architecture_decisions.md\`."
                echo
                awk '/^## Decisions/{f=1} f' "$ADR_SRC"
            } > "$PROJECT/project/decisions/architecture_decisions.md"
        fi
    fi
fi

move_tree "01_ROADMAPS"                              "roadmaps"
move_tree "02_IMPLEMENTATION_PLANS"                  "plans"
move_tree "02_IMPLEMENTATION_PLANS/PROPOSALS"        "plans/proposals"
move_tree "02_IMPLEMENTATION_PLANS/COMPLETED"        "plans/completed"
move_tree "02_IMPLEMENTATION_PLANS/UPCOMING"         "plans/upcoming"
move_tree "02_IMPLEMENTATION_PLANS/IDEAS"            "plans/ideas"
move_tree "02_IMPLEMENTATION_PLANS/02_99_ARCHIVE"    "plans/archive"
move_tree "04_IMPLEMENTATION_CHECKLISTS"             "checklists"
move_tree "04_IMPLEMENTATION_CHECKLISTS/04_99_COMPLETED" "checklists/completed"
move_tree "04_IMPLEMENTATION_CHECKLISTS/04_99_BLOCKED"   "checklists/blocked"
move_tree "05_SUMMARIES"                             "summaries"
move_tree "05_SUMMARIES/05_00_PHASE_SUMMARIES"       "summaries/phases"
move_tree "05_SUMMARIES/05_01_FIX_SUMMARIES"         "summaries/fixes"
move_tree "05_SUMMARIES/05_99_ARCHIVE"               "summaries/archive"
move_tree "06_RELEASE"                               "release"
move_tree "06_BACKUP_FILES"                          "archive"

# Reference material nests by subject — copy the tree, not just its top level.
# A maxdepth-1 move silently strands whole subdirectories (ApplesoftBASIC kept
# five language-reference documents under "07_LIBRARY/AppleSoft BASIC/").
move_tree_deep() {  # <src-rel> <dst-rel>
    local src="$DG/$1" dst="$PROJECT/project/$2"
    [ -d "$src" ] || return 0
    local n
    n=$(find "$src" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] || return 0
    run "mkdir -p '$dst'"
    # -R preserves the subject subdirectories; names may contain spaces.
    if [ "$DRY" -eq 0 ]; then
        find "$src" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' e; do
            cp -R "$e" "$dst/"
        done
    fi
    say "$1 -> project/$2 ($n, recursive)"
    return 0
}

move_tree_deep "07_LIBRARY"                          "library"
move_tree_deep "03_TECHNICAL_DOCS"                   "docs/technical"

# --------------------------------------------------- completeness sweep -----
# The mappings above are maxdepth-1, so any subdirectory nobody anticipated is
# silently stranded. ApplesoftBASIC nested reference docs under
# "07_LIBRARY/AppleSoft BASIC/"; SwiftXLSX nests
# "02_IMPLEMENTATION_PLANS/02_99_ARCHIVE/QUESTIONS/". Rather than chase each
# shape, sweep for project documents that did not land anywhere and place them
# under their mapped root, preserving the sub-path.
sweep_root() {  # <v1-dir> <project-subdir>
    local src="$DG/$1" root="$2"
    [ -d "$src" ] || return 0
    local n=0
    while IFS= read -r -d '' f; do
        is_template "$f" && continue
        local base; base=$(basename "$f")
        # already placed by an explicit mapping?
        if [ -d "$PROJECT/project" ] && find "$PROJECT/project" -name "$base" -type f 2>/dev/null | grep -q .; then
            continue
        fi
        local sub; sub=$(dirname "${f#"$src"/}")
        # strip the numeric v1 prefixes from any surviving sub-path
        sub=$(echo "$sub" | sed -E 's|[0-9]{2}_[0-9]{2}_||g; s|[0-9]{2}_||g' | tr '[:upper:]' '[:lower:]')
        [ "$sub" = "." ] && sub=""
        local dst="$PROJECT/project/$root${sub:+/$sub}"
        run "mkdir -p '$dst'"
        run "cp -p '$f' '$dst/$base'"
        n=$((n+1))
    done < <(find "$src" -mindepth 2 -type f -name '*.md' -print0 2>/dev/null)
    [ "$n" -gt 0 ] && say "sweep: $1 -> project/$root (+$n nested)"
    return 0
}

sweep_root "02_IMPLEMENTATION_PLANS"      "plans"
sweep_root "04_IMPLEMENTATION_CHECKLISTS" "checklists"
sweep_root "05_SUMMARIES"                 "summaries"
sweep_root "01_ROADMAPS"                  "roadmaps"
sweep_root "06_RELEASE"                   "release"

# Projects invent their own top-level directories. iconquer had 06_DEPLOYMENT
# (an operations guide referenced twice from its summaries) and 06_BLOG — both
# invisible to a fixed mapping table, and both stranded. Anything not recognised
# as framework is project content: carry it across under its own name rather
# than leave it behind.
while IFS= read -r d; do
    b=$(basename "$d")
    case "$b" in
        00_CORE_RULES|01_ROADMAPS|02_IMPLEMENTATION_PLANS|03_STRATEGIES_AND_FRAMEWORKS) continue ;;
        03_TECHNICAL_DOCS|04_IMPLEMENTATION_CHECKLISTS|05_SUMMARIES) continue ;;
        06_BACKUP_FILES|06_RELEASE|07_LIBRARY) continue ;;
        scripts|templates|rules|skills|strategies|.claude|.git|.github) continue ;;
    esac
    n=$(find "$d" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
    [ "$n" -gt 0 ] || continue
    dest=$(echo "$b" | sed -E 's|^[0-9]{2}_||' | tr '[:upper:]' '[:lower:]')
    run "mkdir -p '$PROJECT/project/$dest'"
    if [ "$DRY" -eq 0 ]; then
        find "$d" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' e; do
            cp -R "$e" "$PROJECT/project/$dest/"
        done
    fi
    say "unmapped: $b -> project/$dest ($n)"
done < <(find "$DG" -mindepth 1 -maxdepth 1 -type d)

# ------------------------------------------------------- install framework ---
if [ -n "$FRAMEWORK" ] && [ -d "$FRAMEWORK" ]; then
    say "preserving pre-migration tree as development-guidelines.pre-v2/"
    run "cp -R '$DG' '$PROJECT/development-guidelines.pre-v2'"
    run "rm -rf '$DG'"
    run "mkdir -p '$DG'"
    run "(cd '$FRAMEWORK' && git archive HEAD) | tar -x -C '$DG'"
    run "rm -rf '$DG/project' '$DG/CLAUDE.md'"
    SHA=$(git -C "$FRAMEWORK" rev-parse --short HEAD 2>/dev/null || echo unknown)
    run "printf 'version: 2.0.0\ncommit:  %s\napplied: %s\nsource:  jpurnell/development-guidelines\n' '$SHA' \"\$(date +%Y-%m-%d)\" > '$DG/.framework-version'"
    say "installing skills into .claude/skills/"
    run "mkdir -p '$PROJECT/.claude/skills'"
    if [ "$DRY" -eq 0 ]; then
        for s in "$DG"/skills/*/; do
            n=$(basename "$s")
            ln -sfn "../../development-guidelines/skills/$n" "$PROJECT/.claude/skills/$n"
        done
    fi
fi

# ------------------------------------------------------- rewrite references --
say "rewriting references in project/ and CLAUDE.md"
if [ "$DRY" -eq 0 ]; then
    SED=$(mktemp)
    cat > "$SED" <<'SEDEOF'
s|development-guidelines/05_SUMMARIES/05_00_PHASE_SUMMARIES|project/summaries/phases|g
s|development-guidelines/05_SUMMARIES/05_01_FIX_SUMMARIES|project/summaries/fixes|g
s|development-guidelines/05_SUMMARIES/05_99_ARCHIVE|project/summaries/archive|g
s|05_SUMMARIES/05_00_PHASE_SUMMARIES|project/summaries/phases|g
s|05_SUMMARIES/05_01_FIX_SUMMARIES|project/summaries/fixes|g
s|05_SUMMARIES/05_99_ARCHIVE|project/summaries/archive|g
s|04_IMPLEMENTATION_CHECKLISTS/04_99_COMPLETED|project/checklists/completed|g
s|04_IMPLEMENTATION_CHECKLISTS/04_99_BLOCKED|project/checklists/blocked|g
s|02_IMPLEMENTATION_PLANS/PROPOSALS|project/plans/proposals|g
s|02_IMPLEMENTATION_PLANS/COMPLETED|project/plans/completed|g
s|02_IMPLEMENTATION_PLANS/UPCOMING|project/plans/upcoming|g
s|02_IMPLEMENTATION_PLANS/IDEAS|project/plans/ideas|g
s|development-guidelines/00_CORE_RULES/00_MASTER_PLAN\.md|project/master_plan.md|g
s|00_CORE_RULES/00_MASTER_PLAN\.md|project/master_plan.md|g
s|00_MASTER_PLAN\.md|master_plan.md|g
s|development-guidelines/00_CORE_RULES|development-guidelines/rules|g
s|00_CORE_RULES|development-guidelines/rules|g
s|03_STRATEGIES_AND_FRAMEWORKS|development-guidelines/strategies|g
s|01_ROADMAPS|project/roadmaps|g
s|02_IMPLEMENTATION_PLANS|project/plans|g
s|03_TECHNICAL_DOCS|project/docs/technical|g
s|04_IMPLEMENTATION_CHECKLISTS|project/checklists|g
s|05_SUMMARIES|project/summaries|g
s|06_RELEASE|project/release|g
s|07_LIBRARY|project/library|g
s|06_BACKUP_FILES|project/archive|g
s|01_CODING_RULES\.md|coding_rules.md|g
s|02_USAGE_EXAMPLES\.md|usage_examples.md|g
s|03_DOCC_GUIDELINES\.md|docc_guidelines.md|g
s|04_IMPLEMENTATION_CHECKLIST\.md|implementation_checklist.md|g
s|05_DESIGN_PROPOSAL\.md|design_proposal.md|g
s|06_ARCHITECTURE_DECISIONS\.md|architecture_decisions.md|g
s|07_SESSION_WORKFLOW\.md|session_workflow.md|g
s|08_FLOATING_POINT_FORMATTING\.md|floating_point_formatting.md|g
s|09_TEST_DRIVEN_DEVELOPMENT\.md|test_driven_development.md|g
s|10_APPLICATION_TESTING_PATTERNS\.md|application_testing_patterns.md|g
s|11_NO_HARDCODED_CONSTANTS\.md|no_hardcoded_constants.md|g
s|11_CI_QUALITY_GATE\.md|ci_quality_gate.md|g
s|12_UI_TESTING\.md|ui_testing.md|g
s|12_ENFORCEMENT\.md|enforcement.md|g
s|13_LOGGING_INSTRUMENTATION\.md|logging_instrumentation.md|g
s|13_TUI_DEVELOPMENT\.md|tui_development.md|g
s|14_CAPABILITY_MAP\.md|capability_map.md|g
s|SESSION_SUMMARY_TEMPLATE\.md|development-guidelines/templates/session_summary.md|g
s|project/checklists/TEMPLATE\.md|development-guidelines/templates/checklist.md|g
SEDEOF
    find "$PROJECT/project" -name '*.md' -print0 | xargs -0 -r sed -i '' -f "$SED"
    [ -f "$PROJECT/CLAUDE.md" ] && sed -i '' -f "$SED" "$PROJECT/CLAUDE.md"
    # collapse any doubled prefix produced by the bare-name rules above
    # Collapse artifacts of the bare-name rules above. A path that already carried
    # the development-guidelines/ prefix picks it up again when its trailing
    # component maps into project/ — e.g. "development-guidelines/01_ROADMAPS/x.md"
    # becomes "development-guidelines/project/roadmaps/x.md". 46 files across 19
    # projects hit this before it was caught.
    find "$PROJECT/project" -name '*.md' -print0 | xargs -0 -r sed -i '' \
        -e 's|development-guidelines/development-guidelines/|development-guidelines/|g' \
        -e 's|development-guidelines/project/|project/|g' \
        -e 's|project/project/|project/|g' \
        -e 's|development-guidelines/06_ARCHITECTURE_DECISIONS/|project/decisions/|g'
    [ -f "$PROJECT/CLAUDE.md" ] && sed -i '' \
        -e 's|development-guidelines/development-guidelines/|development-guidelines/|g' \
        -e 's|project/project/|project/|g' "$PROJECT/CLAUDE.md"
    rm -f "$SED"
fi

# --------------------------------------------------------- quality-gate cfg --
# quality-gate's status checker defaults to the v1 path
# (development-guidelines/00_CORE_RULES/00_MASTER_PLAN.md) and SKIPS SILENTLY when
# it is missing. Without this, every migrated project quietly stops being status-
# audited and nothing says so. masterPlanPath is relative to guidelinesPath.
if [ "$DRY" -eq 0 ]; then
    QG="$PROJECT/.quality-gate.yml"
    if [ -f "$QG" ] && grep -q '^status:' "$QG"; then
        say "NOTE: .quality-gate.yml already has a status: block — set masterPlanPath: project/master_plan.md by hand"
    else
        printf '\n# v2 layout: the master plan is project-owned, not framework content.\nstatus:\n  guidelinesPath: "."\n  masterPlanPath: project/master_plan.md\n' >> "$QG"
        say "pointed .quality-gate.yml status checker at project/master_plan.md"
    fi
fi

# ------------------------------------------------------------------ ignore ---
UNTRACKED_N=0
if [ "$DRY" -eq 0 ]; then
    GI="$PROJECT/.gitignore"
    grep -q '^/\?development-guidelines/$' "$GI" 2>/dev/null || printf '\n# Vendored development-guidelines framework (managed, replaceable)\n/development-guidelines/\n' >> "$GI"
    grep -q '^/\.claude/skills/$' "$GI" 2>/dev/null || printf '/.claude/skills/\n' >> "$GI"
    grep -q '^/development-guidelines\.pre-v2/$' "$GI" 2>/dev/null || printf '/development-guidelines.pre-v2/\n' >> "$GI"

    # A .gitignore entry does not untrack what is already in the index. Six of the
    # eleven Iconquer projects had the whole framework committed; without this the
    # ignore rule is inert and the framework stays in the repository forever.
    UNTRACKED_N=$(git -C "$PROJECT" ls-files development-guidelines 2>/dev/null | wc -l | tr -d ' ')
    if [ "$UNTRACKED_N" -gt 0 ]; then
        git -C "$PROJECT" rm -r -q --cached development-guidelines 2>/dev/null || true
        say "untracked $UNTRACKED_N framework files from the index (content untouched on disk)"
    fi
fi

# ------------------------------------------------------------------ report ---
AFTER=0
[ -d "$PROJECT/project" ] && AFTER=$(find "$PROJECT/project" -type f -name '*.md' 2>/dev/null | wc -l | tr -d ' ')
if [ "$DRY" -eq 0 ]; then
cat > "$REPORT" <<EOF
# Migration Report — $(basename "$PROJECT")

Migrated to the v2 layout on $(date +%Y-%m-%d).

- Files in the pre-migration tree: $BEFORE
- Project documents repatriated to \`project/\`: $AFTER
- Pre-migration tree preserved at: \`development-guidelines.pre-v2/\` (gitignored)
- Framework files untracked from the index: $UNTRACKED_N
- Master plan: **$MP_STATE**$( [ "${MP_STATE#UNFILLED}" != "$MP_STATE" ] && echo " — \`project/master_plan.md\` is still the shipped template. The \`status\` checker reads this file; fill it in." )

## Framework divergence

Content found locally that upstream does not ship. **Nothing was discarded** — it
remains in \`development-guidelines.pre-v2/\`. Each item is an upstream candidate.

### Local-only rules
$( [ -n "$LOCAL_ONLY" ] && for f in $LOCAL_ONLY; do echo "- \`$f\`"; done || echo "_none_" )

### Locally modified rules
Content upstream has never held — genuine local edits.

$( [ -n "$MODIFIED" ] && for f in $MODIFIED; do echo "- \`$f\`"; done || echo "_none_" )

### Stale rules (no action needed)
Older upstream releases, superseded by the framework just installed. Listed for
completeness only — nothing to upstream.

$( [ -n "$STALE" ] && for f in $STALE; do echo "- \`$f\`"; done || echo "_none_" )

## Next steps

1. Review \`project/\` and commit it to this repository.
2. Upstream anything listed above that belongs in the framework.
3. Only then remove \`development-guidelines.pre-v2/\`.
4. The \`project-state/*\` branch on the development-guidelines remote may be
   deleted only after this repository's commit is pushed.
EOF
fi

echo "  project documents: $AFTER"
[ -n "$LOCAL_ONLY" ] && echo "  local-only (upstream candidates):$LOCAL_ONLY"
[ -n "$MODIFIED" ]   && echo "  LOCAL EDITS (review):$MODIFIED"
true
[ -n "$STALE" ]      && echo "  stale, no action: $(echo "$STALE" | wc -w | tr -d ' ') rules"
echo "  report: ${REPORT#"$PROJECT"/}"
echo "  nothing deleted; pre-migration tree at development-guidelines.pre-v2/"
exit 0
