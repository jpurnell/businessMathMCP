import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Time Series Domain Tests")
struct TimeSeriesDomainTests {

    // MARK: - Time Series Tools

    @Test("calculate_simple_growth_rate computes growth between values")
    func testSimpleGrowthRate() async throws {
        let tool = CalculateGrowthRateTool()
        let args = argsFromJSON("""
            {"oldValue": 100.0, "newValue": 150.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("50") || result.text.contains("Growth"))
    }

    @Test("calculate_cagr computes compound annual growth rate")
    func testCAGR() async throws {
        let tool = CalculateCAGRTool()
        let args = argsFromJSON("""
            {"beginningValue": 100000.0, "endingValue": 200000.0, "periods": 5}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("CAGR") || result.text.contains("14") || result.text.contains("Growth"))
    }

    // MARK: - Forecasting Tools (via SeasonalityTools)

    @Test("apply_seasonality applies seasonal factors to trend values")
    func testApplySeasonality() async throws {
        let tool = ApplySeasonalTool()
        let args = argsFromJSON("""
            {"trendValues": [100.0, 100.0, 100.0, 100.0], "seasonalIndices": [0.85, 0.95, 1.0, 1.20]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Season") || result.text.contains("85") || result.text.contains("120"))
    }

    // MARK: - Trend Forecasting Tools

    @Test("forecast_linear_trend extrapolates trend from historical values")
    func testForecastLinearTrend() async throws {
        let tool = toolHandlersByName()["forecast_linear_trend"]
        guard let tool = tool else {
            Issue.record("forecast_linear_trend not found in registry")
            return
        }
        let args = argsFromJSON("""
            {"historicalValues": [100.0, 105.0, 110.0, 115.0, 120.0], "forecastPeriods": 3}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Forecast") || result.text.contains("forecast") || result.text.contains("Trend"))
    }

    // MARK: - Seasonality Tools (data format tests)

    @Test("calculate_seasonal_indices extracts seasonal patterns")
    func testSeasonalIndices() async throws {
        let tool = CalculateSeasonalIndicesTool()
        // Point shape is `"value": <scalar>`, per TimeSeriesPointJSON — not `"values": [...]`.
        // A quarterly period is expressed by its first `month` (PeriodJSON.toPeriod
        // derives the quarter as (month - 1) / 3 + 1); there is no `quarter` key.
        let args = argsFromJSON("""
            {
                "data": [
                    {"period": {"type": "quarterly", "year": 2022, "month": 1}, "value": 80.0},
                    {"period": {"type": "quarterly", "year": 2022, "month": 4}, "value": 100.0},
                    {"period": {"type": "quarterly", "year": 2022, "month": 7}, "value": 120.0},
                    {"period": {"type": "quarterly", "year": 2022, "month": 10}, "value": 100.0},
                    {"period": {"type": "quarterly", "year": 2023, "month": 1}, "value": 85.0},
                    {"period": {"type": "quarterly", "year": 2023, "month": 4}, "value": 105.0},
                    {"period": {"type": "quarterly", "year": 2023, "month": 7}, "value": 125.0},
                    {"period": {"type": "quarterly", "year": 2023, "month": 10}, "value": 105.0}
                ],
                "periodsPerYear": 4
            }
        """)
        // Two full years of quarterly data is a well-formed input for seasonal
        // decomposition, so this asserts the indices come back rather than merely
        // that nothing crashed.
        let result = try await tool.execute(arguments: args)
        #expect(result.isError != true, "seasonal indices returned an error: \(result.text)")
        #expect(result.text.contains("Seasonal") || result.text.contains("seasonal") || result.text.contains("Index"))
    }

    // MARK: - Growth Analysis Tools

    @Test("calculate_growth_rate computes growth from two values")
    func testGrowthRate() async throws {
        let tool = GrowthRateTool()
        let args = argsFromJSON("""
            {"fromValue": 1000000.0, "toValue": 1150000.0, "metricName": "Revenue"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Growth") || result.text.contains("15") || result.text.contains("Rate"))
    }

    @Test("apply_growth_rate projects values forward")
    func testApplyGrowthRate() async throws {
        let tool = ApplyGrowthTool()
        let args = argsFromJSON("""
            {"baseValue": 1000000.0, "annualGrowthRate": 0.15, "periods": 5}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Growth") || result.text.contains("Projection") || result.text.contains("Year"))
    }
}
