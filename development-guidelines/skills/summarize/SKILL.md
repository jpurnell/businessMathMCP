---
name: summarize
description: Create an end-of-session summary. Use before ending a work session to capture progress and next steps.
---
Create a session summary following the template at `./development-guidelines/templates/session_summary.md`.

Save it to `./project/summaries/` with today's date as the filename prefix (YYYY-MM-DD_description.md).

Include:
- Work completed this session
- Current phase and status
- Quality gate results (run `quality-gate` if not already run)
- Exact next step for the next session
- Any blockers or decisions needed

Also update any active `./project/checklists/CURRENT_*.md` to reflect current progress.