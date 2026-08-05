# businessMathMCP — MCP server + swift-sdk 2026-07-28 effort

This repo hosts the BusinessMath MCP server (207+ tools) AND coordinates the upstream
`modelcontextprotocol/swift-sdk` MCP `2026-07-28` implementation effort. It is a sibling of
`../BusinessMath/` (the core library, where the development-guidelines process lives).

## Session Start / `/recover` (read in this order)

1. **`MCP2_SESSION_HANDOFF.md`** — LIVE state: current repos/branches/PRs, the pivot, the exact
   next action. Always read this first; it's the volatile "where we left off."
2. `SWIFT_SDK_2026-07-28_IMPLEMENTATION_ROADMAP.md` — the full-spec plan (has a re-sequenced banner).
3. `SEP-2575_STATELESS_CORE_DESIGN_PROPOSAL.md` — read the NOT-APPROVED banner + Revised Direction
   (why we are NOT building the stateless core yet; the corrected spec facts).
4. `MCP_2026-07-28_MIGRATION_PLAN.md` — earlier consumer-side migration plan.
5. Cross-session memory (does NOT auto-load here — keyed to the BusinessMath project path):
   `~/.claude/projects/-Users-jpurnell-Dropbox-Computer-Development-Swift-Playgrounds-Math-BusinessMath/memory/project_swift_sdk_mcp2_impl.md`

## Process (MANDATORY — same discipline as BusinessMath)

The development-guidelines are in the sibling repo: `../BusinessMath/development-guidelines/`.
For any non-trivial feature:
1. **Design proposal** first (`development-guidelines/rules/design_proposal.md` template). Ground it in the
   REAL spec source (schema.json + the official `@modelcontextprotocol/conformance` scenarios)
   BEFORE writing it — do not paraphrase from memory.
2. **Adversarial review** of the proposal (fan out independent reviewers to break it) BEFORE
   seeking approval. This is not optional — it rejected the SEP-2575 proposal and saved weeks.
3. **User approval** → **TDD** (RED/GREEN/REFACTOR) → **quality gate** → upstream PR (fork-carried).

## Upstream contribution model

- Implement MCP `2026-07-28` as **upstream PRs** to `modelcontextprotocol/swift-sdk`, carried on
  the `jpurnell/swift-sdk` fork (`0.12.x`) as fallback. Baseline: upstream **0.12.1**.
- **Outward-facing actions need user approval before posting** — upstream PRs and issue comments
  go out under the user's GitHub identity.

## Environment / gotchas

- **swift-sdk working clone is ephemeral** (session scratchpad). Re-clone upstream + add `fork`
  remote to continue; all branches/PRs are safe on the fork. Nothing is lost on restart.
- **Build with `--scratch-path <DIR OUTSIDE Dropbox>`** — Dropbox sync fights `.build`/`rm -rf`.
- **NEVER `git add -a`/`-A` in the swift-sdk clone** — scratch DESIGN/PR_BODY md files sit in the
  repo root and have leaked into a PR before. Stage explicit paths only.
- swift-async-algorithms must be ≥1.1.3 on Swift 6.4 (not a direct dep at upstream 0.12.1).
- Untracked here that are NOT session work: `scripts/`, `BusinessMathMCP_README/DEPLOYMENT_QUICKSTART.md`.

## Repo facts

- This repo pins swift-sdk fork `0.11.0..<0.12.0` + BusinessMath/SwiftMCPServer `branch: main`.
- Server transport is **stdio** (`businessmath-mcp-server`) — needs ~none of the stateless HTTP surface.
- Tools live in `Sources/BusinessMathMCP/Tools/`; 291 MCP tests.
