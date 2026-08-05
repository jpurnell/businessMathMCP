# Design Proposal: New MCP Tools — Batch 1 (Coverage Gaps)

**Date:** 2026-03-18
**Status:** APPROVED — Moving to implementation

---

## 1. Objective

Expose significant businessMath library features that currently lack MCP tool wrappers. These are mature, standalone functions that would be directly useful to MCP users.

**Scope:** 8 new tools covering forecasting, fixed income, equity valuation, credit risk, financial ratios, lease analysis, and cap table modeling.

---

## 2. Proposed Tools

### Tool 1: `holt_winters_forecast`

**Library function:** `HoltWintersModel<Double>.forecast(timeSeries:periods:)` and `forecastWithConfidence(timeSeries:periods:confidenceLevel:)`

**Objective:** Triple exponential smoothing with trend + seasonality — the standard production forecasting method.

**MCP Schema:**
```json
{
  "values": [112, 118, 132, 129, 121, 135, 148, 148, 136, 119, 104, 118],
  "seasonalPeriods": 4,
  "forecastPeriods": 4,
  "alpha": 0.2,
  "beta": 0.1,
  "gamma": 0.1,
  "confidenceLevel": 0.95
}
```

**Parameters:**
- `values` (array, required): Historical time series values
- `seasonalPeriods` (integer, required): Length of seasonal cycle (e.g., 4 for quarterly, 12 for monthly)
- `forecastPeriods` (integer, required): Number of periods to forecast
- `alpha` (number, optional, default 0.2): Level smoothing parameter (0-1)
- `beta` (number, optional, default 0.1): Trend smoothing parameter (0-1)
- `gamma` (number, optional, default 0.1): Seasonal smoothing parameter (0-1)
- `confidenceLevel` (number, optional): If provided, includes confidence intervals

**Output:** Forecast values, optionally with upper/lower confidence bounds.

**File:** `Sources/BusinessMathMCP/Tools/TrendForecastingTools.swift`

---

### Tool 2: `detect_anomalies`

**Library function:** `ZScoreAnomalyDetector<Double>.detect(in:threshold:)`

**Objective:** Rolling z-score anomaly detection on time series data.

**MCP Schema:**
```json
{
  "values": [100, 102, 98, 101, 150, 99, 103, 97, 200, 101],
  "windowSize": 5,
  "threshold": 2.0
}
```

**Parameters:**
- `values` (array, required): Time series values
- `windowSize` (integer, required): Rolling window size for z-score calculation
- `threshold` (number, optional, default 2.0): Z-score threshold for flagging anomalies

**Output:** List of anomalies with period index, value, expected value, z-score, severity (mild/moderate/severe).

**File:** `Sources/BusinessMathMCP/Tools/TrendForecastingTools.swift`

---

### Tool 3: `fit_nelson_siegel`

**Library function:** `NelsonSiegelYieldCurve.calibrate(to:)` and `yield(maturity:)` / `forwardRate(maturity:)`

**Objective:** Nelson-Siegel yield curve fitting and interpolation — core fixed income tool.

**MCP Schema:**
```json
{
  "maturities": [0.25, 0.5, 1, 2, 3, 5, 7, 10, 20, 30],
  "yields": [0.045, 0.046, 0.047, 0.048, 0.049, 0.050, 0.051, 0.052, 0.053, 0.054],
  "interpolateAt": [0.75, 1.5, 4, 15],
  "lambda": 2.5
}
```

**Parameters:**
- `maturities` (array, required): Observed maturities in years
- `yields` (array, required): Observed yields (decimal, e.g. 0.05 for 5%)
- `interpolateAt` (array, optional): Maturities to interpolate yields at
- `lambda` (number, optional, default 2.5): Decay parameter
- `includeForwardRates` (boolean, optional, default false): Also compute forward rates

**Output:** Fitted parameters (beta0, beta1, beta2, lambda), interpolated yields, optionally forward rates, goodness-of-fit (SSE).

**File:** `Sources/BusinessMathMCP/Tools/DebtValuationTools.swift` (new file or append to existing)

---

### Tool 4: `value_equity_h_model`

**Library function:** `HModel<Double>.valuePerShare()`

**Objective:** H-Model dividend discount — linearly declining growth rate (Fuller-Hsia formula). Third standard DDM variant alongside Gordon Growth and Two-Stage.

**MCP Schema:**
```json
{
  "currentDividend": 2.00,
  "initialGrowthRate": 0.15,
  "terminalGrowthRate": 0.04,
  "halfLife": 5,
  "requiredReturn": 0.10
}
```

**Parameters:**
- `currentDividend` (number, required): Current annual dividend (D0)
- `initialGrowthRate` (number, required): Short-term high growth rate
- `terminalGrowthRate` (number, required): Long-term stable growth rate
- `halfLife` (integer, required): Years until growth rate is halfway to terminal (full transition = 2H)
- `requiredReturn` (number, required): Required rate of return

**Output:** Intrinsic value per share, terminal value component, growth premium component.

**File:** `Sources/BusinessMathMCP/Tools/ValuationTools.swift` (append alongside existing DDM tools)

---

### Tool 5: `calculate_recovery_metrics`

**Library function:** `RecoveryModel<Double>` — `lossGivenDefault()`, `expectedLoss()`, `impliedRecoveryRate()`

**Objective:** Credit loss/recovery rate analysis — completes the credit risk toolkit alongside CDS pricing and Merton.

**MCP Schema:**
```json
{
  "defaultProbability": 0.02,
  "recoveryRate": 0.40,
  "exposure": 1000000,
  "seniority": "seniorUnsecured",
  "marketSpread": 0.015,
  "maturity": 5
}
```

**Parameters:**
- `defaultProbability` (number, required): Probability of default (0-1)
- `recoveryRate` (number, optional): Recovery rate (0-1). If omitted, uses industry standard for seniority.
- `exposure` (number, required): Exposure at default
- `seniority` (string, optional): "seniorSecured", "seniorUnsecured", "subordinated", "junior"
- `marketSpread` (number, optional): If provided, computes implied recovery rate
- `maturity` (number, optional): Maturity for implied recovery calculation

**Output:** LGD, expected loss, standard recovery rate by seniority, implied recovery from spread (if applicable).

**File:** `Sources/BusinessMathMCP/Tools/DebtValuationTools.swift`

---

### Tool 6: `calculate_ratio_summary`

**Library functions:** `profitabilityRatios()`, `efficiencyRatios()`, `liquidityRatios()`, `solvencyRatios()`

**Objective:** Compute all key financial ratios from statement data in a single call — replaces 10+ individual tool calls.

**MCP Schema:**
```json
{
  "revenue": [500000, 550000, 600000],
  "cogs": [300000, 320000, 340000],
  "operatingExpenses": [100000, 110000, 120000],
  "interestExpense": [10000, 12000, 14000],
  "taxExpense": [18000, 21600, 25200],
  "totalAssets": [800000, 900000, 1000000],
  "totalLiabilities": [400000, 420000, 450000],
  "totalEquity": [400000, 480000, 550000],
  "currentAssets": [200000, 220000, 250000],
  "currentLiabilities": [150000, 160000, 170000],
  "cash": [50000, 60000, 70000],
  "inventory": [80000, 85000, 90000],
  "accountsReceivable": [70000, 75000, 80000],
  "categories": ["profitability", "liquidity", "solvency", "efficiency"]
}
```

**Parameters:**
- Financial statement line items as arrays (one value per period)
- `categories` (array, optional): Which ratio groups to compute. Default: all four.

**Output:** Organized ratio table with all computed ratios by category.

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift` (append)

---

### Tool 7: `analyze_lease_vs_buy`

**Library functions:** `LeaseVsBuyAnalysis`, `leasePaymentsPV()`, `buyAssetPV()`

**Objective:** Full lease-vs-buy decision analysis with NPV comparison.

**MCP Schema:**
```json
{
  "leasePayment": 5000,
  "leasePeriods": 36,
  "purchasePrice": 150000,
  "salvageValue": 30000,
  "holdingPeriod": 36,
  "discountRate": 0.06,
  "maintenanceCost": 500
}
```

**Parameters:**
- `leasePayment` (number, required): Periodic lease payment
- `leasePeriods` (integer, required): Number of lease periods
- `purchasePrice` (number, required): Asset purchase price
- `salvageValue` (number, required): Expected salvage/residual value
- `holdingPeriod` (integer, required): Holding period if purchased
- `discountRate` (number, required): Discount rate for NPV
- `maintenanceCost` (number, optional, default 0): Periodic maintenance cost if buying

**Output:** Lease PV, Buy PV, Net Advantage to Leasing (NAL), recommendation, savings percentage.

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift` (append)

---

### Tool 8: `model_cap_table`

**Library function:** `CapTable` — `modelRound()`, `ownership()`, `grantOptions()`, `liquidationWaterfall()`

**Objective:** Full startup cap table modeling — rounds, dilution, ownership, option grants.

**MCP Schema:**
```json
{
  "shareholders": [
    {"name": "Founder A", "shares": 4000000, "pricePerShare": 0.001},
    {"name": "Founder B", "shares": 4000000, "pricePerShare": 0.001},
    {"name": "Seed Investor", "shares": 1000000, "pricePerShare": 1.00, "liquidationPreference": 1.0}
  ],
  "optionPool": 1000000,
  "action": "modelRound",
  "roundParams": {
    "newInvestment": 5000000,
    "preMoneyValuation": 20000000,
    "optionPoolIncrease": 0.10,
    "investorName": "Series A",
    "poolTiming": "preRound"
  }
}
```

**Parameters:**
- `shareholders` (array, required): Current shareholders with name, shares, pricePerShare, optional liquidationPreference
- `optionPool` (number, required): Current option pool shares
- `action` (string, required): "ownership" | "modelRound" | "grantOptions" | "liquidationWaterfall"
- `roundParams` (object, optional): For modelRound action
- `grantParams` (object, optional): For grantOptions action (recipient, shares, strikePrice)
- `exitValue` (number, optional): For liquidationWaterfall action

**Output:** Ownership table, post-round cap table, or waterfall distribution depending on action.

**File:** `Sources/BusinessMathMCP/Tools/FinancialStatementTools.swift` (append)

---

## 3. Files to Modify/Create

| File | Action | Tools |
|------|--------|-------|
| `Tools/TrendForecastingTools.swift` | Modify | `holt_winters_forecast`, `detect_anomalies` |
| `Tools/DebtValuationTools.swift` | Create or modify | `fit_nelson_siegel`, `calculate_recovery_metrics` |
| `Tools/ValuationTools.swift` | Modify | `value_equity_h_model` |
| `Tools/FinancialStatementTools.swift` | Modify | `calculate_ratio_summary`, `analyze_lease_vs_buy`, `model_cap_table` |
| `MCPCompat.swift` | Modify | Add helpers if needed for new input types |
| `main.swift` or tool registration | Modify | Register new tools |

---

## 4. Constraints & Compliance

- **Concurrency:** All tool structs are `Sendable` (immutable value types)
- **Generics:** Library uses `<T: Real>`, MCP tools use `Double` (standard for JSON)
- **Safety:** No force unwraps, all inputs validated, guard clauses for invalid parameters
- **Formatting:** Use `formatNumber()` / `formatDecimal()` from businessMath — NO C-string formatting (`String(format: "%s", ...)`)
- **MCP Ready:** All JSON schemas defined above with explicit types

---

## 5. Test Strategy

Each tool requires:

- **Golden path test:** Known inputs → verified output (reference: Excel, textbook, or analytic formula)
- **Edge case tests:** Empty arrays, single values, zero parameters
- **Invalid input tests:** Negative rates, mismatched array lengths, out-of-range parameters
- **Smoke test:** Already covered by existing `SchemaSmoke` test suite (auto-generated minimal arguments)

**Test file:** `Tests/BusinessMathMCPTests/NewToolsBatch1Tests.swift`

**Reference truth sources:**
- Holt-Winters: Compare against R's `HoltWinters()` or Python's `statsmodels`
- Nelson-Siegel: Compare against published curve parameters
- H-Model: Textbook formula V = D0(1+gL)/(r-gL) + D0*H*(gS-gL)/(r-gL)
- Lease-vs-Buy: Manual NPV calculation
- Recovery: EL = PD * LGD * Exposure (analytic)

---

## 6. Dependencies

**Internal only** — all features are already implemented in the businessMath library. No new external packages required.

---

## 7. Resolved Questions

1. **Tool naming:** `calculate_ratio_summary` will accept **both** raw arrays (for ad hoc usage) AND financial statement objects (for structured usage). Implementation should detect which format was provided.
2. **Cap table dates:** Accept **ISO 8601 strings** for `Shareholder.investmentDate`. Parse with `ISO8601DateFormatter` internally.
3. **Nelson-Siegel calibration:** Accept raw maturities/yields arrays and **construct `BondMarketData` internally** (using par bond assumption: couponRate=yield, faceValue=100, marketPrice=100).

---

## 8. Priority Order

Recommended implementation order (most value first):

1. `holt_winters_forecast` — high demand, clean API
2. `fit_nelson_siegel` — unique capability, no equivalent
3. `value_equity_h_model` — trivial to add, completes DDM family
4. `calculate_recovery_metrics` — completes credit risk toolkit
5. `detect_anomalies` — clean API, broadly useful
6. `calculate_ratio_summary` — replaces 10+ individual calls
7. `analyze_lease_vs_buy` — straightforward wrapper
8. `model_cap_table` — most complex input schema
