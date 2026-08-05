# MCP Server Testing Strategy

A comprehensive, mandatory testing strategy for Swift-based MCP servers. Organized by failure mode, with exhaustive coverage at every layer. No sampling, no exceptions.

## Coverage Requirements

These rules are non-negotiable for every MCP server project:

1. **Every registered tool** MUST be covered by automated schema invariant tests (Layer 1), smoke tests (Layer 3), and exhaustive error handling tests (Layer 5). No tool is exempt.
2. **Every tool category** (`get*Tools()` function) MUST have at least one golden-path domain correctness test (Layer 10) with realistic inputs, a success assertion, and output content validation.
3. **New tool categories** MUST ship with domain tests before merge. If `allToolHandlers()` gains a new `get*Tools()` call, the tool count test and registration test will fail until corresponding domain tests exist.
4. **No layer uses sampling.** Layers 1, 3, and 5 iterate ALL tools automatically. Layer 10 covers every category explicitly. Layers 2, 4, 6, 7 cover their respective systems completely.
5. **All tests must pass** before any merge to main. A single failure blocks the merge.

## Testing Layers

### Layer 1: Schema Structural Invariants (Automated, All Tools)

**What it catches:** Empty tool names, invalid JSON Schema types, required params not in properties, duplicate tool names, malformed schemas.

**Approach:** Iterate ALL tool handlers via `allToolHandlers()` and assert invariants. One test function covers every tool.

**Required tests:**
- Every tool has non-empty name and description
- No duplicate tool names across all registration functions
- All required parameters exist in properties dictionary
- Property types are valid JSON Schema types (`string`, `number`, `integer`, `boolean`, `array`, `object`)
- Array properties have `items` defined
- Enum properties have 2+ values
- Tool names follow snake_case convention
- Schema `type` is always `"object"`
- SDK conversion (`toToolDefinition()`) succeeds for all tools

**Test file:** `SchemaContractTests/SchemaContractTests.swift`

### Layer 2: Tool Registration Completeness (Automated, All Tools)

**What it catches:** Tools defined but never registered, registry dispatch failures, registration functions not called.

**Required tests:**
- Registry round-trip: register all handlers, list all tools, counts match
- Every `get*Tools()` function returns at least one handler
- Tool names in registry match handler tool names exactly
- Dispatch by name works for a known tool
- Unknown tool name returns error (not crash)

**Test file:** `RegistrationTests/ToolRegistrationTests.swift`

### Layer 3: Schema-Implementation Contract (Automated, All Tools)

**What it catches:** Schema says "rate" is required but code uses different name; schema says "number" but code calls `getString()`; tools crash on valid-shaped input.

**Approach:** Smoke-test every tool with nil arguments, empty arguments, and auto-generated minimal valid arguments based on schema introspection.

**Required tests:**
- Every tool handles nil arguments without crashing (throws or returns error)
- Every tool handles empty arguments without crashing
- Every tool with required params executes without crash when given auto-generated minimal valid arguments (type-appropriate defaults from schema introspection)
- Tool count matches expected registration total (catches forgotten `get*Tools()` calls)

**Test file:** `SchemaContractTests/SchemaSmokeTests.swift`

### Layer 4: Parameter Marshalling (Unit Tests)

**What it catches:** Int/Double coercion failures, null handling, array element type mismatches, nested object extraction, complex type format issues.

**Required tests for `[String: AnyCodable]` path (MCPCompat.swift):**
- `getString()` returns string, throws on missing/wrong type
- `getDouble()` handles Double and Int-to-Double coercion, throws on missing/wrong type
- `getInt()` returns int, throws on missing/wrong type
- `getBool()` returns bool, throws on missing/wrong type
- `getDoubleArray()` handles mixed Int/Double elements
- `getStringArray()` returns strings, throws on non-string elements
- Optional variants return nil for missing keys
- Wire-format round-trip: JSON → MCP.Value → AnyCodable preserves types

**Required tests for `[String: MCP.Value]` path (ValueExtensions.swift):**
- Same coverage as above using SDK value types
- Verify both paths behave consistently

**Required tests for complex types (TypeMarshalling.swift):**
- PeriodJSON round-trips for annual, monthly, quarterly, daily
- Period type accepts both Int and String (e.g., `5` or `"monthly"`)
- Sub-daily period types throw descriptive error
- Invalid period type throws `MarshallingError`
- TimeSeriesJSON wrapped format decodes correctly
- TimeSeriesJSON flat array format decodes correctly

**Test files:** `MarshallingTests/ValueExtractionTests.swift`, `MarshallingTests/TypeMarshallingTests.swift`

### Layer 5: Exhaustive Error Handling (Automated, All Tools)

**What it catches:** Missing required args causing crash instead of error, wrong types causing crash, invalid enum values not caught.

**Approach:** Iterate ALL tool handlers via `allToolHandlers()` and verify every tool gracefully handles wrong types, missing required params, and invalid enum values. No tool is exempt.

**Required tests:**
- Every tool with required number params rejects string values (error, not crash)
- Every tool errors when each required param is individually omitted
- Every tool with enum params rejects invalid enum values
- Hand-crafted representative examples for readability (simple numeric, array-based, enum-based patterns)

**Test files:** `ErrorHandlingTests/ExhaustiveErrorHandlingTests.swift`, `ErrorHandlingTests/ToolErrorHandlingTests.swift`

### Layer 6: Response Format (All Patterns)

**What it catches:** Empty content in results, missing isError flag, non-descriptive error messages.

**Required tests:**
- Successful results have non-empty text content
- Error results have `isError: true`
- Error messages include the problematic parameter name
- `MCPToolCallResult.success()` and `.error()` factory methods produce correct format
- `ToolError` and `ValueExtractionError` descriptions are human-readable

**Test file:** `ProtocolComplianceTests/ToolResponseFormatTests.swift`

### Layer 7: Protocol Compliance (Full Verification)

**What it catches:** Invalid tool objects from registry, schema conversion failures, broken request/response flow.

**Required tests:**
- `ToolDefinitionRegistry.listTools()` returns valid `Tool` objects for all registered tools (count matches, non-empty names/descriptions, valid inputSchema)
- All tool `inputSchema.toValue()` conversions succeed without error
- Full registry round-trip: register all → list → execute known tool via `MCP.Value` args → verify success
- Registry wraps all thrown errors into `CallTool.Result` (never leaks raw exceptions)

**Test file:** `ProtocolComplianceTests/ToolResponseFormatTests.swift`

### Layer 8: Transport

**What it catches:** SSE lifecycle issues, HTTP request/response errors, session management bugs.

**Required tests:**
- HTTP server start/stop lifecycle
- Health check and server info endpoints
- 404 for unknown paths, 405 for wrong methods
- SSE client connection establishment
- SSE endpoint event contains correct POST URL
- Multiple concurrent SSE clients
- Session cleanup on disconnect

**Test files:** `HTTPTransportTests.swift`, `SSETransportTests.swift`

### Layer 9: Authentication

**What it catches:** Auth bypass, token validation failures, public vs protected endpoint mismatches.

**Required tests:**
- API key creation, validation, revocation
- Protected endpoint rejects unauthenticated requests
- Protected endpoint accepts valid auth
- Public endpoints work without auth
- OAuth client registration, authorization, token exchange
- PKCE challenge/verifier flow
- CSRF token generation, validation, single-use enforcement
- Consent page approve/deny flows

**Test files:** `APIAuthTests.swift`, `APIKeyStoreTests.swift`, `OAuthServerTests.swift`, `OAuthConsentTests.swift`, `PKCETests.swift`

### Layer 10: Domain Correctness (Mandatory Per Category)

**What it catches:** Tool calculates wrong answer, output format missing expected sections, business logic errors.

**Approach:** Every tool category (`get*Tools()` function) MUST have at least one golden-path domain test. Tests use hand-crafted realistic business inputs and validate both success and domain-specific output content.

**Required test pattern per category:**
1. Construct realistic, hand-crafted input arguments
2. Execute the tool
3. Assert success (`!result.isError`)
4. Validate output contains expected domain-specific content (computed values, section headers, formatted numbers)

**Domain test files (one per domain area):**

| Domain Area | Categories Covered | File |
|-------------|-------------------|------|
| TVM & Debt | TVM, Debt, ExtendedDebt, Financing, LoanPayment | `DomainTests/TVMAndDebtDomainTests.swift` |
| Statistics | Statistical, HypothesisTesting, AdvancedStatistics, Bayesian | `DomainTests/StatisticsDomainTests.swift` |
| Portfolio & Risk | Portfolio, RiskAnalytics | `DomainTests/PortfolioAndRiskDomainTests.swift` |
| Optimization | Optimization, Adaptive, Parallel, Advanced, IntegerProg, Heuristic, Metaheuristic, Benchmark | `DomainTests/OptimizationDomainTests.swift` |
| Time Series | TimeSeries, Forecasting, TrendForecasting, Seasonality, GrowthAnalysis | `DomainTests/TimeSeriesDomainTests.swift` |
| Monte Carlo | MonteCarlo | `DomainTests/MonteCarloSimulationDomainTests.swift` |
| Valuation | ValuationCalculators, EquityValuation, BondValuation, InvestmentMetrics | `DomainTests/ValuationDomainTests.swift` |
| Options & Derivatives | RealOptions, AdvancedOptions, CreditDerivatives | `DomainTests/OptionsAndDerivativesDomainTests.swift` |
| Financial Ratios | FinancialRatios, ExtendedFinancialRatios, WorkingCapital, AdvancedRatio | `DomainTests/FinancialRatiosDomainTests.swift` |
| Financial Statements | FinancialStatement, OperationalMetrics, CapitalStructure, EnhancedCovenant, MultiPeriod, AdvancedFinancialModeling, LeaseAndCovenant | `DomainTests/FinancialStatementsAndModelingDomainTests.swift` |
| Utility | Utility | `DomainTests/UtilityDomainTests.swift` |

**Pre-existing domain tests (already compliant):**
- `MeanVariancePortfolioToolTests.swift` — covers MeanVariancePortfolio category
- `ScenarioAnalysisToolTests.swift` — covers ScenarioAnalysis category

## Implementation Priority

1. **Helpers + Schema Introspection** — foundation everything builds on
2. **Schema Contract Tests (Layers 1-3)** — automated coverage of ALL tools with zero per-tool effort
3. **Registration Tests (Layer 2)** — catches deployment-breaking registration gaps
4. **Marshalling Tests (Layer 4)** — catches the schema-says-X-code-does-Y class of bugs
5. **Error Handling (Layer 5)** — exhaustive error testing for ALL tools, not a sample
6. **Response Format + Protocol Compliance (Layers 6-7)** — catches format and round-trip bugs
7. **Domain Tests (Layer 10)** — MANDATORY for every category, no exceptions

## Portability Guide

To reuse in a new MCP server project:

1. **Copy as-is:** `SchemaIntrospection.swift`, `SchemaContractTests.swift`, `SchemaSmokeTests.swift`, `ExhaustiveErrorHandlingTests.swift`
2. **Adapt `allToolHandlers()`** in `MCPTestHelpers.swift` — update the list of `get*Tools()` calls
3. **Adapt marshalling tests** — replace project-specific types (PeriodJSON, TimeSeriesJSON) with your domain types
4. **Write domain tests** — one file per domain area, following the golden-path pattern
5. **Verify coverage** — run the full suite and confirm all layers pass

## Running Tests

```bash
# Full suite
swift test

# Layer-by-layer verification:
swift test --filter SchemaContractTests       # Layer 1: Schema invariants
swift test --filter SchemaSmokeTests          # Layer 3: Nil, empty, auto-generated args
swift test --filter ToolRegistration          # Layer 2: Registration completeness
swift test --filter ValueExtraction           # Layer 4a: Value extraction
swift test --filter TypeMarshalling           # Layer 4b: Type marshalling
swift test --filter ExhaustiveError           # Layer 5: All-tools error handling
swift test --filter ToolErrorHandling         # Layer 5: Hand-crafted error examples
swift test --filter ToolResponse              # Layers 6+7: Response format + protocol
swift test --filter SSETransport              # Layer 8: SSE transport
swift test --filter HTTPTransport             # Layer 8: HTTP transport
swift test --filter APIAuth                   # Layer 9: Authentication
swift test --filter DomainTests               # Layer 10: Domain correctness (all categories)
swift test --filter MeanVariancePortfolio     # Layer 10: Portfolio domain (pre-existing)
swift test --filter ScenarioAnalysis          # Layer 10: Scenario domain (pre-existing)
```
