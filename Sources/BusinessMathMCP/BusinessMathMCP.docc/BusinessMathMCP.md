# ``BusinessMathMCP``

A Model Context Protocol (MCP) server exposing comprehensive financial mathematics tools to AI assistants.

## Overview

BusinessMathMCP provides AI assistants with access to ~195 professional-grade financial calculation tools through the Model Context Protocol. Whether you're building financial models, analyzing investments, running Monte Carlo simulations, or optimizing portfolios, BusinessMathMCP delivers the computational power your AI workflows need.

The server supports two transport modes:
- **Stdio mode** for Claude Desktop and local AI integrations
- **HTTP+SSE mode** for production deployments with authentication

### Key Capabilities

BusinessMathMCP covers the full spectrum of business mathematics:

- **Time Value of Money**: NPV, IRR, PV, FV, PMT, annuities
- **Monte Carlo Simulation**: 15 probability distributions with correlation support
- **Portfolio Optimization**: Modern portfolio theory, efficient frontiers
- **Financial Statements**: Income statements, balance sheets, cash flow
- **Statistical Analysis**: Regression, hypothesis testing, confidence intervals
- **Optimization**: Linear programming, capital allocation, multi-period planning

### Getting Started

Add BusinessMathMCP to your Claude Desktop configuration:

```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/path/to/BusinessMathMCP",
      "args": []
    }
  }
}
```

Or run in HTTP mode for production:

```bash
./BusinessMathMCP --mode http --port 8080 --api-key YOUR_KEY
```

## Topics

### Tutorials

- <doc:GettingStartedTutorial>
- <doc:TimeValueOfMoneyTutorial>
- <doc:MonteCarloSimulationTutorial>
- <doc:PortfolioOptimizationTutorial>
- <doc:FinancialStatementsTutorial>

### Time Value of Money

- ``getTVMTools()``
- ``getTimeSeriesTools()``

### Statistical Analysis

- ``getStatisticalTools()``
- ``getAdvancedStatisticsTools()``
- ``getHypothesisTestingTools()``
- ``getBayesianTools()``

### Monte Carlo & Simulation

- ``getMonteCarloTools()``
- ``getAdvancedSimulationTools()``

### Portfolio & Risk

- ``getMeanVariancePortfolioTools()``
- ``getPortfolioTools()``
- ``getRiskAnalyticsTools()``
- ``getRealOptionsTools()``

### Optimization

- ``getOptimizationTools()``
- ``getAdvancedOptimizationTools()``
- ``getIntegerProgrammingTools()``
- ``getHeuristicOptimizationTools()``

### Financial Analysis

- ``getFinancialRatiosTools()``
- ``getValuationCalculatorsTools()``
- ``getBondValuationTools()``
- ``getEquityValuationTools()``

### Financial Statements

- ``getFinancialStatementTools()``
- ``getOperationalMetricsTools()``
- ``getCapitalStructureTools()``

### Forecasting

- ``getForecastingTools()``
- ``getTrendForecastingTools()``
- ``getSeasonalityTools()``
