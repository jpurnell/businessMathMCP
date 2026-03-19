import Foundation
import BusinessMathMCP
import SwiftMCPServer

try await MCPServer.builder()
    .serverName("BusinessMath MCP Server")
    .serverVersion("2.0.0")
    .serverInstructions("""
        Comprehensive business mathematics, financial modeling, Monte Carlo simulation, and advanced analytics server.

        **Capabilities**:
        - 187+ computational tools across 33 categories
        - 15 probability distributions
        - 9 essential financial ratios (liquidity, leverage, profitability, efficiency)
        - 12 valuation calculators (EPS, P/E, P/B, market cap, enterprise value, free cash flow)
        - 4 investment decision metrics (PI, payback period, discounted payback, MIRR)
        - 4 loan payment analysis tools
        - 4 trend forecasting models (linear, exponential, logistic, decomposition)
        - 3 seasonality tools
        - 2 advanced options tools (Greeks, binomial tree pricing)
        - Bayesian inference
        - 10 documentation and example resources
        - 6 prompt templates for common financial analyses

        **Tool Categories**:
        1. Time Value of Money (TVM): NPV, IRR, PV, FV, payments, annuities
        2. Time Series Analysis: Growth rates, moving averages, comparisons
        3. Forecasting: Trend analysis, seasonal adjustment, projections
        4. Debt & Financing: Amortization, WACC, CAPM, coverage ratios
        5. Statistical Analysis: Correlation, regression, confidence intervals
        6. Monte Carlo Simulation: Risk modeling, 15 distributions, sensitivity analysis
        7. Hypothesis Testing: T-tests, chi-square, F-tests, sample size, A/B testing
        8. Optimization & Solvers: Newton-Raphson, gradient descent, capital allocation
        9. Portfolio Optimization: Modern Portfolio Theory, efficient frontier, risk parity
        10. Real Options: Black-Scholes, binomial trees, expansion/abandonment valuation
        11. Risk Analytics: Stress testing, VaR/CVaR, risk aggregation
        12. Financial Ratios: Liquidity, leverage, profitability, efficiency ratios
        13. Valuation: EPS, BVPS, P/E, P/B, market cap, enterprise value, DCF
        14. Integer Programming: Branch-and-bound, cutting planes
        15. Financial Statements: Income statement, balance sheet, cash flow, validation

        **Resources**: Access comprehensive documentation and examples
        **Prompts**: Use prompt templates for guided analysis workflows
        """)
    .tools(allToolHandlers())
    .resourceProvider(ResourceProvider())
    .promptProvider(PromptProvider())
    .run()
