import Testing
import Foundation
import MCP
import BusinessMath
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// SwiftMCPServer 5.0.0 returns an error's text only when the error's type says it was written
/// for the caller. These pin what each type says, and that everything else says nothing.
@Suite("Errors that reach the caller")
struct CallerVisibleErrorTests {

    /// Runs a handler the way the server does and returns what the caller would receive.
    private func call(
        _ handler: any MCPToolHandler, _ json: String
    ) async throws -> (text: String, isError: Bool) {
        let registry = ToolDefinitionRegistry()
        try await registry.register(handler.toToolDefinition())
        let value = try JSONDecoder().decode(MCP.Value.self, from: Data(json.utf8))
        guard case .object(let arguments) = value else {
            throw MCPTestError.decodingFailed("arguments must be a JSON object")
        }
        let result = try await registry.executeTool(name: handler.tool.name, arguments: arguments)
        guard case .text(let text, _, _) = result.content.first else {
            throw MCPTestError.unexpectedResult("no text content")
        }
        return (text, result.isError ?? false)
    }

    // MARK: - This package's own errors

    @Test("MarshallingError says what was wrong with the series")
    func marshallingError() {
        #expect(MarshallingError.invalidPeriodType("9").callerMessage == "Invalid period type: 9")
        #expect(MarshallingError.missingField("month").callerMessage
            == "Missing required field: month")
        #expect(MarshallingError.invalidData("Invalid date components").callerMessage
            == "Invalid data: Invalid date components")
        #expect(MarshallingError.conversionFailed("no periods").callerMessage
            == "Conversion failed: no periods")
    }

    @Test("ToolFailure is returned exactly as the handler wrote it")
    func toolFailure() {
        #expect(ToolFailure("Failed to calculate XNPV: There must be one date for each cash flow.").callerMessage
            == "Failed to calculate XNPV: There must be one date for each cash flow.")
    }

    @Test("ResourceError repeats the URI that was asked for")
    func resourceError() {
        #expect(ResourceError.notFound("docs://nothing").callerMessage
            == "Resource not found: docs://nothing")
    }

    @Test("An unknown resource reaches the caller as an MCP error carrying that message")
    func unknownResourceThroughTheServer() async throws {
        let error = await #expect(throws: MCPError.self) {
            _ = try await MCPServer.readResource(from: ResourceProvider(), uri: "docs://nothing")
        }
        #expect(error == MCPError.internalError("Resource not found: docs://nothing"))
    }

    // MARK: - BusinessMath errors with an authored description

    @Test("BusinessMathError uses its own description")
    func businessMathError() {
        #expect(BusinessMathError.divisionByZero(context: "current ratio").callerMessage
            == "Division by zero in current ratio")
        #expect(BusinessMathError.insufficientData(required: 2, actual: 1, context: "IRR").callerMessage
            == "Insufficient data for IRR: need 2, got 1")
        #expect(BusinessMathError.invalidInput(
            message: "rate must not be negative", value: "-0.1", expectedRange: "≥ 0").callerMessage
            == "Invalid input: rate must not be negative (provided: -0.1) (expected: ≥ 0)")
        #expect(BusinessMathError.calculationFailed(
            operation: "IRR", reason: "no sign change", suggestions: ["add an outflow"]).callerMessage
            == "IRR calculation failed: no sign change\nSuggestions:\n\t• add an outflow")
    }

    @Test("FinancialModelError uses its own description")
    func financialModelError() {
        #expect(FinancialModelError.accountMustHaveAtLeastOneRole.callerMessage
            == "Account must have at least one role: incomeStatementRole, balanceSheetRole, or cashFlowRole")
        #expect(FinancialModelError.entityMismatch(
            expected: "Acme", found: "Globex", accountName: "Revenue").callerMessage
            == "Entity mismatch: expected 'Acme' but account 'Revenue' has entity 'Globex'")
    }

    @Test("SimulationError uses its own description")
    func simulationError() {
        #expect(SimulationError.insufficientIterations.callerMessage
            == "Monte Carlo simulation requires at least 1 iteration")
        #expect(SimulationError.noInputs.callerMessage
            == "Monte Carlo simulation requires at least 1 input variable")
        #expect(SimulationError.invalidModel(iteration: 3, details: "NaN result").callerMessage
            == "Model function produced invalid result at iteration 3: NaN result")
        #expect(SimulationError.correlationDimensionMismatch.callerMessage
            == "Correlation matrix dimensions must match the number of input variables")
        #expect(SimulationError.invalidCorrelationMatrix.callerMessage
            == "Correlation matrix is not valid (must be symmetric, positive semi-definite, with unit diagonal)")
    }

    @Test("ScenarioError uses its own description")
    func scenarioError() {
        #expect(ScenarioError.missingInputConfiguration(
            scenario: "Base", missingInputs: ["price", "volume"]).callerMessage
            == "Scenario 'Base' is missing configuration for inputs: price, volume")
        #expect(ScenarioError.unknownInput(scenario: "Base", inputName: "margin").callerMessage
            == "Scenario 'Base' references unknown input: margin")
        #expect(ScenarioError.noScenarios.callerMessage
            == "No scenarios have been added to the analysis")
    }

    // MARK: - BusinessMath errors with no description: a sentence per case

    @Test("TrendModelError")
    func trendModelError() {
        #expect(TrendModelError.modelNotFitted.callerMessage
            == "The trend model has not been fitted to data.")
        #expect(TrendModelError.insufficientData(required: 3, provided: 2).callerMessage
            == "Not enough data to fit the trend: 3 data point(s) are required and 2 were provided.")
        #expect(TrendModelError.invalidData("Exponential trend requires all positive values").callerMessage
            == "The data cannot be used for this trend model: Exponential trend requires all positive values")
        #expect(TrendModelError.projectionFailed("Cannot project negative periods").callerMessage
            == "The trend could not be projected: Cannot project negative periods")
    }

    @Test("SeasonalityError")
    func seasonalityError() {
        #expect(SeasonalityError.insufficientData(required: 24, provided: 10).callerMessage
            == "Not enough data for the seasonal calculation: 24 data point(s) are required and 10 were provided.")
        #expect(SeasonalityError.mismatchedSizes(timeSeriesCount: 12, indicesCount: 0).callerMessage
            == "The seasonal indices do not fit the time series: 0 indices were supplied for 12 data point(s). At least one index is required.")
        #expect(SeasonalityError.invalidPeriodsPerYear(0).callerMessage
            == "periodsPerYear must be greater than zero; got 0.")
        #expect(SeasonalityError.divisionByZero("Seasonal index is zero at position 2").callerMessage
            == "The seasonal adjustment divides by zero: Seasonal index is zero at position 2")
    }

    @Test("OperationsError")
    func operationsError() {
        #expect(OperationsError.insufficientData(required: 1, got: 0).callerMessage
            == "Not enough data: 1 observation(s) are required and 0 were provided.")
        #expect(OperationsError.invalidParameter(
            "forecastRMSE is required for the forecastError method").callerMessage
            == "Invalid parameter: forecastRMSE is required for the forecastError method")
        #expect(OperationsError.invalidServiceLevel.callerMessage
            == "The service level must be greater than 0 and less than 1.")
        #expect(OperationsError.zeroDemand.callerMessage == "Demand must be greater than zero.")
        #expect(OperationsError.negativeCost.callerMessage == "Every cost must be greater than zero.")
    }

    @Test("ForecastError")
    func forecastError() {
        #expect(ForecastError.insufficientData(required: 2, got: 1).callerMessage
            == "Not enough data to forecast: 2 data point(s) are required and 1 were provided.")
        #expect(ForecastError.modelNotTrained.callerMessage
            == "The forecast model has not been trained on data.")
        #expect(ForecastError.invalidParameter("seasonLength must be ≥ 1").callerMessage
            == "Invalid forecast parameter: seasonLength must be ≥ 1")
        #expect(ForecastError.invalidConfidenceLevel.callerMessage
            == "The confidence level must be greater than 0 and no greater than 1.")
    }

    @Test("ValuationError")
    func valuationError() {
        #expect(ValuationError.invalidParameters("shares must be positive").callerMessage
            == "Invalid valuation parameters: shares must be positive")
        #expect(ValuationError.invalidModelAssumptions("growth must be below the discount rate").callerMessage
            == "The valuation model's assumptions do not hold: growth must be below the discount rate")
        #expect(ValuationError.insufficientData("no dividends").callerMessage
            == "Not enough data for the valuation: no dividends")
    }

    @Test("PortfolioOptimizerError")
    func portfolioOptimizerError() {
        #expect(PortfolioOptimizerError.emptyReturns.callerMessage
            == "Expected returns must contain at least one asset.")
    }

    @Test("AccountError")
    func accountError() {
        #expect(AccountError.invalidName.callerMessage == "An account name must not be empty.")
        #expect(AccountError.emptyTimeSeries.callerMessage
            == "An account must have a value for at least one period.")
        #expect(AccountError.invalidAccountType(expected: .balanceSheet, actual: .revenue).callerMessage
            == "Account type 'revenue' is not a 'balanceSheet' account type.")
    }

    @Test("ExperimentError")
    func experimentError() {
        #expect(ExperimentError.invalidPower(1.5).callerMessage
            == "Power must be greater than 0 and less than 1; got 1.5.")
        #expect(ExperimentError.invalidAlpha(0).callerMessage
            == "The significance level must be greater than 0 and less than 1; got 0.0.")
        #expect(ExperimentError.nonPositiveEffect(-0.1).callerMessage
            == "The minimum detectable effect must be greater than zero; got -0.1.")
        #expect(ExperimentError.invalidProportion(1.2).callerMessage
            == "A proportion must be between 0 and 1; got 1.2. Check the baseline rate, and the baseline plus the effect.")
        #expect(ExperimentError.nonPositiveStandardDeviation(0).callerMessage
            == "The standard deviation must be greater than zero; got 0.0.")
        #expect(ExperimentError.emptyArm(arm: "control").callerMessage
            == "The control arm has no observations.")
        #expect(ExperimentError.conversionsExceedObservations(
            arm: "treatment", conversions: 12, observations: 10).callerMessage
            == "The treatment arm's conversions (12) must be between 0 and its observations (10).")
        #expect(ExperimentError.nonPositiveSampleSize(0).callerMessage
            == "The sample size per arm must be greater than zero; got 0.")
    }

    @Test("RegressionError")
    func regressionError() {
        #expect(RegressionError.insufficientData(message: "X and y cannot be empty").callerMessage
            == "Not enough data for the regression: X and y cannot be empty")
        #expect(RegressionError.dimensionMismatch(
            expected: "X rows (5) must equal y length", actual: "y has length 4").callerMessage
            == "The regression's inputs disagree in size: X rows (5) must equal y length; y has length 4.")
        #expect(RegressionError.invalidPredictorMatrix(message: "X must be rectangular").callerMessage
            == "The predictor matrix is not valid: X must be rectangular")
        #expect(RegressionError.singularMatrix(message: "XᵀX is singular").callerMessage
            == "The regression has no unique solution: XᵀX is singular")
        #expect(RegressionError.noVariance(message: "y has no variance").callerMessage
            == "The regression cannot be fitted: y has no variance")
    }

    @Test("MatrixError, without LAPACK's account of a failed decomposition")
    func matrixError() {
        #expect(MatrixError.notPositiveDefinite.callerMessage
            == "The matrix must be positive definite.")
        #expect(MatrixError.notSquare.callerMessage == "The matrix must be square.")
        #expect(MatrixError.invalidDimensions(
            expected: "Non-empty array", actual: "Empty array").callerMessage
            == "The matrix's dimensions are not valid. Expected: Non-empty array. Got: Empty array.")
        #expect(MatrixError.notSymmetric.callerMessage == "The matrix must be symmetric.")
        #expect(MatrixError.singularMatrix.callerMessage
            == "The matrix is singular, so it cannot be inverted.")
        #expect(MatrixError.dimensionMismatch(
            expected: "Vector length must equal matrix rows: 3",
            actual: "Vector has length 2").callerMessage
            == "The matrix dimensions do not match. Expected: Vector length must equal matrix rows: 3. Got: Vector has length 2.")
        #expect(MatrixError.invalidDecomposition(reason: "dgeqrf failed with info=-4").callerMessage
            == "The matrix could not be decomposed. Check that every value is finite and that the matrix is well conditioned.")
    }

    @Test("OptimizationError says what kind of failure, never the solver's own account")
    func optimizationError() {
        let internalDetail = "Metal matrix multiply did not complete: MTLCommandBufferError 4"
        #expect(OptimizationError.failedToConverge(message: internalDetail).callerMessage
            == "The calculation did not converge. Check that the inputs describe a problem with a solution, or try different starting values or more iterations.")
        #expect(OptimizationError.invalidInput(message: internalDetail).callerMessage
            == "The inputs do not describe a problem that can be solved. Check that every required value is present and that the numbers of variables, coefficients and constraints agree.")
        #expect(OptimizationError.dimensionMismatch(message: internalDetail).callerMessage
            == "The inputs disagree in size. Check that the numbers of variables, coefficients and constraints agree.")
        #expect(OptimizationError.nonFiniteValue(message: internalDetail).callerMessage
            == "The calculation produced a value that is not a finite number. Check the inputs for extreme or degenerate values.")
        #expect(OptimizationError.numericalInstability(message: internalDetail).callerMessage
            == "The calculation is numerically unstable for these inputs. Rescaling the inputs may help.")
        #expect(OptimizationError.singularMatrix(message: internalDetail).callerMessage
            == "The inputs form a singular matrix, so the problem has no unique solution.")
        #expect(OptimizationError.maxIterationsReached.callerMessage
            == "The calculation reached its iteration limit without converging.")
        #expect(OptimizationError.unsupportedConstraints(internalDetail).callerMessage
            == "The method does not support this kind of constraint.")
        #expect(OptimizationError.nonlinearModel(message: internalDetail).callerMessage
            == "The method requires a linear model, and the one supplied is not linear.")
    }

    @Test("XNPVError")
    func xnpvError() {
        #expect(XNPVError.mismatchedArrays.callerMessage
            == "There must be one date for each cash flow.")
        #expect(XNPVError.invalidCashFlows.callerMessage
            == "The cash flows must include at least one positive and one negative amount.")
        #expect(XNPVError.insufficientData.callerMessage == "At least two cash flows are required.")
        #expect(XNPVError.convergenceFailed.callerMessage
            == "The rate did not converge for these cash flows. Try a different guess.")
    }

    @Test("BacktestError")
    func backtestError() {
        #expect(BacktestError.seriesTooShort(required: 10, got: 6).callerMessage
            == "The series is too short to backtest: 10 data point(s) are required and 6 were provided.")
        #expect(BacktestError.invalidConfig("step must be positive").callerMessage
            == "Invalid backtest configuration: step must be positive")
        #expect(BacktestError.unforecastableSeries(spectralEntropy: 0.98, threshold: 0.9).callerMessage
            == "The series is indistinguishable from noise (spectral entropy 0.98 exceeds the threshold 0.9), so no forecast was produced.")
    }

    @Test("CorrelatedNormalsError")
    func correlatedNormalsError() {
        #expect(CorrelatedNormalsError.dimensionMismatch.callerMessage
            == "The correlation matrix must have one row and one column for each input.")
        #expect(CorrelatedNormalsError.invalidCorrelationMatrix.callerMessage
            == "The correlation matrix is not valid. It must be symmetric, have 1 on its diagonal, hold values between -1 and 1, and be positive semi-definite.")
    }

    // MARK: - What does not conform says nothing

    /// An error nobody wrote for a caller, carrying the kind of text that must not reach one.
    private struct ServerSideError: Error, LocalizedError {
        var errorDescription: String? { "open /Users/server/secrets.json: permission denied" }
    }

    private struct ThrowingTool: MCPToolHandler {
        let tool = MCPTool(
            name: "always_throws", description: "Throws an error that was not written for a caller.",
            inputSchema: MCPToolInputSchema(properties: [:], required: []))

        func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
            throw ServerSideError()
        }
    }

    @Test("An error that does not conform reaches the caller as a reference id and nothing else")
    func nonConformingErrorIsGeneric() async throws {
        let result = try await call(ThrowingTool(), "{}")
        #expect(result.isError)
        let reference = try #require(
            result.text.wholeMatch(of: #/The server could not complete the request\. Reference: (err-[0-9a-f]{16})/#))
        #expect(reference.output.1.count == 20)
        #expect(!result.text.contains("secrets"))
    }

    // MARK: - A malformed time series is the caller's argument

    @Test("A value of the wrong type in a time series names the path to it")
    func timeSeriesWrongType() async throws {
        let result = try await call(CreateTimeSeriesTool(), """
            {"data": [
                {"period": {"year": 2024, "month": 1, "type": "monthly"}, "value": 100},
                {"period": {"year": 2024, "month": 2, "type": "monthly"}, "value": "lots"}]}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: data[1].value must be a number")
    }

    @Test("A missing field in a time series names the path to it")
    func timeSeriesMissingField() async throws {
        let flat = try await call(CreateTimeSeriesTool(), """
            {"data": [{"value": 100}]}
            """)
        #expect(flat.isError)
        #expect(flat.text == "Missing required argument: data[0].period")

        let wrapped = try await call(CreateTimeSeriesTool(), """
            {"data": {"data": [{"period": {"month": 1, "type": "monthly"}, "value": 100}]}}
            """)
        #expect(wrapped.isError)
        #expect(wrapped.text == "Missing required argument: data.data[0].period.year")
    }

    @Test("A time series that is not an array or an object is refused, not passed to JSONSerialization",
          arguments: [#""monthly""#, "42", "true"])
    func timeSeriesScalar(value: String) async throws {
        let result = try await call(CreateTimeSeriesTool(), """
            {"data": \(value)}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: data must be a time series: an object with a 'data' array, or an array of {period, value} points")
    }

    @Test("A period the series cannot express is still MarshallingError's sentence")
    func timeSeriesMarshallingError() async throws {
        let result = try await call(CreateTimeSeriesTool(), """
            {"data": [{"period": {"year": 2024, "type": "monthly"}, "value": 100}]}
            """)
        #expect(result.isError)
        #expect(result.text == "Missing required field: month")
    }

    @Test("The MCP.Value accessor reports a malformed series the same way")
    func valueTimeSeries() throws {
        let arguments: [String: MCP.Value] = [
            "data": .array([.object(["period": .object(["year": .int(2024), "type": .int(0)]), "value": .string("x")])])
        ]
        let wrongType = #expect(throws: ArgumentDecodingError.self) {
            _ = try arguments.getTimeSeries("data")
        }
        #expect(wrongType?.callerMessage == "Invalid arguments: data[0].value must be a number")

        let scalar: [String: MCP.Value] = ["data": .string("monthly")]
        let notASeries = #expect(throws: ArgumentDecodingError.self) {
            _ = try scalar.getTimeSeries("data")
        }
        #expect(notASeries?.callerMessage == "Invalid arguments: data must be an object")
    }

    // MARK: - Handlers that report a failure themselves

    @Test("calculate_irr: BusinessMath's sentence, not an arbitrary error's description")
    func irrFailure() async throws {
        let result = try await call(IRRTool(), #"{"cashFlows": [-1000]}"#)
        #expect(result.isError)
        #expect(result.text
            == "Failed to calculate IRR: Insufficient data for IRR calculation requires at least 2 cash flows: need 2, got 1. The cash flows may not have a valid IRR.")
    }

    @Test("calculate_xirr: a sentence for the case, not 'XNPVError error 1'")
    func xirrFailure() async throws {
        let result = try await call(XIRRTool(), """
            {"cashFlows": [{"date": "2024-01-01T00:00:00Z", "amount": 100},
                           {"date": "2024-06-01T00:00:00Z", "amount": 200}]}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Failed to calculate XIRR: The cash flows must include at least one positive and one negative amount. The cash flows may not have a valid XIRR.")
    }

    @Test("calculate_mirr: BusinessMath's error reaches the caller as written")
    func mirrFailure() async throws {
        let result = try await call(MIRRTool(), """
            {"cashFlows": [100, 200, 300], "financeRate": 0.1, "reinvestmentRate": 0.1}
            """)
        #expect(result.isError)
        #expect(result.text == """
            MIRR calculation failed: Cash flows must contain both positive and negative values
            Suggestions:
            \t• Ensure you have at least one negative cash flow (outflows/investments)
            \t• Ensure you have at least one positive cash flow (inflows/returns)
            \t• Verify cash flow signs are correct (negative for costs, positive for receipts)
            """)
    }

    @Test("backtest_forecast: the forecaster's refusal is a sentence, not a case dump")
    func backtestFailure() async throws {
        let result = try await call(BacktestForecastTool(), """
            {"historicalValues": [1, 2, 3, 4, 5, 6], "initialTrainSize": 1, "horizon": 1,
             "forecaster": "drift"}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: Backtest failed: Not enough data to forecast: 2 data point(s) are required and 1 were provided.")
    }

    @Test("test_stationarity: a degenerate series is a sentence, not a case dump")
    func stationarityFailure() async throws {
        let result = try await call(TestStationarityTool(), """
            {"historicalValues": [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: Stationarity test failed: The regression cannot be fitted: y has no variance (all values approximately equal)")
    }

    @Test("analyze_scenarios: a scenario missing an input is ScenarioError's sentence")
    func scenarioMissingInput() async throws {
        let result = try await call(ScenarioAnalysisTool(), """
            {"inputNames": ["volume", "price"], "model": "volume * price", "iterations": 10,
             "scenarios": [{"name": "Only", "inputs": {"volume": {"value": 10}}}]}
            """)
        #expect(result.isError)
        #expect(result.text == """
            Scenario Analysis Failed

            Could not complete scenario analysis.

            Error: Scenario 'Only' is missing configuration for inputs: price

            Common issues:
            • Scenario missing configuration for one or more inputs
            • Distribution parameters out of valid range
            """)
    }

    @Test("No handler builds a response from an arbitrary error's text")
    func noInterpolatedErrors() throws {
        // The thirteen hand-written disclosures were all one of these three spellings.
        let sources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Sources/BusinessMathMCP")
        let files = try #require(FileManager.default.enumerator(at: sources, includingPropertiesForKeys: nil))
        var offenders: [String] = []
        var scanned: Set<String> = []
        for case let file as URL in files where file.pathExtension == "swift" {
            scanned.insert(file.lastPathComponent)
            let text = try String(contentsOf: file, encoding: .utf8)
            for (index, line) in text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).enumerated()
            where line.contains("localizedDescription") || line.contains(#"\(error)"#)
                || line.contains("String(describing: error") {
                offenders.append("\(file.lastPathComponent):\(index + 1)")
            }
        }
        #expect(scanned.isSuperset(of: [
            "TVMTools.swift", "OptimizationTools.swift", "AdvancedStatisticsTools.swift",
            "MeanVariancePortfolioTools.swift", "ScenarioAnalysisTools.swift",
            "InvestmentMetricsTools.swift", "ForecastEvaluationTools.swift",
        ]))
        #expect(offenders == [])
    }
}
