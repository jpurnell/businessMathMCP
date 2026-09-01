# Implementation Checklist: New MCP Tools — Batch 1

**Design Proposal:** [NewMCPTools_Batch1.md](../project/plans/upcoming/NewMCPTools_Batch1.md)
**Created:** 2026-03-18
**Status:** COMPLETE

---

## Summary

8 new MCP tools wrapping existing businessMath library functions.

### Tool Status

- [x] **Tool 1: `holt_winters_forecast`** — Triple exponential smoothing
- [x] **Tool 2: `detect_anomalies`** — Z-score anomaly detection
- [x] **Tool 3: `fit_nelson_siegel`** — Yield curve fitting
- [x] **Tool 4: `value_equity_h_model`** — H-Model DDM
- [x] **Tool 5: `calculate_recovery_metrics`** — Credit loss/recovery
- [x] **Tool 6: `calculate_ratio_summary`** — Financial ratio summary
- [x] **Tool 7: `analyze_lease_vs_buy`** — Lease vs buy NPV
- [x] **Tool 8: `model_cap_table`** — Cap table modeling

---

## Tool 1: `holt_winters_forecast`

**File:** `Sources/BusinessMathMCP/Tools/TrendForecastingTools.swift`

### Phase 0: Design — COMPLETE
- [x] Proposal approved

### Phase 1: Testing (RED)
- [ ] Golden path: 12+ values with known seasonal pattern → verified forecast
- [ ] Golden path with confidence intervals
- [ ] Edge case: Minimum data (2 * seasonalPeriods)
- [ ] Invalid: Too few values for seasonalPeriods
- [ ] Invalid: Zero or negative forecastPeriods
- [ ] Invalid: Alpha/beta/gamma outside 0-1
- [ ] Schema: Tool name and required params correct

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Execute method calling HoltWintersModel
- [ ] Register in getTrendForecastingTools()

### Phase 3-5: Refactor, Document, Verify
- [ ] Safety audit
- [ ] All tests pass
- [ ] `swift build` zero warnings

---

## Tool 2: `detect_anomalies`

**File:** `Sources/BusinessMathMCP/Tools/TrendForecastingTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Known anomalies detected with correct severity
- [ ] Edge case: No anomalies in clean data
- [ ] Edge case: All values same (zero variance)
- [ ] Invalid: Window size > data length
- [ ] Invalid: Empty values array
- [ ] Schema: Tool name and required params correct

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Execute method calling ZScoreAnomalyDetector
- [ ] Register in getTrendForecastingTools()

---

## Tool 3: `fit_nelson_siegel`

**File:** `Sources/BusinessMathMCP/Tools/BondValuationTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Fit known yield curve, verify parameters
- [ ] Interpolation at custom maturities
- [ ] Forward rates calculation
- [ ] Invalid: Mismatched maturities/yields arrays
- [ ] Edge case: Single maturity point

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Construct BondMarketData from raw maturities/yields
- [ ] Register in getBondValuationTools()

---

## Tool 4: `value_equity_h_model`

**File:** `Sources/BusinessMathMCP/Tools/EquityValuationTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Textbook H-Model formula verification
- [ ] Edge case: initialGrowthRate == terminalGrowthRate (collapses to Gordon)
- [ ] Invalid: requiredReturn <= terminalGrowthRate
- [ ] Invalid: Negative dividend

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Execute method calling HModel
- [ ] Register in getEquityValuationTools()

---

## Tool 5: `calculate_recovery_metrics`

**File:** `Sources/BusinessMathMCP/Tools/CreditDerivativesTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: EL = PD * LGD * Exposure
- [ ] Standard recovery rates by seniority
- [ ] Implied recovery from market spread
- [ ] Invalid: Probabilities outside 0-1

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Execute method calling RecoveryModel
- [ ] Register in getCreditDerivativesTools()

---

## Tool 6: `calculate_ratio_summary`

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Raw arrays → all ratio categories
- [ ] Selective categories
- [ ] Invalid: Mismatched array lengths
- [ ] Edge case: Single period

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema (both raw array and statement object inputs)
- [ ] Execute method calling ratio functions
- [ ] Register in getFinancialStatementTools()

---

## Tool 7: `analyze_lease_vs_buy`

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Manual NPV verification
- [ ] Edge case: Zero maintenance cost
- [ ] Edge case: Zero salvage value
- [ ] Invalid: Negative discount rate

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] Execute method computing lease vs buy PVs
- [ ] Register in getFinancialStatementTools()

---

## Tool 8: `model_cap_table`

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift`

### Phase 1: Testing (RED)
- [ ] Golden path: Ownership calculation
- [ ] Golden path: Model funding round
- [ ] Golden path: Liquidation waterfall
- [ ] Option grant
- [ ] ISO 8601 date parsing
- [ ] Invalid: Unknown action

### Phase 2: Implementation (GREEN)
- [ ] Tool struct with schema
- [ ] ISO 8601 date parsing
- [ ] Execute method dispatching to CapTable methods
- [ ] Register in getFinancialStatementTools()

---

## Quality Gates

- [ ] `swift build` — zero warnings
- [ ] `swift test` — zero failures
- [ ] Safety audit — no forbidden patterns
- [ ] All 8 tools appear in `tools/list` response

---

**Last Updated:** 2026-03-18
