import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Financial Ratios Domain Tests")
struct FinancialRatiosDomainTests {

    // MARK: - Financial Ratios Tools

    @Test("calculate_current_ratio computes 2.0x ratio")
    func testCurrentRatio() async throws {
        let tool = CurrentRatioTool()
        let args = argsFromJSON("""
            {"currentAssets": 200000.0, "currentLiabilities": 100000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("2.0"))
    }

    @Test("calculate_debt_to_equity computes D/E ratio")
    func testDebtToEquity() async throws {
        let tool = DebtToEquityTool()
        let args = argsFromJSON("""
            {"totalLiabilities": 500000.0, "shareholderEquity": 1000000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("0.5"))
    }

    @Test("calculate_roe computes return on equity")
    func testROE() async throws {
        let tool = ROETool()
        let args = argsFromJSON("""
            {"netIncome": 150000.0, "shareholderEquity": 1000000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("15"))
    }

    @Test("calculate_profit_margin computes net profit margin")
    func testProfitMargin() async throws {
        let tool = ProfitMarginTool()
        let args = argsFromJSON("""
            {"netIncome": 200000.0, "revenue": 1000000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("20"))
    }

    // MARK: - Extended Financial Ratios Tools

    @Test("calculate_roa computes return on assets")
    func testROA() async throws {
        let tool = ROATool()
        let args = argsFromJSON("""
            {"netIncome": 100000.0, "totalAssets": 2000000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("5"))
    }

    // MARK: - Working Capital Tools

    @Test("calculate_dso computes days sales outstanding")
    func testDSO() async throws {
        let tool = DaysSalesOutstandingTool()
        let args = argsFromJSON("""
            {"averageAccountsReceivable": 150000.0, "netSales": 1800000.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Days") || result.text.contains("days") || result.text.contains("30"))
    }

    // MARK: - Advanced Ratio Tools

    @Test("dupont_3_way decomposes ROE into three components")
    func testDuPont3Way() async throws {
        let tool = DuPont3WayTool()
        let args = argsFromJSON("""
            {
                "netIncome": 150000.0,
                "sales": 1000000.0,
                "totalAssets": 2000000.0,
                "shareholderEquity": 800000.0
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("DuPont") || result.text.contains("Margin") || result.text.contains("Turnover"))
    }
}
