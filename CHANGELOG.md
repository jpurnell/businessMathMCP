# Changelog

All notable changes to the BusinessMath MCP server are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- **`ab_test_analysis` reported significance backwards.** The tool derived its p-value
  from a helper returning `normSDist(|z|)` — a left-tail probability of an absolute
  value, so **always ≥ 0.5**. Every experiment came back insignificant by that number,
  while the verdict line printed beside it was computed separately and often said the
  opposite. Confirmed against the running server, which returned
  `P-Value: 0.9824` and `✓ SIGNIFICANT at α = 0.05` in the same response. The p-value and
  the verdict now both come from `Experiment.analyze(_:alpha:)`, so they cannot disagree.
- **`analyze_scenarios` silently dropped inputs.** Inside `Scenario`'s non-throwing
  configuration closure, a malformed distribution hit `catch { return }` — abandoning the
  scenario's *remaining* inputs, not just the bad one — and a distribution of an
  unsupported type was dropped with no error at all. Inputs are now resolved before the
  closure, where a failure can throw and name the scenario and input it came from.
- **`optimize_stochastic` and `genetic_algorithm_optimize` ignored declared arguments.**
  Both advertise a parameter in `inputSchema` and document it in their own usage
  examples, then never read it — `uncertainParameters` and `searchRegion` respectively.
  A caller supplying either got guidance computed as though they had not. Both are now
  read and reflected in the output.
- **`calculate_mirr` asserted a cause it had not checked.** A failed IRR was reported as
  "unusual cash flows"; IRR also fails on fewer than two flows and on non-convergence.
  The outcome is now carried as a `Result` so the real reason reaches the caller, and an
  IRR failure still does not fail the MIRR call it only supplements.
- **`calculate_seasonal_indices` had a test that never ran it.** The fixture used
  `"values": [80.0]` where the decoder wants a scalar `"value"`, and omitted the required
  `periodsPerYear`; a `catch` accepting "success or error, both fine" let it pass anyway.
  Fixing the fixture exposed a second shape error — a quarterly period is expressed by its
  first `month`, not a `quarter` key, since `PeriodJSON.toPeriod` derives the quarter as
  `(month - 1) / 3 + 1`. The test now asserts the indices actually come back.
- **Five `try?` sites in `ForecastingTools` collapsed two different failures into one
  message.** `TrendModel.project` both throws *and* returns an optional, so "Failed to
  project forecast" was all a caller ever saw. A thrown error now propagates with its own
  reason, and only a nil result is reported locally.
- **Two time-series decode probes named the wrong problem.** `getTimeSeries` decoded the
  wrapped `{"data": …}` shape and caught the failure to reach the flat-array shape, so a
  malformed *wrapped* series fell through and reported "expected an array" — hiding the
  field that was actually wrong. The shape is now decided from the payload's opening
  token, before decoding.
- **99 force unwraps removed**, in four families and mostly hiding something:
  - `x != nil ? … x! …` ternaries became `map`/`flatMap`, which is where the two
    division-by-zero bugs above surfaced;
  - `.first!`/`.last!` on arrays became bound endpoints, stated where the "at least two
    entries" invariant is still visible rather than twenty lines away;
  - `String.data(using: .utf8)!` became `Data(s.utf8)`, which cannot fail at all;
  - `Calendar.date(byAdding:)!` became a `guard` that reports an unrepresentable maturity
    date instead of trapping on it.
- **Seven dead private helpers removed** — copy-pasted `formatNumber`/`formatCurrency`/
  `formatRatio`/`separator`/`createDistribution` bodies that no file called.
- **`try!` gone from the test suite**; the enclosing tests throw, so a failure names itself
  instead of taking the run down.
- **Exact float equality in marshalling tests** now says what it means. These compare a
  decoded value against the literal it was decoded from, so exactness is the claim —
  `isEqual(to:)` is `==` under a name that reads as a decision.


- **`value_equity_fcfe` advertised no way to reach its per-share output.** `execute` reads
  `sharesOutstanding` and appends a "Value Per Share" section when it is supplied, but the
  tool's `inputSchema` never declared the argument — so no client could know to send it,
  and that section was unreachable in practice. Confirmed against the running server: the
  advertised schema carried five properties, and a call returned a valuation with no
  per-share line. The sibling equity tools declare the same argument in the same words.
- **Infinite ARPU on a zero-customer tenant.** `saas_metrics` computed
  `mrr / customers!` with only a `!= nil` check, so a tenant with zero customers divided
  by zero. That guard and four others in the same function are now expressed with
  `map`/`flatMap`, which removes the force unwraps and adds the zero checks that were
  missing.

### Changed

- **Both first-party dependencies are pinned to version tags, not `branch: "main"`.**
  `BusinessMath` at `.upToNextMinor(from: "2.7.0")` and `SwiftMCPServer` at
  `.upToNextMinor(from: "1.1.6")`. A branch pin means a fresh clone today and in a month
  resolve to different code, which is a reproducibility gap rather than a style
  preference — it was the last thing between this package and a clean gate. Both
  dependencies were released to make it possible.
- **`swift-tools-version` raised 6.0 → 6.2**, meeting the gate's floor.
- **The `.docc` catalogue is declared `resources: [.copy(...)]`**, not `exclude:`.
  `exclude:` removes the catalogue from the file list swift-docc-plugin reads, so DocC
  ran with no catalogue and `doc-lint` passed while checking nothing.
- **Conditionally required arguments are read conditionally.** `calculate_probability`
  needs `threshold` for `above`/`below` and `lower`/`upper` for `between`;
  `calculate_confidence_interval` needs either `values` or a complete
  `mean`/`stdDev`/`sampleSize` triple. All were read through throwing getters while
  absent from `required`. They now read optionally and throw an error naming the branch
  that needed the key.
- **`growthRate` is guarded rather than caught** in `analyze_financial_trends` — a zero
  beginning value is the only way that function fails, so the condition is tested where
  it is visible.

### Tests

- **Twenty-three tests had no assertion.** Twenty were "valid params don't throw", real
  tests now stated explicitly with `#expect(throws: Never.self)`. Three swallowed their
  errors internally, where such a wrapper would have asserted nothing; each got a real
  assertion instead — that the schema sweep exercised a handler at all, that every
  registered tool's schema converted, and the seasonal-indices fix above.
- **Four `!= nil` assertions now assert the value:** schema `type == "object"`, the
  snake_case regex matching exactly once, `items` naming a real JSON Schema type, and the
  round-trip tool unwrapped with `#require` and checked for its advertised description.

### Notes

- A local checkout of `SwiftMCPServer` resolved at `774d7e1` produced
  `redefinition of module 'CSQLite'` for anything compiling against the full dependency
  graph. That revision predates the commit which removed SwiftMCPServer's own `CSQLite`
  target, and SwiftOAuth vends a `CSQLite` system-library shim of its own, so both were
  present at once. `swift build` tolerated it; the doc-comment compiler did not.
  `Package.resolved` is not tracked here, so there is nothing in the repository to fix —
  `swift package update SwiftMCPServer` clears it, and a fresh clone resolves `main` and
  never sees it. Recorded because the error names a module collision and reads like a
  design problem, which it is not.
### Added

- **Documentation for 800 public declarations.** Every tool type, its `tool` definition,
  its `execute` method and its initialiser now carry documentation generated from that
  tool's own name and description, so each names the tool it implements rather than
  repeating a template. Coverage moved from 5% to 89%.

## [1.0.0] - 2026-02-06

### Added

- **Initial MCP server extraction from BusinessMath.** The server exposes the library's
  statistics, time-series, financial-statement, valuation, optimization and simulation
  functions as MCP tools over stdio, with `TypeMarshalling` translating between JSON
  arguments and the library's Swift types.

[Unreleased]: https://github.com/jpurnell/businessMathMCP/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/jpurnell/businessMathMCP/releases/tag/v1.0.0
