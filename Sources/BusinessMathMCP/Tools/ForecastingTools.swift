import Foundation
import MCP
import SwiftMCPServer
import BusinessMath

// MARK: - Fit Linear Trend Tool

/// Fit a linear trend model to time series data. Linear trends assume constant rate of change (straight line). Returns slope, intercept, and R-squared.
///
/// Exposed to clients as the `fit_linear_trend` tool.
public struct FitLinearTrendTool: MCPToolHandler, Sendable {
    /// The `fit_linear_trend` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "fit_linear_trend",
        description: "Fit a linear trend model to time series data. Linear trends assume constant rate of change (straight line). Returns slope, intercept, and R-squared.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data with periods and values",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["data"]
        )
    )

    /// Creates the `fit_linear_trend` handler.
    public init() {}

    /// Runs `fit_linear_trend` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")

        var model = LinearTrend<Double>()
        try model.fit(to: ts)

        // Project one period to demonstrate the fitted model
		// A failed projection used to become 0 here, which the report then presented as
		// the next value — a real number the model never produced. It propagates now.
		let sampleProjection = try model.project(periods: 1)
		let nextValue = sampleProjection?.valuesArray.first ?? 0
        let lastValue = ts.valuesArray.last ?? 0
        let periodChange = nextValue - lastValue
        
        // Format change with explicit sign
        let changeSign = periodChange >= 0 ? "+" : ""
        let changeFormatted = "\(changeSign)\(periodChange.formatDecimal())"

        let result = """
        Linear Trend Model Fitted:
        • Data Points: \(ts.count)
        • Period Range: \(ts.periods.first?.label ?? "N/A") to \(ts.periods.last?.label ?? "N/A")
        • Model Type: Linear (y = mx + b)
        • Last Historical Value: \(lastValue.formatDecimal())
        • Next Projected Value: \(nextValue.formatDecimal())
        • Period-to-Period Change: \(changeFormatted)

        Use this fitted model with 'forecast_trend' to project future values.
        """

        return .success(text: result)
    }
}

// MARK: - Fit Exponential Trend Tool

/// Fit an exponential trend model to time series data. Exponential trends capture accelerating or decelerating growth. Best for viral growth, compound returns.
///
/// Exposed to clients as the `fit_exponential_trend` tool.
public struct FitExponentialTrendTool: MCPToolHandler, Sendable {
    /// The `fit_exponential_trend` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "fit_exponential_trend",
        description: "Fit an exponential trend model to time series data. Exponential trends capture accelerating or decelerating growth. Best for viral growth, compound returns.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data with periods and values (all values must be positive)",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["data"]
        )
    )

    /// Creates the `fit_exponential_trend` handler.
    public init() {}

    /// Runs `fit_exponential_trend` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")

        // Verify all values are positive
        let values = ts.valuesArray
        guard values.allSatisfy({ $0 > 0 }) else {
            throw ToolError.invalidArguments("Exponential trend requires all positive values")
        }

        var model = ExponentialTrend<Double>()
        try model.fit(to: ts)

        let result = """
        Exponential Trend Model Fitted:
        • Data Points: \(ts.count)
        • Period Range: \(ts.periods.first?.label ?? "N/A") to \(ts.periods.last?.label ?? "N/A")
        • Model Type: Exponential (y = a × e^(bx))

        Use this fitted model with 'forecast_trend' to project future values.
        Note: Exponential models are best for short to medium-term forecasts.
        """

        return .success(text: result)
    }
}

// MARK: - Fit Logistic Trend Tool

/// Fit a logistic (S-curve) trend model to time series data. Logistic trends model growth that approaches a maximum capacity. Best for market penetration, user adoption.
///
/// Exposed to clients as the `fit_logistic_trend` tool.
public struct FitLogisticTrendTool: MCPToolHandler, Sendable {
    /// The `fit_logistic_trend` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "fit_logistic_trend",
        description: "Fit a logistic (S-curve) trend model to time series data. Logistic trends model growth that approaches a maximum capacity. Best for market penetration, user adoption.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data with periods and values",
                    items: MCPSchemaItems(type: "object")
                ),
                "capacity": MCPSchemaProperty(
                    type: "number",
                    description: "Maximum capacity (L parameter) - the upper asymptote"
                )
            ],
            required: ["data", "capacity"]
        )
    )

    /// Creates the `fit_logistic_trend` handler.
    public init() {}

    /// Runs `fit_logistic_trend` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let capacity = try args.getDouble("capacity")

        var model = LogisticTrend<Double>(capacity: capacity)
        try model.fit(to: ts)

        let result = """
        Logistic Trend Model Fitted:
        • Data Points: \(ts.count)
        • Period Range: \(ts.periods.first?.label ?? "N/A") to \(ts.periods.last?.label ?? "N/A")
        • Model Type: Logistic S-Curve
        • Maximum Capacity: \(capacity.formatDecimal())

        Use this fitted model with 'forecast_trend' to project future values.
        Note: Growth will asymptotically approach the capacity limit.
        """

        return .success(text: result)
    }
}

// MARK: - Forecast Trend Tool

/// Project a fitted trend model forward for specified periods. Must fit a trend model first using fit_linear_trend, fit_exponential_trend, or fit_logistic_trend.
///
/// Exposed to clients as the `forecast_trend` tool.
public struct ForecastTrendTool: MCPToolHandler, Sendable {
    /// The `forecast_trend` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "forecast_trend",
        description: "Project a fitted trend model forward for specified periods. Must fit a trend model first using fit_linear_trend, fit_exponential_trend, or fit_logistic_trend.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Original time series data that was fitted",
                    items: MCPSchemaItems(type: "object")
                ),
                "trendType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of trend model to use",
                    enum: ["linear", "exponential", "logistic"]
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to forecast forward"
                ),
                "capacity": MCPSchemaProperty(
                    type: "number",
                    description: "Capacity parameter (only for logistic trend)"
                )
            ],
            required: ["data", "trendType", "periods"]
        )
    )

    /// Creates the `forecast_trend` handler.
    public init() {}

    /// Runs `forecast_trend` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let trendType = try args.getString("trendType")
        let periods = try args.getInt("periods")

        let forecast: TimeSeries<Double>

        switch trendType {
        case "linear":
            var model = LinearTrend<Double>()
            try model.fit(to: ts)
            // `project` both throws and returns an optional. The former `try?`
            // collapsed the two into one message; a thrown error now propagates
            // with its own reason, and only a nil result is reported here.
            guard let result = try model.project(periods: periods) else {
                throw ToolError.invalidArguments(
                    "Trend model \(trendType) produced no forecast for \(periods) periods")
            }
            forecast = result
case "exponential":
            var model = ExponentialTrend<Double>()
            try model.fit(to: ts)
            // `project` both throws and returns an optional. The former `try?`
            // collapsed the two into one message; a thrown error now propagates
            // with its own reason, and only a nil result is reported here.
            guard let result = try model.project(periods: periods) else {
                throw ToolError.invalidArguments(
                    "Trend model \(trendType) produced no forecast for \(periods) periods")
            }
            forecast = result
case "logistic":
            guard let capacity = args.getDoubleOptional("capacity") else {
                throw ToolError.missingRequiredArgument("capacity (required for logistic trend)")
            }
            var model = LogisticTrend<Double>(capacity: capacity)
            try model.fit(to: ts)
            // `project` both throws and returns an optional. The former `try?`
            // collapsed the two into one message; a thrown error now propagates
            // with its own reason, and only a nil result is reported here.
            guard let result = try model.project(periods: periods) else {
                throw ToolError.invalidArguments(
                    "Trend model \(trendType) produced no forecast for \(periods) periods")
            }
            forecast = result
default:
            throw ToolError.invalidArguments("Invalid trend type: \(trendType). Must be linear, exponential, or logistic")
        }

        var forecastDetails = ""
        let forecastData = zip(forecast.periods, forecast.valuesArray)
        for (index, (period, value)) in forecastData.enumerated() {
            forecastDetails += "\n  \(period.label): \(value.formatDecimal())"
            if index >= 9 && forecast.count > 10 {
                forecastDetails += "\n  ... (\(forecast.count - 10) more periods)"
                break
            }
        }

        let result = """
        Trend Forecast:
        • Trend Type: \(trendType.capitalized)
        • Historical Data: \(ts.count) periods
        • Forecast Periods: \(periods)
        • Projected Values:\(forecastDetails)
        """

        return .success(text: result)
    }
}

// MARK: - Calculate Seasonal Indices Tool

/// Calculate seasonal indices from time series data. Indices show the typical pattern for each season (e.g., each month of the year). Values >1 indicate above-average periods, <1 indicate below-average.
///
/// Exposed to clients as the `calculate_seasonal_indices` tool.
public struct CalculateSeasonalIndicesTool: MCPToolHandler, Sendable {
    /// The `calculate_seasonal_indices` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_seasonal_indices",
        description: "Calculate seasonal indices from time series data. Indices show the typical pattern for each season (e.g., each month of the year). Values >1 indicate above-average periods, <1 indicate below-average.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data with at least 2 complete years",
                    items: MCPSchemaItems(type: "object")
                ),
                "periodsPerYear": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods in a year (4 for quarterly, 12 for monthly)"
                )
            ],
            required: ["data", "periodsPerYear"]
        )
    )

    /// Creates the `calculate_seasonal_indices` handler.
    public init() {}

    /// Runs `calculate_seasonal_indices` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let periodsPerYear = try args.getInt("periodsPerYear")

        let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: periodsPerYear)

        var indicesDetails = ""
        for (index, value) in indices.enumerated() {
            let seasonName: String
            if periodsPerYear == 4 {
                seasonName = "Q\(index + 1)"
            } else if periodsPerYear == 12 {
                seasonName = "Month \(index + 1)"
            } else {
                seasonName = "Period \(index + 1)"
            }
            let percentChange = (value - 1.0) * 100
            indicesDetails += "\n  \(seasonName): \(value.formatDecimal(decimals: 3)) (\(percentChange >= 0 ? "+" : "")\(percentChange.formatDecimal(decimals: 1))%)"
        }

        let result = """
        Seasonal Indices Calculated:
        • Data Points: \(ts.count)
        • Periods Per Year: \(periodsPerYear)
        • Number of Indices: \(indices.count)

        Seasonal Indices:\(indicesDetails)

        Interpretation:
        • Index = 1.0 → Average seasonal period
        • Index > 1.0 → Above-average (high season)
        • Index < 1.0 → Below-average (low season)

        Use these indices with 'seasonally_adjust' to remove seasonality.
        """

        return .success(text: result)
    }
}

// MARK: - Seasonally Adjust Tool

/// Remove seasonal patterns from time series data using seasonal indices. This reveals the underlying trend by normalizing seasonal fluctuations.
///
/// Exposed to clients as the `seasonally_adjust` tool.
public struct SeasonallyAdjustTool: MCPToolHandler, Sendable {
    /// The `seasonally_adjust` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "seasonally_adjust",
        description: "Remove seasonal patterns from time series data using seasonal indices. This reveals the underlying trend by normalizing seasonal fluctuations.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data to adjust",
                    items: MCPSchemaItems(type: "object")
                ),
                "indices": MCPSchemaProperty(
                    type: "array",
                    description: "Seasonal indices (from calculate_seasonal_indices)",
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["data", "indices"]
        )
    )

    /// Creates the `seasonally_adjust` handler.
    public init() {}

    /// Runs `seasonally_adjust` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let indices = try args.getDoubleArray("indices")

        let adjusted = try seasonallyAdjust(timeSeries: ts, indices: indices)

        var comparisonDetails = ""
        let comparisonData = zip(ts.periods, zip(ts.valuesArray, adjusted.valuesArray))
        for (index, (period, (original, adjustedVal))) in comparisonData.prefix(6).enumerated() {
            comparisonDetails += "\n  \(period.label): \(original.formatDecimal()) → \(adjustedVal.formatDecimal())"
            if index == 5 && ts.count > 6 {
                comparisonDetails += "\n  ... (\(ts.count - 6) more periods)"
            }
        }

        let result = """
        Seasonally Adjusted Data:
        • Original Data Points: \(ts.count)
        • Seasonal Indices Used: \(indices.count)
        • Adjusted Data Points: \(adjusted.count)

        Sample Comparisons (Original → Adjusted):\(comparisonDetails)

        The adjusted data shows the underlying trend without seasonal variation.
        Use this for year-over-year comparisons or trend analysis.
        """

        return .success(text: result)
    }
}

// MARK: - Decompose Time Series Tool

/// Decompose time series into trend, seasonal, and residual components. This separates the long-term pattern, seasonal effects, and random variation.
///
/// Exposed to clients as the `decompose_time_series` tool.
public struct DecomposeTimeSeriesTo: MCPToolHandler, Sendable {
    /// The `decompose_time_series` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "decompose_time_series",
        description: "Decompose time series into trend, seasonal, and residual components. This separates the long-term pattern, seasonal effects, and random variation.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data with at least 2 complete years",
                    items: MCPSchemaItems(type: "object")
                ),
                "periodsPerYear": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods in a year (4 for quarterly, 12 for monthly)"
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Decomposition method: 'additive' (for constant seasonal variation) or 'multiplicative' (for proportional variation)",
                    enum: ["additive", "multiplicative"]
                )
            ],
            required: ["data", "periodsPerYear", "method"]
        )
    )

    /// Creates the `decompose_time_series` handler.
    public init() {}

    /// Runs `decompose_time_series` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let periodsPerYear = try args.getInt("periodsPerYear")
        let methodString = try args.getString("method")

        let method: DecompositionMethod = (methodString == "multiplicative") ? .multiplicative : .additive

        let decomposition = try decomposeTimeSeries(
            timeSeries: ts,
            periodsPerYear: periodsPerYear,
            method: method
        )

        // Sample some values from each component
        let sampleSize = min(5, decomposition.trend.count)
        var trendSample = ""
        var seasonalSample = ""
        var residualSample = ""

        let trendData = zip(decomposition.trend.periods, decomposition.trend.valuesArray)
		for (_, (period, value)) in trendData.prefix(sampleSize).enumerated() {
            trendSample += "\n    \(period.label): \(value.formatDecimal())"
        }

        let seasonalData = zip(decomposition.seasonal.periods, decomposition.seasonal.valuesArray)
		for (_, (period, value)) in seasonalData.prefix(sampleSize).enumerated() {
            seasonalSample += "\n    \(period.label): \(value.formatDecimal(decimals: 3))"
        }

        let residualData = zip(decomposition.residual.periods, decomposition.residual.valuesArray)
		for (_, (period, value)) in residualData.prefix(sampleSize).enumerated() {
            residualSample += "\n    \(period.label): \(value.formatDecimal(decimals: 3))"
        }

        let result = """
        Time Series Decomposition:
        • Method: \(methodString.capitalized)
        • Original Data: \(ts.count) periods
        • Periods Per Year: \(periodsPerYear)

        Components:

        1. Trend (long-term pattern):
           • Points: \(decomposition.trend.count)
           • Sample values:\(trendSample)

        2. Seasonal (repeating pattern):
           • Points: \(decomposition.seasonal.count)
           • Sample indices:\(seasonalSample)
           \(method == .multiplicative ? "• (Multiplicative: 1.0 = average, >1.0 = above average)" : "• (Additive: 0.0 = average, >0 = above average)")

        3. Residual (unexplained variation):
           • Points: \(decomposition.residual.count)
           • Sample values:\(residualSample)

        Use this decomposition to:
        • Understand what drives your data
        • Forecast trend and seasonal components separately
        • Identify anomalies in the residuals
        • Quantify seasonal effects
        """

        return .success(text: result)
    }
}

// MARK: - Forecast with Seasonality Tool

/// Create a complete forecast combining trend projection and seasonal patterns. This provides the most accurate forecasts for data with both trend and seasonality.
///
/// Exposed to clients as the `forecast_with_seasonality` tool.
public struct ForecastWithSeasonalityTool: MCPToolHandler, Sendable {
    /// The `forecast_with_seasonality` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "forecast_with_seasonality",
        description: "Create a complete forecast combining trend projection and seasonal patterns. This provides the most accurate forecasts for data with both trend and seasonality.",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Historical time series data",
                    items: MCPSchemaItems(type: "object")
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods to forecast"
                ),
                "periodsPerYear": MCPSchemaProperty(
                    type: "number",
                    description: "Number of periods in a year (4 for quarterly, 12 for monthly)"
                ),
                "trendType": MCPSchemaProperty(
                    type: "string",
                    description: "Type of trend to use for projection",
                    enum: ["linear", "exponential"]
                )
            ],
            required: ["data", "periods", "periodsPerYear", "trendType"]
        )
    )

    /// Creates the `forecast_with_seasonality` handler.
    public init() {}

    /// Runs `forecast_with_seasonality` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let periods = try args.getInt("periods")
        let periodsPerYear = try args.getInt("periodsPerYear")
        let trendType = try args.getString("trendType")

        // Step 1: Calculate seasonal indices
        let indices = try seasonalIndices(timeSeries: ts, periodsPerYear: periodsPerYear)

        // Step 2: Remove seasonality
        let deseasonalized = try seasonallyAdjust(timeSeries: ts, indices: indices)

        // Step 3: Fit trend to deseasonalized data
        let trendForecast: TimeSeries<Double>
        switch trendType {
        case "linear":
            var model = LinearTrend<Double>()
            try model.fit(to: deseasonalized)
            // `project` both throws and returns an optional. The former `try?`
            // collapsed the two into one message; a thrown error now propagates
            // with its own reason, and only a nil result is reported here.
            guard let result = try model.project(periods: periods) else {
                throw ToolError.invalidArguments(
                    "Trend model \(trendType) produced no forecast for \(periods) periods")
            }
            trendForecast = result
case "exponential":
            var model = ExponentialTrend<Double>()
            try model.fit(to: deseasonalized)
            // `project` both throws and returns an optional. The former `try?`
            // collapsed the two into one message; a thrown error now propagates
            // with its own reason, and only a nil result is reported here.
            guard let result = try model.project(periods: periods) else {
                throw ToolError.invalidArguments(
                    "Trend model \(trendType) produced no forecast for \(periods) periods")
            }
            trendForecast = result
default:
            throw ToolError.invalidArguments("Invalid trend type: \(trendType)")
        }

        // Step 4: Reapply seasonality to forecast
        let finalForecast = try applySeasonal(timeSeries: trendForecast, indices: indices)

        var forecastDetails = ""
        let forecastData = zip(finalForecast.periods, finalForecast.valuesArray)
        for (index, (period, value)) in forecastData.enumerated() {
            forecastDetails += "\n  \(period.label): \(value.formatDecimal())"
            if index >= 9 && finalForecast.count > 10 {
                forecastDetails += "\n  ... (\(finalForecast.count - 10) more periods)"
                break
            }
        }

        let result = """
        Forecast with Seasonality:
        • Historical Data: \(ts.count) periods
        • Trend Type: \(trendType.capitalized)
        • Seasonal Cycle: \(periodsPerYear) periods/year
        • Forecast Periods: \(periods)

        Forecasted Values:\(forecastDetails)

        Method:
        1. Extracted seasonal indices from historical data
        2. Removed seasonality to reveal underlying trend
        3. Projected trend forward using \(trendType) model
        4. Reapplied seasonal patterns to projection

        This forecast accounts for both long-term trends and seasonal patterns.
        """

        return .success(text: result)
    }
}

/// Get all Forecasting tools
public func getForecastingTools() -> [any MCPToolHandler] {
    // Note: CalculateSeasonalIndicesTool and SeasonallyAdjustTool are
    // registered via getSeasonalityTools().
    // DecomposeTimeSeriesTo shares its name with TimeSeriesDecomposeTool
    // (registered via getTrendForecastingTools()), so it is omitted here.
    return [
        FitLinearTrendTool(),
        FitExponentialTrendTool(),
        FitLogisticTrendTool(),
        ForecastTrendTool(),
        ForecastWithSeasonalityTool()
    ]
}
