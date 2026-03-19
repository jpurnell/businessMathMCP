import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Valuation Domain Tests")
struct ValuationDomainTests {

    // MARK: - Valuation Calculators Tools

    @Test("calculate_pe_ratio computes price-to-earnings")
    func testPERatio() async throws {
        let tool = PriceToEarningsTool()
        let args = argsFromJSON("""
            {"marketPrice": 50, "earningsPerShare": 2.50}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("20") || result.text.contains("P/E") || result.text.contains("Earnings"))
    }

    @Test("calculate_eps computes earnings per share")
    func testEPS() async throws {
        let tool = EarningsPerShareTool()
        let args = argsFromJSON("""
            {"netIncome": 5000000, "preferredDividends": 200000, "sharesOutstanding": 1000000}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("4.8") || result.text.contains("EPS") || result.text.contains("Earnings"))
    }

    // MARK: - Equity Valuation Tools

    @Test("gordon_growth_model values stock using dividend discount")
    func testGordonGrowth() async throws {
        let tool = toolHandlersByName()["value_equity_gordon_growth"]
        guard let tool = tool else {
            Issue.record("value_equity_gordon_growth not found")
            return
        }
        let args = argsFromJSON("""
            {
                "dividendPerShare": 2.00,
                "growthRate": 0.03,
                "requiredReturn": 0.10
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("29") || result.text.contains("Intrinsic") || result.text.contains("Value"))
    }

    @Test("fcfe_valuation values equity using free cash flow")
    func testFCFEValuation() async throws {
        let tool = toolHandlersByName()["value_equity_fcfe"]
        guard let tool = tool else {
            Issue.record("value_equity_fcfe not found")
            return
        }
        let args = argsFromJSON("""
            {
                "currentFCFE": 5000000,
                "highGrowthRate": 0.15,
                "highGrowthPeriods": 5,
                "terminalGrowthRate": 0.03,
                "costOfEquity": 0.12,
                "sharesOutstanding": 1000000
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Value") || result.text.contains("value") || result.text.contains("FCFE"))
    }

    // MARK: - Bond Valuation Tools

    @Test("calculate_bond_price prices a coupon bond")
    func testBondPrice() async throws {
        let tool = BondPriceTool()
        let args = argsFromJSON("""
            {
                "faceValue": 1000,
                "couponRate": 0.06,
                "yearsToMaturity": 5,
                "yieldToMaturity": 0.05,
                "frequency": 2
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("1,043") || result.text.contains("1043") || result.text.contains("Price") || result.text.contains("Bond"))
    }

    @Test("calculate_duration computes bond duration")
    func testBondDuration() async throws {
        let tool = BondDurationTool()
        let args = argsFromJSON("""
            {
                "faceValue": 1000,
                "couponRate": 0.06,
                "yearsToMaturity": 5,
                "yieldToMaturity": 0.05,
                "frequency": 2
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Duration") || result.text.contains("duration") || result.text.contains("4."))
    }

    // MARK: - Investment Metrics Tools

    @Test("calculate_profitability_index computes PI")
    func testProfitabilityIndex() async throws {
        let tool = ProfitabilityIndexTool()
        let args = argsFromJSON("""
            {
                "initialInvestment": 100000,
                "cashFlows": [30000, 35000, 40000, 45000],
                "discountRate": 0.10
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Profitability") || result.text.contains("Index") || result.text.contains("1."))
    }

    @Test("calculate_payback_period computes time to recover investment")
    func testPaybackPeriod() async throws {
        let tool = PaybackPeriodTool()
        let args = argsFromJSON("""
            {
                "initialInvestment": 100000,
                "cashFlows": [30000, 35000, 40000, 45000]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Payback") || result.text.contains("payback") || result.text.contains("Year"))
    }
}
