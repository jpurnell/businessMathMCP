# Financial Statements Modeling

Build comprehensive financial models with income statements, balance sheets, and cash flow statements.

## Overview

Financial statements tell the story of a company's financial health. BusinessMathMCP provides tools to construct and analyze the three core statements:

- **Income Statement**: Revenue, expenses, and profitability
- **Balance Sheet**: Assets, liabilities, and equity
- **Cash Flow Statement**: Operating, investing, and financing cash flows

This tutorial shows how to build an integrated financial model and perform common analyses.

## Income Statement

The income statement shows profitability over a period.

### Basic Income Statement

**Scenario**: Construct annual income statement for a SaaS company.

```json
{
  "period": {"year": 2024, "type": "annual"},
  "revenue": {
    "subscriptionRevenue": 2500000,
    "professionalServices": 300000,
    "otherRevenue": 50000
  },
  "costOfRevenue": {
    "hostingCosts": 250000,
    "customerSuccess": 200000,
    "paymentProcessing": 75000
  },
  "operatingExpenses": {
    "salesAndMarketing": 800000,
    "researchAndDevelopment": 600000,
    "generalAndAdministrative": 350000
  },
  "otherIncome": 15000,
  "interestExpense": 25000,
  "taxRate": 0.25
}
```

**Result**:

| Line Item | Amount |
|-----------|--------|
| Total Revenue | $2,850,000 |
| Gross Profit | $2,325,000 |
| Operating Income | $575,000 |
| Net Income | $423,750 |

### Key Ratios

The income statement tool calculates key profitability metrics:

| Metric | Formula | Example |
|--------|---------|---------|
| Gross Margin | Gross Profit / Revenue | 81.6% |
| Operating Margin | Operating Income / Revenue | 20.2% |
| Net Margin | Net Income / Revenue | 14.9% |
| EBITDA | Operating Income + D&A | Varies |

## Balance Sheet

The balance sheet shows financial position at a point in time.

### Basic Balance Sheet

**Scenario**: Construct balance sheet for the same company.

```json
{
  "asOfDate": "2024-12-31",
  "assets": {
    "current": {
      "cash": 1500000,
      "accountsReceivable": 450000,
      "prepaidExpenses": 75000
    },
    "nonCurrent": {
      "propertyAndEquipment": 500000,
      "accumulatedDepreciation": -150000,
      "intangibleAssets": 200000,
      "goodwill": 300000
    }
  },
  "liabilities": {
    "current": {
      "accountsPayable": 175000,
      "accruedExpenses": 125000,
      "deferredRevenue": 400000,
      "currentPortionLongTermDebt": 50000
    },
    "nonCurrent": {
      "longTermDebt": 450000,
      "deferredTaxLiability": 75000
    }
  },
  "equity": {
    "commonStock": 100000,
    "additionalPaidInCapital": 800000,
    "retainedEarnings": 600000
  }
}
```

**Result**:

| Category | Amount |
|----------|--------|
| Total Assets | $2,875,000 |
| Total Liabilities | $1,275,000 |
| Total Equity | $1,600,000 |
| Assets = Liabilities + Equity | ✓ Balanced |

### Balance Sheet Ratios

| Metric | Formula | Example |
|--------|---------|---------|
| Current Ratio | Current Assets / Current Liabilities | 2.70 |
| Debt-to-Equity | Total Debt / Equity | 0.31 |
| Working Capital | Current Assets - Current Liabilities | $1,275,000 |

## Cash Flow Statement

The cash flow statement reconciles net income to cash changes.

### Basic Cash Flow Statement

**Scenario**: Construct cash flow statement using indirect method.

```json
{
  "period": {"year": 2024, "type": "annual"},
  "operatingActivities": {
    "netIncome": 423750,
    "adjustments": {
      "depreciation": 50000,
      "amortization": 20000,
      "stockBasedCompensation": 75000
    },
    "workingCapitalChanges": {
      "accountsReceivable": -50000,
      "prepaidExpenses": -10000,
      "accountsPayable": 25000,
      "accruedExpenses": 15000,
      "deferredRevenue": 100000
    }
  },
  "investingActivities": {
    "capitalExpenditures": -120000,
    "acquisitions": 0,
    "investmentPurchases": -50000
  },
  "financingActivities": {
    "debtRepayment": -50000,
    "stockIssuance": 0,
    "dividends": 0
  },
  "beginningCash": 1020250
}
```

**Result**:

| Category | Amount |
|----------|--------|
| Cash from Operations | $648,750 |
| Cash from Investing | -$170,000 |
| Cash from Financing | -$50,000 |
| Net Change in Cash | $428,750 |
| Ending Cash | $1,449,000 |

### Cash Flow Metrics

| Metric | Formula | Example |
|--------|---------|---------|
| Free Cash Flow | CFO - CapEx | $528,750 |
| Cash Conversion | CFO / Net Income | 153% |
| FCF Margin | FCF / Revenue | 18.6% |

## Integrated Financial Model

Connect the three statements for comprehensive modeling.

### Three-Statement Model

**Scenario**: Build a connected three-statement model.

```json
{
  "companyName": "TechCorp Inc.",
  "periods": [
    {"year": 2024, "type": "annual"},
    {"year": 2025, "type": "annual"},
    {"year": 2026, "type": "annual"}
  ],
  "assumptions": {
    "revenueGrowth": [0.25, 0.20, 0.15],
    "grossMargin": 0.82,
    "opexAsPercentOfRevenue": 0.55,
    "taxRate": 0.25,
    "capexAsPercentOfRevenue": 0.04,
    "depreciationYears": 5,
    "receivableDays": 45,
    "payableDays": 30
  },
  "startingBalance": {
    "cash": 1500000,
    "accountsReceivable": 450000,
    "ppe": 500000,
    "accountsPayable": 175000,
    "debt": 500000,
    "equity": 1600000
  }
}
```

**Result**: Projected income statements, balance sheets, and cash flows for all periods with automatic linkages.

## Financial Ratios Analysis

Comprehensive ratio analysis across categories.

### Profitability Ratios

```json
{
  "incomeStatement": {...},
  "balanceSheet": {...},
  "ratioCategories": ["profitability"]
}
```

**Result**:

| Ratio | Formula | Value |
|-------|---------|-------|
| ROA | Net Income / Avg Assets | 14.7% |
| ROE | Net Income / Avg Equity | 26.5% |
| ROIC | NOPAT / Invested Capital | 22.1% |

### Liquidity Ratios

```json
{
  "balanceSheet": {...},
  "ratioCategories": ["liquidity"]
}
```

**Result**:

| Ratio | Formula | Value |
|-------|---------|-------|
| Current Ratio | Current Assets / Current Liabilities | 2.70 |
| Quick Ratio | (Cash + AR) / Current Liabilities | 2.60 |
| Cash Ratio | Cash / Current Liabilities | 2.00 |

### Leverage Ratios

```json
{
  "balanceSheet": {...},
  "incomeStatement": {...},
  "ratioCategories": ["leverage"]
}
```

**Result**:

| Ratio | Formula | Value |
|-------|---------|-------|
| Debt-to-Equity | Total Debt / Equity | 0.31 |
| Interest Coverage | EBIT / Interest Expense | 24.0x |
| Debt-to-EBITDA | Total Debt / EBITDA | 0.78x |

### Efficiency Ratios

```json
{
  "incomeStatement": {...},
  "balanceSheet": {...},
  "ratioCategories": ["efficiency"]
}
```

**Result**:

| Ratio | Formula | Value |
|-------|---------|-------|
| Inventory Turnover | COGS / Avg Inventory | N/A (SaaS) |
| Receivables Turnover | Revenue / Avg AR | 6.3x |
| Asset Turnover | Revenue / Avg Assets | 1.0x |

## DuPont Analysis

Decompose ROE into component drivers.

```json
{
  "incomeStatement": {...},
  "balanceSheet": {...},
  "analysis": "dupont"
}
```

**Result**:

```
ROE = Net Margin × Asset Turnover × Equity Multiplier
26.5% = 14.9% × 1.0x × 1.78x
```

## Common Size Statements

Express line items as percentages for comparison.

### Common Size Income Statement

```json
{
  "incomeStatement": {...},
  "format": "commonSize",
  "base": "revenue"
}
```

**Result**:

| Line Item | Amount | % of Revenue |
|-----------|--------|--------------|
| Revenue | $2,850,000 | 100.0% |
| COGS | $525,000 | 18.4% |
| Gross Profit | $2,325,000 | 81.6% |
| OpEx | $1,750,000 | 61.4% |
| Operating Income | $575,000 | 20.2% |

## Forecasting

Project future statements based on assumptions.

### Revenue Forecast

```json
{
  "historicalRevenue": [1500000, 2000000, 2850000],
  "forecastMethod": "growth",
  "growthRates": [0.20, 0.15, 0.12],
  "periods": 3
}
```

### Expense Forecast

```json
{
  "expenses": {
    "salesAndMarketing": {"method": "percentOfRevenue", "rate": 0.28},
    "researchAndDevelopment": {"method": "percentOfRevenue", "rate": 0.21},
    "generalAndAdministrative": {"method": "fixed", "baseAmount": 350000, "inflationRate": 0.03}
  }
}
```

## SaaS Metrics

Specialized metrics for subscription businesses.

```json
{
  "metrics": "saas",
  "data": {
    "mrr": 237500,
    "newMrr": 25000,
    "churnedMrr": 8000,
    "expansionMrr": 12000,
    "customers": 950,
    "newCustomers": 80,
    "churnedCustomers": 25,
    "cac": 1500,
    "salesAndMarketingSpend": 66667
  }
}
```

**Result**:

| Metric | Value |
|--------|-------|
| Net Revenue Retention | 101.7% |
| Gross Churn | 3.4% |
| LTV | $42,500 |
| CAC Payback | 6 months |
| LTV:CAC | 28.3x |

## Valuation

Calculate enterprise value and equity value.

### DCF Valuation

```json
{
  "projectedFCF": [500000, 600000, 700000, 750000, 800000],
  "terminalGrowthRate": 0.03,
  "discountRate": 0.12,
  "netDebt": -1000000,
  "sharesOutstanding": 1000000
}
```

**Result**:

| Component | Value |
|-----------|-------|
| PV of FCF | $2,456,789 |
| Terminal Value | $9,166,667 |
| PV of Terminal | $5,201,234 |
| Enterprise Value | $7,658,023 |
| Equity Value | $8,658,023 |
| Per Share | $8.66 |

## Next Steps

- Add uncertainty to projections using <doc:MonteCarloSimulationTutorial>
- Calculate project-level NPV with <doc:TimeValueOfMoneyTutorial>
- Optimize capital structure with <doc:PortfolioOptimizationTutorial>

## See Also

- ``getFinancialStatementTools()``
- ``getFinancialRatiosTools()``
- ``getValuationCalculatorsTools()``
- ``getOperationalMetricsTools()``
