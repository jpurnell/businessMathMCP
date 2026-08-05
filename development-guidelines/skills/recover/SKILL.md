---
name: recover
description: Recover session context after a break. Use at the start of a new session to reload project state, active tasks, and next steps.
---
Perform context recovery following `./development-guidelines/rules/session_workflow.md`.

Read in order:
1. `./project/master_plan.md`
2. `./development-guidelines/rules/coding_rules.md`
3. `./development-guidelines/rules/test_driven_development.md`
4. Any `./project/checklists/CURRENT_*.md` files
5. The most recent file in `./project/summaries/`
6. Recent git log (`git log --oneline -20`)

Then report:
- Current phase and feature being worked on
- What was completed last session
- Exact next step to resume work
- Any blockers or open questions