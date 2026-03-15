# Getting Started with BusinessMathMCP

Set up BusinessMathMCP and make your first financial calculations through AI.

## Overview

This tutorial walks you through installing BusinessMathMCP, connecting it to Claude Desktop or another MCP client, and running your first calculations. By the end, you'll understand how to leverage 195+ financial tools through natural language.

## Building from Source

Clone and build the project:

```bash
git clone https://github.com/jpurnell/businessMathMCP.git
cd businessMathMCP
swift build -c release
```

The executable is located at `.build/release/BusinessMathMCPServer`.

## Configuring Claude Desktop

Add BusinessMathMCP to your Claude Desktop configuration file.

### macOS Configuration

Edit `~/Library/Application Support/Claude/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "businessmath": {
      "command": "/path/to/BusinessMathMCPServer",
      "args": []
    }
  }
}
```

### Windows Configuration

Edit `%APPDATA%\Claude\claude_desktop_config.json` with the same structure, using the Windows executable path.

## Your First Calculation

After restarting Claude Desktop, ask Claude to perform a calculation:

> "Calculate the NPV of an investment with an initial cost of $100,000 and annual returns of $30,000 for 4 years, using a 10% discount rate."

Claude will use the `npv` tool:

```json
{
  "discountRate": 0.10,
  "cashFlows": [-100000, 30000, 30000, 30000, 30000]
}
```

**Result**: NPV = -$4,641.92 (the investment does not meet the required return)

## Understanding Tool Structure

Every BusinessMathMCP tool follows a consistent JSON structure. Here's the anatomy of a tool call:

### Input Structure

```json
{
  "parameterName": value,
  "arrayParameter": [value1, value2],
  "objectParameter": {
    "nestedField": value
  }
}
```

### Common Patterns

**Rates**: Express as decimals (10% = 0.10)

```json
{"rate": 0.10}
```

**Cash Flows**: Arrays with initial investment negative

```json
{"cashFlows": [-100000, 30000, 30000, 30000]}
```

**Dates**: ISO 8601 format

```json
{"date": "2024-01-15T00:00:00Z"}
```

**Periods**: Objects with type specification

```json
{"year": 2024, "month": 6, "type": "monthly"}
```

## Available Tool Categories

BusinessMathMCP organizes tools into logical categories:

| Category | Example Tools | Use Cases |
|----------|---------------|-----------|
| Time Value of Money | npv, irr, pv, fv, pmt | Investment analysis |
| Monte Carlo | monteCarloSimulation | Risk modeling |
| Portfolio | efficientFrontier | Asset allocation |
| Statistics | regression, correlation | Data analysis |
| Financial Statements | incomeStatement | Financial modeling |
| Optimization | linearProgramming | Resource allocation |

## Running in HTTP Mode

For production deployments, run BusinessMathMCP as an HTTP server:

```bash
./BusinessMathMCPServer --mode http --port 8080 --api-key YOUR_SECRET_KEY
```

Connect MCP clients to `http://localhost:8080/mcp/v1` with the API key header:

```
Authorization: Bearer YOUR_SECRET_KEY
```

## Troubleshooting

### Server Not Recognized

Verify the executable path is correct and the file is executable:

```bash
chmod +x /path/to/BusinessMathMCPServer
```

### Tool Calls Failing

Check that parameter names match exactly. Common issues:
- Using `rate` instead of `discountRate`
- Forgetting to express percentages as decimals
- Missing required fields in nested objects

### HTTP Mode Connection Issues

Ensure the port is not in use and firewall allows connections:

```bash
lsof -i :8080
```

## Next Steps

- Follow <doc:TimeValueOfMoneyTutorial> to master NPV, IRR, and cash flow analysis
- Explore <doc:MonteCarloSimulationTutorial> for risk modeling with probability distributions
- Learn <doc:PortfolioOptimizationTutorial> for modern portfolio theory calculations

## See Also

- ``getTVMTools()``
- ``getStatisticalTools()``
- ``getMonteCarloTools()``
