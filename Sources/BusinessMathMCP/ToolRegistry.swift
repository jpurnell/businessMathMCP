import Foundation
import SwiftMCPServer

// MARK: - Tool Registry

/// Collect ALL registered tool handlers from all registration functions.
/// When adding a new tool category, add its get*Tools() call here.
public func allToolHandlers() -> [any MCPToolHandler] {
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
    // getAdvancedSimulationTools() intentionally excluded — API not yet stable
    handlers += getFinancialStatementTools()
    handlers += getOperationalMetricsTools()
    handlers += getCapitalStructureTools()
    handlers += getEnhancedCovenantTools()
    handlers += getMultiPeriodAnalysisTools()
    handlers += getAdvancedFinancialModelingTools()
    return handlers
}
