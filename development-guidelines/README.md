# Development Guidelines - AI Assistant Instruction Set

**Purpose:** Reusable template for guiding AI assistants (Claude, etc.) in software development projects.

---

## Quick Start

1. **Clone this repo** into your project:
   ```bash
   cd ~/Projects/MyProject
   git clone https://github.com/jpurnell/development-guidelines.git
   ```
2. **Run the setup script** to generate the `.claude/` bridge layer and project scaffolding:
   ```bash
   swift development-guidelines/setup.swift
   ```
3. **Gitignore the directory in your outer repo** so the inner `.git` doesn't get added as a submodule:
   ```bash
   echo "development-guidelines/" >> .gitignore
   ```
4. **Switch the inner repo to a project-state branch** before any customization:
   ```bash
   git -C development-guidelines checkout -b project-state/myproject
   ```
5. **Replace `[PROJECT_NAME]`** placeholders in `project/master_plan.md` and customize `development-guidelines/rules/` for your project. Commit on the project-state branch:
   ```bash
   git -C development-guidelines add -A
   git -C development-guidelines commit -m "Project-state initial"
   git -C development-guidelines push -u origin project-state/myproject
   ```
6. **Commit** `.claude/` and `CLAUDE.md` to your **outer project's** repository.

The setup script creates:
- `CLAUDE.md` — AI session entry point with read order and key rules (project root)
- `.claude/rules/` — Path-scoped Swift development rules (project root)
- `.claude/skills/` — Workflow skills `/design`, `/recover`, `/summarize`, `/checklist` (project root)
- `.claude/settings.json` — Default permissions for Swift development (project root)
- **Project-state directories scaffolded *inside* `development-guidelines/`** — `project/plans/`, `project/checklists/`, `project/summaries/`. Templates (`TEMPLATE.md`, `session_summary.md`) already live in those folders, so no copying is needed.

Only `.claude/` and `CLAUDE.md` are written to the project root because those are conventions Claude Code expects there. Project-state content (master plan, proposals, checklists, summaries) lives inside `development-guidelines/` on a `project-state/<project>` branch — see [Ownership Model](#ownership-model-template-vs-project-content) below.

---

## Ownership Model: Template vs. Project Content

This repository is a **living template** — it provides the framework, and each project fills in the content. Two git repositories work together: your **outer project repo** (the application) and the **inner `development-guidelines/.git`** (this template plus your project's process state).

### How It Works

When you clone `development-guidelines` into your project, the directory retains its own `.git`. The two repos play different roles:

- **Outer project `.git`** (your library/app/CLI). Tracks application code, `.claude/`, and `CLAUDE.md`. **The `development-guidelines/` directory is `.gitignore`d here** — git's standard semantics make a nested `.git` impractical to track inline (it would be added as a submodule pointer, not as files), so the clean answer is to gitignore it.
- **Inner `development-guidelines/.git`**. Tracks template files on `main` and your project-specific content on a `project-state/<your-project>` branch. Pulling template updates is `git -C development-guidelines pull origin main` (with project work safely on its own branch).

### What Belongs Where

| File | Tracked by | On branch |
|------|------------|-----------|
| `Sources/`, `Tests/`, `Package.swift`, app code | **outer** project repo | your project's main branch |
| `.claude/`, `CLAUDE.md` | **outer** project repo | your project's main branch |
| `development-guidelines/rules/*.md` (defaults), `setup.swift`, `README.md`, `TEMPLATE.md`, `session_summary.md` | **inner** template repo | `main` |
| `project/master_plan.md` (your customizations) | **inner** template repo | `project-state/<project>` |
| `project/plans/{PROPOSALS,UPCOMING,COMPLETED}/*.md` | **inner** template repo | `project-state/<project>` |
| `project/checklists/CURRENT_*.md` | **inner** template repo | `project-state/<project>` |
| `project/summaries/*.md` (non-template) | **inner** template repo | `project-state/<project>` |
| `project/roadmaps/*.md` | **inner** template repo | `project-state/<project>` |

### Initial Setup

```bash
cd ~/Projects/your-project
git init                                              # outer repo
git clone https://github.com/jpurnell/development-guidelines.git
swift development-guidelines/setup.swift              # generates CLAUDE.md, .claude/, etc.

# Outer repo ignores the inner; the inner has its own .git for template + project state.
echo "development-guidelines/" >> .gitignore

# Switch the inner repo to a project-state branch immediately so customizations
# never accidentally land on the template's main.
git -C development-guidelines checkout -b project-state/your-project
# customize project/master_plan.md, write proposals, etc.
git -C development-guidelines add -A
git -C development-guidelines commit -m "Project-state initial: master plan + ..."
git -C development-guidelines push -u origin project-state/your-project
```

### Pulling Template Updates

Run from the project-state branch inside `development-guidelines`:

```bash
cd development-guidelines
git fetch origin main
git rebase origin/main          # or: git merge origin/main
git push --force-with-lease origin project-state/your-project
```

Conflicts in customized files (most often `project/master_plan.md`) are resolved by keeping your customizations — the template version is the starting point, not the authority.

### Working in the Outer Repo

Outer project commits as normal — `git add`, `git commit`, `git push` from the project root. Because `development-guidelines/` is gitignored, the outer repo doesn't see the inner `.git` at all.

### Do Not Push Project Content to `main`

The template repo's `main` branch is the **clean template**. Project-specific content (proposals, checklists, summaries, customized master plans) lives on `project-state/<project>` branches. **Never push project-specific files to `main`.** A misnamed commit there pollutes the template for every other project that pulls.

### Summary

```
your-project/                           ← outer repo
├── .git                                 ← outer .git
├── .gitignore                           ← contains: development-guidelines/
├── Sources/, Tests/, Package.swift     ← tracked by outer
├── CLAUDE.md, .claude/                  ← tracked by outer
└── development-guidelines/              ← gitignored by outer
    ├── .git                             ← inner .git (template + project state)
    ├── (template files on main)
    ├── project/master_plan.md ← on project-state/<project>
    ├── project/plans/         ← on project-state/<project>
    ├── project/checklists/    ← on project-state/<project>
    └── project/summaries/                    ← on project-state/<project>
```

---

## Folder Organization

### development-guidelines/rules - **Read First, Reference Always**
Fundamental rules, guidelines, and standards that govern all development work.

| File | Purpose |
|------|---------|
| `project/master_plan.md` | Project vision and architecture |
| `coding_rules.md` | Code style, patterns, and standards |
| `usage_examples.md` | API usage patterns and examples |
| `docc_guidelines.md` | Documentation standards (DocC) |
| `design_proposal.md` | Architecture validation before coding |
| `session_workflow.md` | **Context recovery and session protocols** |
| `floating_point_formatting.md` | Number formatting standards |
| `test_driven_development.md` | TDD approach and testing contract |
| `application_testing_patterns.md` | Integration, E2E, benchmarks, and test metrics |
| `no_hardcoded_constants.md` | Constant extraction rules |
| `ui_testing.md` | State-matrix coverage and view model testing for SwiftUI |
| `logging_instrumentation.md` | Structural observability: instrumented types, banned raw I/O, OSLog rules |
| `capability_map.md` | Format spec for the project capability inventory |
| `performance.md` | Performance guidelines |
| `release_checklist.md` | Release verification checklist |
| `TESTING.md` | Testing strategy |

### project/roadmaps - **Strategic Planning**
Long-term strategic plans and phase roadmaps.

### project/plans - **Tactical Implementation**
Detailed implementation plans organized by status:
- `PROPOSALS/` - Drafted but not-yet-approved design proposals
- `UPCOMING/` - Approved work ready for implementation
- `COMPLETED/` - Past implementations (for reference)
- `MIGRATIONS/` - Migration guides
  - `02_99_ARCHIVE/` Maintenance folder

### development-guidelines/strategies - **High-Level Guidance**
Strategic documents for product direction and architecture.

| File | Purpose |
|------|---------|
| `CAPABILITY_MAP_TEMPLATE.md` | Blank starting template for the project capability inventory |
| `playgroundFormat.md` | Xcode playground bundle layout and manifest contract for projects that ship playgrounds alongside an SPM package |

### project/checklists - **Task Tracking**
Per-feature implementation checklists using Design-First TDD workflow.
- `TEMPLATE.md` - Checklist template for new features
- `CURRENT_*.md` - Active feature checklists
- `completed/` - Archived shipped features
- `blocked/` - Parked features waiting on dependencies

### project/summaries - **Session History**
Post-session summaries of completed work:
- `session_summary.md` - **Template for session summaries**
- `phases/` - Phase completions
- `fixes/` - Bug fix summaries

### project/archive - **Archive**
Archived files for reference only.

### project/library - **Reference Materials**
Educational and reference materials (papers, tutorials, etc.)

---

## For AI Assistants (Claude, etc.)

> **📖 Full Protocol: [session_workflow.md](development-guidelines/rules/session_workflow.md)**

### Session Start — Context Recovery

Choose the appropriate recovery tier:

**Quick Recovery** (bug fixes, resuming same-day work):
```
1. Latest file in project/summaries/                → Where we left off
2. project/checklists/CURRENT_*.md   → Active tasks
```

**Full Recovery** (new sessions, complex features, after long breaks):
Read documents in this order:
```
1. project/master_plan.md                           → Vision and priorities
2. coding_rules.md                          → Forbidden patterns, safety rules
3. test_driven_development.md               → Testing contract
4. project/checklists/CURRENT_*.md   → Current tasks
5. Latest file in project/summaries/                → Where we left off
```

Then confirm: *"Context recovered. Current task is [X]. Ready to follow Zero Warnings Gate."*

### Development Workflow — Design-First TDD

```
0. DESIGN   → Propose architecture (see design_proposal.md)
1. RED      → Write failing tests
2. GREEN    → Write minimum code to pass
3. REFACTOR → Improve code, keep tests green
4. DOCUMENT → DocC comments and examples
5. VERIFY   → Zero warnings/errors gate
```

### Session End — Handover Protocol

Before ending any session:

1. **Verify Quality Gate** — All checks pass (zero warnings, zero failures)
2. **Update State** — Move tasks in `project/checklists/CURRENT_*.md`
3. **Create Summary** — New file in `project/summaries/` with:
   - Work completed
   - Quality gate status
   - **Immediate next step** (exact starting point for next session)
   - Pending blockers

### Decision Framework

| Task Type | Reference |
|-----------|-----------|
| New Feature | `design_proposal.md` → `development-guidelines/templates/checklist.md` |
| Design Proposal | `design_proposal.md` → `project/plans/proposals/` |
| Bug Fix | TDD approach, create summary in `fixes/` |
| Documentation | `docc_guidelines.md` |
| Planning | `project/roadmaps/`, `project/plans/` |
| Release | `release_checklist.md` (verification only) |

---

## Customization Guide

### Required Customizations

1. **`project/master_plan.md`** - Replace with your project's vision and architecture
2. **`coding_rules.md`** - Adapt to your tech stack and conventions
3. **`usage_examples.md`** - Add your project's API examples

### Optional Customizations

- Add project-specific guides to `development-guidelines/rules/`
- Create roadmaps in `project/roadmaps/`
- Add reference materials to `project/library/`

---

## MCP Server (Live Guidelines)

These guidelines are served as an MCP server at `https://roseclub.org:8082/mcp`, making them queryable from any Claude Code session. The server reads files from disk on every request.

### Publishing changes

After editing any guideline files, sync them to the server:

```bash
rsync -av --exclude='.build' --exclude='.DS_Store' --exclude='.git' --exclude='BLOG_POST*' \
  ~/Dropbox/Computer/Development/Swift/Tools/development-guidelines/ \
  roseclub.org:~/development-guidelines/
```

Changes are live immediately — no rebuild or restart needed.

### When a rebuild is needed

If you add/remove documents, change the document map, or modify tool definitions, the MCP server itself needs to be rebuilt:

```bash
# Sync server source and rebuild
rsync -av --exclude='.build' --exclude='.DS_Store' \
  ~/Dropbox/Computer/Development/Swift/Tools/DevGuidelinesMCP/ \
  roseclub.org:~/DevGuidelinesMCP/

ssh roseclub.org "source ~/.swiftly/env.sh && cd ~/DevGuidelinesMCP && swift build -c release"

# Restart the service
ssh roseclub.org "launchctl stop com.roseclub.devguidelines-mcp && launchctl start com.roseclub.devguidelines-mcp"
```

### Available tools

| Tool | Purpose |
|------|---------|
| `list_documents` | Browse all guideline documents |
| `list_sections` | See H2 sections within a document |
| `get_section` | Retrieve a specific section by number or keyword |
| `search_guidelines` | Full-text search across all guidelines |
| `get_quick_reference` | Topic lookup (concurrency, testing, docc, etc.) |
| `get_workflow` | Workflow steps for new_feature, bug_fix, release, etc. |
| `get_template` | Blank templates (design_proposal, checklist, summary) |

Server source: [DevGuidelinesMCP](../DevGuidelinesMCP/)

---

## Branches

- **`main`** - Clean template with placeholders
- **`example`** - Working example (BusinessMath project) for reference

---

**Maintained By:** Justin Purnell
**Template Version:** 1.0.1
