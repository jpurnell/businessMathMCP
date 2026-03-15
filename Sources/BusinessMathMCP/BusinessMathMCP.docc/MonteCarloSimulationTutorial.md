# Monte Carlo Simulation

Model uncertainty and risk using probability distributions and Monte Carlo simulation.

## Overview

Monte Carlo simulation uses random sampling to model uncertainty in financial projections. Instead of single-point estimates, you define probability distributions for uncertain variables and run thousands of simulations to understand the range of possible outcomes.

BusinessMathMCP provides 15 probability distributions and comprehensive Monte Carlo tools for:
- Revenue and cost uncertainty modeling
- Risk quantification (VaR, CVaR)
- Scenario probability analysis
- Correlated variable simulation

## Understanding Monte Carlo

Traditional financial models use single estimates:

```
Revenue = $1,000,000
Costs = $600,000
Profit = $400,000
```

Monte Carlo recognizes uncertainty:

```
Revenue ~ Normal(mean: $1,000,000, stdDev: $200,000)
Costs ~ Normal(mean: $600,000, stdDev: $100,000)
Profit = Revenue - Costs  // Run 10,000 times
```

## Basic Simulation

### Single Variable Simulation

**Scenario**: Model uncertain revenue with normal distribution.

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    }
  ],
  "calculation": "{0}",
  "iterations": 10000
}
```

**Result**: Distribution of revenue outcomes with statistics.

### Profit Model (Two Variables)

**Scenario**: Revenue minus costs with independent uncertainty.

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    },
    {
      "name": "Costs",
      "distribution": "normal",
      "parameters": {"mean": 600000, "stdDev": 100000}
    }
  ],
  "calculation": "{0} - {1}",
  "iterations": 10000
}
```

**Result**: Profit distribution showing probability of different outcomes.

## Available Distributions

BusinessMathMCP supports 15 probability distributions:

### Continuous Distributions

| Distribution | Use Case | Parameters |
|--------------|----------|------------|
| Normal | General uncertainty | mean, stdDev |
| Lognormal | Asset prices, multiplicative growth | mu, sigma |
| Uniform | Equal probability range | min, max |
| Triangular | Three-point estimates | min, mode, max |
| Beta | Bounded percentages | alpha, beta |
| Exponential | Time between events | lambda |
| Gamma | Waiting times | shape, scale |
| Weibull | Failure rates | shape, scale |

### Discrete Distributions

| Distribution | Use Case | Parameters |
|--------------|----------|------------|
| Binomial | Success/failure counts | n, p |
| Poisson | Event counts | lambda |
| Geometric | Trials until success | p |

### Distribution Examples

**Triangular** (expert estimates with min/max/most likely):

```json
{
  "name": "ProjectCost",
  "distribution": "triangular",
  "parameters": {"min": 80000, "mode": 100000, "max": 150000}
}
```

**Lognormal** (stock prices, always positive):

```json
{
  "name": "StockPrice",
  "distribution": "lognormal",
  "parameters": {"mu": 4.6, "sigma": 0.3}
}
```

**Beta** (conversion rates, bounded 0-1):

```json
{
  "name": "ConversionRate",
  "distribution": "beta",
  "parameters": {"alpha": 2, "beta": 5}
}
```

## Complex Calculations

### NPV with Uncertainty

**Scenario**: Investment NPV with uncertain annual returns.

```json
{
  "inputs": [
    {
      "name": "Year1",
      "distribution": "normal",
      "parameters": {"mean": 30000, "stdDev": 5000}
    },
    {
      "name": "Year2",
      "distribution": "normal",
      "parameters": {"mean": 35000, "stdDev": 6000}
    },
    {
      "name": "Year3",
      "distribution": "normal",
      "parameters": {"mean": 40000, "stdDev": 7000}
    }
  ],
  "calculation": "-100000 + {0}/1.1 + {1}/1.21 + {2}/1.331",
  "iterations": 10000
}
```

**Result**: NPV distribution showing probability of positive vs negative outcomes.

### Multi-Variable Business Model

**Scenario**: SaaS revenue model with growth uncertainty.

```json
{
  "inputs": [
    {
      "name": "Customers",
      "distribution": "normal",
      "parameters": {"mean": 1000, "stdDev": 150}
    },
    {
      "name": "ARPU",
      "distribution": "triangular",
      "parameters": {"min": 45, "mode": 50, "max": 65}
    },
    {
      "name": "ChurnRate",
      "distribution": "beta",
      "parameters": {"alpha": 2, "beta": 18}
    }
  ],
  "calculation": "{0} * {1} * 12 * (1 - {2})",
  "iterations": 10000
}
```

## Risk Metrics

### Value at Risk (VaR)

VaR quantifies the maximum loss at a confidence level.

**Scenario**: 95% VaR for portfolio returns.

```json
{
  "inputs": [
    {
      "name": "Return",
      "distribution": "normal",
      "parameters": {"mean": 0.08, "stdDev": 0.15}
    }
  ],
  "calculation": "1000000 * {0}",
  "iterations": 10000,
  "riskMetrics": {
    "var": [0.95, 0.99],
    "cvar": [0.95]
  }
}
```

**Result**:
- 95% VaR: Maximum expected loss in 95% of scenarios
- 99% VaR: Worst-case 1% threshold
- 95% CVaR: Average loss in worst 5% of scenarios

### Probability of Outcomes

Calculate probability of specific thresholds:

```json
{
  "inputs": [...],
  "calculation": "{0} - {1}",
  "iterations": 10000,
  "thresholds": [0, 100000, 500000]
}
```

**Result**: Probability that result exceeds each threshold.

## Correlated Simulations

Real-world variables often move together. Use correlation matrices for realistic modeling.

### Correlated Revenue and Costs

**Scenario**: Revenue and costs positively correlated (0.7 correlation).

```json
{
  "inputs": [
    {
      "name": "Revenue",
      "distribution": "normal",
      "parameters": {"mean": 1000000, "stdDev": 200000}
    },
    {
      "name": "Costs",
      "distribution": "normal",
      "parameters": {"mean": 600000, "stdDev": 100000}
    }
  ],
  "correlationMatrix": [
    [1.0, 0.7],
    [0.7, 1.0]
  ],
  "calculation": "{0} - {1}",
  "iterations": 10000
}
```

### Correlation Effects

| Correlation | Effect on Profit Variance |
|-------------|---------------------------|
| +1.0 | Maximum variance (perfect positive) |
| 0.0 | Independent (baseline variance) |
| -1.0 | Minimum variance (perfect hedge) |

## Sensitivity Analysis

Identify which variables most impact outcomes.

### Tornado Diagram Data

```json
{
  "baseCase": {
    "revenue": 1000000,
    "costs": 600000,
    "growth": 0.10
  },
  "variables": [
    {"name": "revenue", "low": 800000, "high": 1200000},
    {"name": "costs", "low": 500000, "high": 700000},
    {"name": "growth", "low": 0.05, "high": 0.15}
  ],
  "calculation": "(revenue - costs) * (1 + growth)"
}
```

**Result**: Impact ranking showing revenue has highest sensitivity.

## Best Practices

### Choosing Distributions

| Data Available | Recommended Distribution |
|----------------|-------------------------|
| Historical data | Fit to empirical distribution |
| Min/Max/Most Likely | Triangular |
| Mean and StdDev | Normal (if unbounded) |
| Percentages (0-1) | Beta |
| Always positive | Lognormal |
| Expert range | Uniform |

### Iteration Count

| Analysis Type | Recommended Iterations |
|---------------|------------------------|
| Quick estimate | 1,000 |
| Standard analysis | 10,000 |
| Precise tail risk | 100,000 |

### Validation

- Compare mean of simulation to deterministic calculation
- Verify standard deviation is reasonable
- Check for impossible values (negative prices, >100% rates)

## Next Steps

- Apply simulations to <doc:PortfolioOptimizationTutorial> for robust portfolio construction
- Combine with <doc:TimeValueOfMoneyTutorial> for probabilistic NPV analysis
- Use in <doc:FinancialStatementsTutorial> for pro forma projections

## See Also

- ``getMonteCarloTools()``
- ``getAdvancedSimulationTools()``
- ``getRiskAnalyticsTools()``
