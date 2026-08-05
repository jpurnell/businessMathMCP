# Rules — reading order

Filenames carry no numeric prefix. Ordering lives here, so a rule can be inserted or
retired without renaming its neighbours or invalidating every reference to them.

## Start here

1. [`coding_rules.md`](coding_rules.md) — forbidden patterns, safety, the zero-tolerance list
2. [`test_driven_development.md`](test_driven_development.md) — the testing contract; DESIGN → RED → GREEN → REFACTOR → DOCUMENT → VERIFY
3. [`session_workflow.md`](session_workflow.md) — how a session starts, hands off, and ends

## Before writing code

4. [`design_proposal.md`](design_proposal.md) — mandatory for non-trivial features
5. [`architecture_decisions.md`](architecture_decisions.md) — the ADR log and its lifecycle
6. Per-feature progress tracking — copy [`../templates/checklist.md`](../templates/checklist.md) into `project/checklists/`

## While writing code

7. [`docc_guidelines.md`](docc_guidelines.md) — documentation standards
8. [`no_hardcoded_constants.md`](no_hardcoded_constants.md)
9. [`floating_point_formatting.md`](floating_point_formatting.md)
10. [`logging_instrumentation.md`](logging_instrumentation.md)
11. [`performance.md`](performance.md)
12. [`swift_development.md`](swift_development.md)

## Testing

13. [`testing.md`](testing.md) — general testing guidance
14. [`application_testing_patterns.md`](application_testing_patterns.md)
15. [`ui_testing.md`](ui_testing.md)
16. [`mcp_testing_strategy.md`](mcp_testing_strategy.md) — for MCP server projects
17. [`tui_development.md`](tui_development.md) — for terminal UI projects

## Shipping

18. [`enforcement.md`](enforcement.md) — the mechanical enforcement layers
19. [`ci_quality_gate.md`](ci_quality_gate.md)
20. [`release_checklist.md`](release_checklist.md)

## Reference

- [`usage_examples.md`](usage_examples.md)
- [`capability_map.md`](capability_map.md)

---

**These files are framework content.** They live in `development-guidelines/`, which is gitignored and
replaced wholesale on update. Edits here are lost. Improvements belong upstream in the
`development-guidelines` repository.

Project-specific content — master plan, plans, proposals, checklists, summaries — lives in
`project/`, which is tracked in the project's own repository.
