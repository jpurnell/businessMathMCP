import Testing
import Foundation
import MCP
@testable import BusinessMathMCP

// MARK: - MCPToolCallResult Convenience

extension MCPToolCallResult {
    /// Whether this result represents an error
    var isError: Bool {
        return result.isError ?? false
    }

    /// Extract the text content from the first content block
    var text: String {
        guard let firstContent = result.content.first else {
            return ""
        }
        switch firstContent {
        case .text(let string):
            return string
        case .image, .resource, .audio:
            return ""
        @unknown default:
            return ""
        }
    }
}

// MARK: - Argument Construction Helpers

/// Build AnyCodable arguments from a JSON string, matching the MCP wire format path:
/// JSON -> MCP.Value -> AnyCodable (same conversion the real server performs)
func decodeArguments(_ json: String) throws -> [String: AnyCodable] {
    guard let data = json.data(using: .utf8) else {
        throw MCPTestError.invalidJson
    }
    let mcpValue = try JSONDecoder().decode(MCP.Value.self, from: data)
    guard case .object(let dict) = mcpValue else {
        throw MCPTestError.decodingFailed("JSON must be an object")
    }
    return dict.mapValues { AnyCodable($0) }
}

/// Build AnyCodable arguments from a JSON string literal.
/// Shorthand for decodeArguments that returns an empty dict on failure.
func argsFromJSON(_ json: String) -> [String: AnyCodable] {
    return (try? decodeArguments(json)) ?? [:]
}

// MARK: - Test Error Type

enum MCPTestError: Error, LocalizedError {
    case invalidJson
    case decodingFailed(String)
    case unexpectedResult(String)

    var errorDescription: String? {
        switch self {
        case .invalidJson:
            return "Invalid JSON in test"
        case .decodingFailed(let msg):
            return "Decoding failed: \(msg)"
        case .unexpectedResult(let msg):
            return "Unexpected result: \(msg)"
        }
    }
}

// MARK: - Tool Collection

/// Collect ALL registered tool handlers from all registration functions.
/// This mirrors the registration list in main.swift.
/// When adding a new tool category, add its get*Tools() call here.
func allToolHandlers() -> [any MCPToolHandler] {
    var handlers: [any MCPToolHandler] = []
    handlers += getTVMTools()
    handlers += getTimeSeriesTools()
    handlers += getForecastingTools()
    handlers += getDebtTools()
    handlers += getStatisticalTools()
    handlers += getMonteCarloTools()
    handlers += getHypothesisTestingTools()
    handlers += getAdvancedStatisticsTools()
    handlers += getOptimizationTools()
    handlers += getAdaptiveOptimizationTools()
    handlers += getPerformanceBenchmarkTools()
    handlers += getParallelOptimizationTools()
    handlers += getPortfolioTools()
    handlers += getMeanVariancePortfolioTools()
    handlers += getScenarioAnalysisTools()
    handlers += getRealOptionsTools()
    handlers += getRiskAnalyticsTools()
    handlers += getFinancialRatiosTools()
    handlers += getExtendedFinancialRatiosTools()
    handlers += getWorkingCapitalTools()
    handlers += getAdvancedRatioTools()
    handlers += getExtendedDebtTools()
    handlers += getFinancingTools()
    handlers += getLeaseAndCovenantTools()
    handlers += getUtilityTools()
    handlers += getBayesianTools()
    handlers += getValuationCalculatorsTools()
    handlers += getEquityValuationTools()
    handlers += getBondValuationTools()
    handlers += getCreditDerivativesTools()
    handlers += getInvestmentMetricsTools()
    handlers += getLoanPaymentAnalysisTools()
    handlers += getGrowthAnalysisTools()
    handlers += getTrendForecastingTools()
    handlers += getSeasonalityTools()
    handlers += getAdvancedOptionsTools()
    handlers += getAdvancedOptimizationTools()
    handlers += getIntegerProgrammingTools()
    handlers += getHeuristicOptimizationTools()
    handlers += getMetaheuristicOptimizationTools()
    // getAdvancedSimulationTools() intentionally excluded — commented out in main.swift
    handlers += getFinancialStatementTools()
    handlers += getOperationalMetricsTools()
    handlers += getCapitalStructureTools()
    handlers += getEnhancedCovenantTools()
    handlers += getMultiPeriodAnalysisTools()
    handlers += getAdvancedFinancialModelingTools()
    return handlers
}

/// Map of tool name -> tool handler for direct lookup
func toolHandlersByName() -> [String: any MCPToolHandler] {
    var map: [String: any MCPToolHandler] = [:]
    for handler in allToolHandlers() {
        map[handler.tool.name] = handler
    }
    return map
}
