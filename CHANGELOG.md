# Changelog

All notable changes to the BusinessMath MCP server are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed

- **Two divisions state their own zero guard**, for the widened quality-gate rule
  `fp-division-unguarded`. Neither could divide by zero, and no result or error message
  changes.
  - `simulated_annealing_optimize`: the step estimate divides by `initialTemperature`.
    `execute` already refuses a value that is not greater than 0; `estimateTemperatureSteps`
    now makes the same check, with the same message, before it divides.
  - `apply_seasonal_pattern`: the seasonalized average is taken with `meanValue`, in the
    guard that already refuses an empty `trendValues`, instead of a separate division by
    the count.

## [3.0.0] - 2026-10-04

**A breaking release: formulas give different answers, a server started as before is no longer
reachable from other machines, and errors say less unless they were written for the caller.**
All three follow from moving to [SwiftMCPServer 5.0.0][smcp-5], a security release. Read
[Upgrading a deployed server](#upgrading-a-deployed-server) before deploying.

The version is 3.0.0 because the server has reported `2.0.0` since before this changelog had
an entry for it; everything listed under this heading, including the fixes that had
accumulated as unreleased, ships together.

### Formula results change

Ten tools take a formula as text: `newton_raphson_optimize`, `gradient_descent_optimize`,
`goal_seek`, `run_monte_carlo`, `sensitivity_analysis`, `tornado_analysis`,
`run_scenario_analysis`, `analyze_scenarios`, `run_correlated_monte_carlo` and
`run_monte_carlo_gpu`. They used to paste each input's value into the formula text and hand
the result to `NSExpression`. They now pass values as values to a bounded arithmetic parser.
**The same formula can return a different number, and several formulas that used to return a
number are now errors.**

| Formula | Before | Now |
| :--- | :--- | :--- |
| `2 ^ 3` | **1** — `^` was bitwise XOR | **8** — `^` is power, right-associative, tighter than unary minus (`-2 ^ 2` is −4) |
| `10 / 4` | **2** — integer literals divided as integers | **2.5** — division is always floating-point |
| `{0} ^ 2` with `{0}` = −3 | evaluated the text `-3.0 ^ 2` | 9 — the value is passed, not pasted |
| `exp(x)`, `max(x, 1)` in `newton_raphson_optimize` | every `x` was replaced, including the ones inside `exp` and `max` | evaluated — `x` is a variable |
| `rate_cap - rate` in `analyze_scenarios` | `rate` was replaced inside `rate_cap` too | evaluated — a name is a whole word |
| `1 / 0` | 0 | an error |
| `exp(1000)`, `sqrt(-1)`, any non-finite result | `inf` or `nan`, returned as a result | an error |
| `2 ** 3` | 8 | an error — write `2 ^ 3` |
| `sum({…})`, `average({…})`, `median({…})`, `stddev({…})`, `count({…})` | evaluated over the list | an error — these functions are gone |
| `max({1, 5, 3})` | aggregate over a list | an error — write `max(1, 5, 3)` |
| `random()`, hex literals (`0x10`), `&` `\|` `<<`, `TERNARY(…)` | evaluated | an error |
| `pi`, `e` | 0 | 3.14159…, 2.71828… — constants |
| `pow(2, 3)`, `sin(0)`, `log10(100)`, `2 +`, an empty formula, an unknown name | **stopped the server** (an uncaught `NSException`) | evaluated, or an error |
| anything else that did not evaluate | 0, fed into the calculation as though it were a result | an error |

The grammar, the function list and the constants are in every formula argument's schema
description and in the new *Formulas and Errors* article.

**A formula that cannot be evaluated is now an error, never a zero.** Each formula is checked
once before anything runs, and a bad one is refused with what is wrong and where —
`Invalid arguments: formula is not a valid formula. Unexpected '*' at position 3.` A formula
that is well formed but has no value at some point — it divides by zero at the initial guess,
on one Monte Carlo iteration, at one step of a sweep — fails the whole call and names the
point: `Invalid arguments: calculation has no value at revenue = 100.0, {1} = 100.0. The
formula divides by zero.` Previously that iteration contributed a zero and the tool reported
statistics over the result.

**`analyze_scenarios` input names must be identifiers** — a letter or underscore, then
letters, digits and underscores, each used once. The model refers to inputs by name, and a
name with a space in it could never be referred to: the tool's own example
(`"inputNames": ["Sales Volume", …]` with the model `volume * price * (1 - margin)`) named
three things that had no value, and never worked. The example now uses `volume`, `price` and `margin`, and a name
that is not an identifier is refused. `inputs[0]` is still accepted as a spelling of `{0}`.

Inputs can also be written by name where they have one: `x` in `goal_seek` and
`sensitivity_analysis` as well as `newton_raphson_optimize`; each input's `name` in
`run_monte_carlo`, `tornado_analysis`, `run_correlated_monte_carlo` and `run_monte_carlo_gpu`;
each entry of `inputNames` in `run_scenario_analysis` — in each case when the name is an
identifier. `{0}`, `{1}`, … work everywhere, as before.

### Security

- **The HTTP listener binds `127.0.0.1` unless asked for more.** With SwiftMCPServer 5.0.0 a
  server started with `--http 8080` alone listens on loopback only. `scripts/deploy.sh` now
  starts the production server with `--host 0.0.0.0`, and the run instructions, Docker and
  systemd examples say which bind each wants.
- **Formulas are no longer evaluated by `NSExpression`.** A formula is text chosen by the
  caller, and `NSExpression(format:)` is an interpreter with key paths, `FUNCTION()` selector
  calls and `CAST()`. What it could not parse raised an Objective-C exception that Swift
  cannot catch, so `pow(2,3)` in a formula argument terminated the process.
- **An error's text reaches the caller only if it was written for the caller.** SwiftMCPServer
  5.0.0 returns a thrown error's message only when its type conforms to `CallerVisibleError`;
  anything else is `The server could not complete the request. Reference: err-…`, with the
  detail in the server's log under that id. This package now conforms the error types its
  tools throw about the caller's own data:
  - `BusinessMathError`, `FinancialModelError`, `SimulationError` and `ScenarioError` use the
    description BusinessMath wrote.
  - `TrendModelError`, `SeasonalityError`, `OperationsError`, `ForecastError`,
    `ValuationError`, `PortfolioOptimizerError`, `AccountError`, `ExperimentError`,
    `RegressionError`, `MatrixError`, `OptimizationError`, `XNPVError`, `BacktestError` and
    `CorrelatedNormalsError` have no description in BusinessMath. Callers used to receive
    `The operation couldn’t be completed. (BusinessMath.ForecastError error 0.)`; each case
    now has a sentence — `Not enough data to forecast: 2 data point(s) are required and 1 were
    provided.` `OptimizationError`'s associated messages name solver types and GPU state, and
    `MatrixError.invalidDecomposition`'s quotes LAPACK, so those are not passed on.
  - `MarshallingError` and `ResourceError`, this package's own.
- **No handler builds a response from an arbitrary error.** Thirteen `catch` blocks
  interpolated `error.localizedDescription` or `\(error)` into what they returned
  (`calculate_irr`, `calculate_xnpv`, `calculate_xirr`, `newton_raphson_optimize`,
  `gradient_descent_optimize`, `goal_seek`, `optimize_mean_variance_portfolio`,
  `analyze_scenarios`, `calculate_mirr` twice, `backtest_forecast`, `assess_forecastability`,
  `test_stationarity`). Each now catches the specific type the call throws, and throws its
  fuller account — built from that error's caller message — as a `ToolFailure`; anything
  the `catch` did not name propagates to the server's disclosure. A test fails if any
  source file contains one of the three spellings again.
- **The bond tools refuse a maturity or call date beyond 100 years.** `price_bond`,
  `calculate_bond_ytm`, `calculate_bond_duration`, `price_callable_bond` and `calculate_oas`
  build one cash flow per coupon period and, for a yield or a spread, reprice the bond on
  every solver iteration — so the work a call asks for grew with a number the caller chose.
  `yearsToMaturity: 100000` held a core for minutes, and a value too large for `Int` stopped
  the process at `Int(yearsToMaturity)`. Both are now
  `Invalid arguments: yearsToMaturity must be a number of years from 0 to 100`. This is also
  what `SchemaSmokeTests`, which sends `100000.0` for every number and accepts any outcome,
  had been spending fifteen minutes on: 903.5 seconds on `main`, against ten for the whole
  suite now.
- **A malformed time series is reported as the caller's argument.** `getTimeSeries` let a
  `DecodingError` escape, which 5.0.0 withholds. It is now wrapped, and the path begins with
  the argument's name: `Invalid arguments: data[1].value must be a number`,
  `Missing required argument: data[0].period`.

### Fixed: what the quality gate had learned to see

The repository was last at zero findings on 2026-09-01. The gate has since gained a
`fallback` checker, a `temporal-determinism` checker and a stricter `logging` rule, and on
`main` it reported 19 errors and 64 warnings. They are fixed here, in code; each of the first
two groups is a way a caller's number could stop the server or be reported as something it
was not.

- **`Int(Double)` on a caller's number — 19 sites, each a trap.** `Int(.nan)`,
  `Int(.infinity)` and `Int(1e300)` stop the process. Arguments are now validated where they
  are read, and the tool says which and why: `crossoverRate` and `mutationRate` must be
  probabilities, `differentialWeight` from 0 to 2, the annealing temperatures positive and
  ordered and `coolingRate` strictly between 0 and 1, `timeHorizon` from 0 to 100 years, a
  gamma shape or degrees of freedom from 1 to 1,000,000. Conversions that existed only to
  print a number format the number instead; a sample size or step count too large to count is
  refused. `tornado_analysis` no longer divides zero by zero when no variable moves the
  output, and `analyze_simulation_results` refuses values whose spread is not finite.
  **Inputs outside those ranges used to produce output and are now refused.**
- **A value that is not a number is no longer sorted into a category — 46 sites.** Chains such
  as `if ratio >= 2 { "Excellent" } else if … else { "Low" }` put a NaN in the last arm and an
  infinity in the first, so an overflowed ratio was "Excellent" and 0/0 was "Low". Each chain
  now has a first arm for the non-finite case that says so (`Not available - the current ratio
  is not a finite number for these inputs`); where the value is the caller's own argument
  (`beta`, a credit `zScore`) it is refused instead. Nothing changes for a finite value.
- **Dates no longer depend on the machine's time zone — 9 sites.** Daily periods and
  bond and loan maturities were built with `Calendar.current`, while BusinessMath reads every
  date in Gregorian UTC. On a machine east of UTC `{"year": 2024, "month": 3, "day": 15}`
  was local midnight, which is the 14th in UTC, so the library saw the day before the one
  named. There is now one Gregorian-UTC calendar for the package. A day that is not on the
  calendar — 30 February, month 13 — used to roll forward silently and is now refused.
- **A handler's fuller account of a failure is thrown, not returned from a `catch`** (the
  eight handlers above that wrap a failure in advice), so no `catch` ends an error's life
  without logging or rethrowing it.

### Upgrading a deployed server

1. **Add `--host 0.0.0.0` to whatever starts the server, if it is reached from another
   machine.** `scripts/deploy.sh` has it. A launchd plist, a systemd unit or a container
   command that lives outside this repository does not, and a server upgraded without it will
   start, log `Listening on loopback only (127.0.0.1)`, and answer nobody. A server behind a
   reverse proxy on the same machine, or run over stdio, needs no change.
2. **Tell callers about `^` and `/`.** A stored formula using `^` meant XOR and now means
   power; one dividing integer literals truncated and now does not.
3. **Expect `Reference: err-…` for server-side faults**, and find the detail in the log
   (`subsystem: com.swiftmcp`, `category: ErrorDisclosure`). Error text no longer begins
   `Execution error: `.
4. **Session ids are 64 hex characters**, not UUIDs; nothing here parsed them.

### Fixed

- **`run_scenario_analysis` refused every call.** It cast `scenarios` straight to
  `[[String: AnyCodable]]`, which arguments decoded from JSON never are, so the tool answered
  `scenarios must be an array of objects` to any input. Found by the first test to call it
  the way the server does.
- **A time series argument that was a string, a number or a boolean could stop the server.**
  `getTimeSeries` passed the value to `JSONSerialization.data(withJSONObject:)`, which raises
  an Objective-C exception for a top-level value that is not an array or an object. Such a
  value is now refused with `Invalid arguments: data must be a time series: …`.
- **`newton_raphson_optimize` and `goal_seek` trapped on a negative `maxIterations`**, which
  reached the solver's `0..<maxIterations`. A limit that is not positive is refused.
- **`calculate_mirr` reported a failed IRR as a Swift case dump** —
  `calculationFailed(operation: "IRR", reason: …)` — where it now gives the sentence.
- **`backtest_forecast` let the forecaster's own refusal escape its `catch`**, which named
  only `BacktestError`; a drift forecaster with one training point surfaced as
  `(BusinessMath.ForecastError error 0.)`.
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

- **SwiftMCPServer 4.4.3 → 5.0.0** (`from: "5.0.0"`). This package builds the server with
  `MCPServer.builder()` and never constructs `HTTPServerTransport` or an authenticator
  itself, so the transport and authentication API changes in 5.0.0 required no code here.
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

- **Formula tools are tested through the registry**, so what is asserted is what a caller
  receives: each tool with `^`, `/`, a named input, a positional placeholder and `x` beside
  `exp(x)` and `max(x, 1)`; a bad formula's exact message; a mid-run failure failing the run.
- **Every case of every conformed error type has its caller message pinned**, and an error
  that does not conform is shown to reach the caller as a reference id with none of its text.
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

[Unreleased]: https://github.com/jpurnell/businessMathMCP/compare/v3.0.0...HEAD
[3.0.0]: https://github.com/jpurnell/businessMathMCP/compare/v1.0.0...v3.0.0
[smcp-5]: https://github.com/jpurnell/SwiftMCPServer/blob/main/CHANGELOG.md#500---2026-10-04
[1.0.0]: https://github.com/jpurnell/businessMathMCP/releases/tag/v1.0.0
