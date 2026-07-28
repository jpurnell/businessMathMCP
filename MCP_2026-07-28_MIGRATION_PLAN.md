# MCP 2026-07-28 ("v2") Migration Plan — businessMathMCP

Status: PLAN (2026-07-28). Owner: TBD.
Scope: three repos — `jpurnell/swift-sdk` (fork), `jpurnell/SwiftMCPServer`, `businessMathMCP`.

## 0. TL;DR

- **v2 = the MCP `2026-07-28` specification** — "largest revision since launch." Stateless
  core (no sessions / no `initialize` handshake), per-request `_meta`, an Extensions
  framework (Tasks, MCP Apps, EMA), an OAuth/OIDC authorization rewrite (CIMD replaces
  DCR), and deprecation of Roots / Sampling / Logging / legacy HTTP+SSE (12-month runway).
- **Swift is NOT a Tier-1 SDK.** TS/Python/Go/C# speak `2026-07-28` today; `swift-sdk`
  does not. **v2 adoption is gated on `swift-sdk` implementing `2026-07-28`.** Until then,
  the newest spec we can serve is `2025-11-25` (swift-sdk 0.11.0).
- **Our tool layer is spec-stable.** All 200+ tools use `tools/list` + `tools/call`, which
  are unchanged in shape. The migration cost lives in the SDK + `SwiftMCPServer` transport,
  lifecycle, and auth layers — not in `ForecastEvaluationTools.swift` et al.
- **Near-term (this effort): ship the swift-sdk 0.11.0 fork-forward** (2025-11-25 spec +
  the Swift 6.3 concurrency fix). That is the right step regardless of v2 and unblocks us
  now. v2 is phased behind SDK support.

## 1. What actually changed in 2026-07-28 (server-relevant)

| Area | Change | Who absorbs it |
|---|---|---|
| **Lifecycle** | `initialize`/`initialized` handshake and `Mcp-Session-Id` removed. Every request self-describing. | swift-sdk transport + SwiftMCPServer |
| **Per-request `_meta`** | `MCP-Protocol-Version: 2026-07-28`, `io.modelcontextprotocol/clientInfo`, capabilities travel on every request. New `Mcp-Method` / `Mcp-Name` headers for gateway routing (SEP-2243). | swift-sdk transport |
| **Auth rewrite** | RFC 9207 `iss` validation (SEP-2468); **CIMD** (Client ID Metadata Documents) replaces **DCR** (deprecated); credentials bound to issuer (SEP-2352); `application_type` for localhost redirects (SEP-837). | SwiftMCPServer (it owns OAuth/session mgmt) |
| **Extensions framework** | Tasks → `io.modelcontextprotocol/tasks` (`tasks/get`, `tasks/update`, `subscriptions/listen`); MCP Apps (server-rendered UI); EMA. Namespaced, opt-in. | swift-sdk + optional server adoption |
| **Deprecations (12-mo)** | Roots, Sampling, Logging (SEP-2577); legacy HTTP+SSE transport. Keep working ≥12 months; new code shouldn't adopt. | Audit our usage (see §3) |
| **New server capabilities** | MRTR mid-call input (`resultType:"input_required"` + `inputResponses`, SEP-2322); cacheable list responses (`ttlMs`, `cacheScope` on `tools/list`, `prompts/list`, `resources/list`, `resources/read`, SEP-2549); optional `server/discover`. | Optional adoption, high value |

Sources: MCP blog `2026-07-28` post + release candidate; WorkOS auth writeup; The Register.

## 2. Impact assessment for businessMathMCP

**Low-impact (good news):**
- **Tools (207):** `tools/call`/`tools/list` semantics unchanged. `MCPToolHandler`,
  `MCPTool`, `MCPToolInputSchema`, `.success(text:)` — all stable. No per-tool rewrites.
- **Transport:** we run stdio (`businessmath-mcp-server`), not the deprecated HTTP+SSE, so
  that deprecation doesn't bite. Stateless core is mostly transparent for a stdio tools server.

**Medium-impact:**
- **Lifecycle/`_meta`:** handled inside swift-sdk once it supports 2026-07-28; our
  `MCPServer.builder()...run()` bootstrap should need only minor changes (drop any session
  assumptions; nothing in our tools depends on sessions).
- **Cacheable lists (opt-in):** with 207 tools, advertising `ttlMs`/`cacheScope` on
  `tools/list` is a real win for clients/gateways — worth adopting once supported.

**High-impact (but not ours to write first):**
- **Auth:** `SwiftMCPServer` advertises "transport, auth, OAuth, session management." The
  CIMD/RFC-9207 rewrite lands there, not in businessMathMCP. If we only ship stdio, auth is
  moot for us today; it matters if/when we expose HTTP.

**Deprecated-feature audit (must do — see §3):** confirm we don't rely on Roots / Sampling
/ Logging capabilities.

## 3. Pre-work we can do NOW (SDK-independent)

1. **Deprecated-feature audit.** `grep` the server for Sampling / Roots / Logging capability
   use. Expectation: a pure tools server uses none. Record the result so v2 is a non-event here.
2. **Session-assumption audit.** Confirm no tool or the bootstrap relies on `Mcp-Session-Id`
   or cross-call session state. (Our tools are stateless request/response — expected clean.)
3. **Transport confirmation.** We ship stdio; note we are not on the deprecated HTTP+SSE path.
4. **Version-string hygiene.** `main.swift` hardcodes `serverVersion("2.0.0")` — decouple
   the *server* version from the *protocol* version to avoid confusion when we advertise
   `2026-07-28` later.

## 4. Phased roadmap

### Phase A — NOW: swift-sdk 0.11.0 fork-forward (2025-11-25 spec)  ← this effort
- `jpurnell/swift-sdk`: branch from upstream `0.11.0`, re-apply the `SendOnce @MainActor`
  fix to `sendContinuationResumed`/`receiveContinuationResumed` in `NetworkTransport.swift`
  (upstream 0.11.0 still has this Swift-6.3 sending-risk bug — verified by build), push, tag `0.11.x`.
- `SwiftMCPServer`: point at fork `0.11.x`; fix any 0.11.0 API breakage in its own code.
- `businessMathMCP`: point at fork `0.11.x` + new SwiftMCPServer; `swift build && swift test` (291).
- Outcome: current on the newest SDK-supported spec, fork isolated to one small concurrency fix.

### Phase B — WATCH/PREP: track swift-sdk 2026-07-28 support
- Monitor `modelcontextprotocol/swift-sdk` for a `2026-07-28` release (it is not Tier-1, so
  expect a lag; watch issues/PRs / a community fork).
- Do the §3 audits; keep the tool layer clean.
- Decision gate: **adopt upstream when it ships**, or (if the fix cadence is slow and we
  need it) **contribute the 2026-07-28 work / fork it** — same maintenance model we already run.

### Phase C — ADOPT: swift-sdk 2026-07-28 available
- Bump swift-sdk to a 2026-07-28-capable version; re-run the Phase-A wiring across the 3 repos.
- SwiftMCPServer: absorb stateless lifecycle + `_meta` plumbing + `Mcp-Method`/`Mcp-Name`
  headers; auth rewrite (CIMD/RFC-9207) *if* we expose HTTP.
- businessMathMCP: advertise `MCP-Protocol-Version: 2026-07-28`; drop session assumptions
  (none expected); regression-test all 207 tools.

### Phase D — CAPABILITIES: opt into the good parts
- Cacheable `tools/list` (`ttlMs`/`cacheScope`) — high value at our tool count.
- Consider Tasks extension for the genuinely long-running tools (some optimizers / large
  Monte Carlo) via `io.modelcontextprotocol/tasks` + `subscriptions/listen`.
- MRTR (`input_required`) only if a tool needs mid-call input (none today).

## 5. Risks & watch-items
- **Swift not Tier-1** → indefinite lag on 2026-07-28 SDK support is the dominant risk. Mitigation:
  we already maintain a swift-sdk fork; contributing/forwarding 2026-07-28 is within our model.
- **Two forks to carry** (swift-sdk today; possibly again for 2026-07-28) — track the upstream
  sending-risk fix and the 2026-07-28 work so we can *drop* the fork the moment upstream is clean.
- **Client interop**: 2026-07-28 servers may not talk to old clients and vice versa (no version
  negotiation). Since we control our deployment, coordinate server+client cutover.

## 6. Immediate next actions
- [ ] Phase A: swift-sdk 0.11.0 fork-forward + SendOnce fix (in progress).
- [ ] Phase A: wire SwiftMCPServer + businessMathMCP to fork 0.11.x; build + 291 tests.
- [ ] §3 audits (deprecated features, session assumptions, transport, version string).
- [ ] Open a tracking issue watching `swift-sdk` for `2026-07-28`.
