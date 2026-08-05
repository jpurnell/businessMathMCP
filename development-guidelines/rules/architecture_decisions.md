# Architecture Decisions Log

**Purpose:** Machine-readable log of architectural decisions. Each entry is a YAML block.

> **When to add entries:**
> - Choosing between competing approaches (actor vs struct, sync vs async)
> - Establishing conventions (error handling, naming, file structure)
> - Making tradeoffs (performance vs safety, simplicity vs flexibility)
> - Rejecting a previously considered approach

---

## How to Use

1. **Add new entries** at the bottom of this file using the YAML template below
2. **Increment the ID** sequentially (ADR-001, ADR-002, etc.)
3. **Query entries** by category, status, or keyword
4. **Supersede** old entries by updating `superseded_by` and creating a new entry

### Querying Examples

```
"Check the architecture decisions log for any decisions about concurrency
(category: concurrency). Summarize what was decided and why."
```

```
"Find ADR-001 and tell me what alternatives were rejected."
```

---

## Entry Template

Copy this template for each new decision:

```yaml
id: ADR-NNN
date: YYYY-MM-DD
status: proposed  # proposed | accepted | superseded | amended | deprecated
category: [category]  # concurrency | storage | api | testing | performance | architecture
title: [Brief title]
context: |
  [Describe the specific problem, constraints, and why a decision is needed.]
decision: |
  [Detail the chosen architectural approach or convention.]
rationale: |
  - [Reason 1]
  - [Reason 2]
consequences: |
  [Document the positive and negative impacts on the codebase,
   performance, or workflow.]
alternatives_rejected:
  - "[Alternative]: [Why rejected]"
affected_files:
  - [file path]
supersedes: null  # ADR-NNN if this completely replaces an earlier decision
amends: null  # ADR-NNN if this refines/extends an existing decision
superseded_by: null  # ADR-NNN if this was later replaced
```

### Lifecycle Management

- **`supersedes`**: Use when a new decision completely replaces an older one. Update the original entry's `status` to `superseded` and set its `superseded_by` field.
- **`amends`**: Use when a new decision refines or adds constraints to an existing one without replacing it. Update the original entry's `status` to `amended`.
- **When updating**: Always go back to the original entry and update its `status` field to reflect that it is no longer the sole authority.

---


## Where the decisions live

This file defines the **format**. The decisions themselves are project-owned and belong in
your own repository:

```
project/decisions/architecture_decisions.md
```

They are never shipped in `development-guidelines/`, because one project's architectural
history is not another project's rule. This repository keeps its own log at that same
path — see it for worked examples of the format above.
