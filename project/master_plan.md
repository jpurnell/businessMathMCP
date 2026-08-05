# businessMathMCP Master Plan

**Purpose:** Source of truth for project vision, architecture, and goals.

> **Provenance:** Written 2026-08-05 from README, `Package.swift`, and the source tree.

---

## Project Overview

### Mission

An MCP server exposing BusinessMath's financial and statistical library as tools an AI agent
can call.

### Target Users
- AI agents doing financial analysis — valuation, statistics, optimisation, forecasting
- MCP-capable hosts such as Claude Desktop and Claude Code
- Anyone who wants BusinessMath's results without writing Swift

### Key Differentiators
- **A large, coherent tool surface** rather than a handful of calculator endpoints — the
  library's breadth is the product
- **Deterministic, auditable answers.** Every result comes from tested library code, so the
  same inputs give the same output and the derivation is inspectable — the opposite of an
  LLM estimating a discount rate
- Financial correctness is the library's problem, already solved and tested there

---

## Architecture

- **Language:** Swift 6 · **Build:** SwiftPM · **Testing:** Swift Testing

```
Sources/BusinessMathMCP/
├── Tools/                 # one file per tool family
└── BusinessMathMCP.docc/
Sources/BusinessMathMCPServer/
└── main.swift             # builder invocation only
```

57 source files, 26 test files (291 cases).

### Dependencies

| Package | Role |
|---|---|
| `BusinessMath` | the computation being served |
| [`SwiftMCPServer`](../../../Tools/SwiftMCPServer/project/master_plan.md) | transport, auth, session management |
| `swift-sdk` (fork, 0.11.x) | MCP protocol — 2025-11-25 spec |
| `swift-numerics` | shared numeric support |
| `swift-docc-plugin` | documentation |

The server is assembled declaratively: `main.swift` is a single
`MCPServer.builder()` chain supplying a name, instructions, `allToolHandlers()`,
a `ResourceProvider` and a `PromptProvider`. No transport, framing, or
authentication code lives here.

> **Correction (2026-08-05).** This section previously stated that `Package.swift`
> "declares no external package dependencies" and raised adopting `SwiftMCPServer`
> as an open question. Both were wrong: it declares the five above, and every one
> of the 57 sources already imports `SwiftMCPServer`. The claim cited `Package.swift`
> as its provenance while contradicting it. Nothing was migrated to resolve this —
> the work was already done, and only the record was inaccurate.

---

## Current Status

- [x] Tool surface implemented and tested — 26 test files, 291 cases
- [x] CI configured
- [x] Built on `SwiftMCPServer` (verified 2026-08-05: builds clean, 291 tests pass)

### Priorities
**[NEEDS INPUT]** — the tool surface is broad and green; nothing here is a known
defect. The open question is scope: which of the 187+ tools are actually exercised
by callers, and whether the long tail earns its maintenance.

## Quality Standards

`coding_rules.md`, Swift 6 strict concurrency, zero warnings, DocC on public types.
**Every tool documents its JSON schema** — required fields, units, enum cases. An agent
cannot introspect intent from a Swift signature, and a financial tool whose units are
ambiguous will be called wrongly with confident-looking results.

## Roadmap

**[NEEDS INPUT]**

---

**Last Updated:** 2026-08-05
