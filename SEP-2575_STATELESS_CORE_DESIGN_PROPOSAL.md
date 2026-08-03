# Design Proposal: SEP-2575 Stateless Core (swift-sdk, MCP 2026-07-28)

> ## ⛔ Adversarial Review Outcome (2026-07-29): NOT APPROVED — restructure + re-sequence
> Four independent adversarial reviewers (spec-conformance, SDK-architecture, test-strategy,
> scope/upstream) unanimously rejected this proposal as written. Do NOT enter RED against it.
> Blocking findings (all evidence-backed):
>
> **Data model is wrong (correctness defect, not cosmetic):**
> - `_meta` keys are **namespaced** `io.modelcontextprotocol/{protocolVersion,clientInfo,clientCapabilities,logLevel}` — the flat `RequestMeta` in §3/§4 decodes *nothing* from any conformant request. (spec + test reviewers, independently)
> - `DiscoverResult` requires **5** fields (`supportedVersions, capabilities, cacheScope, resultType, ttlMs`); §3 has 2.
> - `-32022` UnsupportedProtocolVersion never stated; needs `data.requested` (echo) + `data.supported`.
> - `-32020` is a **header-vs-`_meta` mismatch**, not a missing header.
> - Removed-method set omits `resources/subscribe` + `resources/unsubscribe`.
> - serverInfo lives in result `_meta['io.modelcontextprotocol/serverInfo']` on *every* response; `logLevel` field missing; all errors must echo request id.
>
> **Architecture infeasible as "one Server.swift change + 3 files":**
> - `Server` is transport-agnostic and can't know the mode at dispatch (strict gate precedes HTTP context; version only stored via handshake). Needs mode threaded from transport → `handleRequest` before the gate.
> - Wire model (`Request<M>`, 4 fixed CodingKeys, double round-trip) drops `_meta` before handlers run → wire-model change required.
> - Stateless transport drops server→client requests → sampling/elicitation/roots **hang**.
> - `MCPError` is a fixed enum; `.serverError` encodes no `data` → can't carry `requiredCapabilities`; transport always returns HTTP 200 → no 400/404 mapping.
> - `initialize`/`ping` registered unconditionally; `validateClientCapability` reads stored state → returns `-32601` not `-32021` in stateless mode.
>
> **Test loop is not executable ("checks are our RED" is false 3×):**
> - Harness is **stateful** (`HTTPApp` requires `Mcp-Session-Id`) → every check dies at the session gate (transport noise + **false greens** on HTTP-400 checks). A **stateless harness rewrite + diagnostic tools** (`test_missing_capability`, `test_logging_tool`) is the *real* first RED and is unscoped.
> - `run-conformance.sh` uses unpinned `latest` (0.1.16, no stateless scenario) with **no** `--spec-version draft`; CI uses action `@v0.1.15` → the suite has never run here and CI gates none of it. Pin `@0.2.0-alpha.10`, add draft, add a CI job, populate `conformance-baseline.yml` `server:` block.
> - `Version.supported` lacks `2026-07-28` → probes fail at the validator; need an internal "known-but-gated" draft version early (conflicts with OQ#4 "advertise last").
>
> **Strategically mis-sequenced (the crux):**
> - Upstream #245 (SEP-2575) is maintainer-authored, **0 assignees, 0 comments, 7 weeks old**; repo has merged **nothing to `main` in ~3 months**; our own #267/#268 have 0 reviews.
> - businessMathMCP is **stdio** — the entire stateless *HTTP* surface (headers, 400/404, `-32020`) is inapplicable; the stdio consumer needs only a version bump + accepting per-request namespaced `_meta`.
> - "Phase 1b" is a **phantom**: subscription checks auto-SKIP for a non-`listChanged` server.
> - Carrying a 5-PR dispatch-core delta on the fork against a frozen upstream (TS already closed its SEP-2575; wire details still litigated in TS #2537/#2410) is the worst thing to carry.
>
> **Pivoted plan → see the "Revised direction" section appended below. This proposal is retained for the record; the corrected scope supersedes §2–§10.**

Status: NOT APPROVED (2026-07-29) — superseded by the Revised Direction below.
Original status: PROPOSAL — awaiting approval before RED.
Follows `development-guidelines/00_CORE_RULES/05_DESIGN_PROPOSAL.md`. Target repo:
`modelcontextprotocol/swift-sdk` (upstream PRs, carried on `jpurnell/swift-sdk` fork).
This is Phase 1 of `SWIFT_SDK_2026-07-28_IMPLEMENTATION_ROADMAP.md`.

## 1. Objective

Bring `swift-sdk` to the stateless server lifecycle defined by **SEP-2575** (MCP `2026-07-28`):
no `initialize`/`initialized` handshake, no session id; every request is self-describing via
per-request `_meta` (protocolVersion, clientCapabilities, optional clientInfo) plus routing
headers, with capability discovery moved to a new `server/discover` endpoint.

**Reference truth:** the official `@modelcontextprotocol/conformance` suite
(`0.2.0-alpha.10`, `--spec-version draft`), scenario `src/scenarios/server/stateless.ts`
(`ServerStatelessScenario`, ~22 checks, SEP-2575). This SDK already runs it via
`scripts/run-conformance.sh` against the `mcp-everything-server` harness with
`conformance-baseline.yml` tracking known failures.

## 2. Proposed Architecture

The stateless lifecycle is a **new mode** alongside the existing handshake path — we do NOT
delete the 2025-11-25 lifecycle (still supported per spec; deprecations get a 12-mo runway).
Selection is driven by the negotiated protocol version (draft/2026-07-28 → stateless).

**New files:**
- `Sources/MCP/Base/RequestMeta.swift` — typed per-request `_meta` envelope
  (`protocolVersion`, `clientCapabilities`, `clientInfo?`) + decode/validation.
- `Sources/MCP/Server/Discover.swift` — `server/discover` request/result types.
- `Sources/MCP/Base/StatelessErrors.swift` — new error signatures (`-32020` header mismatch,
  `-32021` missing-required-client-capability, unsupported-protocol-version) + `error.data`.

**Modified files:**
- `Sources/MCP/Base/Versioning.swift` — add the draft `2026-07-28` version + selection.
- `Sources/MCP/Server/Server.swift` — bypass `checkInitialized()` in stateless mode; derive
  `clientCapabilities` per-request from `_meta` instead of the stored handshake value; route
  `server/discover`; return 404/-32601 for removed methods (`initialize`, `ping`,
  `logging/setLevel`).
- `Sources/MCP/Base/Transports/HTTPServer/StatelessHTTPServerTransport.swift` — surface
  `MCP-Protocol-Version` / `Mcp-Method` / `Mcp-Name` (SEP-2243) into the handler context;
  map the new error signatures to HTTP 400/404.
- `Sources/MCP/Server/HandlerContext` — add per-request `clientCapabilities` + `requestMeta`.

**Scope boundary (Phase 1 vs deferred):** subscriptions (`subscriptions/listen`,
`notifications/subscriptions/acknowledged`) and dynamic list-changed streaming are part of the
conformance scenario but are a distinct streaming surface — proposed as **Phase 1b** (separate
PR) so the core lifecycle lands first. Auth stays Phase 4. `Mcp-Name`/`Mcp-Method` headers
(SEP-2243) are in-scope here because the stateless lifecycle asserts them.

## 3. API Surface

```swift
// Per-request _meta envelope (SEP-2575)
public struct RequestMeta: Sendable, Codable {
    public let protocolVersion: String
    public let clientCapabilities: Client.Capabilities
    public let clientInfo: Client.Info?          // SHOULD; server MUST NOT require it
}

// server/discover
public enum Discover: Method {
    public static let name = "server/discover"
    public struct Result: Codable, Sendable {
        public let supportedVersions: [String]
        public let capabilities: Server.Capabilities
        // self-identify via _meta["io.modelcontextprotocol/serverInfo"]
    }
}

// Handler context gains per-request client capabilities (no stored handshake state)
extension Server.HandlerContext {
    public var clientCapabilities: Client.Capabilities? { get }
    public var requestMeta: RequestMeta? { get }
}

// New error signatures (see §4 for wire shape)
extension MCPError {
    static func headerMismatch(_ detail: String) -> MCPError            // -32020, HTTP 400
    static func missingRequiredClientCapability(_ caps: Client.Capabilities) -> MCPError // -32021, 400
    static func unsupportedProtocolVersion(requested: String, supported: [String]) -> MCPError // 400
}
```

## 4. Wire Schema (per-request `_meta` + errors)

Stateless request (no handshake; `_meta` on every request):
```json
{
  "jsonrpc": "2.0", "id": 1, "method": "tools/call",
  "params": { "name": "x", "arguments": {} },
  "_meta": {
    "protocolVersion": "2026-07-28",
    "clientCapabilities": { "sampling": {}, "elicitation": {} },
    "clientInfo": { "name": "app", "version": "1.0" }
  }
}
```
Headers: `MCP-Protocol-Version: 2026-07-28`, `Mcp-Method: tools/call`,
`Mcp-Name: <params.name | params.uri | params.taskId>` (SEP-2243).

Error signatures (conformance-asserted):
- Missing `_meta`/`protocolVersion`/`clientCapabilities` → `-32602` + HTTP 400.
- Missing/altered `MCP-Protocol-Version` header → `-32020` "Header Mismatch" + 400.
- Undeclared capability use → `-32021` + 400, `error.data.requiredCapabilities` a
  `ClientCapabilities` object (e.g. `{"sampling":{}}`), NOT an array.
- Unknown/removed method (`initialize`,`ping`,`logging/setLevel`) → HTTP 404 + `-32601`,
  original request id preserved.

## 5. Constraints & Compliance

- **Concurrency:** `RequestMeta`, `Discover.Result` are immutable `Sendable` value types.
  Removing stored `isInitialized`/`clientCapabilities` from the actor makes the server *more*
  stateless (per-request derivation), reducing shared mutable state.
- **Safety:** no force unwrap; validate `_meta` with guards → typed errors; division-free.
- **Back-compat:** 2025-11-25 handshake path untouched; stateless selected by version.
- **Generics:** N/A (protocol wire types, not numeric).

## 6. Backend Abstraction

N/A — lifecycle/transport change, no compute backend.

## 7. Dependencies

- Internal: existing `Metadata`/`_meta` (`Lifecycle.swift`), `Version` (`Versioning.swift`),
  `Client.Capabilities`/`Server.Capabilities`, `StatelessHTTPServerTransport` (now with the
  #267/#268 fixes), `HTTPContextProviding`.
- External: none new. Test-time only: `npx @modelcontextprotocol/conformance@alpha` (already
  used by `scripts/run-conformance.sh`).

## 8. Test Strategy

**Reference truth = the official conformance suite** (spec-authored, independently verifiable):
```
npx @modelcontextprotocol/conformance@alpha server --spec-version draft \
    --url http://localhost:3001/mcp --suite all
```
The stateless scenario's ~22 checks ARE the RED set. TDD loop per requirement group:
1. Run conformance → capture the failing checks for the group (RED).
2. Implement the minimal server/transport change (GREEN).
3. Update `conformance-baseline.yml` (remove the now-passing expected-failures).

**Supplementary Swift-Testing unit tests** (fast inner loop, mirror `HTTPServerTransportTests`):
- `_meta` validation: missing `_meta` → -32602/400; missing `clientInfo` → served.
- `server/discover` returns supportedVersions + capabilities + serverInfo `_meta`.
- Version header: bad → unsupported-version/400; missing → -32020/400.
- Capability gate: undeclared sampling use → -32021/400 with `requiredCapabilities` object.
- Method routing: `initialize`/`ping`/unknown → 404/-32601, id preserved.

**Validation trace (golden):** a `tools/call` with `_meta.clientCapabilities` omitting
`sampling`, whose handler requests sampling → response `error.code == -32021`,
`error.data.requiredCapabilities == {"sampling":{}}`, HTTP 400. (Asserted by the conformance
`Client Capability Constraints` check.)

## 9. Architecture Decision Review

- New ADR recommended (repo-local, in the PR description, not BusinessMath's ADR log):
  **"swift-sdk stateless lifecycle is additive, version-selected"** — key decision: keep the
  2025-11-25 handshake path; select stateless by negotiated protocol version; derive client
  capabilities per-request from `_meta` rather than stored handshake state.

## 10. Open Questions

1. **PR granularity:** one PR per conformance requirement group (≈5 PRs: version/headers →
   `_meta` validation → `server/discover` → capability gate → method routing), or one larger
   "stateless core" PR? Recommendation: **per-group PRs**, stacked, for reviewability.
2. **Colliding-id support (deferred from #267):** fold the internal-id-remap +
   `HandlerContext.originalID` into the `server/discover`/routing PR, or its own follow-up?
   Recommendation: its own follow-up once routing lands (keeps #267 mitigation intact meanwhile).
3. **`mcp-everything-server` harness:** does it need new tools (`test_missing_capability`) the
   conformance scenario references? Likely yes — a harness-only change, no library impact.
4. Do we advertise `2026-07-28` in `Version.supported` immediately, or behind a flag until all
   groups pass (avoid claiming support mid-implementation)? Recommendation: **behind the
   stacked PRs**; flip `supported` in the final group PR.

## 11. Documentation Strategy

**Type:** API docs (DocC) on all new public types + a short narrative note in the transport
docstring. Not a full guide article (the conformance suite is the normative reference).

---

## Proposal Review Checklist
- [x] Module placement follows swift-sdk structure (Base/ + Server/ + transports).
- [x] Concurrency: immutable Sendable value types; less shared mutable state.
- [x] No forbidden patterns (guards, typed errors, no force unwrap).
- [x] Test reference truth = official conformance suite (no hallucinated expectations).
- [ ] **User approval to proceed to RED.**

---

## Revised Direction (2026-07-29, post-adversarial-review)

The keystone-first plan is replaced by a coordinate-and-de-risk sequence:

1. **Coordinate upstream FIRST (blocking gate).** Comment on issue #245 to claim intent and
   ask the maintainer (localden) for the intended design/ownership. No stateless-core code
   until there's a reply or explicit green light. Rationale: #245 is unowned, the repo is
   merge-frozen (~3mo), and TS has already implemented SEP-2575 — Swift will be expected to
   match *that* shape, not ours.
2. **Prove a merge path exists.** Get the already-open Phase-0 transport bugfixes (#267/#268)
   reviewed/merged. If a ~60-line fix can't merge, a 5-PR dispatch-core rewrite won't.
3. **Ship the consumer's real need cheaply — minimal stdio 2026-07-28.** Add the
   `2026-07-28` version constant + accept per-request **namespaced** `_meta`
   (`io.modelcontextprotocol/*`) on the existing path. This is ~all businessMathMCP (a stdio
   tools server) needs; no HTTP/headers/400-404 surface.
4. **Do the self-contained, high-value pieces next (low fork risk):** SEP-2164 (standardize
   resource-not-found to `-32602`, trivial) and SEP-2549 (TTL/`cacheScope` on list results —
   "high value for 207 tools"). Neither touches the lifecycle/dispatch core.
5. **Defer the full stateless HTTP core** until #245 has a maintainer-blessed design and a
   demonstrated merge path. When undertaken, the CORRECTED scope must include (omitted from
   the original §2 file list):
   - **Harness rewrite**: a session-less `mcp-everything-server` entrypoint on
     `StatelessHTTPServerTransport` + diagnostic tools (`test_missing_capability`,
     `test_logging_tool`) with the scenario's exact semantics — the *real* first RED.
   - **Wire-model change**: carry namespaced `_meta` through `Request<M>` /
     `AnyRequest` / `TypedRequestHandler`.
   - **Mode threading**: transport → `handleRequest` sets a per-request lifecycle mode before
     the strict gate (Server never parses HTTP itself).
   - **Error-model**: new `MCPError` cases for `-32020`/`-32021`/`-32022` with custom `data`
     encoding + Equatable/Hashable/decode; transport response-body-aware HTTP status mapping.
   - **server→client in stateless**: add SSE-on-POST or explicitly gate sampling/elicitation/
     roots as unsupported (today they silently hang).
   - **Corrected data model**: namespaced `_meta` keys; 5-field `DiscoverResult`;
     serverInfo in result `_meta` on every response; `logLevel`; id-echo on all errors.
   - **Deterministic oracle + CI**: pin `@0.2.0-alpha.10`, `--spec-version draft`, new CI job
     vs the stateless harness, populated `conformance-baseline.yml` `server:` block; keep the
     stable/2025-11-25 suite as the back-compat regression oracle.

**What the reviewers confirmed correct (keep):** `-32021` + HTTP 400 + `requiredCapabilities`
as a `ClientCapabilities` object; missing `_meta` → `-32602` + 400; `clientInfo` optional
(follow conformance/PR #3002, not the SEP's stale "Required"); removed methods → 404 + `-32601`.
