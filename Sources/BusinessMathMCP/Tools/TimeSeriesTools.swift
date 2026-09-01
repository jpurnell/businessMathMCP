import Foundation
import MCP
import SwiftMCPServer
import BusinessMath

// MARK: - Create Time Series Tool

/// Create a time series from periods and values for analysis.
///
/// Exposed to clients as the `create_time_series` tool.
public struct CreateTimeSeriesTool: MCPToolHandler, Sendable {
    /// The `create_time_series` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "create_time_series",
        description: """
        Create a time series from periods and values for analysis.

        Supports annual, quarterly, monthly, and daily time periods.
        Use for analyzing trends, growth, seasonality, and forecasting.

        REQUIRED STRUCTURE:
        {
          "data": [
            {"period": {"year": 2023, "type": "annual"}, "value": 100000},
            {"period": {"year": 2024, "type": "annual"}, "value": 120000}
          ]
        }

        EXAMPLES:

        1. Annual Revenue:
        {
          "data": [
            {"period": {"year": 2021, "type": "annual"}, "value": 1000000},
            {"period": {"year": 2022, "type": "annual"}, "value": 1200000},
            {"period": {"year": 2023, "type": "annual"}, "value": 1450000}
          ],
          "name": "Annual Revenue",
          "unit": "USD"
        }

        2. Quarterly Sales:
        {
          "data": [
            {"period": {"year": 2024, "month": 1, "type": "quarterly"}, "value": 250000},
            {"period": {"year": 2024, "month": 4, "type": "quarterly"}, "value": 280000},
            {"period": {"year": 2024, "month": 7, "type": "quarterly"}, "value": 310000},
            {"period": {"year": 2024, "month": 10, "type": "quarterly"}, "value": 350000}
          ],
          "name": "Q1-Q4 2024 Sales",
          "unit": "USD"
        }

        3. Monthly Revenue:
        {
          "data": [
            {"period": {"year": 2024, "month": 1, "type": "monthly"}, "value": 85000},
            {"period": {"year": 2024, "month": 2, "type": "monthly"}, "value": 92000},
            {"period": {"year": 2024, "month": 3, "type": "monthly"}, "value": 88000}
          ]
        }

        Period types: "annual", "quarterly", "monthly", "daily"
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of time series data points. Each object must have:
                    • period (object): Time period with fields:
                      - year (number): Required for all types
                      - month (number): Required for quarterly/monthly/daily (1-12)
                      - day (number): Required for daily only (1-31)
                      - type (string): "annual", "quarterly", "monthly", or "daily"
                    • value (number): Numeric value for this period

                    Example: [{"period": {"year": 2024, "month": 1, "type": "monthly"}, "value": 100000}]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "name": MCPSchemaProperty(
                    type: "string",
                    description: "Name of the time series (optional)"
                ),
                "description": MCPSchemaProperty(
                    type: "string",
                    description: "Description of the time series (optional)"
                ),
                "unit": MCPSchemaProperty(
                    type: "string",
                    description: "Unit of measurement, e.g., 'USD', 'units', 'customers' (optional)"
                )
            ],
            required: ["data"]
        )
    )

    /// Creates the `create_time_series` handler.
    public init() {}

    /// Runs `create_time_series` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let timeSeriesData = try args.getTimeSeries("data")
        let name = args.getStringOptional("name")
        let description = args.getStringOptional("description")
        let unit = args.getStringOptional("unit")

        // Create new time series with updated metadata if provided
        let ts: TimeSeries<Double>
        if name != nil || description != nil || unit != nil {
            let newMetadata = TimeSeriesMetadata(
                name: name ?? timeSeriesData.metadata.name,
                description: description ?? timeSeriesData.metadata.description,
                unit: unit ?? timeSeriesData.metadata.unit
            )
            ts = TimeSeries(
                periods: timeSeriesData.periods,
                values: timeSeriesData.valuesArray,
                metadata: newMetadata
            )
        } else {
            ts = timeSeriesData
        }

        let dataPoints = ts.count
        let firstPeriod = ts.periods.first?.label ?? "N/A"
        let lastPeriod = ts.periods.last?.label ?? "N/A"

        let result = """
        Time Series Created:
        • Name: \(name ?? "Unnamed")
        • Description: \(description ?? "No description")
        • Unit: \(unit ?? "No unit")
        • Data Points: \(dataPoints)
        • Period Range: \(firstPeriod) to \(lastPeriod)
        """

        return .success(text: result)
    }
}

// MARK: - Calculate Growth Rate Tool

/// Calculate the simple growth rate between two values.
///
/// Exposed to clients as the `calculate_simple_growth_rate` tool.
public struct CalculateGrowthRateTool: MCPToolHandler, Sendable {
    /// The `calculate_simple_growth_rate` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_simple_growth_rate",
        description: "Calculate the simple growth rate between two values",
        inputSchema: MCPToolInputSchema(
            properties: [
                "oldValue": MCPSchemaProperty(
                    type: "number",
                    description: "The starting value"
                ),
                "newValue": MCPSchemaProperty(
                    type: "number",
                    description: "The ending value"
                )
            ],
            required: ["oldValue", "newValue"]
        )
    )

    /// Creates the `calculate_simple_growth_rate` handler.
    public init() {}

    /// Runs `calculate_simple_growth_rate` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let oldValue = try args.getDouble("oldValue")
        let newValue = try args.getDouble("newValue")

        let growth = try growthRate(from: oldValue, to: newValue)
        let change = newValue - oldValue

        let result = """
        Growth Rate Analysis:
        • Starting Value: \(oldValue.formatDecimal())
        • Ending Value: \(newValue.formatDecimal())
        • Absolute Change: \(change.formatDecimal())
        • Growth Rate: \((growth).percent())
        """

        return .success(text: result)
    }
}

// MARK: - Calculate CAGR Tool

/// Calculate the Compound Annual Growth Rate (CAGR) between two values over a period.
///
/// Exposed to clients as the `calculate_cagr` tool.
public struct CalculateCAGRTool: MCPToolHandler, Sendable {
    /// The `calculate_cagr` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_cagr",
        description: "Calculate the Compound Annual Growth Rate (CAGR) between two values over a period",
        inputSchema: MCPToolInputSchema(
            properties: [
                "beginningValue": MCPSchemaProperty(
                    type: "number",
                    description: "The starting value"
                ),
                "endingValue": MCPSchemaProperty(
                    type: "number",
                    description: "The ending value"
                ),
                "periods": MCPSchemaProperty(
                    type: "number",
                    description: "The number of periods (years)"
                )
            ],
            required: ["beginningValue", "endingValue", "periods"]
        )
    )

    /// Creates the `calculate_cagr` handler.
    public init() {}

    /// Runs `calculate_cagr` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let beginningValue = try args.getDouble("beginningValue")
        let endingValue = try args.getDouble("endingValue")
        let periods = try args.getInt("periods")

        let cagrValue = cagr(
            beginningValue: beginningValue,
            endingValue: endingValue,
            years: Double(periods)
        )

		// `try?` then `!` two lines later was the same trap with an extra step: a zero
		// beginning value makes growthRate throw, and the report crashed rather than
		// saying the growth was not computable. A zero divisor is the only way that
		// function fails, so the condition is tested here instead of caught.
		let totalGrowthText: String
		if beginningValue == 0 {
			// A zero beginning value has no growth rate; saying so beats reporting a number.
			totalGrowthText = "n/a (beginning value is zero)"
		} else {
			totalGrowthText = try growthRate(from: beginningValue, to: endingValue).percent()
		}

        let result = """
        Compound Annual Growth Rate (CAGR):
        • Beginning Value: \(beginningValue.formatDecimal())
        • Ending Value: \(endingValue.formatDecimal())
        • Number of Periods: \(periods)
        • Total Growth: \(totalGrowthText)
        • CAGR: \(cagrValue.percent())
        """

        return .success(text: result)
    }
}

// MARK: - Time Series Statistics Tool

/// Calculate descriptive statistics for a time series (mean, median, std dev, min, max).
///
/// Exposed to clients as the `time_series_statistics` tool.
public struct TimeSeriesStatisticsTool: MCPToolHandler, Sendable {
    /// The `time_series_statistics` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "time_series_statistics",
        description: "Calculate descriptive statistics for a time series (mean, median, std dev, min, max)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["data"]
        )
    )

    /// Creates the `time_series_statistics` handler.
    public init() {}

    /// Runs `time_series_statistics` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let values = ts.valuesArray

        guard !values.isEmpty else {
            throw ToolError.invalidArguments("Time series cannot be empty")
        }

        let meanValue = mean(values)
        let medianValue = median(values)
        let stdDevValue = stdDev(values, .sample)
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 0

        let result = """
        Time Series Statistics:
        • Data Points: \(values.count)
        • Mean: \(meanValue.formatDecimal())
        • Median: \(medianValue.formatDecimal())
        • Std Deviation: \(stdDevValue.formatDecimal())
        • Minimum: \(minValue.formatDecimal())
        • Maximum: \(maxValue.formatDecimal())
        • Range: \((maxValue - minValue).formatDecimal())
        """

        return .success(text: result)
    }
}

// MARK: - Moving Average Tool

/// Calculate a moving average for a time series.
///
/// Exposed to clients as the `calculate_moving_average` tool.
public struct MovingAverageTool: MCPToolHandler, Sendable {
    /// The `calculate_moving_average` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_moving_average",
        description: "Calculate a moving average for a time series",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                ),
                "window": MCPSchemaProperty(
                    type: "number",
                    description: "The window size for the moving average"
                )
            ],
            required: ["data", "window"]
        )
    )

    /// Creates the `calculate_moving_average` handler.
    public init() {}

    /// Runs `calculate_moving_average` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let window = try args.getInt("window")

        guard window > 0 else {
            throw ToolError.invalidArguments("Window size must be positive")
        }

        let ma = ts.movingAverage(window: window)

        var maDetails = ""
        let maPeriodsAndValues = zip(ma.periods, ma.valuesArray)
        for (index, (period, value)) in maPeriodsAndValues.prefix(10).enumerated() {
            maDetails += "\n  \(period.label): \(value.formatDecimal())"
            if index == 9 && ma.count > 10 {
                maDetails += "\n  ... (\(ma.count - 10) more)"
            }
        }

        let result = """
        Moving Average Calculation:
        • Original Data Points: \(ts.count)
        • Window Size: \(window)
        • Moving Average Points: \(ma.count)
        • First \(min(10, ma.count)) Values:\(maDetails)
        """

        return .success(text: result)
    }
}

// MARK: - Time Series Aggregation Tool

/// Aggregate time series data (sum, mean, min, max).
///
/// Exposed to clients as the `aggregate_time_series` tool.
public struct TimeSeriesAggregationTool: MCPToolHandler, Sendable {
    /// The `aggregate_time_series` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "aggregate_time_series",
        description: "Aggregate time series data (sum, mean, min, max)",
        inputSchema: MCPToolInputSchema(
            properties: [
                "data": MCPSchemaProperty(
                    type: "array",
                    description: "Time series data",
                    items: MCPSchemaItems(type: "object")
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Aggregation method",
                    enum: ["sum", "mean", "min", "max"]
                )
            ],
            required: ["data", "method"]
        )
    )

    /// Creates the `aggregate_time_series` handler.
    public init() {}

    /// Runs `aggregate_time_series` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let ts = try args.getTimeSeries("data")
        let method = try args.getString("method")

        guard ts.count > 0 else {
            throw ToolError.invalidArguments("Time series cannot be empty")
        }

        let values = ts.valuesArray
        let aggregatedValue: Double
        switch method {
        case "sum":
            aggregatedValue = values.reduce(0, +)
        case "mean":
            aggregatedValue = mean(values)
        case "min":
            aggregatedValue = values.min() ?? 0
        case "max":
            aggregatedValue = values.max() ?? 0
        default:
            throw ToolError.invalidArguments("Invalid aggregation method: \(method)")
        }

        let result = """
        Time Series Aggregation:
        • Data Points: \(ts.count)
        • Method: \(method.uppercased())
        • Result: \(aggregatedValue.formatDecimal())
        """

        return .success(text: result)
    }
}

/// Get all Time Series tools
public func getTimeSeriesTools() -> [any MCPToolHandler] {
    return [
        CreateTimeSeriesTool(),
        CalculateGrowthRateTool(),
        CalculateCAGRTool(),
        TimeSeriesStatisticsTool(),
        MovingAverageTool(),
        TimeSeriesAggregationTool()
    ]
}
