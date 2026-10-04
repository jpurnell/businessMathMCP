import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// A tool that sorts a figure into words — "Excellent", "Weak", "Slow" — does it with a
/// chain of comparisons, and every comparison with a NaN is false. A ratio that is not a
/// number therefore fell through to the trailing `else` and was reported as whatever that
/// arm says ("Weak", "High", "Fast"), and an infinite one as the best or worst band. JSON
/// cannot carry either value, but arithmetic on the largest finite arguments produces
/// both, so a remote caller can reach them. Each chain now says so instead.
@Suite("Classification of values that are not finite numbers")
struct NonFiniteClassificationTests {

    private func call(
        _ handler: any MCPToolHandler, values arguments: [String: MCP.Value]
    ) async throws -> (text: String, isError: Bool) {
        let registry = ToolDefinitionRegistry()
        try await registry.register(handler.toToolDefinition())
        let result = try await registry.executeTool(name: handler.tool.name, arguments: arguments)
        guard case .text(let text, _, _) = result.content.first else {
            throw MCPTestError.unexpectedResult("no text content")
        }
        return (text, result.isError ?? false)
    }

    private func call(
        _ handler: any MCPToolHandler, _ json: String
    ) async throws -> (text: String, isError: Bool) {
        let value = try JSONDecoder().decode(MCP.Value.self, from: Data(json.utf8))
        guard case .object(let arguments) = value else {
            throw MCPTestError.decodingFailed("arguments must be a JSON object")
        }
        return try await call(handler, values: arguments)
    }

    /// The lines of `text` that begin with `prefix`, with indentation removed.
    private func lines(of text: String, startingWith prefix: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix(prefix) }
    }

    /// Calls `handler` and returns its `• Interpretation:` lines.
    private func interpretation(
        _ handler: any MCPToolHandler, _ json: String
    ) async throws -> [String] {
        let result = try await call(handler, json)
        #expect(!result.isError)
        return lines(of: result.text, startingWith: "• Interpretation:")
    }

    private func notAvailable(_ subject: String) -> [String] {
        ["• Interpretation: Not available - \(subject) is not a finite number for these inputs"]
    }

    // MARK: - FinancialRatiosTools

    @Test("The nine core ratios say so when the ratio overflows")
    func coreRatiosOverflow() async throws {
        #expect(try await interpretation(AssetTurnoverTool(), """
            {"netSales": 1e308, "averageTotalAssets": 1e-300}
            """) == notAvailable("asset turnover"))
        #expect(try await interpretation(CurrentRatioTool(), """
            {"currentAssets": 1e308, "currentLiabilities": 1e-300}
            """) == notAvailable("the current ratio"))
        #expect(try await interpretation(QuickRatioTool(), """
            {"currentAssets": 1e308, "inventory": -1e308, "currentLiabilities": 1000}
            """) == notAvailable("the quick ratio"))
        #expect(try await interpretation(DebtToEquityTool(), """
            {"totalLiabilities": 1e308, "shareholderEquity": 1e-300}
            """) == notAvailable("the debt to equity ratio"))
        #expect(try await interpretation(InterestCoverageTool(), """
            {"earningsBeforeInterestAndTax": 1e308, "interestExpense": 1e-300}
            """) == notAvailable("interest coverage"))
        #expect(try await interpretation(InventoryTurnoverTool(), """
            {"costOfGoodsSold": 1e308, "averageInventory": 1e-300}
            """) == notAvailable("inventory turnover"))
        #expect(try await interpretation(ProfitMarginTool(), """
            {"netIncome": -1e308, "revenue": 1e-300}
            """) == notAvailable("the profit margin"))
        #expect(try await interpretation(ROETool(), """
            {"netIncome": -1e308, "shareholderEquity": 1e-300}
            """) == notAvailable("ROE"))
        #expect(try await interpretation(ROITool(), """
            {"gainFromInvestment": -1e308, "costOfInvestment": 1e-300}
            """) == notAvailable("ROI"))
    }

    @Test("A finite asset turnover is classified as before")
    func assetTurnoverFinite() async throws {
        #expect(try await interpretation(AssetTurnoverTool(), """
            {"netSales": 2000000, "averageTotalAssets": 1000000}
            """) == ["• Interpretation: Excellent - Company efficiently converts assets into sales"])
        #expect(try await interpretation(AssetTurnoverTool(), """
            {"netSales": 100000, "averageTotalAssets": 1000000}
            """) == ["• Interpretation: Low - Consider reviewing asset utilization or business model"])
        #expect(try await interpretation(DebtToEquityTool(), """
            {"totalLiabilities": 3000000, "shareholderEquity": 1000000}
            """) == ["• Interpretation: High - Significant leverage, higher financial risk"])
    }

    // MARK: - FinancialRatiosToolsExtensions

    @Test("ROA, cash ratio and debt ratio say so when the ratio overflows")
    func extendedRatiosOverflow() async throws {
        #expect(try await interpretation(ROATool(), """
            {"netIncome": -1e308, "totalAssets": 1e-300}
            """) == notAvailable("ROA"))
        #expect(try await interpretation(CashRatioTool(), """
            {"cashAndEquivalents": -1e308, "currentLiabilities": 1e-300}
            """) == notAvailable("the cash ratio"))
        #expect(try await interpretation(DebtRatioTool(), """
            {"totalDebt": 1e308, "totalAssets": 1e-300}
            """) == notAvailable("the debt ratio"))
    }

    @Test("A finite cash ratio is classified as before")
    func cashRatioFinite() async throws {
        #expect(try await interpretation(CashRatioTool(), """
            {"cashAndEquivalents": 200, "currentLiabilities": 1000}
            """) == ["• Interpretation: Adequate - Typical for most businesses"])
        #expect(try await interpretation(CashRatioTool(), """
            {"cashAndEquivalents": 50, "currentLiabilities": 1000}
            """) == ["• Interpretation: Low - Limited immediate liquidity, may need credit lines"])
    }

    // MARK: - ValuationCalculatorsTools

    @Test("P/B, P/S, EV/Sales and debt-to-assets say so when the ratio overflows")
    func valuationRatiosOverflow() async throws {
        #expect(try await interpretation(PriceToBookTool(), """
            {"marketPrice": 1e308, "bookValuePerShare": 1e-300}
            """) == notAvailable("the P/B ratio"))
        #expect(try await interpretation(PriceToSalesTool(), """
            {"marketCap": 1e308, "totalRevenue": 1e-300}
            """) == notAvailable("the P/S ratio"))
        #expect(try await interpretation(EVToSalesTool(), """
            {"enterpriseValue": 1e308, "totalRevenue": 1e-300}
            """) == notAvailable("the EV/Sales ratio"))
        #expect(try await interpretation(DebtToAssetsTool(), """
            {"totalDebt": 1e308, "totalAssets": 1e-300}
            """) == notAvailable("the debt-to-assets ratio"))
    }

    @Test("A finite price-to-book ratio is classified as before")
    func priceToBookFinite() async throws {
        #expect(try await interpretation(PriceToBookTool(), """
            {"marketPrice": 50, "bookValuePerShare": 10}
            """) == ["• Interpretation: High - Very asset-light or growth business"])
        #expect(try await interpretation(PriceToBookTool(), """
            {"marketPrice": 5, "bookValuePerShare": 10}
            """) == ["• Interpretation: Below Book - Trading at discount to net assets"])
    }

    // MARK: - WorkingCapitalTools

    @Test("DIO, DSO and DPO say so when the day count overflows")
    func daysOutstandingOverflow() async throws {
        #expect(try await interpretation(DaysInventoryOutstandingTool(), """
            {"averageInventory": 1e308, "costOfGoodsSold": 1e-300}
            """) == notAvailable("DIO"))
        #expect(try await interpretation(DaysSalesOutstandingTool(), """
            {"averageAccountsReceivable": 1e308, "netSales": 1e-300}
            """) == notAvailable("DSO"))
        #expect(try await interpretation(DaysPayableOutstandingTool(), """
            {"averageAccountsPayable": -1e308, "costOfGoodsSold": 1e-300}
            """) == notAvailable("DPO"))
    }

    @Test("A finite DPO is classified as before")
    func daysPayableFinite() async throws {
        #expect(try await interpretation(DaysPayableOutstandingTool(), """
            {"averageAccountsPayable": 10, "costOfGoodsSold": 365}
            """) == ["• Interpretation: Fast - Paying quickly, may miss cash management opportunities"])
        #expect(try await interpretation(DaysPayableOutstandingTool(), """
            {"averageAccountsPayable": 100, "costOfGoodsSold": 365}
            """) == ["• Interpretation: Extended - Good cash preservation, but monitor supplier relationships"])
    }

    // MARK: - UtilityTools

    @Test("Budget vs actual says so when the variance percentage overflows")
    func budgetVarianceOverflow() async throws {
        #expect(try await interpretation(BudgetVsActualTool(), """
            {"budgeted": 1e-300, "actual": 1e308, "metricName": "Revenue", "isRevenueType": true}
            """) == notAvailable("the variance percentage"))
    }

    @Test("A finite budget variance is classified as before")
    func budgetVarianceFinite() async throws {
        #expect(try await interpretation(BudgetVsActualTool(), """
            {"budgeted": 100, "actual": 150, "metricName": "Revenue", "isRevenueType": true}
            """) == ["• Interpretation: Significant variance - needs investigation"])
        #expect(try await interpretation(BudgetVsActualTool(), """
            {"budgeted": 100, "actual": 101, "metricName": "Revenue", "isRevenueType": true}
            """) == ["• Interpretation: Minimal variance - on track with budget"])
    }

    // MARK: - OperationalMetricsTools

    @Test("SaaS benchmarks say so when NRR is 0/0-like and the magic number overflows")
    func saasRetentionAndMagicNumber() async throws {
        // Net new MRR of -1e308 makes the starting MRR infinite, so NRR is inf / inf, and
        // annualising it makes the magic number infinite.
        let result = try await call(CalculateSaaSMetricsTool(), """
            {"entity": "Acme", "period": "2025-Q1", "mrr": 1e308, "new_mrr": -1e308,
             "sales_and_marketing": 1000}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️ NRR")
                == ["⚠️ NRR: not a finite number for these inputs"])
        #expect(lines(of: result.text, startingWith: "❌ NRR") == [])
        #expect(lines(of: result.text, startingWith: "⚠️ Magic Number")
                == ["⚠️ Magic Number: not a finite number for these inputs"])
        #expect(lines(of: result.text, startingWith: "❌ Magic Number") == [])
    }

    @Test("SaaS benchmarks say so when LTV:CAC overflows")
    func saasLifetimeValueRatio() async throws {
        let result = try await call(CalculateSaaSMetricsTool(), """
            {"entity": "Acme", "period": "2025-Q1", "mrr": 1e308, "customers": 100,
             "new_customers": 10, "churned_customers": 5, "sales_and_marketing": 1000}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️ LTV:CAC")
                == ["⚠️ LTV:CAC: not a finite number for these inputs"])
        #expect(lines(of: result.text, startingWith: "✅ LTV:CAC") == [])
    }

    @Test("Each SaaS benchmark names a value that is not a finite number",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func saasBenchmarkSeam(value: Double) {
        #expect(CalculateSaaSMetricsTool.benchmarks(
            netRevenueRetention: value, ltvToCACRatio: value,
            customerChurnRate: value, magicNumber: value
        ) == [
            "⚠️ NRR: not a finite number for these inputs",
            "⚠️ LTV:CAC: not a finite number for these inputs",
            "⚠️ Churn: not a finite number for these inputs",
            "⚠️ Magic Number: not a finite number for these inputs"
        ])
    }

    @Test("Finite SaaS benchmarks are classified as before")
    func saasBenchmarksFinite() async throws {
        #expect(CalculateSaaSMetricsTool.benchmarks(
            netRevenueRetention: 1.1, ltvToCACRatio: 2.0, customerChurnRate: 0.2, magicNumber: 0.1
        ) == [
            "✅ NRR > 100%: Excellent retention with expansion",
            "⚠️ LTV:CAC 1.5-3×: Marginal unit economics",
            "❌ Churn > 10%: High churn is a red flag",
            "❌ Magic Number < 0.5: Poor sales efficiency"
        ])
        #expect(CalculateSaaSMetricsTool.benchmarks(
            netRevenueRetention: nil, ltvToCACRatio: nil, customerChurnRate: 0.01, magicNumber: nil
        ) == ["✅ Churn < 5%: Excellent retention"])

        // Starting MRR 1,200, ending 1,000: NRR 83%.
        let result = try await call(CalculateSaaSMetricsTool(), """
            {"entity": "Acme", "period": "2025-Q1", "mrr": 1000, "churned_mrr": 200}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "❌ NRR")
                == ["❌ NRR < 90%: Retention concerns"])
    }

    @Test("E-commerce insights say so when conversion and gross margin overflow")
    func ecommerceOverflow() async throws {
        let result = try await call(CalculateEcommerceMetricsTool(), """
            {"entity": "Shop", "period": "2025-Q1", "orders": 1e308, "gmv": 1000,
             "sessions": 1e-300, "revenue": 1e308, "cogs": -1e308}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️ Conversion rate")
                == ["⚠️ Conversion rate: not a finite number for these inputs"])
        #expect(lines(of: result.text, startingWith: "✅ Conversion rate") == [])
        #expect(lines(of: result.text, startingWith: "⚠️ Gross margin")
                == ["⚠️ Gross margin: not a finite number for these inputs"])
        #expect(lines(of: result.text, startingWith: "✅ Gross margin") == [])
    }

    @Test("Finite e-commerce insights are classified as before")
    func ecommerceFinite() async throws {
        let result = try await call(CalculateEcommerceMetricsTool(), """
            {"entity": "Shop", "period": "2025-Q1", "orders": 100, "gmv": 10000,
             "sessions": 10000, "cogs": 9000}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️ Conversion rate")
                == ["⚠️ Conversion rate < 2%: Optimize checkout and product pages"])
        #expect(lines(of: result.text, startingWith: "❌ Gross margin")
                == ["❌ Gross margin < 25%: Pricing or cost concerns"])
    }

    // MARK: - FinancialStatementTools

    @Test("Validation warns, and does not pass, a net margin that overflows")
    func netMarginOverflow() async throws {
        let result = try await call(ValidateFinancialStatementsTool(), """
            {"income_statement": {"total_revenue": 1e-300, "net_income": 1e308}}
            """)
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️") == [
            "⚠️ Net margin is not a finite number for these inputs (net income ÷ total revenue)"
        ])
        #expect(lines(of: result.text, startingWith: "✅ Net margin") == [])
    }

    @Test("Validation warns, and does not pass, a net margin of zero over zero")
    func netMarginZeroOverZero() async throws {
        let result = try await call(ValidateFinancialStatementsTool(), values: [
            "income_statement": .object(["total_revenue": .double(0), "net_income": .double(0)])
        ])
        #expect(!result.isError)
        #expect(lines(of: result.text, startingWith: "⚠️") == [
            "⚠️ Net margin is not a finite number for these inputs (net income ÷ total revenue)"
        ])
        #expect(lines(of: result.text, startingWith: "✅ Net margin") == [])
    }

    @Test("A finite net margin is checked as before")
    func netMarginFinite() async throws {
        let high = try await call(ValidateFinancialStatementsTool(), """
            {"income_statement": {"total_revenue": 100.5, "net_income": 80.4}}
            """)
        #expect(lines(of: high.text, startingWith: "✅ Net margin") == ["✅ Net margin: 80.0%"])
        #expect(lines(of: high.text, startingWith: "⚠️")
                == ["⚠️ Unusually high net margin (80.0%)"])

        let ordinary = try await call(ValidateFinancialStatementsTool(), """
            {"income_statement": {"total_revenue": 100.5, "net_income": 20.1}}
            """)
        #expect(lines(of: ordinary.text, startingWith: "✅ Net margin") == ["✅ Net margin: 20.0%"])
        #expect(lines(of: ordinary.text, startingWith: "⚠️") == [])
    }

    // MARK: - CapitalStructureTools

    @Test("A beta that is not a finite number is refused",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func betaNotFinite(beta: Double) async throws {
        let result = try await call(CalculateCostOfEquityTool(), values: [
            "risk_free_rate": .double(0.03), "beta": .double(beta), "market_return": .double(0.08)
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: beta must be a finite number")
    }

    @Test("A finite beta is interpreted as before")
    func betaFinite() async throws {
        let zero = try await call(CalculateCostOfEquityTool(), """
            {"risk_free_rate": 0.03, "beta": 0.0, "market_return": 0.08}
            """)
        #expect(!zero.isError)
        #expect(lines(of: zero.text, startingWith: "β =") == ["β = 0.00: No systematic risk"])

        let high = try await call(CalculateCostOfEquityTool(), """
            {"risk_free_rate": 0.03, "beta": 1.5, "market_return": 0.08}
            """)
        #expect(!high.isError)
        #expect(lines(of: high.text, startingWith: "β =") == ["β = 1.50: High systematic risk"])
    }
}
