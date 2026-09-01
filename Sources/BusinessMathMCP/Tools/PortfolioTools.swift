import Foundation
import MCP
import SwiftMCPServer
import BusinessMath

// MARK: - Portfolio Optimization Tool

/// Find the optimal portfolio allocation using Modern Portfolio Theory (Markowitz optimization). Maximizes the Sharpe ratio to get the best risk-adjusted returns.
///
/// Exposed to clients as the `optimize_portfolio` tool.
public struct OptimizePortfolioTool: MCPToolHandler, Sendable {
    /// The `optimize_portfolio` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "optimize_portfolio",
        description: """
        Find the optimal portfolio allocation using Modern Portfolio Theory (Markowitz optimization). Maximizes the Sharpe ratio to get the best risk-adjusted returns.

        Example: Optimize allocation across 3 assets
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02, 0.10], [0.06, 0.04, 0.02, 0.08], [0.02, 0.03, 0.02, 0.03]]
        - riskFreeRate: 0.0002  (2% annual / 12 months = 0.167% monthly)

        Returns optimal weights, expected return, risk, and Sharpe ratio.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset (array of arrays, one per asset)",
                    items: MCPSchemaItems(type: "array")
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate for Sharpe ratio calculation (use same period as returns data)"
                )
            ],
            required: ["assets", "returns", "riskFreeRate"]
        )
    )

    /// Creates the `optimize_portfolio` handler.
    public init() {}

    /// Runs `optimize_portfolio` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")
        let riskFreeRate = try args.getDouble("riskFreeRate")

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for (index, assetReturns) in returnsArray.enumerated() {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("returns[\(index)] must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        if returnsData.count != assetNames.count {
            throw ToolError.invalidArguments("Number of return series (\(returnsData.count)) must match number of assets (\(assetNames.count))")
        }

        // Create TimeSeries for each asset
        let numPeriods = returnsData[0].count
        let periods = (1...numPeriods).map { Period.month(year: 2024, month: $0) }

        var timeSeriesArray: [TimeSeries<Double>] = []
        for returns in returnsData {
            if returns.count != numPeriods {
                throw ToolError.invalidArguments("All assets must have the same number of return periods")
            }
            timeSeriesArray.append(TimeSeries(periods: periods, values: returns))
        }

        // A mean needs at least one observation and a sample covariance at least two;
        // `count` and `count - 1` are the divisors below, and an asset with a single
        // return used to fill the matrix with infinities rather than say anything.
        guard returnsData.allSatisfy({ $0.count >= 2 }) else {
            throw ToolError.invalidArguments("Each asset needs at least two return observations")
        }

        // Calculate expected returns (mean of each asset's returns)
        var meanReturns: [Double] = []
        for returns in returnsData {
            let observationCount = Double(returns.count)
            guard observationCount > 0 else {
                throw ToolError.invalidArguments("Each asset needs at least one return observation")
            }
            meanReturns.append(returns.reduce(0, +) / observationCount)
        }
        let expectedReturns = VectorN(meanReturns)

        // Calculate covariance matrix
        let n = returnsData.count
        var covarianceMatrix: [[Double]] = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            let meanI = expectedReturns[i]
            for j in 0..<n {
                let meanJ = expectedReturns[j]
                var covariance = 0.0
                for k in 0..<returnsData[i].count {
                    covariance += (returnsData[i][k] - meanI) * (returnsData[j][k] - meanJ)
                }
                let degreesOfFreedom = Double(returnsData[i].count - 1)
                guard degreesOfFreedom > 0 else {
                    throw ToolError.invalidArguments("A sample covariance needs at least two observations per asset")
                }
                covarianceMatrix[i][j] = covariance / degreesOfFreedom
            }
        }

        // Use new PortfolioOptimizer API
        let optimizer = PortfolioOptimizer()
        let optimalPortfolio = try optimizer.maximumSharpePortfolio(
            expectedReturns: expectedReturns,
            covariance: covarianceMatrix,
            riskFreeRate: riskFreeRate
        )

        var result = """
        Portfolio Optimization Results

        Optimal Portfolio (Maximum Sharpe Ratio):
        - Expected Return: \(optimalPortfolio.expectedReturn.percent(2))
        - Risk (Volatility): \(optimalPortfolio.volatility.percent(2))
        - Sharpe Ratio: \(optimalPortfolio.sharpeRatio.number(3))

        Optimal Weights:
        """

        for (asset, weight) in zip(assetNames, optimalPortfolio.weights.toArray()) {
			result += "\n  \(asset): \(weight.percent(1))"
        }

        result += """


        Interpretation:
        - Sharpe Ratio measures return per unit of risk (higher is better)
        - This allocation maximizes risk-adjusted returns
        - Risk is measured as standard deviation of returns

        Note: These are single-period returns. For annualized metrics:
        - Annual Return ≈ Return × periods per year
        - Annual Risk ≈ Risk × √(periods per year)
        """

        return .success(text: result)
    }
}

// MARK: - Efficient Frontier Tool

/// Generate the efficient frontier showing all optimal risk-return combinations. Each point represents a portfolio with maximum return for its risk level.
///
/// Exposed to clients as the `calculate_efficient_frontier` tool.
public struct EfficientFrontierTool: MCPToolHandler, Sendable {
    /// The `calculate_efficient_frontier` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_efficient_frontier",
        description: """
        Generate the efficient frontier showing all optimal risk-return combinations. Each point represents a portfolio with maximum return for its risk level.

        Example: Calculate 20 points on the frontier
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02], [0.06, 0.04, 0.02], [0.02, 0.03, 0.02]]
        - riskFreeRate: 0.0002
        - points: 20

        Returns array of risk-return combinations with optimal weights.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset",
                    items: MCPSchemaItems(type: "array")
                ),
                "riskFreeRate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate"
                ),
                "points": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of points to calculate on the frontier (default: 20)"
                )
            ],
            required: ["assets", "returns", "riskFreeRate"]
        )
    )

    /// Creates the `calculate_efficient_frontier` handler.
    public init() {}

    /// Runs `calculate_efficient_frontier` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")
        let riskFreeRate = try args.getDouble("riskFreeRate")
        let numPoints = args.getIntOptional("points") ?? 20

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for assetReturns in returnsArray {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each asset's returns must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        // Calculate expected returns and covariance matrix
        var meanReturns: [Double] = []
        for returns in returnsData {
            let observationCount = Double(returns.count)
            guard observationCount > 0 else {
                throw ToolError.invalidArguments("Each asset needs at least one return observation")
            }
            meanReturns.append(returns.reduce(0, +) / observationCount)
        }
        let expectedReturns = VectorN(meanReturns)

        let n = returnsData.count
        var covarianceMatrix: [[Double]] = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            let meanI = expectedReturns[i]
            for j in 0..<n {
                let meanJ = expectedReturns[j]
                var covariance = 0.0
                for k in 0..<returnsData[i].count {
                    covariance += (returnsData[i][k] - meanI) * (returnsData[j][k] - meanJ)
                }
                let degreesOfFreedom = Double(returnsData[i].count - 1)
                guard degreesOfFreedom > 0 else {
                    throw ToolError.invalidArguments("A sample covariance needs at least two observations per asset")
                }
                covarianceMatrix[i][j] = covariance / degreesOfFreedom
            }
        }

        // Use new PortfolioOptimizer API
        let optimizer = PortfolioOptimizer()
        let frontier = try optimizer.efficientFrontier(
            expectedReturns: expectedReturns,
            covariance: covarianceMatrix,
            riskFreeRate: riskFreeRate,
            numberOfPoints: numPoints
        )

        var result = """
        Efficient Frontier (\(numPoints) points)

        The efficient frontier shows all optimal portfolios - those with maximum return for each risk level.

        Risk (σ)  | Return (μ) | Sharpe  | Top Allocation
        ----------|------------|---------|---------------
        """

        for portfolio in frontier.portfolios {
            // Find top holding
            let weights = portfolio.weights.toArray()
            let maxWeightIndex = weights.enumerated().max(by: { $0.element < $1.element })?.offset ?? 0
            let topAsset = assetNames[maxWeightIndex]
            let topWeight = weights[maxWeightIndex]
			result += "\n\(portfolio.volatility.percent(2).paddingLeft(toLength: 6)) | \(portfolio.expectedReturn.percent(2).paddingLeft(toLength: 8)) | \(portfolio.sharpeRatio.number(3).paddingLeft(toLength: 7)) | \(topAsset) (\(topWeight.percent(1).paddingLeft(toLength: 4)))"
        }

        // Get key points from frontier
        let minRisk = frontier.minimumVariancePortfolio
        let maxSharpe = frontier.maximumSharpePortfolio

        result += """


        Key Points:
        • Minimum Risk Portfolio: \(minRisk.volatility.percent(2)) risk, \(minRisk.expectedReturn.percent(2)) return
        • Maximum Sharpe Portfolio: \(maxSharpe.sharpeRatio.number(3)) Sharpe, \(maxSharpe.expectedReturn.percent(2)) return

        Usage:
        - Portfolios on the frontier are optimal (no portfolio with same risk has higher return)
        - Choose based on risk tolerance: left side = conservative, right side = aggressive
        - Maximum Sharpe point offers best risk-adjusted returns
        """

        return .success(text: result)
    }
}

// MARK: - Risk Parity Tool

/// Calculate risk parity allocation where each asset contributes equally to portfolio risk. Alternative to mean-variance optimization that doesn't rely on return forecasts.
///
/// Exposed to clients as the `calculate_risk_parity` tool.
public struct RiskParityAllocationTool: MCPToolHandler, Sendable {
    /// The `calculate_risk_parity` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_risk_parity",
        description: """
        Calculate risk parity allocation where each asset contributes equally to portfolio risk. Alternative to mean-variance optimization that doesn't rely on return forecasts.

        Example:
        - assets: ["Stock A", "Stock B", "Bonds"]
        - returns: [[0.08, 0.05, -0.02], [0.06, 0.04, 0.02], [0.02, 0.03, 0.02]]

        Returns weights where each asset has equal risk contribution.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "assets": MCPSchemaProperty(
                    type: "array",
                    description: "Asset names",
                    items: MCPSchemaItems(type: "string")
                ),
                "returns": MCPSchemaProperty(
                    type: "array",
                    description: "Historical returns for each asset",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["assets", "returns"]
        )
    )

    /// Creates the `calculate_risk_parity` handler.
    public init() {}

    /// Runs `calculate_risk_parity` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let assetNames = try args.getStringArray("assets")

        guard let returnsValue = args["returns"],
              let returnsArray = returnsValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("returns must be an array of arrays")
        }

        // Parse returns data
        var returnsData: [[Double]] = []
        for assetReturns in returnsArray {
            guard let returnsForAsset = assetReturns.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Each asset's returns must be an array")
            }

            var assetReturnValues: [Double] = []
            for returnValue in returnsForAsset {
                if let doubleVal = returnValue.value as? Double {
                    assetReturnValues.append(doubleVal)
                } else if let intVal = returnValue.value as? Int {
                    assetReturnValues.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("All return values must be numbers")
                }
            }
            returnsData.append(assetReturnValues)
        }

        // Calculate expected returns and covariance matrix
        var meanReturns: [Double] = []
        for returns in returnsData {
            let observationCount = Double(returns.count)
            guard observationCount > 0 else {
                throw ToolError.invalidArguments("Each asset needs at least one return observation")
            }
            meanReturns.append(returns.reduce(0, +) / observationCount)
        }
        let expectedReturns = VectorN(meanReturns)

        let n = returnsData.count
        var covarianceMatrix: [[Double]] = Array(repeating: Array(repeating: 0.0, count: n), count: n)

        for i in 0..<n {
            let meanI = expectedReturns[i]
            for j in 0..<n {
                let meanJ = expectedReturns[j]
                var covariance = 0.0
                for k in 0..<returnsData[i].count {
                    covariance += (returnsData[i][k] - meanI) * (returnsData[j][k] - meanJ)
                }
                let degreesOfFreedom = Double(returnsData[i].count - 1)
                guard degreesOfFreedom > 0 else {
                    throw ToolError.invalidArguments("A sample covariance needs at least two observations per asset")
                }
                covarianceMatrix[i][j] = covariance / degreesOfFreedom
            }
        }

        // Use new PortfolioOptimizer API
        let optimizer = PortfolioOptimizer()
        let portfolio = try optimizer.riskParityPortfolio(
            expectedReturns: expectedReturns,
            covariance: covarianceMatrix
        )

        // Calculate risk contributions for display
        let weights = portfolio.weights.toArray()
        let assetCount = Double(assetNames.count)
        guard assetCount > 0 else {
            throw ToolError.invalidArguments("At least one asset is required")
        }
        let targetContribution = 1.0 / assetCount

        var result = """
        Risk Parity Allocation

        Philosophy: Each asset contributes equally to total portfolio risk.
        Unlike mean-variance optimization, this doesn't rely on return forecasts.

        Optimal Weights:
        """

        for (asset, weight) in zip(assetNames, weights) {
			result += "\n  \(asset): \(weight.percent(1))"
        }

		result += "\n\nRisk Contributions (each should be ~\(targetContribution.percent(1))):"

        // Calculate actual risk contributions
        var actualRiskContributions: [Double] = []
        for i in 0..<n {
            var marginalRisk = 0.0
            for j in 0..<n {
                marginalRisk += covarianceMatrix[i][j] * weights[j]
            }
            // A zero-volatility portfolio has no risk to attribute; dividing by it gave
            // every asset an infinite contribution.
            let portfolioVolatility = portfolio.volatility
            guard portfolioVolatility > 0 else {
                throw ToolError.invalidArguments("Portfolio volatility is zero; risk contributions are undefined")
            }
            let riskContribution = weights[i] * marginalRisk / portfolioVolatility
            actualRiskContributions.append(riskContribution)
        }

        for (asset, contribution) in zip(assetNames, actualRiskContributions) {
			result += "\n  \(asset): \((contribution / portfolio.volatility).percent(1)) of total risk"
        }

        result += """


        Portfolio Metrics:
        - Expected Return: \(portfolio.expectedReturn.percent(2))
        - Risk (Volatility): \(portfolio.volatility.percent(2))
        - Sharpe Ratio: \(portfolio.sharpeRatio.number(3))

        When to use:
        ✓ Skeptical of return forecasts
        ✓ Want balanced risk exposure
        ✓ Prefer diversification focus

        When not to use:
        ✗ Have strong views on returns
        ✗ Want to maximize Sharpe ratio
        ✗ Some assets clearly dominate
        """

        return .success(text: result)
    }
}

// MARK: - Tool Registration

/// Every portfolio tool this server exposes.
public func getPortfolioTools() -> [MCPToolHandler] {
    return [
        OptimizePortfolioTool(),
        EfficientFrontierTool(),
        RiskParityAllocationTool()
    ]
}
