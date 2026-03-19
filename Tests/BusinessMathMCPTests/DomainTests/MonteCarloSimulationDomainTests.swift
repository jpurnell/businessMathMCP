import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Monte Carlo Simulation Domain Tests")
struct MonteCarloSimulationDomainTests {

    // MARK: - Monte Carlo Tools (ScenarioAnalysis already tested separately)

    @Test("create_distribution creates normal distribution")
    func testCreateDistribution() async throws {
        let tool = CreateDistributionTool()
        let args = argsFromJSON("""
            {"type": "normal", "parameters": {"mean": 100000.0, "stdDev": 15000.0}}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Normal") || result.text.contains("Distribution") || result.text.contains("100"))
    }

    @Test("analyze_simulation_results computes statistics from values")
    func testAnalyzeSimulationResults() async throws {
        let tool = AnalyzeSimulationResultsTool()
        let args = argsFromJSON("""
            {"values": [95000.0, 100000.0, 105000.0, 110000.0, 98000.0, 102000.0, 107000.0, 99000.0, 103000.0, 108000.0]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Mean") || result.text.contains("Median") || result.text.contains("Statistics"))
    }

    @Test("calculate_simulation_var computes VaR from simulation output")
    func testSimulationVaR() async throws {
        let tool = CalculateValueAtRiskTool()
        let args = argsFromJSON("""
            {
                "values": [95000.0, 100000.0, 105000.0, 110000.0, 98000.0, 102000.0, 107000.0, 99000.0, 103000.0, 108000.0,
                           92000.0, 96000.0, 104000.0, 111000.0, 97000.0, 101000.0, 106000.0, 93000.0, 109000.0, 100500.0],
                "confidenceLevel": 0.95
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("VaR") || result.text.contains("Value at Risk") || result.text.contains("95"))
    }

    @Test("calculate_probability computes probability from distribution")
    func testCalculateProbability() async throws {
        let tool = CalculateProbabilityTool()
        let args = argsFromJSON("""
            {
                "values": [95000.0, 100000.0, 105000.0, 110000.0, 98000.0, 102000.0, 107000.0, 99000.0, 103000.0, 108000.0],
                "type": "above",
                "threshold": 105000.0
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Probability") || result.text.contains("probability") || result.text.contains("%"))
    }

    @Test("sensitivity_analysis identifies impact of variable changes")
    func testSensitivityAnalysis() async throws {
        let tool = SensitivityAnalysisTool()
        let args = argsFromJSON("""
            {
                "baseValue": 1000000.0,
                "variableRange": {"percentChange": 20},
                "calculation": "{0} * 0.4",
                "variableName": "Revenue",
                "steps": 5
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Sensitivity") || result.text.contains("sensitivity") || result.text.contains("Impact"))
    }

    @Test("tornado_analysis ranks variables by impact")
    func testTornadoAnalysis() async throws {
        let tool = TornadoAnalysisTool()
        let args = argsFromJSON("""
            {
                "variables": [
                    {"name": "Revenue", "baseValue": 1000000.0, "lowValue": 800000.0, "highValue": 1200000.0},
                    {"name": "Costs", "baseValue": 600000.0, "lowValue": 500000.0, "highValue": 700000.0}
                ],
                "calculation": "{0} - {1}"
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Tornado") || result.text.contains("tornado") || result.text.contains("Impact"))
    }
}
