import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Tests that verify tool registration, discovery, and dispatch through the registry.
@Suite("Tool Registration Tests")
struct ToolRegistrationTests {

    // MARK: - Registry Round-Trip

    @Test("Registry registers and lists all unique tools")
    func testRegistryRoundTrip() async throws {
        let registry = ToolDefinitionRegistry()
        let handlers = allToolHandlers()

        for handler in handlers {
            try await registry.register(handler.toToolDefinition())
        }

        let listed = await registry.listTools()
        let uniqueNames = Set(handlers.map { $0.tool.name })
        #expect(listed.count == uniqueNames.count,
                "Registry listed \(listed.count) tools but \(uniqueNames.count) unique names exist")
    }

    @Test("Registry tool names match handler tool names")
    func testNameConsistency() async throws {
        let registry = ToolDefinitionRegistry()
        let handlers = allToolHandlers()

        for handler in handlers {
            try await registry.register(handler.toToolDefinition())
        }

        let registeredNames = Set(await registry.listTools().map(\.name))
        let handlerNames = Set(handlers.map { $0.tool.name })

        #expect(registeredNames == handlerNames,
                "Mismatch between registry and handler names")
    }

    // MARK: - Dispatch

    @Test("Registry dispatches known tool by name")
    func testDispatchKnownTool() async throws {
        let registry = ToolDefinitionRegistry()
        for handler in getTVMTools() {
            try await registry.register(handler.toToolDefinition())
        }

        let result = try await registry.executeTool(
            name: "calculate_present_value",
            arguments: [
                "futureValue": .double(1000),
                "rate": .double(0.05),
                "periods": .int(10)
            ]
        )

        #expect(result.isError != true,
                "Known tool should execute successfully")
    }

    @Test("Registry returns error for unknown tool name")
    func testDispatchUnknownTool() async throws {
        let registry = ToolDefinitionRegistry()
        let result = try await registry.executeTool(
            name: "nonexistent_tool",
            arguments: nil
        )
        #expect(result.isError == true,
                "Unknown tool should return error")
    }

    // MARK: - Registration Function Coverage

    @Test("Every registration function returns at least one handler")
    func testRegistrationFunctionsNonEmpty() {
        let functions: [(String, [any MCPToolHandler])] = [
            ("getTVMTools", getTVMTools()),
            ("getTimeSeriesTools", getTimeSeriesTools()),
            ("getForecastingTools", getForecastingTools()),
            ("getDebtTools", getDebtTools()),
            ("getStatisticalTools", getStatisticalTools()),
            ("getMonteCarloTools", getMonteCarloTools()),
            ("getHypothesisTestingTools", getHypothesisTestingTools()),
            ("getAdvancedStatisticsTools", getAdvancedStatisticsTools()),
            ("getOptimizationTools", getOptimizationTools()),
            ("getAdaptiveOptimizationTools", getAdaptiveOptimizationTools()),
            ("getPerformanceBenchmarkTools", getPerformanceBenchmarkTools()),
            ("getParallelOptimizationTools", getParallelOptimizationTools()),
            ("getPortfolioTools", getPortfolioTools()),
            ("getMeanVariancePortfolioTools", getMeanVariancePortfolioTools()),
            ("getScenarioAnalysisTools", getScenarioAnalysisTools()),
            ("getRealOptionsTools", getRealOptionsTools()),
            ("getRiskAnalyticsTools", getRiskAnalyticsTools()),
            ("getFinancialRatiosTools", getFinancialRatiosTools()),
            ("getExtendedFinancialRatiosTools", getExtendedFinancialRatiosTools()),
            ("getWorkingCapitalTools", getWorkingCapitalTools()),
            ("getAdvancedRatioTools", getAdvancedRatioTools()),
            ("getExtendedDebtTools", getExtendedDebtTools()),
            ("getFinancingTools", getFinancingTools()),
            ("getLeaseAndCovenantTools", getLeaseAndCovenantTools()),
            ("getUtilityTools", getUtilityTools()),
            ("getBayesianTools", getBayesianTools()),
            ("getValuationCalculatorsTools", getValuationCalculatorsTools()),
            ("getEquityValuationTools", getEquityValuationTools()),
            ("getBondValuationTools", getBondValuationTools()),
            ("getCreditDerivativesTools", getCreditDerivativesTools()),
            ("getInvestmentMetricsTools", getInvestmentMetricsTools()),
            ("getLoanPaymentAnalysisTools", getLoanPaymentAnalysisTools()),
            ("getGrowthAnalysisTools", getGrowthAnalysisTools()),
            ("getTrendForecastingTools", getTrendForecastingTools()),
            ("getSeasonalityTools", getSeasonalityTools()),
            ("getAdvancedOptionsTools", getAdvancedOptionsTools()),
            ("getAdvancedOptimizationTools", getAdvancedOptimizationTools()),
            ("getIntegerProgrammingTools", getIntegerProgrammingTools()),
            ("getHeuristicOptimizationTools", getHeuristicOptimizationTools()),
            ("getMetaheuristicOptimizationTools", getMetaheuristicOptimizationTools()),
            ("getFinancialStatementTools", getFinancialStatementTools()),
            ("getOperationalMetricsTools", getOperationalMetricsTools()),
            ("getCapitalStructureTools", getCapitalStructureTools()),
            ("getEnhancedCovenantTools", getEnhancedCovenantTools()),
            ("getMultiPeriodAnalysisTools", getMultiPeriodAnalysisTools()),
            ("getAdvancedFinancialModelingTools", getAdvancedFinancialModelingTools()),
        ]

        for (name, handlers) in functions {
            #expect(!handlers.isEmpty,
                    "\(name) returned 0 handlers")
        }
    }
}
