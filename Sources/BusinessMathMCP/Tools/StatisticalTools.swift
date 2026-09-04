//
//  StatisticalTools.swift
//  BusinessMath MCP Server
//
//  Statistical analysis tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all statistical analysis tools
public func getStatisticalTools() -> [any MCPToolHandler] {
    return [
        CalculateCorrelationTool(),
        LinearRegressionTool(),
        MultipleLinearRegressionTool(),
        SpearmansCorrelationTool(),
        CalculateConfidenceIntervalTool(),
        CalculateCovarianceTool(),
        CalculateZScoreTool(),
        DescriptiveStatsExtendedTool(),
        ConcordanceAnalysisTool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Format a percentage (input is already in percentage form, e.g., 95.5 for 95.5%)

// MARK: - 1. Calculate Correlation (Pearson)

/// Calculate Pearson correlation coefficient between two datasets.
///
/// Exposed to clients as the `calculate_correlation` tool.
public struct CalculateCorrelationTool: MCPToolHandler, Sendable {
    /// The `calculate_correlation` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_correlation",
        description: """
        Calculate Pearson correlation coefficient between two datasets.

        The correlation coefficient measures the linear relationship between two variables:
        • 1.0 = Perfect positive correlation
        • 0.0 = No linear correlation
        • -1.0 = Perfect negative correlation

        Supports both sample and population correlation.

        Example: Analyze relationship between advertising spend and revenue
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset (independent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset (dependent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "population": MCPSchemaProperty(
                    type: "string",
                    description: "Whether data represents 'sample' or 'population' (default: 'sample')",
                    enum: ["sample", "population"]
                )
            ],
            required: ["x", "y"]
        )
    )

    /// Creates the `calculate_correlation` handler.
    public init() {}

    /// Runs `calculate_correlation` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")
        let populationType = args.getStringOptional("population") ?? "sample"

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points to calculate correlation")
        }

        let population: Population = populationType == "population" ? .population : .sample
        let correlation = try correlationCoefficient(x, y, population)

        // Interpret correlation strength
        let absCorr = abs(correlation)
        let strength = absCorr > 0.7 ? "Strong" :
                      absCorr > 0.4 ? "Moderate" :
                      absCorr > 0.2 ? "Weak" : "Very weak"
        let direction = correlation > 0 ? "positive" : "negative"

        let output = """
        Pearson Correlation Coefficient:
        • Correlation (r): \(formatNumber(correlation, decimals: 4))
        • Type: \(populationType == "population" ? "Population" : "Sample")
        • N: \(x.count) data points

        Interpretation:
        • Strength: \(strength) \(direction) correlation
        • R²: \(formatNumber(correlation * correlation, decimals: 4)) (\((correlation * correlation).percent())% of variance explained)

        \(correlation > 0 ? "✓ Positive relationship: as X increases, Y tends to increase" : "✗ Negative relationship: as X increases, Y tends to decrease")
        """

        return .success(text: output)
    }
}

// MARK: - 2. Linear Regression

/// Perform linear regression analysis to model the relationship between variables.
///
/// Exposed to clients as the `linear_regression` tool.
public struct LinearRegressionTool: MCPToolHandler, Sendable {
    /// The `linear_regression` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "linear_regression",
        description: """
        Perform linear regression analysis to model the relationship between variables.

        Fits the equation: y = mx + b (slope-intercept form)

        Returns:
        • Slope (m): Rate of change
        • Intercept (b): Y-value when x=0
        • R² (coefficient of determination): Goodness of fit (0-1)
        • Predictions for specified x values (optional)

        Example: Predict sales based on advertising spend
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "Independent variable (predictor)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Dependent variable (outcome)",
                    items: MCPSchemaItems(type: "number")
                ),
                "predictFor": MCPSchemaProperty(
                    type: "array",
                    description: "Optional: X values to generate predictions for",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    /// Creates the `linear_regression` handler.
    public init() {}

    /// Runs `linear_regression` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points for regression")
        }

        // Calculate regression parameters
        let slope = try slope(x, y)
        let intercept = try intercept(x, y)
        let rSquared = try rSquared(x, y, .sample)

        var output = """
        Linear Regression Analysis:

        Equation: y = \(formatNumber(slope, decimals: 4))x + \(formatNumber(intercept, decimals: 4))

        Parameters:
        • Slope (m): \(formatNumber(slope, decimals: 4))
        • Intercept (b): \(formatNumber(intercept, decimals: 4))
        • R² (goodness of fit): \(formatNumber(rSquared, decimals: 4)) (\(rSquared.percent())%)
        • N: \(x.count) data points

        Interpretation:
        • For each 1-unit increase in X, Y changes by \(formatNumber(slope, decimals: 4)) units
        • When X = 0, Y = \(formatNumber(intercept, decimals: 4))
        • The model explains \(rSquared.percent())% of the variance in Y
        """

        // Generate predictions if requested
        if let predictFor = try args.getDoubleArrayIfPresent("predictFor") {
            output += "\n\nPredictions:"
            for xVal in predictFor {
                let prediction = intercept + slope * xVal
                output += "\n• X = \(formatNumber(xVal, decimals: 2)) → Y = \(formatNumber(prediction, decimals: 2))"
            }
        }

        return .success(text: output)
    }
}

// MARK: - 2b. Multiple Linear Regression

/// Perform multiple linear regression with two or more predictor variables.
///
/// Exposed to clients as the `multiple_linear_regression` tool.
public struct MultipleLinearRegressionTool: MCPToolHandler, Sendable {
    /// The `multiple_linear_regression` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "multiple_linear_regression",
        description: """
        Perform multiple linear regression with two or more predictor variables.

        Fits: y = b0 + b1*x1 + b2*x2 + ... + bp*xp

        Returns comprehensive diagnostics:
        - Coefficients with standard errors, t-statistics, p-values, confidence intervals
        - R-squared and adjusted R-squared
        - F-statistic for overall model significance
        - Variance Inflation Factors (VIF) for multicollinearity detection
        - Residuals and fitted values
        - Predictions for new data points (optional)

        Input format: X is a matrix where each row is an observation and each column is a predictor.
        Example with 3 observations and 2 predictors: [[x1_1, x2_1], [x1_2, x2_2], [x1_3, x2_3]]
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "X": MCPSchemaProperty(
                    type: "array",
                    description: "Predictor matrix: array of rows, each row is [x1, x2, ...] for one observation. Example: [[230.1, 37.8], [44.5, 39.3], [17.2, 45.9]]",
                    items: MCPSchemaItems(type: "array")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Response variable (one value per observation)",
                    items: MCPSchemaItems(type: "number")
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level for intervals (default: 0.95)"
                ),
                "predictorNames": MCPSchemaProperty(
                    type: "array",
                    description: "Optional names for predictor variables (e.g. [\"TV\", \"Radio\"])",
                    items: MCPSchemaItems(type: "string")
                ),
                "predictFor": MCPSchemaProperty(
                    type: "array",
                    description: "Optional: new X rows to predict y for. Same format as X rows.",
                    items: MCPSchemaItems(type: "array")
                )
            ],
            required: ["X", "y"]
        )
    )

    /// Creates the `multiple_linear_regression` handler.
    public init() {}

    /// Runs `multiple_linear_regression` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let X = try args.getDoubleMatrix("X")
        let y = try args.getDoubleArray("y")
        let confidenceLevel = args.getDoubleOptional("confidenceLevel") ?? 0.95
        let predictorNames = try args.getStringArrayIfPresent("predictorNames")

        guard !X.isEmpty else {
            throw ToolError.invalidArguments("X must not be empty")
        }

        let p = X[0].count
        guard p >= 1 else {
            throw ToolError.invalidArguments("Each observation must have at least 1 predictor")
        }

        guard X.count == y.count else {
            throw ToolError.invalidArguments("X rows (\(X.count)) must match y length (\(y.count))")
        }

        for (i, row) in X.enumerated() {
            guard row.count == p else {
                throw ToolError.invalidArguments("X[\(i)] has \(row.count) predictors, expected \(p)")
            }
        }

        let names: [String]
        if let provided = predictorNames {
            guard provided.count == p else {
                throw ToolError.invalidArguments("predictorNames length (\(provided.count)) must match number of predictors (\(p))")
            }
            names = provided
        } else {
            names = (1...p).map { "X\($0)" }
        }

        // Run regression
        let result = try multipleLinearRegression(X: X, y: y, confidenceLevel: confidenceLevel)

        // Build equation string
        var equation = "y = \(formatNumber(result.intercept, decimals: 4))"
        for (i, coef) in result.coefficients.enumerated() {
            let sign = coef >= 0 ? " + " : " - "
            equation += "\(sign)\(formatNumber(abs(coef), decimals: 4))*\(names[i])"
        }

        // Build coefficients table using string interpolation (no C-string formatting)
        var table = "Variable         Coefficient    Std Error      t-stat     p-value   CI"
        table += "\n" + String(repeating: "-", count: 90)

        // Intercept row
        let intCI = result.confidenceIntervals[0]
        let intSig = significanceStars(result.pValues[0])
        table += "\n(Intercept)      \(formatNumber(result.intercept, decimals: 4))  \(formatNumber(result.standardErrors[0], decimals: 4))  \(formatNumber(result.tStatistics[0], decimals: 3))  \(formatPValue(result.pValues[0]))   [\(formatNumber(intCI.lower, decimals: 4)), \(formatNumber(intCI.upper, decimals: 4))] \(intSig)"

        // Coefficient rows
        for i in 0..<p {
            let ci = result.confidenceIntervals[i + 1]
            let sig = significanceStars(result.pValues[i + 1])
            table += "\n\(names[i])  \(formatNumber(result.coefficients[i], decimals: 4))  \(formatNumber(result.standardErrors[i + 1], decimals: 4))  \(formatNumber(result.tStatistics[i + 1], decimals: 3))  \(formatPValue(result.pValues[i + 1]))   [\(formatNumber(ci.lower, decimals: 4)), \(formatNumber(ci.upper, decimals: 4))] \(sig)"
        }

        table += "\n" + String(repeating: "-", count: 90)
        table += "\nSignif: *** p<0.001, ** p<0.01, * p<0.05, . p<0.1"

        // VIF section
        var vifSection = "\nVariance Inflation Factors (VIF):"
        for i in 0..<p {
            let flag: String
            if result.vif[i] >= 10 { flag = " *** HIGH" }
            else if result.vif[i] >= 5 { flag = " * moderate" }
            else { flag = "" }
            vifSection += "\n  \(names[i]): \(formatNumber(result.vif[i], decimals: 2))\(flag)"
        }

        var output = """
        Multiple Linear Regression Analysis
        ====================================

        Equation: \(equation)

        Coefficients (\(formatNumber(confidenceLevel * 100, decimals: 0))% CI):
        \(table)

        Model Summary:
          R-squared:          \(formatNumber(result.rSquared, decimals: 4)) (\(formatNumber(result.rSquared * 100, decimals: 1))% of variance explained)
          Adjusted R-squared: \(formatNumber(result.adjustedRSquared, decimals: 4))
          F-statistic:        \(formatNumber(result.fStatistic, decimals: 2)) (p-value: \(formatPValue(result.fStatisticPValue)))
          Residual Std Error: \(formatNumber(result.residualStandardError, decimals: 4))
          Observations:       \(result.n)
          Predictors:         \(result.p)
        \(vifSection)
        """

        // Predictions
        if let predictFor = try args.getDoubleMatrixIfPresent("predictFor") {
            output += "\n\nPredictions:"
            for (i, row) in predictFor.enumerated() {
                guard row.count == p else {
                    output += "\n  Row \(i+1): ERROR - expected \(p) predictors, got \(row.count)"
                    continue
                }
                var yHat = result.intercept
                for j in 0..<p {
                    yHat += result.coefficients[j] * row[j]
                }
                let xDesc = row.enumerated().map { "\(names[$0.0])=\(formatNumber($0.1, decimals: 1))" }.joined(separator: ", ")
                output += "\n  [\(xDesc)] -> y = \(formatNumber(yHat, decimals: 4))"
            }
        }

        return .success(text: output)
    }

    private func formatPValue(_ p: Double) -> String {
        if p < 0.0001 { return "<0.0001" }
        if p < 0.001 { return formatNumber(p, decimals: 4) }
        return formatNumber(p, decimals: 4)
    }

    private func significanceStars(_ p: Double) -> String {
        if p < 0.001 { return "***" }
        if p < 0.01 { return "**" }
        if p < 0.05 { return "*" }
        if p < 0.1 { return "." }
        return ""
    }
}

// MARK: - 3. Spearman's Correlation

/// Calculate Spearman's rank correlation coefficient (rho).
///
/// Exposed to clients as the `spearmans_correlation` tool.
public struct SpearmansCorrelationTool: MCPToolHandler, Sendable {
    /// The `spearmans_correlation` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "spearmans_correlation",
        description: """
        Calculate Spearman's rank correlation coefficient (rho).

        A non-parametric measure of rank correlation that assesses monotonic relationships.
        Unlike Pearson, it works well with:
        • Non-linear monotonic relationships
        • Ordinal data
        • Data with outliers

        Values range from -1 to 1:
        • 1 = Perfect monotonic increase
        • 0 = No monotonic relationship
        • -1 = Perfect monotonic decrease

        Example: Analyze relationship between customer satisfaction rankings and sales
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    /// Creates the `spearmans_correlation` handler.
    public init() {}

    /// Runs `spearmans_correlation` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 3 else {
            throw ToolError.invalidArguments("Need at least 3 data points for Spearman's correlation")
        }

        let rho = try spearmansRho(x, vs: y)

        let absRho = abs(rho)
        let strength = absRho > 0.7 ? "Strong" :
                      absRho > 0.4 ? "Moderate" :
                      absRho > 0.2 ? "Weak" : "Very weak"
        let direction = rho > 0 ? "positive" : "negative"

        let output = """
        Spearman's Rank Correlation Coefficient:
        • Spearman's rho (ρ): \(formatNumber(rho, decimals: 4))
        • N: \(x.count) data points

        Interpretation:
        • Strength: \(strength) \(direction) monotonic relationship
        • Type: Non-parametric (rank-based)

        \(rho > 0 ? "✓ Monotonic increase: higher ranks in X associate with higher ranks in Y" : "✗ Monotonic decrease: higher ranks in X associate with lower ranks in Y")

        Use Case:
        • Better than Pearson for non-linear monotonic relationships
        • Robust to outliers
        • Works with ordinal (ranked) data
        """

        return .success(text: output)
    }
}

// MARK: - 4. Calculate Confidence Interval

/// Calculate confidence interval for a population parameter based on sample data.
///
/// Exposed to clients as the `calculate_confidence_interval` tool.
public struct CalculateConfidenceIntervalTool: MCPToolHandler, Sendable {
    /// The `calculate_confidence_interval` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_confidence_interval",
        description: """
        Calculate confidence interval for a population parameter based on sample data.

        A confidence interval provides a range within which the true population parameter
        likely falls, with a specified level of confidence (e.g., 95%).

        Supports two modes:
        1. From raw data (automatically calculates mean and std dev)
        2. From summary statistics (mean, std dev, sample size)

        Example: Estimate the true average revenue with 95% confidence
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Sample data (use this OR use mean/stdDev/sampleSize)",
                    items: MCPSchemaItems(type: "number")
                ),
                "mean": MCPSchemaProperty(
                    type: "number",
                    description: "Sample mean (if not providing raw values)"
                ),
                "stdDev": MCPSchemaProperty(
                    type: "number",
                    description: "Sample standard deviation (if not providing raw values)"
                ),
                "sampleSize": MCPSchemaProperty(
                    type: "number",
                    description: "Sample size (if not providing raw values)"
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "Confidence level (e.g., 0.95 for 95% confidence, 0.90 for 90%, 0.99 for 99%). Default: 0.95"
                )
            ],
            required: []
        )
    )

    /// Creates the `calculate_confidence_interval` handler.
    public init() {}

    /// Runs `calculate_confidence_interval` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let confidenceLevel = args.getDoubleOptional("confidenceLevel") ?? 0.95

        guard confidenceLevel > 0 && confidenceLevel < 1 else {
            throw ToolError.invalidArguments("Confidence level must be between 0 and 1")
        }

        let meanValue: Double
        let stdDevValue: Double
        let n: Int

        // Check if using raw values or summary statistics
        if let values = try args.getDoubleArrayIfPresent("values") {
            guard !values.isEmpty else {
                throw ToolError.invalidArguments("Values array cannot be empty")
            }
            meanValue = mean(values)
            stdDevValue = stdDev(values, .sample)
            n = values.count
        } else {
            // Use summary statistics. These are required only on this branch — a caller who
            // supplied `values` must not supply them — so they are read optionally and
            // reported together, which also tells the caller exactly what is missing.
            guard let summaryMean = args.getDoubleOptional("mean"),
                  let summaryStdDev = args.getDoubleOptional("stdDev"),
                  let summarySize = args.getIntOptional("sampleSize") else {
                throw ToolError.invalidArguments(
                    "Provide either 'values', or all three of 'mean', 'stdDev', and 'sampleSize'")
            }
            meanValue = summaryMean
            stdDevValue = summaryStdDev
            n = summarySize

            guard n > 0 else {
                throw ToolError.invalidArguments("Sample size must be positive")
            }
            guard stdDevValue >= 0 else {
                throw ToolError.invalidArguments("Standard deviation cannot be negative")
            }
        }

        // Calculate confidence interval
        let ci = confidenceInterval(ci: confidenceLevel, values: Array(repeating: meanValue, count: n))

        let marginOfError = (ci.high - ci.low) / 2

        let output = """
        Confidence Interval:

        \(confidenceLevel.percent())% Confidence Interval: [\(formatNumber(ci.low, decimals: 4)), \(formatNumber(ci.high, decimals: 4))]

        Sample Statistics:
        • Mean: \(formatNumber(meanValue, decimals: 4))
        • Standard Deviation: \(formatNumber(stdDevValue, decimals: 4))
        • Sample Size: \(n)

        Margin of Error:
        • ± \(formatNumber(marginOfError, decimals: 4))

        Interpretation:
        We are \(confidenceLevel.percent())% confident that the true population
        parameter falls within the interval [\(formatNumber(ci.low, decimals: 2)), \(formatNumber(ci.high, decimals: 2))].
        """

        return .success(text: output)
    }
}

// MARK: - 5. Calculate Covariance

/// Calculate covariance between two datasets.
///
/// Exposed to clients as the `calculate_covariance` tool.
public struct CalculateCovarianceTool: MCPToolHandler, Sendable {
    /// The `calculate_covariance` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_covariance",
        description: """
        Calculate covariance between two datasets.

        Covariance measures how much two variables change together:
        • Positive: Variables tend to move in the same direction
        • Negative: Variables tend to move in opposite directions
        • Zero: No linear relationship

        Unlike correlation, covariance is not standardized, so its magnitude
        depends on the scale of the variables.

        Supports both sample and population covariance.

        Example: Measure how revenue and costs vary together
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset",
                    items: MCPSchemaItems(type: "number")
                ),
                "population": MCPSchemaProperty(
                    type: "string",
                    description: "Whether data represents 'sample' or 'population' (default: 'sample')",
                    enum: ["sample", "population"]
                )
            ],
            required: ["x", "y"]
        )
    )

    /// Creates the `calculate_covariance` handler.
    public init() {}

    /// Runs `calculate_covariance` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")
        let populationType = args.getStringOptional("population") ?? "sample"

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 data points to calculate covariance")
        }

        let population: Population = populationType == "population" ? .population : .sample
        let cov = covariance(x, y, population)

        // Calculate correlation for context
        let corr = try correlationCoefficient(x, y, population)

        let output = """
        Covariance Analysis:
        • Covariance: \(formatNumber(cov, decimals: 4))
        • Type: \(populationType == "population" ? "Population" : "Sample")
        • N: \(x.count) data points

        Related Metrics:
        • Correlation: \(formatNumber(corr, decimals: 4)) (standardized covariance)

        Interpretation:
        \(cov > 0 ? "✓ Positive covariance: variables tend to move together" : cov < 0 ? "✗ Negative covariance: variables tend to move in opposite directions" : "○ Zero covariance: no linear relationship")

        Note: Unlike correlation, covariance is not bounded and depends on
        the scale of the variables. Use correlation for standardized comparison.
        """

        return .success(text: output)
    }
}

// MARK: - 6. Calculate Z-Score (for correlation)

/// Calculate z-score for testing correlation significance.
///
/// Exposed to clients as the `calculate_z_score` tool.
public struct CalculateZScoreTool: MCPToolHandler, Sendable {
    /// The `calculate_z_score` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_z_score",
        description: """
        Calculate z-score for testing correlation significance.

        The z-score quantifies how many standard deviations a correlation coefficient
        is from zero, helping determine if a correlation is statistically significant.

        Uses Spearman's rank correlation and Fisher's Z-transformation.

        Interpretation:
        • |z| > 2.576: Significant at 99% confidence level
        • |z| > 1.96: Significant at 95% confidence level
        • |z| > 1.645: Significant at 90% confidence level

        Example: Test if correlation between variables is statistically significant
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "x": MCPSchemaProperty(
                    type: "array",
                    description: "First dataset (independent variable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "y": MCPSchemaProperty(
                    type: "array",
                    description: "Second dataset (dependent variable)",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["x", "y"]
        )
    )

    /// Creates the `calculate_z_score` handler.
    public init() {}

    /// Runs `calculate_z_score` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let x = try args.getDoubleArray("x")
        let y = try args.getDoubleArray("y")

        guard x.count == y.count else {
            throw ToolError.invalidArguments("Arrays x and y must have the same length")
        }

        guard x.count >= 3 else {
            throw ToolError.invalidArguments("Need at least 3 data points for z-score calculation")
        }

        let z = try zScore(x, vs: y)
        let absZ = abs(z)

        let significance = absZ > 2.576 ? "Highly significant (99% confidence)" :
                          absZ > 1.96 ? "Significant (95% confidence)" :
                          absZ > 1.645 ? "Marginally significant (90% confidence)" :
                          "Not significant"

        let output = """
        Z-Score for Correlation Significance:

        • Z-Score: \(formatNumber(z, decimals: 4))
        • |Z-Score|: \(formatNumber(absZ, decimals: 4))
        • N: \(x.count) data points

        Significance:
        • Result: \(significance)

        Critical Values:
        • 90% confidence: |z| > 1.645 \(absZ > 1.645 ? "✓" : "✗")
        • 95% confidence: |z| > 1.96 \(absZ > 1.96 ? "✓" : "✗")
        • 99% confidence: |z| > 2.576 \(absZ > 2.576 ? "✓" : "✗")

        Interpretation:
        \(absZ > 1.96 ? "The correlation is statistically significant - unlikely to be due to chance." : "The correlation is not statistically significant at the 95% level.")
        """

        return .success(text: output)
    }
}

// MARK: - 7. Descriptive Statistics (Extended)

/// Calculate comprehensive descriptive statistics for a dataset.
///
/// Exposed to clients as the `descriptive_stats_extended` tool.
public struct DescriptiveStatsExtendedTool: MCPToolHandler, Sendable {
    /// The `descriptive_stats_extended` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "descriptive_stats_extended",
        description: """
        Calculate comprehensive descriptive statistics for a dataset.

        Provides:
        • Central Tendency: mean, median
        • Dispersion: std dev, variance, range, min, max
        • Shape: skewness (asymmetry measure)
        • Percentiles: 25th, 50th, 75th (quartiles)
        • Interquartile Range (IQR)

        Skewness interpretation:
        • > 0: Right-skewed (long tail on right)
        • = 0: Symmetric
        • < 0: Left-skewed (long tail on left)

        Example: Comprehensive analysis of sales data distribution
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Dataset to analyze",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["values"]
        )
    )

    /// Creates the `descriptive_stats_extended` handler.
    public init() {}

    /// Runs `descriptive_stats_extended` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Values array cannot be empty")
        }

        // Use SimulationStatistics for comprehensive stats
        let stats = SimulationStatistics(values: values)
        let percentiles = try Percentiles(values: values)

        let range = stats.max - stats.min

        // Interpret skewness
        let skewnessInterpretation: String
        if abs(stats.skewness) < 0.5 {
            skewnessInterpretation = "Approximately symmetric"
        } else if stats.skewness > 0 {
            skewnessInterpretation = "Right-skewed (tail extends right)"
        } else {
            skewnessInterpretation = "Left-skewed (tail extends left)"
        }

        let output = """
        Comprehensive Descriptive Statistics:

        Central Tendency:
        • Mean: \(formatNumber(stats.mean, decimals: 4))
        • Median: \(formatNumber(stats.median, decimals: 4))

        Dispersion:
        • Standard Deviation: \(formatNumber(stats.stdDev, decimals: 4))
        • Variance: \(formatNumber(stats.variance, decimals: 4))
        • Range: \(formatNumber(range, decimals: 4))
        • Minimum: \(formatNumber(stats.min, decimals: 4))
        • Maximum: \(formatNumber(stats.max, decimals: 4))

        Distribution Shape:
        • Skewness: \(formatNumber(stats.skewness, decimals: 4)) (\(skewnessInterpretation))

        Percentiles (Quartiles):
        • Q1 (25th percentile): \(formatNumber(percentiles.p25, decimals: 4))
        • Q2 (50th percentile): \(formatNumber(percentiles.p50, decimals: 4))
        • Q3 (75th percentile): \(formatNumber(percentiles.p75, decimals: 4))
        • Interquartile Range (IQR): \(formatNumber(percentiles.interquartileRange, decimals: 4))

        Additional Percentiles:
        • 5th: \(formatNumber(percentiles.p5, decimals: 4))
        • 10th: \(formatNumber(percentiles.p10, decimals: 4))
        • 90th: \(formatNumber(percentiles.p90, decimals: 4))
        • 95th: \(formatNumber(percentiles.p95, decimals: 4))

        Sample Size:
        • N: \(values.count) observations

        Interpretation:
        \(abs(stats.mean - stats.median) < stats.stdDev * 0.1 ? "✓ Mean ≈ Median suggests symmetric distribution" : "✗ Mean ≠ Median suggests skewed distribution")
        """

        return .success(text: output)
    }
}

// MARK: - Concordance Analysis

/// Kendall's W coefficient of concordance — agreement among several judges ranking the same
/// items.
///
/// Accepts three shapes of the same question, because callers rarely hold the data in the form
/// the statistic wants: a full ranking matrix, pre-computed rank sums with the judge and item
/// counts, or a matrix with gaps handled by the Brueckl (2011) pairwise approach.
public struct ConcordanceAnalysisTool: MCPToolHandler, Sendable {
    /// The tool's MCP declaration: name, description and input schema.
    public let tool = MCPTool(
        name: "concordance_analysis",
        description: """
        Calculate Kendall's W coefficient of concordance with full statistical analysis.

        Measures agreement among multiple judges ranking multiple items.
        Returns W (uncorrected and tie-corrected), chi-square, Friedman statistic,
        p-value, F-statistic, and degrees of freedom.

        Supports three modes:
        1. Full ranking matrix (rankings parameter)
        2. Pre-computed rank sums (rank_sums + judges + items)
        3. Missing data via Brueckl 2011 pairwise approach (rankings + has_missing)
        
        Optionally runs a permutation test for non-parametric p-value.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "rankings": MCPSchemaProperty(
                    type: "array",
                    description: "2D array of rankings: rows = judges, columns = items. Each cell is the rank assigned by that judge to that item.",
                    items: MCPSchemaItems(type: "array")
                ),
                "rank_sums": MCPSchemaProperty(
                    type: "array",
                    description: "Pre-computed rank sums for each item (when individual rankings unavailable)",
                    items: MCPSchemaItems(type: "number")
                ),
                "judges": MCPSchemaProperty(
                    type: "number",
                    description: "Number of judges (required with rank_sums)"
                ),
                "items": MCPSchemaProperty(
                    type: "number",
                    description: "Number of items (required with rank_sums)"
                ),
                "has_missing": MCPSchemaProperty(
                    type: "boolean",
                    description: "If true, treat 0 values in rankings as missing data and use Brueckl 2011 pairwise Spearman approach"
                ),
                "permutation_test": MCPSchemaProperty(
                    type: "boolean",
                    description: "If true, also run a permutation test for p-value"
                ),
                "permutations": MCPSchemaProperty(
                    type: "number",
                    description: "Number of permutations for permutation test (default: 10000)"
                )
            ]
        )
    )

    /// Creates the tool.
    public init() {}

    /// Runs a concordance analysis over whichever input shape the caller supplied.
    ///
    /// - Parameter arguments: Either `rankings`, or `rank_sums` with `judges` and `items`.
    /// - Returns: W, chi-square, the Friedman statistic, p-value, F and degrees of freedom.
    /// - Throws: `ToolError.invalidArguments` if neither input shape is present or an
    ///   argument is malformed.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let hasMissing = args.getBoolOptional("has_missing") ?? false
        let runPermutation = args.getBoolOptional("permutation_test") ?? false
        let numPermutations = args.getIntOptional("permutations") ?? 10000

        let result: ConcordanceResult<Double>

        // Optional accessors rather than throwing ones behind `hasKey`: absence selects the
        // mode, so it is not an error, and a throwing getter would claim otherwise.
        if let rankings = try args.getDoubleMatrixOptional("rankings") {
            if hasMissing {
                let optionalRankings: [[Double?]] = rankings.map { row in
                    row.map { $0 == 0 ? nil : Optional($0) }
                }
                result = try concordanceAnalysisNA(optionalRankings)
            } else {
                result = try concordanceAnalysis(rankings)
            }
        } else if let rankSums = try args.getDoubleArrayOptional("rank_sums") {
            guard let judges = args.getIntOptional("judges"),
                let items = args.getIntOptional("items")
            else {
                throw ToolError.invalidArguments(
                    "'rank_sums' also requires 'judges' and 'items'")
            }
            result = try concordanceAnalysisFromRankSums(rankSums: rankSums, judges: judges, items: items)
        } else {
            throw ToolError.invalidArguments("Provide either 'rankings' (2D array) or 'rank_sums' + 'judges' + 'items'")
        }

        var output = """
        Concordance Analysis (Kendall's W):

        Agreement:
        • W (uncorrected): \(formatNumber(result.w, decimals: 6))
        • W (tie-corrected): \(formatNumber(result.wCorrected, decimals: 6))

        Significance:
        • Chi-square: \(formatNumber(result.chiSquare, decimals: 4))
        • Friedman: \(formatNumber(result.friedman, decimals: 4))
        • F-statistic: \(formatNumber(result.fStatistic, decimals: 4))
        • Degrees of freedom: \(result.degreesOfFreedom)
        • p-value: \(formatNumber(result.pValue, decimals: 6))

        Design:
        • Judges: \(result.judges)
        • Items: \(result.items)
        • Tie correction: \(formatNumber(result.totalTieCorrection, decimals: 4))
        """

        let wVal = result.wCorrected
        let interpretation = wVal >= 0.9 ? "Very strong to perfect" :
                            wVal >= 0.7 ? "Strong" :
                            wVal >= 0.5 ? "Good" :
                            wVal >= 0.3 ? "Moderate" :
                            wVal >= 0.1 ? "Weak" : "No"
        output += "\n\n        Interpretation: \(interpretation) agreement (W = \(formatNumber(wVal, decimals: 4)))"

        if result.pValue < 0.001 {
            output += "\n        ✓ Highly significant (p < 0.001)"
        } else if result.pValue < 0.01 {
            output += "\n        ✓ Very significant (p < 0.01)"
        } else if result.pValue < 0.05 {
            output += "\n        ✓ Significant (p < 0.05)"
        } else {
            output += "\n        ✗ Not significant at α = 0.05 (p = \(formatNumber(result.pValue, decimals: 4)))"
        }

        if runPermutation, !hasMissing,
            let rankings = try args.getDoubleMatrixOptional("rankings") {
            let permResult = try concordancePermutationTest(rankings, permutations: numPermutations)
            output += """

            
            Permutation Test (\(numPermutations) permutations):
            • W: \(formatNumber(permResult.w, decimals: 6))
            • p-value: \(formatNumber(permResult.pValue, decimals: 6))
            """
        }

        return .success(text: output)
    }
}
