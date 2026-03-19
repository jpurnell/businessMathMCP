//
//  TrendForecastingTools.swift
//  BusinessMath MCP Server
//
//  Trend analysis and forecasting tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all trend forecasting tools
public func getTrendForecastingTools() -> [any MCPToolHandler] {
    return [
        LinearTrendForecastTool(),
        ExponentialTrendForecastTool(),
        LogisticTrendForecastTool(),
        TimeSeriesDecomposeTool(),
        HoltWintersForecastTool(),
        DetectAnomaliesTool()
    ]
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

// MARK: - Linear Trend Forecast

public struct LinearTrendForecastTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "forecast_linear_trend",
        description: """
        Forecast future values using linear trend analysis (straight-line projection).

        Fits a straight line to historical data and projects it forward. Best for
        data with steady, constant growth or decline.

        Formula: y = mx + b (where m = slope, b = intercept)

        Use Cases:
        • Revenue forecasting with stable growth
        • Headcount planning
        • Linear cost projections
        • Short to medium-term forecasts

        Example - Steady Revenue Growth:
        Historical: [100, 105, 110, 115]
        Forecast 3 periods: [120, 125, 130]

        Best For: Mature businesses with predictable, steady growth patterns.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values (at least 2 values required)",
                    items: MCPSchemaItems(type: "number")
                ),
                "forecastPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to forecast into the future"
                )
            ],
            required: ["historicalValues", "forecastPeriods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let historicalValues = try args.getDoubleArray("historicalValues")
        let forecastPeriods = try args.getInt("forecastPeriods")

        guard historicalValues.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 historical values")
        }

        guard forecastPeriods > 0 && forecastPeriods <= 50 else {
            throw ToolError.invalidArguments("Forecast periods must be between 1 and 50")
        }

        // Fit linear model
        let xValues = (0..<historicalValues.count).map { Double($0) }
        let slopeValue = try slope(xValues, historicalValues)
        let interceptValue = try intercept(xValues, historicalValues)

        // Project forward
        var forecastValues: [Double] = []
        let startIndex = historicalValues.count
        for i in 0..<forecastPeriods {
            let x = Double(startIndex + i)
            let y = slopeValue * x + interceptValue
            forecastValues.append(y)
        }

        let output = """
        Linear Trend Forecast

        Historical Data (\(historicalValues.count) periods):
        \(historicalValues.enumerated().map { "  Period \($0): \(formatNumber($1))" }.joined(separator: "\n"))

        Linear Model:
        • Slope: \(formatNumber(slopeValue)) per period
        • Intercept: \(formatNumber(interceptValue))
        • Formula: y = \(formatNumber(slopeValue))x + \(formatNumber(interceptValue))

        Forecast (\(forecastPeriods) periods):
        \(forecastValues.enumerated().map { i, val in
            "  Period \(historicalValues.count + i): \(formatNumber(val))"
        }.joined(separator: "\n"))

        Interpretation:
        • Average change per period: \(formatNumber(slopeValue))
        • \(slopeValue > 0 ? "Growing" : "Declining") at constant rate
        • Simple extrapolation of historical trend

        Best used for: Stable, mature businesses with consistent growth patterns.
        """

        return .success(text: output)
    }
}

// MARK: - Exponential Trend Forecast

public struct ExponentialTrendForecastTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "forecast_exponential_trend",
        description: """
        Forecast future values using exponential trend analysis (accelerating/decelerating growth).

        Fits an exponential curve to historical data. Best for compounding growth
        or decline patterns.

        Formula: y = a × e^(bx)

        Use Cases:
        • Viral product growth
        • Investment returns
        • Early-stage company expansion
        • Technology adoption

        Example - Accelerating Growth:
        Historical: [100, 120, 144, 173]
        Forecast: Continues exponential pattern

        Best For: High-growth scenarios with compounding effects.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values (must be positive, at least 2 values)",
                    items: MCPSchemaItems(type: "number")
                ),
                "forecastPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to forecast"
                )
            ],
            required: ["historicalValues", "forecastPeriods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let historicalValues = try args.getDoubleArray("historicalValues")
        let forecastPeriods = try args.getInt("forecastPeriods")

        guard historicalValues.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 historical values")
        }

        guard historicalValues.allSatisfy({ $0 > 0 }) else {
            throw ToolError.invalidArguments("All values must be positive for exponential trend")
        }

        // Log-transform values
        let logValues = historicalValues.map { log($0) }
        let xValues = (0..<historicalValues.count).map { Double($0) }

        // Fit linear model to log-transformed data
        let logSlope = try slope(xValues, logValues)
        let logIntercept = try intercept(xValues, logValues)

        // Project forward
        var forecastValues: [Double] = []
        let startIndex = historicalValues.count
        for i in 0..<forecastPeriods {
            let x = Double(startIndex + i)
            let logY = logSlope * x + logIntercept
            let y = exp(logY)
            forecastValues.append(y)
        }

        // Calculate growth rate
        let growthRate = exp(logSlope) - 1.0

        let output = """
        Exponential Trend Forecast

        Historical Data (\(historicalValues.count) periods):
        \(historicalValues.enumerated().map { "  Period \($0): \(formatNumber($1))" }.joined(separator: "\n"))

        Exponential Model:
        • Effective growth rate: \(formatNumber(growthRate * 100))% per period
        • Compounding pattern detected
        • Formula: y = \(formatNumber(exp(logIntercept))) × e^(\(formatNumber(logSlope))x)

        Forecast (\(forecastPeriods) periods):
        \(forecastValues.enumerated().map { i, val in
            "  Period \(historicalValues.count + i): \(formatNumber(val))"
        }.joined(separator: "\n"))

        Interpretation:
        • \(growthRate > 0 ? "Accelerating growth" : "Decelerating decline")
        • Compounds at \(formatNumber(growthRate * 100))% per period
        • Exponential extrapolation of historical pattern

        Best used for: High-growth scenarios, viral products, early-stage expansion.
        """

        return .success(text: output)
    }
}

// MARK: - Logistic Trend Forecast

public struct LogisticTrendForecastTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "forecast_logistic_trend",
        description: """
        Forecast future values using logistic trend (S-curve with saturation).

        Fits an S-curve that starts with exponential growth but approaches a maximum
        capacity. Best for market penetration and adoption scenarios.

        Formula: y = L / (1 + e^(-k(x-x0)))

        Use Cases:
        • Market penetration forecasts
        • Product adoption curves
        • Population growth with limits
        • Technology diffusion

        Example - Market Penetration:
        Early: Slow growth
        Middle: Rapid acceleration
        Later: Saturation near maximum

        Best For: Growth scenarios with natural capacity limits.

        Note: Requires capacity parameter (maximum achievable value).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values (at least 3 values)",
                    items: MCPSchemaItems(type: "number")
                ),
                "capacity": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum capacity (L parameter) - the saturation point"
                ),
                "forecastPeriods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to forecast"
                )
            ],
            required: ["historicalValues", "capacity", "forecastPeriods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let historicalValues = try args.getDoubleArray("historicalValues")
        let capacity = try args.getDouble("capacity")
        let forecastPeriods = try args.getInt("forecastPeriods")

        guard historicalValues.count >= 3 else {
            throw ToolError.invalidArguments("Need at least 3 historical values for logistic trend")
        }

        // Simple logistic approximation
        // Using capacity and fitting growth rate and inflection point
//        let midpoint = capacity / 2.0
        let n = historicalValues.count

        // Estimate growth rate from early growth
        let earlyGrowth = (historicalValues[min(2, n-1)] - historicalValues[0]) / historicalValues[0]
        let k = earlyGrowth / 2.0 // Growth rate parameter

        // Estimate inflection point
        let x0 = Double(n) / 2.0

        // Project forward
        var forecastValues: [Double] = []
        let startIndex = historicalValues.count
        for i in 0..<forecastPeriods {
            let x = Double(startIndex + i)
            let y = capacity / (1.0 + exp(-k * (x - x0)))
            forecastValues.append(y)
        }

        // Calculate saturation percentage
        let currentValue = historicalValues.last ?? 0
        let saturationPct = (currentValue / capacity) * 100

        let output = """
        Logistic Trend Forecast (S-Curve)

        Historical Data (\(historicalValues.count) periods):
        \(historicalValues.enumerated().map { "  Period \($0): \(formatNumber($1))" }.joined(separator: "\n"))

        Logistic Model:
        • Capacity (Maximum): \(formatNumber(capacity))
        • Current saturation: \(formatNumber(saturationPct))%
        • Growth rate parameter: \(formatNumber(k))
        • Inflection point: ~Period \(formatNumber(x0))

        Forecast (\(forecastPeriods) periods):
        \(forecastValues.enumerated().map { i, val in
            let pct = (val / capacity) * 100
            return "  Period \(historicalValues.count + i): \(formatNumber(val)) (\(formatNumber(pct))% of capacity)"
        }.joined(separator: "\n"))

        Interpretation:
        • S-curve growth approaching maximum capacity
        • \(saturationPct < 20 ? "Early stage - growth will accelerate" :
             saturationPct < 80 ? "Mid-stage - rapid growth phase" :
             "Late stage - approaching saturation")
        • Forecast asymptotically approaches \(formatNumber(capacity))

        Best used for: Market penetration, adoption curves, scenarios with natural limits.
        """

        return .success(text: output)
    }
}

// MARK: - Time Series Decomposition

public struct TimeSeriesDecomposeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "decompose_time_series",
        description: """
        Decompose time series into Trend, Seasonal, and Residual components.

        Separates a time series into three components:
        • Trend: Long-term direction (increasing, decreasing, or stable)
        • Seasonal: Repeating patterns within each cycle
        • Residual: Random fluctuations (noise)

        Methods:
        • Additive: Value = Trend + Seasonal + Residual (constant seasonal variation)
        • Multiplicative: Value = Trend × Seasonal × Residual (proportional seasonal variation)

        Use Cases:
        • Understanding data patterns
        • Seasonal adjustment
        • Forecasting preparation
        • Anomaly detection

        Example - Monthly Sales:
        Decompose into:
        • Trend: Growing $5K/month
        • Seasonal: December spike (+30%), February dip (-15%)
        • Residual: Random noise

        Best For: Data with clear seasonal patterns (monthly, quarterly cycles).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Array of time series values",
                    items: MCPSchemaItems(type: "array")
                ),
                "periodicity": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods in one seasonal cycle (e.g., 12 for monthly data with annual seasonality, 4 for quarterly)"
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Decomposition method: 'additive' (default) or 'multiplicative'"
                )
            ],
            required: ["values", "periodicity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")
        let periodicity = try args.getInt("periodicity")
        let methodStr = args.getStringOptional("method") ?? "additive"

        guard values.count >= periodicity * 2 else {
            throw ToolError.invalidArguments("Need at least 2 full cycles of data (minimum \(periodicity * 2) values)")
        }

        guard periodicity >= 2 && periodicity <= 52 else {
            throw ToolError.invalidArguments("Periodicity must be between 2 and 52")
        }

        // Simple decomposition
        // 1. Calculate trend using moving average
        var trend: [Double] = []
        let halfWindow = periodicity / 2

        for i in 0..<values.count {
            let start = max(0, i - halfWindow)
            let end = min(values.count, i + halfWindow + 1)
            let window = values[start..<end]
            let avg = window.reduce(0.0, +) / Double(window.count)
            trend.append(avg)
        }

        // 2. Calculate detrended values
        let detrended: [Double]
        let isMultiplicative = methodStr.lowercased() == "multiplicative"

        if isMultiplicative {
            detrended = zip(values, trend).map { $1 > 0 ? $0 / $1 : 1.0 }
        } else {
            detrended = zip(values, trend).map { $0 - $1 }
        }

        // 3. Calculate seasonal indices
        var seasonalSums = Array(repeating: 0.0, count: periodicity)
        var seasonalCounts = Array(repeating: 0, count: periodicity)

        for (i, value) in detrended.enumerated() {
            let seasonIndex = i % periodicity
            seasonalSums[seasonIndex] += value
            seasonalCounts[seasonIndex] += 1
        }

        let seasonalIndices = zip(seasonalSums, seasonalCounts).map { $1 > 0 ? $0 / Double($1) : 0.0 }

        // 4. Calculate residuals
        var residuals: [Double] = []
        for i in 0..<values.count {
            let seasonIndex = i % periodicity
            let seasonal = seasonalIndices[seasonIndex]

            let residual: Double
            if isMultiplicative {
                residual = values[i] / (trend[i] * seasonal)
            } else {
                residual = values[i] - trend[i] - seasonal
            }
            residuals.append(residual)
        }

        let output = """
        Time Series Decomposition

        Data: \(values.count) values, Periodicity: \(periodicity), Method: \(methodStr.capitalized)

        Original Series (first 10):
        \(values.prefix(10).enumerated().map { "  [\($0)]: \(formatNumber($1))" }.joined(separator: "\n"))

        Trend Component (first 10):
        \(trend.prefix(10).enumerated().map { "  [\($0)]: \(formatNumber($1))" }.joined(separator: "\n"))

        Seasonal Indices (one full cycle):
        \(seasonalIndices.enumerated().map { i, val in
            "  Period \(i % periodicity + 1): \(formatNumber(val))\(isMultiplicative ? "x" : "")"
        }.joined(separator: "\n"))

        Residual Component (first 10):
        \(residuals.prefix(10).enumerated().map { "  [\($0)]: \(formatNumber($1))" }.joined(separator: "\n"))

        Analysis:
        • Trend: \(trend.last! > trend.first! ? "Increasing" : trend.last! < trend.first! ? "Decreasing" : "Stable")
        • Seasonality: \(periodicity)-period cycle detected
        • Method: \(isMultiplicative ? "Multiplicative (proportional seasonality)" : "Additive (constant seasonality)")

        Interpretation:
        \(isMultiplicative ? """
        • Original = Trend × Seasonal × Residual
        • Seasonal variation is proportional to trend level
        """ : """
        • Original = Trend + Seasonal + Residual
        • Seasonal variation is constant regardless of trend level
        """)

        Use the seasonal indices to:
        • Seasonally adjust data (remove seasonal component)
        • Improve forecasts by adding seasonality back
        • Understand recurring patterns
        """

        return .success(text: output)
    }
}

// MARK: - Holt-Winters Forecast

public struct HoltWintersForecastTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "holt_winters_forecast",
        description: """
        Forecast future values using Holt-Winters triple exponential smoothing.

        Captures level, trend, AND seasonality — the standard production forecasting
        method for time series with recurring patterns.

        Three smoothing parameters:
        • α (alpha): Level smoothing (0-1)
        • β (beta): Trend smoothing (0-1)
        • γ (gamma): Seasonal smoothing (0-1)

        Use Cases:
        • Quarterly/monthly revenue forecasting with seasonal patterns
        • Demand planning with cyclical variation
        • Inventory forecasting
        • Any time series with trend + seasonality

        Example - Quarterly Sales:
        Historical: [110, 120, 95, 90, 115, 125, 100, 95, 120, 130, 105, 100]
        seasonalPeriods: 4
        Forecast: Next 4 quarters with seasonal pattern preserved

        Requires at least 2 full seasonal cycles of data (2 × seasonalPeriods).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Historical time series values (at least 2 × seasonalPeriods required)",
                    items: MCPSchemaItems(type: "number")
                ),
                "seasonalPeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Length of one seasonal cycle (e.g., 4 for quarterly, 12 for monthly)"
                ),
                "forecastPeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of periods to forecast"
                ),
                "alpha": MCPSchemaProperty(
                    type: "number",
                    description: "Level smoothing parameter (0-1, default 0.2)"
                ),
                "beta": MCPSchemaProperty(
                    type: "number",
                    description: "Trend smoothing parameter (0-1, default 0.1)"
                ),
                "gamma": MCPSchemaProperty(
                    type: "number",
                    description: "Seasonal smoothing parameter (0-1, default 0.1)"
                ),
                "confidenceLevel": MCPSchemaProperty(
                    type: "number",
                    description: "If provided, includes confidence intervals (e.g., 0.95 for 95%)"
                )
            ],
            required: ["values", "seasonalPeriods", "forecastPeriods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")
        let seasonalPeriods = try args.getInt("seasonalPeriods")
        let forecastPeriods = try args.getInt("forecastPeriods")
        let alpha = args.getDoubleOptional("alpha") ?? 0.2
        let beta = args.getDoubleOptional("beta") ?? 0.1
        let gamma = args.getDoubleOptional("gamma") ?? 0.1
        let confidenceLevel = args.getDoubleOptional("confidenceLevel")

        guard seasonalPeriods >= 2 else {
            throw ToolError.invalidArguments("seasonalPeriods must be at least 2")
        }

        guard forecastPeriods > 0 else {
            throw ToolError.invalidArguments("forecastPeriods must be positive")
        }

        guard alpha >= 0 && alpha <= 1 && beta >= 0 && beta <= 1 && gamma >= 0 && gamma <= 1 else {
            throw ToolError.invalidArguments("Smoothing parameters (alpha, beta, gamma) must be between 0 and 1")
        }

        let requiredValues = seasonalPeriods * 2
        guard values.count >= requiredValues else {
            throw ToolError.invalidArguments(
                "Need at least \(requiredValues) values (2 × seasonalPeriods=\(seasonalPeriods)), got \(values.count)"
            )
        }

        // Train the model
        var model = HoltWintersModel<Double>(
            alpha: alpha, beta: beta, gamma: gamma, seasonalPeriods: seasonalPeriods
        )
        try model.train(values: values)
        let forecastValues = model.predictValues(periods: forecastPeriods)

        var output = """
        Holt-Winters Forecast (Triple Exponential Smoothing)

        Parameters:
        • Alpha (level): \(formatNumber(alpha))
        • Beta (trend): \(formatNumber(beta))
        • Gamma (seasonal): \(formatNumber(gamma))
        • Seasonal periods: \(seasonalPeriods)
        • Historical data points: \(values.count)

        Forecast (\(forecastPeriods) periods):
        \(forecastValues.enumerated().map { i, val in
            "  Period \(values.count + i + 1): \(formatNumber(val))"
        }.joined(separator: "\n"))
        """

        // Add confidence intervals if requested
        if let cl = confidenceLevel, cl > 0 && cl < 1 {
            // Build a TimeSeries for the confidence interval method
            let periods = (0..<values.count).map { Period.year($0) }
            let ts = TimeSeries(periods: periods, values: values)

            var ciModel = HoltWintersModel<Double>(
                alpha: alpha, beta: beta, gamma: gamma, seasonalPeriods: seasonalPeriods
            )
            try ciModel.train(on: ts)
            let ciResult = try ciModel.predictWithConfidence(
                periods: forecastPeriods, confidenceLevel: cl
            )

            let lowerValues = ciResult.lowerBound.valuesArray
            let upperValues = ciResult.upperBound.valuesArray

            output += """


        Confidence Intervals (\(formatNumber(cl * 100))%):
        \(forecastValues.enumerated().map { i, val in
            let lower = i < lowerValues.count ? formatNumber(lowerValues[i]) : "N/A"
            let upper = i < upperValues.count ? formatNumber(upperValues[i]) : "N/A"
            return "  Period \(values.count + i + 1): \(formatNumber(val))  [Lower: \(lower), Upper: \(upper)]"
        }.joined(separator: "\n"))
        """
        }

        output += """


        Interpretation:
        • Holt-Winters captures level, trend, and seasonal components
        • \(forecastValues.count >= 2 && forecastValues.last.map({ $0 > forecastValues[0] }) == true ? "Upward trend detected" : "Stable or downward trend")
        • Seasonal pattern from \(seasonalPeriods)-period cycle preserved in forecast

        Best used for: Data with both trend and seasonal patterns (quarterly sales, monthly traffic).
        """

        return .success(text: output)
    }
}

// MARK: - Anomaly Detection

public struct DetectAnomaliesTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "detect_anomalies",
        description: """
        Detect anomalies in time series data using rolling z-score method.

        Identifies values that deviate significantly from the local mean within a
        rolling window. Flags anomalies with severity levels based on z-score magnitude.

        Severity Levels:
        • Mild: 2-3 standard deviations from mean
        • Moderate: 3-4 standard deviations
        • Severe: >4 standard deviations

        Use Cases:
        • Revenue/expense spike detection
        • Fraud detection in transaction data
        • Quality control monitoring
        • Server metrics alerting

        Example:
        values: [100, 102, 98, 101, 150, 99, 103, 97, 200, 101]
        windowSize: 5, threshold: 2.0
        → Anomalies at indices 4 (150) and 8 (200)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "values": MCPSchemaProperty(
                    type: "array",
                    description: "Time series values to analyze",
                    items: MCPSchemaItems(type: "number")
                ),
                "windowSize": MCPSchemaProperty(
                    type: "integer",
                    description: "Rolling window size for z-score calculation"
                ),
                "threshold": MCPSchemaProperty(
                    type: "number",
                    description: "Z-score threshold for flagging anomalies (default 2.0)"
                )
            ],
            required: ["values", "windowSize"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let values = try args.getDoubleArray("values")
        let windowSize = try args.getInt("windowSize")
        let threshold = args.getDoubleOptional("threshold") ?? 2.0

        guard values.count > 0 else {
            throw ToolError.invalidArguments("values array must not be empty")
        }

        guard windowSize >= 2 else {
            throw ToolError.invalidArguments("windowSize must be at least 2")
        }

        // Build a TimeSeries with simple period labels
        let periods = (0..<values.count).map { Period.year(2000 + $0) }
        let ts = TimeSeries(periods: periods, values: values)

        // Run anomaly detection
        let detector = ZScoreAnomalyDetector<Double>(windowSize: windowSize)
        let anomalies = detector.detect(in: ts, threshold: threshold)

        if anomalies.isEmpty {
            let output = """
            Anomaly Detection Results

            Parameters:
            • Window size: \(windowSize)
            • Threshold: \(formatNumber(threshold)) standard deviations
            • Data points: \(values.count)

            No anomalies detected. All values are within \(formatNumber(threshold)) standard
            deviations of the rolling mean.

            0 anomalies found in \(values.count) data points.
            """
            return .success(text: output)
        }

        let output = """
        Anomaly Detection Results

        Parameters:
        • Window size: \(windowSize)
        • Threshold: \(formatNumber(threshold)) standard deviations
        • Data points: \(values.count)

        Detected \(anomalies.count) anomal\(anomalies.count == 1 ? "y" : "ies"):
        \(anomalies.enumerated().map { i, anomaly in
            let idx = periods.firstIndex(of: anomaly.period).map { String($0) } ?? "?"
            return """
              \(i + 1). Index \(idx): Value = \(formatNumber(Double(anomaly.value)))
                 Expected: \(formatNumber(Double(anomaly.expectedValue)))
                 Z-Score: \(formatNumber(Double(anomaly.deviationScore)))
                 Severity: \(anomaly.severity.rawValue.capitalized)
            """
        }.joined(separator: "\n"))

        Summary:
        • \(anomalies.filter { $0.severity == .severe }.count) severe anomalies
        • \(anomalies.filter { $0.severity == .moderate }.count) moderate anomalies
        • \(anomalies.filter { $0.severity == .mild }.count) mild anomalies

        Interpretation:
        • Severe: >4σ — likely data error or extreme event
        • Moderate: 3-4σ — unusual, warrants investigation
        • Mild: \(formatNumber(threshold))-3σ — notable but within broader range
        """

        return .success(text: output)
    }
}
