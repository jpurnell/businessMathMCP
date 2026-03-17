import Testing
import Foundation
@testable import BusinessMathMCP

@Suite("Utility Domain Tests")
struct UtilityDomainTests {

    @Test("calculate_rolling_sum computes rolling window sums")
    func testRollingSum() async throws {
        let tool = RollingSumTool()
        let args = argsFromJSON("""
            {"values": [100.0, 105.0, 110.0, 115.0, 120.0, 125.0], "windowSize": 3}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Rolling") || result.text.contains("Sum") || result.text.contains("315"))
    }

    @Test("calculate_percent_change computes period-over-period changes")
    func testPercentChange() async throws {
        let tool = PercentChangeTool()
        let args = argsFromJSON("""
            {"values": [100.0, 110.0, 105.0, 120.0]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("10") || result.text.contains("Change") || result.text.contains("Percent"))
    }

    @Test("calculate_ttm_metrics computes trailing twelve months")
    func testTTMMetrics() async throws {
        let tool = TTMMetricsTool()
        let args = argsFromJSON("""
            {
                "monthlyValues": [100.0, 110.0, 120.0, 130.0, 140.0, 150.0, 160.0, 170.0, 180.0, 190.0, 200.0, 210.0],
                "metricName": "Revenue"
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Revenue") || result.text.contains("TTM"))
    }

    @Test("analyze_budget_vs_actual compares budgeted to actual values")
    func testBudgetVsActual() async throws {
        let tool = BudgetVsActualTool()
        let args = argsFromJSON("""
            {
                "budgeted": 1000000,
                "actual": 1100000,
                "metricName": "Revenue",
                "isRevenueType": true
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Budget") || result.text.contains("Variance") || result.text.contains("Actual"))
    }
}
