import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Forecast Evaluation Domain Tests")
struct ForecastEvaluationDomainTests {

    // MARK: - backtest_forecast

    @Test("backtest_forecast (naive) reports out-of-sample MASE")
    func testBacktestNaive() async throws {
        let tool = BacktestForecastTool()
        let args = argsFromJSON("""
            {"historicalValues": [10,11,12,13,14,15,16,17], "forecaster": "naive",
             "initialTrainSize": 4, "horizon": 1}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Backtest"))
        #expect(result.text.contains("MASE"))
    }

    @Test("backtest_forecast (seasonal_naive) runs on a seasonal series")
    func testBacktestSeasonalNaive() async throws {
        let tool = BacktestForecastTool()
        let args = argsFromJSON("""
            {"historicalValues": [10,20,30,40,10,20,30,40,10,20,30,40],
             "forecaster": "seasonal_naive", "seasonLength": 4,
             "initialTrainSize": 8, "horizon": 2}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("seasonal_naive"))
    }

    @Test("backtest_forecast (seasonal_naive) without seasonLength errors")
    func testBacktestSeasonalNaiveMissingSeason() async throws {
        let tool = BacktestForecastTool()
        let args = argsFromJSON("""
            {"historicalValues": [10,20,30,40,10,20,30,40], "forecaster": "seasonal_naive",
             "initialTrainSize": 4, "horizon": 1}
        """)
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: args)
        }
    }

    @Test("backtest_forecast rejects a series that is too short")
    func testBacktestTooShort() async throws {
        let tool = BacktestForecastTool()
        let args = argsFromJSON("""
            {"historicalValues": [1,2,3], "forecaster": "naive",
             "initialTrainSize": 5, "horizon": 2}
        """)
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: args)
        }
    }

    // MARK: - assess_forecastability

    @Test("assess_forecastability returns a verdict")
    func testAssessForecastability() async throws {
        let tool = AssessForecastabilityTool()
        let args = argsFromJSON("""
            {"historicalValues": [1,2,3,4,1,2,3,4,1,2,3,4]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Forecastability"))
        #expect(result.text.contains("Verdict"))
    }

    @Test("assess_forecastability rejects too-few points")
    func testAssessForecastabilityTooFew() async throws {
        let tool = AssessForecastabilityTool()
        let args = argsFromJSON("""
            {"historicalValues": [1,2]}
        """)
        await #expect(throws: (any Error).self) {
            _ = try await tool.execute(arguments: args)
        }
    }

    // MARK: - test_stationarity

    @Test("test_stationarity reports ADF and KPSS verdicts")
    func testStationarity() async throws {
        let tool = TestStationarityTool()
        let args = argsFromJSON("""
            {"historicalValues": [1,3,6,8,13,15,22,24,33,35,46,48]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Dickey-Fuller"))
        #expect(result.text.contains("KPSS"))
        #expect(result.text.contains("Combined verdict"))
    }

    @Test("test_stationarity honors the trend regression option")
    func testStationarityTrend() async throws {
        let tool = TestStationarityTool()
        let args = argsFromJSON("""
            {"historicalValues": [1,3,6,8,13,15,22,24,33,35,46,48], "kpssRegression": "trend"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("trend"))
    }

    // MARK: - Registration

    @Test("forecast evaluation tools are registered")
    func testRegistration() {
        let names = Set(toolHandlersByName().keys)
        #expect(names.contains("backtest_forecast"))
        #expect(names.contains("assess_forecastability"))
        #expect(names.contains("test_stationarity"))
    }
}
