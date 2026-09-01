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
- [x] Quality gate at **0 errors / 2 warnings**, no overrides (2026-09-01) — from
      111 / 1,206. Both remaining warnings are dependency branch pins, not code.
- [x] Documentation coverage 5% → 89% — ~800 declarations documented
- [ ] Dependency version pinning — see
      [CURRENT_DependencyPinning.md](checklists/CURRENT_DependencyPinning.md)

> **Correction (2026-09-01).** The Priorities note below claimed "nothing here is a
> known defect." That was wrong, and wrong in a way worth preserving: the tool surface
> was broad and green because the tests were green, not because the tools were right.
> Driving the gate to zero surfaced seven behavioural defects, including
> `ab_test_analysis` reporting a p-value that was always ≥ 0.5 — significance backwards,
> in production, contradicting the verdict printed beside it. A green suite said nothing
> about it because one test accepted "success or error, both fine" and so had never
> executed the tool it named. Breadth was not the risk; unexercised breadth was.

### Priorities

1. **Cut the two dependency releases** and pin to them — the only thing between here and
   0 / 0, and a genuine reproducibility gap while it stands.
2. **Find the other unexercised tools.** The seasonal-indices test passed for years
   without ever running its tool. That pattern — a `catch` that accepts any outcome —
   is what to grep for next; the `test-quality` checker now catches assertion-free tests
   but not tests that assert nothing meaningful.
3. **Scope.** Still open, and still the right question: which of the 187+ tools are
   actually called, and whether the long tail earns its maintenance.

## Quality Standards

`coding_rules.md`, Swift 6 strict concurrency, zero warnings, DocC on public types.
**Every tool documents its JSON schema** — required fields, units, enum cases. An agent
cannot introspect intent from a Swift signature, and a financial tool whose units are
ambiguous will be called wrongly with confident-looking results.

## Roadmap

**[NEEDS INPUT]** — beyond the priorities above, no committed roadmap. One candidate
recorded 2026-09-01: reconcile the `PeriodJSON` quarterly contract. Schema descriptions
and tool examples document a `quarter` key, but `toPeriod` reads `month` and derives the
quarter from it. Callers following the documentation are silently wrong; the tests now
encode the decoder's actual behaviour rather than the documented one.

---

**Last Updated:** 2026-09-01 — reconciled Current Status against the quality-gate
sweep: recorded the 0/2 state and doc coverage, added the dependency-pinning checklist,
corrected the "no known defect" claim, and rewrote Priorities around what the sweep found.
