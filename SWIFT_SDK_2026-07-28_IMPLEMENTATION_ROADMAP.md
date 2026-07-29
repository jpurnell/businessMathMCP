# swift-sdk 2026-07-28 Implementation Roadmap (full spec)

Goal: bring `modelcontextprotocol/swift-sdk` to full MCP `2026-07-28` conformance.
Model: **implement as upstream PRs** (claim the existing tracking issues), and **carry each
commit in `jpurnell/swift-sdk` (`0.12.x`)** so businessMathMCP is never blocked on upstream
review. Decision date: 2026-07-29.

## Workflow (per SEP)
1. Claim the upstream tracking issue (comment intent).
2. Read the SEP text (modelcontextprotocol SEP repo) + the Tier-1 reference impls
   (TypeScript/Python already ship 2026-07-28 — mine their PRs for the shape).
3. Design → implement → unit tests (SDK has a test suite; add conformance tests).
4. Open upstream PR against `modelcontextprotocol/swift-sdk:main`.
5. Cherry-pick the same commit onto `jpurnell/swift-sdk` `0.12.x`; tag when a phase is
   consumable so businessMathMCP can bump.
6. Update `businessMathMCP` + `SwiftMCPServer` to exercise the new capability; run 291 tests.

## Current baseline
- Fork `jpurnell/swift-sdk 0.11.1` = upstream 0.11.0 (spec 2025-11-25) + SendOnce fix +
  async-algorithms 1.1.3. businessMathMCP + SwiftMCPServer build + 291 tests green on it.
- Upstream already shipped a partial `StatelessHTTPServerTransport` in 0.11.0 (buggy —
  open PRs #257/#260/#264; issues #254/#255/#265). **Fixing those is prerequisite groundwork
  for the stateless core** and a good on-ramp (small, well-defined).

## Upstream tracking issues (the backlog)
| Issue | SEP | Title | Phase |
|---|---|---|---|
| #245 | 2575 | Make MCP Stateless | 1 |
| #244 | 2567 | Sessionless MCP via Explicit State Handles | 1 |
| #246 | 2577 | Deprecate Roots, Sampling, Logging | 1 |
| #237 | 2260 | Require server requests associated with a client request | 1 |
| #243 | 2549 | TTL for List Results | 2 |
| #238 | 2322 | Multi Round-Trip Requests (MRTR) | 2 |
| #235 | 2164 | Standardize resource-not-found error (-32602) | 2 |
| #247 | 2663 | Tasks Extension | 3 |
| — | 2243 | `Mcp-Method` / `Mcp-Name` routing headers | 3 |
| — | — | Extensions framework + MCP Apps | 3 |
| #242 | 2468 | Recommend Issuer (iss) — RFC 9207 | 4 |
| #241 | 2352 | Authorization-server binding & migration | 4 |
| #240 | 2351 | RFC 8414 well-known URI suffix | 4 |
| #239 | 2350 | Client-side scope accumulation (step-up) | 4 |
| #236 | 2207 | OIDC-flavored refresh-token guidance | 4 |
| — | — | CIMD (Client ID Metadata Docs) replaces DCR | 4 |

## Phased plan (dependency order)

### Phase 0 — Groundwork (unblocks everything)
- Fix the existing StatelessHTTPServerTransport concurrency bugs (issues #254/#255/#265;
  land/rebase PRs #257/#260/#264). These are per-request-isolation + hung-exchange bugs —
  small, and the stateless core sits on this transport.
- Add a `MCP-Protocol-Version` constant `2026-07-28` and version-negotiation plumbing
  (the spec has no negotiation handshake — servers accept the header directly).

### Phase 1 — Stateless core (the keystone) — SEP-2575, 2567, 2577, 2260
- Remove the `initialize`/`initialized` handshake requirement and `Mcp-Session-Id`
  dependence from the server/client core; make `initialize` idempotent (PR #257 direction).
- Move protocol version, `io.modelcontextprotocol/clientInfo`, and capabilities into
  per-request `_meta`; make every request self-describing. Add optional `server/discover`.
- SEP-2567: explicit state handles — helpers so a server can mint a handle from a tool
  result and accept it back as an argument (our tools are already stateless — mostly docs +
  a small API affordance).
- SEP-2577: mark Roots/Sampling/Logging deprecated (attributes + docs); keep functional.
- SEP-2260: associate server→client requests with an originating client request id.
- **Milestone: tag fork `0.12.0`; businessMathMCP advertises `2026-07-28` over stdio and
  passes 291 tests.** (stdio server needs ~none of Phase 4.)

### Phase 2 — Server capabilities — SEP-2549, 2322, 2164
- SEP-2549: add `ttlMs` + `cacheScope` to `tools/list`, `prompts/list`, `resources/list`,
  `resources/read` responses. (High value for businessMathMCP's 207 tools.)
- SEP-2322: MRTR — `resultType: "input_required"` + `inputResponses` retry protocol.
- SEP-2164: standardize resource-not-found to `-32602`.
- Milestone: tag fork `0.12.x`; businessMathMCP advertises cacheable tool lists.

### Phase 3 — Extensions framework — SEP-2663 + 2243 + MCP Apps
- Namespaced extension registration (`io.modelcontextprotocol/*`), opt-in capability model.
- Tasks: `tasks/get`, `tasks/update`, `subscriptions/listen` stream. (Wire our long-running
  optimizers / large Monte Carlo tools as Tasks — real value.)
- `Mcp-Method`/`Mcp-Name` headers for gateway routing (SEP-2243).
- MCP Apps (server-rendered UI) — scaffold; adopt later.

### Phase 4 — Authorization rewrite (largest; HTTP-only) — SEP-2468/2352/2351/2350/2207 + CIMD
- RFC 9207 `iss` validation on both sides; credential binding to issuer.
- CIMD (Client ID Metadata Documents) replacing DCR (keep DCR working, deprecated);
  `application_type` for localhost redirects; RFC 8414 well-known suffix; OIDC refresh guidance.
- Lands in SwiftMCPServer's OAuth layer primarily. **Not needed for our stdio server** —
  sequence last; sequence earlier only if/when we expose an authenticated HTTP endpoint.

## Testing & conformance
- Per-SEP unit tests in swift-sdk; add a conformance suite that exercises `2026-07-28`
  request/response shapes.
- Integration: run businessMathMCP's 291 tests against each fork `0.12.x` tag.
- Cross-client interop: validate against a Tier-1 client (TS/Python) speaking 2026-07-28
  where feasible (no version negotiation → both must be on 2026-07-28).

## Risks
- **Scale**: full spec is a multi-phase program; Phase 1 is the shippable MVP for our server.
- **Upstream review latency**: mitigated by fork-carry (we ship on fork `0.12.x`; upstream
  merges land back and we drop fork deltas as they do).
- **Auth surface (Phase 4)** is the hard part and only matters when we expose HTTP.

## First actions
- [ ] Clone upstream `modelcontextprotocol/swift-sdk` as the PR base; add fork remote.
- [ ] Phase 0: reproduce + fix the StatelessHTTPServerTransport isolation bugs (#254/#255).
- [ ] Phase 1: SEP-2575 stateless core design against the SEP text + TS/Python reference PRs.
- [ ] Comment on issues #245/#244/#246/#237 to claim Phase 1.
