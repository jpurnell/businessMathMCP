//
//  ForecastEvaluationTools.swift
//  BusinessMath MCP Server
//
//  Forecast Evaluation & Diagnostics tools (BusinessMath v2.5.0):
//  rolling-origin backtesting, forecastability assessment, and stationarity testing.
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all forecast evaluation & diagnostics tools.
public func getForecastEvaluationTools() -> [any MCPToolHandler] {
    return [
        BacktestForecastTool(),
        AssessForecastabilityTool(),
        TestStationarityTool()
    ]
}

// MARK: - Helpers

private func fmt(_ value: Double, decimals: Int = 4) -> String {
    value.formatDecimal(decimals: decimals)
}

/// Builds a `TimeSeries<Double>` with synthetic annual periods from a value array.
private func makeSeries(_ values: [Double]) -> TimeSeries<Double> {
    let periods = (0..<values.count).map { Period.year($0) }
    return TimeSeries(periods: periods, values: values)
}

// MARK: - Backtest Forecast

/// Evaluate a baseline forecaster OUT-OF-SAMPLE using rolling-origin (walk-forward).
///
/// Exposed to clients as the `backtest_forecast` tool.
public struct BacktestForecastTool: MCPToolHandler, Sendable {
    /// The `backtest_forecast` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "backtest_forecast",
        description: """
        Evaluate a baseline forecaster OUT-OF-SAMPLE using rolling-origin (walk-forward)
        cross-validation. At each origin the forecaster is trained only on prior data and
        scored against the true future — no leakage — so the reported accuracy is honest,
        unlike in-sample fit.

        Returns pooled out-of-sample RMSE, MAE, MAPE, and MASE. MASE < 1 means the
        forecaster beats the (seasonal-)naive benchmark; MASE ≈ 1 means it does not.

        Use Cases:
        • Decide whether a series is worth modeling (does anything beat naive?)
        • Compare forecasters on the same series apples-to-apples
        • Detect low-forecastability / event-driven series

        Example: values [10,11,12,13,14,15,16,17], forecaster "naive",
        initialTrainSize 4, horizon 1 → MASE near 1 on a pure ramp.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values (chronological order)",
                    items: MCPSchemaItems(type: "number")
                ),
                "forecaster": MCPSchemaProperty(
                    type: "string",
                    description: "Baseline forecaster: 'naive', 'seasonal_naive', or 'drift' (default 'naive')"
                ),
                "initialTrainSize": MCPSchemaProperty(
                    type: "number",
                    description: "Number of observations before the first forecast origin"
                ),
                "horizon": MCPSchemaProperty(
                    type: "number",
                    description: "Number of steps forecast at each origin"
                ),
                "step": MCPSchemaProperty(
                    type: "number",
                    description: "Observations to advance the origin between folds (default 1)"
                ),
                "seasonLength": MCPSchemaProperty(
                    type: "number",
                    description: "Season length for MASE / seasonal_naive (required for seasonal_naive)"
                )
            ],
            required: ["historicalValues", "initialTrainSize", "horizon"]
        )
    )

    /// Creates the `backtest_forecast` handler.
    public init() {}

    /// Runs `backtest_forecast` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }
        let values = try args.getDoubleArray("historicalValues")
        let initialTrainSize = try args.getInt("initialTrainSize")
        let horizon = try args.getInt("horizon")
        let step = args.getIntOptional("step") ?? 1
        let seasonLength = args.getIntOptional("seasonLength")
        let forecasterName = (args.getStringOptional("forecaster") ?? "naive").lowercased()

        guard values.count >= 2 else {
            throw ToolError.invalidArguments("Need at least 2 historical values")
        }
        guard initialTrainSize >= 1, horizon >= 1, step >= 1 else {
            throw ToolError.invalidArguments("initialTrainSize, horizon, and step must be ≥ 1")
        }
        guard values.count >= initialTrainSize + horizon else {
            throw ToolError.invalidArguments(
                "Series too short: need at least initialTrainSize + horizon (\(initialTrainSize + horizon)) values, got \(values.count)")
        }

        let series = makeSeries(values)
        let config = BacktestConfig(
            initialTrainSize: initialTrainSize,
            horizon: horizon,
            step: step,
            seasonLength: seasonLength)

        let report: BacktestReport<Double>
        do {
            switch forecasterName {
            case "naive":
                report = try series.backtest(NaiveForecaster<Double>(), config: config)
            case "drift":
                report = try series.backtest(DriftForecaster<Double>(), config: config)
            case "seasonal_naive", "seasonalnaive":
                guard let m = seasonLength else {
                    throw ToolError.invalidArguments("forecaster 'seasonal_naive' requires seasonLength")
                }
                report = try series.backtest(SeasonalNaiveForecaster<Double>(seasonLength: m), config: config)
            default:
                throw ToolError.invalidArguments(
                    "Unknown forecaster '\(forecasterName)'. Use 'naive', 'seasonal_naive', or 'drift'.")
            }
        } catch let error as BacktestError {
            throw ToolError.invalidArguments("Backtest failed: \(error)")
        }

        let maseText = report.mase.map { fmt($0) } ?? "n/a (degenerate/constant series)"
        let output = """
        Rolling-Origin Backtest — forecaster: \(forecasterName)

        Configuration:
        • Data points: \(values.count)
        • Initial train size: \(initialTrainSize)
        • Horizon: \(report.horizon)
        • Step: \(step)\(seasonLength.map { "\n• Season length: \($0)" } ?? "")
        • Folds evaluated: \(report.foldCount)

        Out-of-sample accuracy (pooled across folds):
        • RMSE: \(fmt(report.rmse))
        • MAE:  \(fmt(report.mae))
        • MAPE: \(fmt(report.mape * 100, decimals: 2))%
        • MASE: \(maseText)

        Interpretation:
        • MASE < 1  → beats the (seasonal-)naive benchmark
        • MASE ≈ 1  → no better than naive (little exploitable structure)
        • MASE > 1  → worse than naive
        """
        return .success(text: output)
    }
}

// MARK: - Assess Forecastability

/// Measure how much exploitable structure a series contains BEFORE modeling, using.
///
/// Exposed to clients as the `assess_forecastability` tool.
public struct AssessForecastabilityTool: MCPToolHandler, Sendable {
    /// The `assess_forecastability` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "assess_forecastability",
        description: """
        Measure how much exploitable structure a series contains BEFORE modeling, using
        the normalized spectral entropy of its periodogram.

        spectralEntropy ranges 0…1: near 0 = concentrated spectrum (highly forecastable,
        e.g. strong seasonality); near 1 = flat spectrum (white noise, unforecastable).
        Returns a verdict: strong / moderate / weak / noise.

        Use this first: if the verdict is 'noise', do not trust any point forecast — seek
        exogenous drivers instead of a fancier model. Requires at least 4 data points.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values (at least 4 required)",
                    items: MCPSchemaItems(type: "number")
                ),
                "seasonLength": MCPSchemaProperty(
                    type: "number",
                    description: "Optional season length hint"
                )
            ],
            required: ["historicalValues"]
        )
    )

    /// Creates the `assess_forecastability` handler.
    public init() {}

    /// Runs `assess_forecastability` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }
        let values = try args.getDoubleArray("historicalValues")
        let seasonLength = args.getIntOptional("seasonLength")
        guard values.count >= 4 else {
            throw ToolError.invalidArguments("Need at least 4 values to assess forecastability")
        }

        let series = makeSeries(values)
        let report: ForecastabilityReport<Double>
        do {
            report = try series.forecastability(seasonLength: seasonLength)
        } catch let error as ForecastError {
            throw ToolError.invalidArguments("Forecastability assessment failed: \(error)")
        }

        let output = """
        Forecastability Assessment

        • Data points: \(values.count)
        • Spectral entropy: \(fmt(report.spectralEntropy)) (0 = forecastable, 1 = noise)
        • Forecastability: \(fmt(report.forecastability)) (1 − entropy)
        • Verdict: \(report.verdict.rawValue.uppercased())

        Interpretation:
        • strong / moderate → structure present; modeling is worthwhile
        • weak → limited structure; simple methods only
        • noise → indistinguishable from noise; do not trust point forecasts —
          seek exogenous drivers instead
        """
        return .success(text: output)
    }
}

// MARK: - Test Stationarity

/// Run the Augmented Dickey-Fuller (ADF) and KPSS tests to decide whether a series is.
///
/// Exposed to clients as the `test_stationarity` tool.
public struct TestStationarityTool: MCPToolHandler, Sendable {
    /// The `test_stationarity` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "test_stationarity",
        description: """
        Run the Augmented Dickey-Fuller (ADF) and KPSS tests to decide whether a series is
        stationary or needs differencing before fitting a trend model.

        ADF null hypothesis: the series has a unit root (NON-stationary).
        KPSS null hypothesis: the series IS stationary.
        Because their nulls are opposite, AGREEMENT is a confident verdict; disagreement is
        reported as ambiguous rather than false certainty. p-values are approximate; the
        stationary/non-stationary decision uses the 5% critical value.

        Requires enough data (ADF: n ≥ lag+4; KPSS: n ≥ 8).
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "historicalValues": MCPSchemaProperty(
                    type: "array",
                    description: "Array of historical data values",
                    items: MCPSchemaItems(type: "number")
                ),
                "kpssRegression": MCPSchemaProperty(
                    type: "string",
                    description: "KPSS deterministic component: 'level' (default) or 'trend'"
                ),
                "lag": MCPSchemaProperty(
                    type: "number",
                    description: "Optional lag override (defaults to a Schwert-style rule)"
                )
            ],
            required: ["historicalValues"]
        )
    )

    /// Creates the `test_stationarity` handler.
    public init() {}

    /// Runs `test_stationarity` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }
        let values = try args.getDoubleArray("historicalValues")
        let lag = args.getIntOptional("lag")
        let regressionName = (args.getStringOptional("kpssRegression") ?? "level").lowercased()
        let regression: KPSSRegression = regressionName == "trend" ? .trend : .level

        guard values.count >= 8 else {
            throw ToolError.invalidArguments("Need at least 8 values for stationarity testing")
        }

        let series = makeSeries(values)
        let adf: StationarityTestResult<Double>
        let kpss: StationarityTestResult<Double>
        do {
            adf = try series.augmentedDickeyFuller(lag: lag)
            kpss = try series.kpss(regression: regression, lag: lag)
        } catch {
            // Includes degenerate inputs (e.g. a perfectly linear series has constant
            // first differences → the ADF regression has no variance to fit).
            throw ToolError.invalidArguments("Stationarity test failed: \(error)")
        }

        let agree = adf.isStationary == kpss.isStationary
        let verdict: String
        if agree {
            verdict = adf.isStationary
                ? "STATIONARY (ADF and KPSS agree)"
                : "NON-STATIONARY (ADF and KPSS agree) — difference before modeling"
        } else {
            verdict = "AMBIGUOUS (ADF and KPSS disagree) — inspect and re-test"
        }

        let output = """
        Stationarity Tests (\(values.count) points)

        Augmented Dickey-Fuller (H0: unit root / non-stationary):
        • statistic: \(fmt(adf.statistic)) · p≈\(fmt(adf.pValue, decimals: 3)) · lag \(adf.usedLag)
        • verdict: \(adf.isStationary ? "stationary (rejects unit root)" : "non-stationary")

        KPSS (\(regressionName)) (H0: stationary):
        • statistic: \(fmt(kpss.statistic)) · p≈\(fmt(kpss.pValue, decimals: 3)) · lag \(kpss.usedLag)
        • verdict: \(kpss.isStationary ? "stationary" : "non-stationary (rejects stationarity)")

        Combined verdict: \(verdict)
        Recommendation: \(adf.recommendation)
        """
        return .success(text: output)
    }
}
