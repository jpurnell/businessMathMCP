# Capability Map

**Purpose:** Maintain a scannable, structured inventory of what the project can do — its feature areas, key types, external interfaces, and application domains. The capability map enables fast evaluation of product opportunities, partnership fit, and integration scoping without re-exploring the codebase.

**When this applies:** Any project that has grown beyond a handful of files and exposes capabilities to users, APIs, plugins, MCP tools, or other systems. Skip for single-purpose scripts or throwaway prototypes.

---

## Why

Codebases grow. After a few months of development, even the author can't quickly answer "what can this project do?" without reading source files. This creates friction in three scenarios:

1. **Opportunity evaluation** — "Could we solve problem X with what we already have?"
2. **Integration scoping** — "Which capabilities should we expose to system Y?"
3. **Onboarding** — "What does this project actually do?"

A capability map is a living inventory that answers these questions in seconds, not hours.

---

## Format

Each project maintains a single `capability_map.md` file in `project/`. Use the template at `development-guidelines/templates/capability_map.md`.

### Structure

Each capability area is an H2 section with three required fields and one optional field:

```markdown
## [Feature Area Name]

**Key types:** `TypeA`, `TypeB`, `TypeC`
**Interfaces:** [tool names, API endpoints, CLI commands, or "internal only"]
**Applications:** [plain-language use cases, comma-separated]
**Dependencies:** [optional — external packages or services required]
```

### Field Definitions

| Field | What goes here | Example |
|-------|---------------|---------|
| **Key types** | The primary Swift types (structs, protocols, actors) that implement this area. Use backtick-delimited names. | `` `HoltWintersModel`, `TrendModel`, `Seasonality` `` |
| **Interfaces** | How external consumers access this capability. MCP tool names, REST endpoints, CLI subcommands, public API entry points. Use "internal only" if the capability is not directly exposed. | `holt_winters_forecast`, `forecast_with_seasonality` |
| **Applications** | Business or technical problems this area solves, written for a non-engineer audience. | Demand forecasting, seasonal planning, sales projections |
| **Dependencies** | External packages, services, or hardware required beyond the base project. Omit if none. | `swift-numerics`, Metal GPU |

### Naming Conventions

- **Feature area names** should be domain-oriented, not code-oriented. Use "Forecasting & Time Series" not "HoltWinters Module."
- **Group by capability**, not by directory structure. A single feature area may span multiple source directories.
- **Keep it scannable.** Each section should be 3–5 lines. If you need more, the feature area is too broad — split it.

---

## Maintenance

### When to Update

| Trigger | Action |
|---------|--------|
| **New feature ships** | Add or update the relevant capability area |
| **Public API changes** | Update key types and interfaces |
| **Feature removed** | Remove the capability area entirely |
| **Release (minor or major)** | Review full map for accuracy |

### Where Updates Happen

- The **Release Checklist** includes a capability map review step (Phase 3)
- The **Session Handover Protocol** includes a capability map update if new features shipped

### What NOT to Include

- **Implementation details** — no file paths, line numbers, or internal architecture
- **Version history** — use git for that
- **Roadmap items** — only shipped, working capabilities
- **Test infrastructure** — only user/consumer-facing capabilities

---

## Using the Capability Map

### Opportunity Evaluation

When evaluating whether the project can solve a new problem:

1. Scan the capability map for relevant feature areas
2. Check that the listed types and interfaces still exist (they may have been renamed)
3. Identify gaps — what's missing that would need to be built?

### Integration Planning

When planning how to expose capabilities to a new system:

1. Filter to feature areas with non-"internal only" interfaces
2. Map existing interfaces to the target system's integration model
3. Identify internal-only capabilities that should be promoted to interfaces

### Onboarding

New contributors or AI sessions should read the capability map after the Master Plan to understand what the project can do before diving into code.

---

## Related Documents

- [CAPABILITY_MAP_TEMPLATE.md](../templates/capability_map.md) — Blank starting template
- [Master Plan](project/master_plan.md) — Project vision and architecture
- [Release Checklist](release_checklist.md) — Includes capability map review
- [Session Workflow](session_workflow.md) — Includes capability map update on feature ship
