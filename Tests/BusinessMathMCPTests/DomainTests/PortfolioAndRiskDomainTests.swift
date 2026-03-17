import Testing
import Foundation
@testable import BusinessMathMCP

@Suite("Portfolio and Risk Domain Tests")
struct PortfolioAndRiskDomainTests {

    // MARK: - Portfolio Tools (MeanVariancePortfolio already tested separately)

    @Test("optimize_portfolio finds optimal weights for 3-asset portfolio")
    func testOptimizePortfolio() async throws {
        let tool = OptimizePortfolioTool()
        let args = argsFromJSON("""
            {
                "assets": ["Stock A", "Stock B", "Bond"],
                "returns": [
                    [0.08, 0.05, -0.02, 0.10, 0.06],
                    [0.06, 0.04, 0.02, 0.08, 0.05],
                    [0.02, 0.03, 0.02, 0.03, 0.02]
                ],
                "riskFreeRate": 0.02
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Portfolio") || result.text.contains("Weight") || result.text.contains("weight"))
    }

    @Test("calculate_efficient_frontier produces frontier points")
    func testEfficientFrontier() async throws {
        let tool = EfficientFrontierTool()
        let args = argsFromJSON("""
            {
                "assets": ["Stock A", "Stock B", "Bond"],
                "returns": [
                    [0.08, 0.05, -0.02, 0.10, 0.06],
                    [0.06, 0.04, 0.02, 0.08, 0.05],
                    [0.02, 0.03, 0.02, 0.03, 0.02]
                ],
                "riskFreeRate": 0.02,
                "points": 10
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Frontier") || result.text.contains("frontier") || result.text.contains("Return"))
    }

    @Test("calculate_risk_parity allocates by equal risk contribution")
    func testRiskParity() async throws {
        let tool = RiskParityAllocationTool()
        let args = argsFromJSON("""
            {
                "assets": ["Stock A", "Stock B", "Bond"],
                "returns": [
                    [0.08, 0.05, -0.02, 0.10, 0.06],
                    [0.06, 0.04, 0.02, 0.08, 0.05],
                    [0.02, 0.03, 0.02, 0.03, 0.02]
                ]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Risk") || result.text.contains("Allocation") || result.text.contains("Weight"))
    }

    // MARK: - Risk Analytics Tools

    @Test("calculate_value_at_risk computes VaR from historical returns")
    func testValueAtRisk() async throws {
        let tool = ValueAtRiskTool()
        let args = argsFromJSON("""
            {
                "returns": [0.08, 0.05, -0.02, 0.10, -0.01, 0.07, 0.04, -0.03, 0.06, 0.02,
                            -0.04, 0.09, 0.03, -0.01, 0.05, 0.08, -0.02, 0.06, 0.01, -0.05],
                "portfolioValue": 1000000,
                "confidenceLevel": 0.95
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("VaR") || result.text.contains("Value at Risk"))
    }

    @Test("run_stress_test analyzes scenario impact")
    func testStressTest() async throws {
        let tool = StressTestTool()
        let args = argsFromJSON("""
            {
                "scenario": "recession",
                "baseRevenue": 5000000,
                "baseCosts": 3000000,
                "baseNPV": 2000000
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Stress") || result.text.contains("Scenario") || result.text.contains("Impact"))
    }
}
