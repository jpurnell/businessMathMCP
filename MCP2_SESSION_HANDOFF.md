# MCP 2026-07-28 (swift-sdk) — Session Handoff

Last updated: 2026-08-03. Purpose: clean `/recover` after restart for the swift-sdk MCP
`2026-07-28` implementation effort. Companion to memory `project_swift_sdk_mcp2_impl.md`
(loaded automatically) — this doc adds live state, exact paths, and the next action.

## Where to `/recover` from
Launch Claude Code **from this repo** (`…/Math/businessMathMCP/`) — it now has its own
`CLAUDE.md` that auto-loads and lists the reading order (this handoff first). Launching from the
sibling `…/Math/BusinessMath/` also works (that's where auto-memory + the `/recover` skill are
wired, and memory points here). Either way, read this file first.

## TL;DR — where we are
Phase 0 (transport groundwork) is DONE and up as two upstream PRs. The Phase-1 stateless-core
design proposal was written, then **rejected by adversarial review** and the plan **pivoted**.
We posted an upstream coordination comment and are now starting the first non-gated,
consumer-valuable piece: **SEP-2549 TTL list caching**, via the full process
(design proposal → adversarial review → TDD → PR). No SEP-2549 code written yet — next step is
grounding + the design proposal.

## Repos, branches, PRs (all pushed/remote — survive restart)
- **Upstream:** `modelcontextprotocol/swift-sdk` (baseline **0.12.1**; builds clean on Swift 6.4;
  async-algorithms no longer a direct dep). Fork: `jpurnell/swift-sdk`.
- **PR #267** (OPEN, REVIEW_REQUIRED) — reject colliding in-flight JSON-RPC ids (fixes #254 hang/leak
  + #265 auth cross-talk). Branch `fix/stateless-transport-id-correlation`, commit `b79c7b3`
  (amended to drop a leaked scratch doc). 552 MCP tests green.
- **PR #268** (OPEN, REVIEW_REQUIRED) — complete a cancelled request's HTTP exchange (fixes #255).
  Branch `fix/stateless-cancelled-hangs` off pristine upstream main, commit `438384c`. 552 tests green.
- **Issue #245** (SEP-2575) — our coordination comment POSTED (issuecomment-5120667111);
  **no maintainer reply yet** (repo merge-frozen ~3mo; treat reply/silence as go/no-go for the keystone).
- businessMathMCP + SwiftMCPServer still pin swift-sdk fork `0.11.0..<0.12.0` (unchanged this effort).

## Planning docs (in businessMathMCP repo)
- `SWIFT_SDK_2026-07-28_IMPLEMENTATION_ROADMAP.md` — full-spec plan; has a RE-SEQUENCED banner (2026-07-29).
- `SEP-2575_STATELESS_CORE_DESIGN_PROPOSAL.md` — has NOT-APPROVED banner + Revised Direction (post-review).
- `MCP_2026-07-28_MIGRATION_PLAN.md` — earlier consumer-side plan.
- This file.

## The pivot (why we're NOT building the stateless core next)
Four parallel adversarial reviewers unanimously rejected the SEP-2575 proposal (2026-07-29):
data model wrong (namespaced `_meta`), architecture infeasible as scoped, test loop circular
(stateful harness), and strategically premature (unowned upstream issue, frozen repo, stdio
consumer needs ~none of the HTTP surface). Full corrected facts are in the proposal's banner and
in memory `project_swift_sdk_mcp2_impl.md` — READ THOSE before touching stateless work.

**Re-sequenced plan:** (0) coordinate #245 + land #267/#268 → (A) minimal stdio 2026-07-28
(version + accept namespaced `_meta`) → (B) SEP-2164 + **SEP-2549** (self-contained, consumer value)
→ (C) full stateless HTTP core, gated on maintainer-blessed design.

## NEXT ACTION (in progress)
**SEP-2549 TTL list caching** — `ttlMs`/`cacheScope` on list results (`tools/list`, `prompts/list`,
`resources/list`, `resources/read`). Roadmap calls it "high value for 207 tools." Self-contained,
low fork risk. Process (MANDATORY per development-guidelines):
1. **Ground first** (the hard lesson): read the ACTUAL SEP-2549 source before writing the proposal —
   draft `schema.json` fields for the list results (are `ttlMs`/`cacheScope` required? enum values
   for cacheScope?), any conformance scenario in `modelcontextprotocol/conformance`
   (`gh api repos/modelcontextprotocol/conformance/git/trees/main?recursive=1`, look for cache/ttl),
   the SEP text, and current swift-sdk list-result types (`Sources/MCP/.../Tools`,`Prompts`,`Resources`).
2. Write design proposal (template `05_DESIGN_PROPOSAL.md`) → save in businessMathMCP.
3. **Adversarial review** (fan out ~3-4 reviewers) BEFORE approval — this is mandated, not optional.
4. Revise → user approval → RED/GREEN/REFACTOR → upstream PR (fork-carried).

## Environment / recovery notes
- **Working clone was in EPHEMERAL session scratchpad** (`/private/tmp/claude-501/.../scratchpad/sdk-impl`)
  — GONE after restart. To continue: re-clone `modelcontextprotocol/swift-sdk` fresh, add `fork`
  remote (`jpurnell/swift-sdk`); the fix branches live on the fork; `main` = upstream.
- **Build:** `swift build/test --scratch-path <DIR OUTSIDE Dropbox>` (Dropbox fights `.build`/`rm -rf`).
  Baseline (upstream 0.12.1 + our changes) builds clean on local Swift 6.4 in ~44s cold.
- **Conformance oracle:** official `@modelcontextprotocol/conformance` (`0.2.0-alpha.10` = draft/2026-07-28
  line; stable `0.1.16` = 2025-11-25). Repo has `src/scenarios/server/stateless.ts`. CI action is
  `@v0.1.15` (no draft) — does NOT gate 2026-07-28 work.
- **gh** authenticated as `jpurnell`. **git add: NEVER `-a`/`-A` in the swift-sdk clone** — scratch
  DESIGN/PR_BODY md files sit in the repo root (a leaked doc into #267 had to be amended out;
  `.git/info/exclude` now has `DESIGN_*.md`/`PR_BODY_*.md` but that's per-clone).
- **Outward-facing actions need approval** before posting (upstream PRs/comments under user's identity).

## Open task list (see TaskList)
- #13 coordinate #245 — POSTED, awaiting reply.
- #14 minimal stdio 2026-07-28 — queued, not gated.
- #15 SEP-2164 + SEP-2549 — IN PROGRESS (SEP-2549 first).
- #10/#11/#12 completed (#267/#268 fixes; rejected stateless proposal).
