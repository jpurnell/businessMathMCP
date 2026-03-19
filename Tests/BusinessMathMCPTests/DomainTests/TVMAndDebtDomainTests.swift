import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("TVM and Debt Domain Tests")
struct TVMAndDebtDomainTests {

    // MARK: - TVM Tools

    @Test("calculate_present_value computes PV of $1000 at 5% for 10 years")
    func testPresentValue() async throws {
        let tool = PresentValueTool()
        let args = argsFromJSON("""
            {"futureValue": 1000, "rate": 0.05, "periods": 10}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("613"))
    }

    @Test("calculate_npv computes NPV of cash flow series")
    func testNPV() async throws {
        let tool = NPVTool()
        let args = argsFromJSON("""
            {"rate": 0.10, "cashFlows": [-100000, 30000, 35000, 40000, 45000]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("NPV"))
    }

    @Test("calculate_irr finds internal rate of return")
    func testIRR() async throws {
        let tool = IRRTool()
        let args = argsFromJSON("""
            {"cashFlows": [-100000, 30000, 35000, 40000, 45000]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("IRR"))
    }

    // MARK: - Debt Tools

    @Test("create_amortization_schedule produces monthly payment schedule")
    func testAmortizationSchedule() async throws {
        let tool = CreateAmortizationScheduleTool()
        let args = argsFromJSON("""
            {"principal": 100000, "annualRate": 0.065, "years": 5, "frequency": "monthly"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Payment"))
    }

    @Test("calculate_dscr computes debt service coverage ratio")
    func testDSCR() async throws {
        let tool = DebtServiceCoverageRatioTool()
        let args = argsFromJSON("""
            {"netOperatingIncome": 500000, "totalDebtService": 300000}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("1.6"))
    }

    // MARK: - Extended Debt Tools

    @Test("calculate_beta_levering computes levered beta")
    func testBetaLevering() async throws {
        let tool = BetaLeveringTool()
        let args = argsFromJSON("""
            {"unleveredBeta": 0.8, "debtToEquityRatio": 0.5, "taxRate": 0.25}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Beta"))
    }

    // MARK: - Financing Tools

    @Test("calculate_post_money_valuation computes post-money valuation")
    func testPostMoneyValuation() async throws {
        let tool = PostMoneyValuationTool()
        let args = argsFromJSON("""
            {"preMoneyValuation": 10000000, "investmentAmount": 2000000}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("12"))
    }

    // MARK: - Loan Payment Analysis Tools

    @Test("calculate_principal_payment computes P&I breakdown")
    func testPrincipalPayment() async throws {
        let tool = PrincipalPaymentTool()
        let args = argsFromJSON("""
            {"interestRate": 0.005, "period": 1, "totalPeriods": 360, "loanAmount": 250000}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Principal"))
    }
}
