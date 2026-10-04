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

60 source files, 34 test files (470 cases in 50 suites) as of 2026-10-04.

### Dependencies

| Package | Role |
|---|---|
| `BusinessMath` | the computation being served |
| [`SwiftMCPServer`](../../../Tools/SwiftMCPServer/project/master_plan.md) 5.x | transport, auth, session management, the formula evaluator, and the rule for what an error may tell a caller |
| `swift-sdk` (fork, 0.11.x) | MCP protocol — 2025-11-25 spec |
| `swift-numerics` | shared numeric support |
| `swift-docc-plugin` | documentation |

The server is assembled declaratively: `main.swift` is a single
`MCPServer.builder()` chain supplying a name, instructions, `allToolHandlers()`,
a `ResourceProvider` and a `PromptProvider`. No transport, framing, or
authentication code lives here.

Two files sit between the tools and SwiftMCPServer 5.x (added 2026-10-04):

| File | What it is |
|---|---|
| `CallerFormula.swift` | A formula from a tool argument: checked once, evaluated with values passed as values, and able to fail a run from inside a callback that cannot throw. Every formula tool goes through it |
| `CallerVisibleErrors.swift` | The `CallerVisibleError` conformances — which error types may say their piece to a caller, and the sentence for each case BusinessMath left without one |

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
- [x] Quality gate at **0 errors / 0 warnings**, no overrides (2026-09-01) — from
      111 / 1,206, with 291 tests green.
- [x] Documentation coverage 5% → 89% — ~800 declarations documented
- [x] **SwiftMCPServer 5.0.0** (2026-10-04, server version 3.0.0): loopback bind by default
      with `--host 0.0.0.0` in `scripts/deploy.sh`; formulas through the bounded parser
      (`^` is power, `/` is floating-point — results change); eighteen BusinessMath error
      types conformed to `CallerVisibleError`; no handler interpolates an arbitrary error.
      470 tests green. **Not deployed, not tagged.** Any launch configuration outside this
      repository (the systemd unit on the dev server, whatever starts production if it is not
      `deploy.sh`) still needs `--host 0.0.0.0` before it runs a 5.0.0 build.
- [x] Quality gate back to **0 errors / 0 warnings**, no overrides (2026-10-04). The gate
      had gained `fallback`, `temporal-determinism` and a stricter `logging` rule since
      2026-09-01, and `main` stood at 19 errors / 64 warnings: nineteen `Int(Double)` traps
      on caller-supplied numbers, forty-six classification chains that sorted a NaN into a
      category, nine `Calendar.current` sites, eight `catch` blocks.
- [ ] Open items after the releases — see
      [CURRENT_OpenAfterTheReleases.md](checklists/CURRENT_OpenAfterTheReleases.md).
      The one that matters: **this package is public and depends on the private
      `SwiftMCPServer`**, so the README's "add this as a dependency" is not true for
      anyone outside the account.
- [x] Dependency version pinning — `BusinessMath` 2.7.0 and `SwiftMCPServer` 1.1.6,
      both `.upToNextMinor`. See
      [completed/2026-09-01_DependencyPinning.md](checklists/completed/2026-09-01_DependencyPinning.md)

> **Correction (2026-09-01).** The Priorities note below claimed "nothing here is a
> known defect." That was wrong, and wrong in a way worth preserving: the tool surface
> was broad and green because the tests were green, not because the tools were right.
> Driving the gate to zero surfaced seven behavioural defects, including
> `ab_test_analysis` reporting a p-value that was always ≥ 0.5 — significance backwards,
> in production, contradicting the verdict printed beside it. A green suite said nothing
> about it because one test accepted "success or error, both fine" and so had never
> executed the tool it named. Breadth was not the risk; unexercised breadth was.

### Priorities

1. ~~**Cut the two dependency releases** and pin to them.~~ Done 2026-09-01. Both were
   released and pinned; the gate reads 0/0.
2. **Find the other unexercised tools.** The seasonal-indices test passed for years
   without ever running its tool. That pattern — a `catch` that accepts any outcome —
   is what to grep for next; the `test-quality` checker now catches assertion-free tests
   but not tests that assert nothing meaningful.
   *2026-10-04: two more, found the same way.* `run_scenario_analysis` refused every call
   that arrived as JSON (a cast that never matched), and no test had called it. And
   `SchemaSmokeTests` — which accepts any outcome by design — had been pricing a
   100,000-year bond, and took 903.5 seconds on `main` to do it; it passed, so nothing said
   so. The bond tools now refuse a maturity beyond 100 years and the whole suite takes ten
   seconds. Why two bond tools became that slow was not investigated. What the smoke suite still
   cannot tell anyone is whether a tool's answer is right.
3. **Scope.** Still open, and still the right question: which of the 187+ tools are
   actually called, and whether the long tail earns its maintenance.

## Quality Standards

`coding_rules.md`, Swift 6 strict concurrency, zero warnings, DocC on public types.
**Every tool documents its JSON schema** — required fields, units, enum cases. An agent
cannot introspect intent from a Swift signature, and a financial tool whose units are
ambiguous will be called wrongly with confident-looking results.

## Roadmap

**[NEEDS INPUT]** — beyond the priorities above, no committed roadmap. Candidates recorded
2026-10-04, all found while tracing which errors reach a caller and none fixed there:
`optimize_portfolio` indexes `returnsData[0]` when `returns` and `assets` are both
empty; `test_stationarity` with `lag: 0` may reach a `1...0` range in BusinessMath's ADF;
and the fourteen error types given sentences in `CallerVisibleErrors.swift` would be
better given an `errorDescription` in BusinessMath itself. One candidate
recorded 2026-09-01: reconcile the `PeriodJSON` quarterly contract. Schema descriptions
and tool examples document a `quarter` key, but `toPeriod` reads `month` and derives the
quarter from it. Callers following the documentation are silently wrong; the tests now
encode the decoder's actual behaviour rather than the documented one.

---

**Last Updated:** 2026-10-04 — reconciled against the SwiftMCPServer 5.0.0 migration:
file and test counts, the dependency table, the two new files between the tools and the
framework, a Current Status entry that says what is and is not deployed, two more
"unexercised tool" findings under Priorities, and three roadmap candidates. Previously
2026-09-01 — reconciled Current Status against the quality-gate sweep: recorded the 0/2 state
and doc coverage, added the dependency-pinning checklist, corrected the "no known defect"
claim, and rewrote Priorities around what the sweep found.
