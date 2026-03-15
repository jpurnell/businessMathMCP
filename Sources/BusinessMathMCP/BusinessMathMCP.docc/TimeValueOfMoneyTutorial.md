# Time Value of Money Calculations

Master NPV, IRR, present value, future value, and cash flow analysis with BusinessMathMCP.

## Overview

The time value of money (TVM) is the foundation of financial analysis. Money today is worth more than the same amount in the future due to its earning potential. BusinessMathMCP provides a comprehensive suite of TVM tools that replicate and extend Excel's financial functions.

This tutorial covers:
- Net Present Value (NPV) for investment decisions
- Internal Rate of Return (IRR) for comparing investments
- Present and Future Value calculations
- Payment (PMT) calculations for loans and annuities
- Irregular cash flows with XNPV and XIRR

## Net Present Value (NPV)

NPV determines if an investment adds value by discounting future cash flows to present value.

### Basic NPV Calculation

**Scenario**: Evaluate a $100,000 investment returning $30,000 annually for 5 years at a 10% discount rate.

```json
{
  "discountRate": 0.10,
  "cashFlows": [-100000, 30000, 30000, 30000, 30000, 30000]
}
```

**Result**: NPV = $13,723.60

A positive NPV means the investment exceeds the required 10% return.

### NPV Decision Rules

| NPV Result | Decision |
|------------|----------|
| NPV > 0 | Accept - exceeds required return |
| NPV = 0 | Indifferent - meets exactly |
| NPV < 0 | Reject - below required return |

### Mathematical Formula

```
NPV = Σ (CFₜ / (1 + r)ᵗ)
```

Where:
- CFₜ = cash flow at time t
- r = discount rate
- t = time period (0, 1, 2, ...)

## Internal Rate of Return (IRR)

IRR finds the discount rate that makes NPV equal to zero.

### Basic IRR Calculation

**Scenario**: Find the return rate for the investment above.

```json
{
  "cashFlows": [-100000, 30000, 30000, 30000, 30000, 30000],
  "guess": 0.10
}
```

**Result**: IRR = 15.24%

The investment yields 15.24%, exceeding the 10% hurdle rate.

### IRR vs NPV

Use IRR to compare investments with different scales:

| Investment | Initial Cost | Annual Return | IRR |
|------------|-------------|---------------|-----|
| Project A | $100,000 | $30,000 x 5 | 15.24% |
| Project B | $50,000 | $18,000 x 5 | 23.06% |

Project B has a higher IRR despite lower absolute returns.

## Present Value (PV)

Calculate what a future sum is worth today.

### Single Sum Present Value

**Scenario**: What is $50,000 in 10 years worth today at 7% interest?

```json
{
  "futureValue": 50000,
  "rate": 0.07,
  "periods": 10
}
```

**Result**: PV = $25,418.98

### Annuity Present Value

**Scenario**: Value of $5,000 annual payments for 20 years at 6%.

```json
{
  "payment": 5000,
  "rate": 0.06,
  "periods": 20,
  "type": "ordinary"
}
```

**Result**: PV = $57,349.61

Use `"type": "due"` for payments at the beginning of each period.

## Future Value (FV)

Calculate what today's money will be worth later.

### Single Sum Future Value

**Scenario**: What will $10,000 grow to in 15 years at 8%?

```json
{
  "presentValue": 10000,
  "rate": 0.08,
  "periods": 15
}
```

**Result**: FV = $31,721.69

### Annuity Future Value

**Scenario**: Value of $500 monthly contributions for 30 years at 7%.

```json
{
  "payment": 500,
  "rate": 0.07,
  "periods": 360,
  "periodsPerYear": 12
}
```

**Result**: FV = $566,765.30 (retirement savings example)

## Payment Calculations (PMT)

Calculate periodic payments for loans or savings goals.

### Loan Payment

**Scenario**: Monthly payment for a $300,000 mortgage at 6.5% for 30 years.

```json
{
  "presentValue": 300000,
  "rate": 0.065,
  "periods": 360,
  "periodsPerYear": 12
}
```

**Result**: PMT = $1,896.20 per month

### Savings Goal Payment

**Scenario**: Monthly deposit needed to save $100,000 in 10 years at 5%.

```json
{
  "futureValue": 100000,
  "rate": 0.05,
  "periods": 120,
  "periodsPerYear": 12
}
```

**Result**: PMT = $643.49 per month

## Irregular Cash Flows (XNPV and XIRR)

For cash flows that don't occur at regular intervals.

### XNPV with Dates

**Scenario**: Investment with irregular return dates.

```json
{
  "rate": 0.10,
  "cashFlows": [
    {"date": "2024-01-15T00:00:00Z", "amount": -100000},
    {"date": "2024-06-20T00:00:00Z", "amount": 25000},
    {"date": "2024-12-01T00:00:00Z", "amount": 35000},
    {"date": "2025-08-15T00:00:00Z", "amount": 50000}
  ]
}
```

**Result**: XNPV = $1,842.33

### XIRR with Dates

```json
{
  "cashFlows": [
    {"date": "2024-01-15T00:00:00Z", "amount": -100000},
    {"date": "2024-06-20T00:00:00Z", "amount": 25000},
    {"date": "2024-12-01T00:00:00Z", "amount": 35000},
    {"date": "2025-08-15T00:00:00Z", "amount": 50000}
  ],
  "guess": 0.10
}
```

**Result**: XIRR = 12.18%

## Excel Equivalents

| BusinessMathMCP | Excel Function |
|-----------------|----------------|
| npv | NPV(rate, value1, ...) |
| irr | IRR(values, [guess]) |
| pv | PV(rate, nper, pmt, [fv]) |
| fv | FV(rate, nper, pmt, [pv]) |
| pmt | PMT(rate, nper, pv, [fv]) |
| xnpv | XNPV(rate, values, dates) |
| xirr | XIRR(values, dates, [guess]) |

## Best Practices

### Rate Consistency

Match rate frequency to payment frequency:

```json
// Monthly payments require monthly rate
{
  "rate": 0.06 / 12,  // Convert annual 6% to monthly
  "periods": 360      // 30 years * 12 months
}
```

### Cash Flow Sign Convention

- **Outflows** (investments, payments): Negative
- **Inflows** (returns, receipts): Positive

```json
{"cashFlows": [-100000, 30000, 30000]}  // Investment then returns
```

### Handling Edge Cases

- Empty cash flows return 0
- Single cash flow returns that value
- IRR may have multiple solutions or no solution for unusual patterns

## Next Steps

- Explore <doc:MonteCarloSimulationTutorial> to add uncertainty to your cash flow projections
- Learn <doc:PortfolioOptimizationTutorial> for multi-asset investment decisions
- Review <doc:FinancialStatementsTutorial> for comprehensive financial modeling

## See Also

- ``getTVMTools()``
- ``getTimeSeriesTools()``
- ``getForecastingTools()``
