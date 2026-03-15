# Portfolio Optimization

Build optimal portfolios using modern portfolio theory and efficient frontier analysis.

## Overview

Portfolio optimization finds the best combination of assets to maximize return for a given risk level, or minimize risk for a target return. BusinessMathMCP implements Harry Markowitz's Modern Portfolio Theory (MPT) and provides tools for:

- Efficient frontier calculation
- Mean-variance optimization
- Risk parity portfolios
- Capital allocation with constraints

## Modern Portfolio Theory Basics

MPT demonstrates that diversification reduces risk. A portfolio's risk isn't simply the weighted average of individual asset risks—correlations matter.

### Key Concepts

| Concept | Definition |
|---------|------------|
| Expected Return | Weighted average of asset returns |
| Portfolio Variance | Risk accounting for correlations |
| Efficient Frontier | Portfolios with best return per risk |
| Sharpe Ratio | Risk-adjusted return measure |

### Portfolio Return Formula

```
E(Rp) = Σ wi × E(Ri)
```

Where wi = weight of asset i, E(Ri) = expected return of asset i

### Portfolio Variance Formula

```
σp² = Σ Σ wi × wj × σi × σj × ρij
```

Where ρij = correlation between assets i and j

## Efficient Frontier

The efficient frontier shows optimal portfolios across risk levels.

### Calculate Efficient Frontier

**Scenario**: Three-asset portfolio optimization.

```json
{
  "assets": [
    {"name": "Stocks", "expectedReturn": 0.10, "standardDeviation": 0.20},
    {"name": "Bonds", "expectedReturn": 0.05, "standardDeviation": 0.08},
    {"name": "Real Estate", "expectedReturn": 0.08, "standardDeviation": 0.15}
  ],
  "correlationMatrix": [
    [1.00, 0.20, 0.40],
    [0.20, 1.00, 0.30],
    [0.40, 0.30, 1.00]
  ],
  "points": 20,
  "riskFreeRate": 0.03
}
```

**Result**: 20 portfolios along the efficient frontier with weights, returns, and risks.

### Interpreting Results

| Portfolio | Stocks | Bonds | RE | Return | Risk | Sharpe |
|-----------|--------|-------|-----|--------|------|--------|
| Min Var | 15% | 70% | 15% | 5.8% | 6.5% | 0.43 |
| Balanced | 40% | 35% | 25% | 7.5% | 11.0% | 0.41 |
| Max Sharpe | 55% | 25% | 20% | 8.3% | 13.5% | 0.39 |
| Max Return | 100% | 0% | 0% | 10.0% | 20.0% | 0.35 |

## Mean-Variance Optimization

Find the optimal portfolio for your objectives.

### Maximize Sharpe Ratio

**Scenario**: Find portfolio with best risk-adjusted return.

```json
{
  "assets": [
    {"name": "Stocks", "expectedReturn": 0.10, "standardDeviation": 0.20},
    {"name": "Bonds", "expectedReturn": 0.05, "standardDeviation": 0.08},
    {"name": "Real Estate", "expectedReturn": 0.08, "standardDeviation": 0.15}
  ],
  "correlationMatrix": [
    [1.00, 0.20, 0.40],
    [0.20, 1.00, 0.30],
    [0.40, 0.30, 1.00]
  ],
  "objective": "maxSharpe",
  "riskFreeRate": 0.03
}
```

### Target Return Optimization

**Scenario**: Minimize risk for 7% target return.

```json
{
  "assets": [...],
  "correlationMatrix": [...],
  "objective": "minVariance",
  "targetReturn": 0.07
}
```

### Target Risk Optimization

**Scenario**: Maximize return for 12% target volatility.

```json
{
  "assets": [...],
  "correlationMatrix": [...],
  "objective": "maxReturn",
  "targetRisk": 0.12
}
```

## Constraints

Add real-world constraints to your optimization.

### Weight Bounds

**Scenario**: No single asset exceeds 60%, minimum 10% in bonds.

```json
{
  "assets": [...],
  "correlationMatrix": [...],
  "constraints": {
    "minWeights": [0.00, 0.10, 0.00],
    "maxWeights": [0.60, 0.60, 0.60]
  },
  "objective": "maxSharpe"
}
```

### Sector Constraints

**Scenario**: Maximum 70% in equities (stocks + real estate).

```json
{
  "assets": [...],
  "correlationMatrix": [...],
  "constraints": {
    "groups": [
      {"assets": [0, 2], "maxWeight": 0.70, "name": "Equities"}
    ]
  }
}
```

### Long-Only vs Short Allowed

```json
{
  "constraints": {
    "allowShort": false,  // Long-only (default)
    "minWeights": [-0.20, -0.20, -0.20],  // Allow 20% short
    "allowShort": true
  }
}
```

## Risk Parity Portfolio

Equal risk contribution from each asset.

**Scenario**: Risk parity for balanced risk exposure.

```json
{
  "assets": [
    {"name": "Stocks", "standardDeviation": 0.20},
    {"name": "Bonds", "standardDeviation": 0.08},
    {"name": "Commodities", "standardDeviation": 0.25}
  ],
  "correlationMatrix": [
    [1.00, 0.20, 0.10],
    [0.20, 1.00, 0.05],
    [0.10, 0.05, 1.00]
  ],
  "objective": "riskParity"
}
```

**Result**: Weights where each asset contributes equally to total portfolio risk.

## Black-Litterman Model

Incorporate your views into market equilibrium.

**Scenario**: You believe stocks will outperform by 2%.

```json
{
  "assets": [...],
  "correlationMatrix": [...],
  "marketCap": [10000000, 5000000, 3000000],
  "views": [
    {"asset": 0, "expectedExcessReturn": 0.02, "confidence": 0.80}
  ],
  "riskFreeRate": 0.03
}
```

## Portfolio Analytics

Analyze an existing portfolio.

### Portfolio Risk Decomposition

```json
{
  "assets": [...],
  "weights": [0.50, 0.30, 0.20],
  "correlationMatrix": [...],
  "analysis": ["riskContribution", "marginalRisk", "componentVaR"]
}
```

**Result**:
- Risk contribution: Each asset's share of total risk
- Marginal risk: Impact of small weight changes
- Component VaR: VaR attributed to each asset

### Diversification Ratio

```json
{
  "assets": [...],
  "weights": [0.50, 0.30, 0.20],
  "correlationMatrix": [...],
  "analysis": ["diversificationRatio"]
}
```

**Result**: Ratio > 1 indicates diversification benefit.

## Capital Allocation

Allocate capital across multiple strategies or managers.

### Risk Budgeting

**Scenario**: Allocate $10M with maximum $2M risk per strategy.

```json
{
  "totalCapital": 10000000,
  "strategies": [
    {"name": "Long/Short Equity", "expectedReturn": 0.12, "risk": 0.18},
    {"name": "Fixed Income", "expectedReturn": 0.05, "risk": 0.06},
    {"name": "Macro", "expectedReturn": 0.08, "risk": 0.12}
  ],
  "riskBudget": 2000000,
  "objective": "maxReturn"
}
```

## Practical Workflow

### Step 1: Gather Data

Collect historical returns, calculate:
- Expected returns (historical or forward-looking)
- Standard deviations
- Correlation matrix

### Step 2: Define Objectives

Choose your optimization goal:
- Maximum Sharpe for best risk-adjusted return
- Minimum variance for conservative investors
- Target return for specific goals

### Step 3: Add Constraints

Apply realistic constraints:
- Weight limits (min/max per asset)
- Sector/group limits
- Turnover constraints

### Step 4: Optimize

Run optimization and review results.

### Step 5: Validate

- Check weights sum to 100%
- Verify constraints are satisfied
- Compare to benchmark

### Step 6: Monitor

Rebalance periodically as weights drift.

## Common Issues

### Estimation Error

Historical data may not predict future correlations. Consider:
- Shrinkage estimators for correlation
- Multiple scenarios
- Robust optimization

### Corner Solutions

Optimizer may put 100% in one asset. Solutions:
- Add minimum weight constraints
- Use regularization
- Check input data for errors

### Negative Weights

If shorting not allowed, ensure `allowShort: false`.

## Next Steps

- Add uncertainty to inputs using <doc:MonteCarloSimulationTutorial>
- Calculate portfolio NPV with <doc:TimeValueOfMoneyTutorial>
- Model portfolio companies with <doc:FinancialStatementsTutorial>

## See Also

- ``getMeanVariancePortfolioTools()``
- ``getPortfolioTools()``
- ``getRiskAnalyticsTools()``
- ``getOptimizationTools()``
