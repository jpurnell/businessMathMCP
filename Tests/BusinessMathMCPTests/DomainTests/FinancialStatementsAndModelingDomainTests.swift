import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

@Suite("Financial Statements and Modeling Domain Tests")
struct FinancialStatementsAndModelingDomainTests {

    // MARK: - Financial Statement Tools

    @Test("create_income_statement builds income statement from accounts")
    func testIncomeStatement() async throws {
        let tool = CreateIncomeStatementTool()
        let args = argsFromJSON("""
            {
                "entity": "Acme Corp",
                "period": "FY2024",
                "accounts": [
                    {"name": "Product Sales", "role": "product_revenue", "value": 5000000},
                    {"name": "Service Revenue", "role": "service_revenue", "value": 1000000},
                    {"name": "Cost of Goods", "role": "cost_of_goods_sold", "value": 2500000},
                    {"name": "Salaries", "role": "general_and_administrative", "value": 1500000},
                    {"name": "Rent", "role": "general_and_administrative", "value": 300000}
                ]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Income") || result.text.contains("Revenue") || result.text.contains("Acme"))
    }

    @Test("create_balance_sheet builds balance sheet from accounts")
    func testBalanceSheet() async throws {
        let tool = CreateBalanceSheetTool()
        let args = argsFromJSON("""
            {
                "entity": "Acme Corp",
                "period": "FY2024",
                "accounts": [
                    {"name": "Cash", "role": "cash_and_equivalents", "value": 500000},
                    {"name": "Receivables", "role": "accounts_receivable", "value": 300000},
                    {"name": "Equipment", "role": "property_plant_equipment", "value": 2000000},
                    {"name": "Payables", "role": "accounts_payable", "value": 200000},
                    {"name": "Long-term Debt", "role": "long_term_debt", "value": 1000000},
                    {"name": "Common Stock", "role": "common_stock", "value": 1600000}
                ]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Balance") || result.text.contains("Assets") || result.text.contains("Acme"))
    }

    // MARK: - Operational Metrics Tools

    @Test("calculate_saas_metrics computes SaaS KPIs")
    func testSaaSMetrics() async throws {
        let tool = CalculateSaaSMetricsTool()
        let args = argsFromJSON("""
            {
                "entity": "SaaSCo",
                "period": "2024-Q4",
                "mrr": 500000,
                "new_mrr": 50000,
                "churned_mrr": 20000,
                "expansion_mrr": 15000,
                "customers": 200,
                "new_customers": 25,
                "churned_customers": 10,
                "sales_and_marketing": 100000
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("MRR") || result.text.contains("SaaS") || result.text.contains("Churn"))
    }

    // MARK: - Capital Structure Tools

    @Test("calculate_wacc computes weighted average cost of capital")
    func testWACC() async throws {
        let tool = CalculateWACCTool()
        let args = argsFromJSON("""
            {
                "market_cap": 5000000,
                "total_debt": 3000000,
                "risk_free_rate": 0.03,
                "market_return": 0.10,
                "beta": 1.2,
                "debt_interest_rate": 0.06,
                "tax_rate": 0.25
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("WACC") || result.text.contains("Weighted") || result.text.contains("Cost"))
    }

    @Test("calculate_cost_of_equity computes cost using CAPM")
    func testCostOfEquity() async throws {
        let tool = CalculateCostOfEquityTool()
        let args = argsFromJSON("""
            {
                "risk_free_rate": 0.03,
                "beta": 1.2,
                "market_return": 0.10
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Cost") || result.text.contains("Equity") || result.text.contains("CAPM"))
    }

    // MARK: - Enhanced Covenant Tools

    @Test("monitor_debt_covenants_comprehensive checks covenant compliance")
    func testCovenantMonitoring() async throws {
        let tool = MonitorDebtCovenantsComprehensiveTool()
        let args = argsFromJSON("""
            {
                "entity": "LoanCo Inc",
                "period": "Q4 2025",
                "financials": {
                    "current_assets": 500000,
                    "current_liabilities": 300000,
                    "inventory": 100000,
                    "total_debt": 2000000,
                    "equity": 1000000,
                    "intangibles": 50000,
                    "ebitda": 300000,
                    "ebit": 200000,
                    "interest_expense": 100000,
                    "principal_payment": 50000
                },
                "covenants": [
                    {"type": "current_ratio", "threshold": 1.5, "direction": "minimum"},
                    {"type": "debt_to_equity", "threshold": 3.0, "direction": "maximum"}
                ]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Covenant") || result.text.contains("covenant") || result.text.contains("Compliance"))
    }

    // MARK: - Multi-Period Analysis Tools

    @Test("analyze_financial_trends projects multi-year trends")
    func testFinancialTrends() async throws {
        let tool = AnalyzeFinancialTrendsTool()
        let args = argsFromJSON("""
            {
                "entity": "GrowthCorp",
                "periods": [
                    {"period": "2021", "revenue": 1000000, "net_income": 100000},
                    {"period": "2022", "revenue": 1200000, "net_income": 130000},
                    {"period": "2023", "revenue": 1450000, "net_income": 170000}
                ]
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Trend") || result.text.contains("Growth") || result.text.contains("GrowthCorp"))
    }

    // MARK: - Advanced Financial Modeling Tools

    @Test("scenario_financial_statements generates three-scenario model")
    func testScenarioFinancialStatements() async throws {
        let tool = ScenarioFinancialStatementsTool()
        let args = argsFromJSON("""
            {
                "entity": "ModelCorp",
                "base_case": {
                    "revenue": 10000000,
                    "gross_margin": 0.60,
                    "opex": 3000000,
                    "tax_rate": 0.25,
                    "equity": 5000000
                }
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Scenario") || result.text.contains("Base") || result.text.contains("ModelCorp"))
    }

    // MARK: - Lease and Covenant Tools

    @Test("calculate_lease_liability computes lease obligation PV")
    func testLeaseLiability() async throws {
        let tool = LeaseLiabilityTool()
        let args = argsFromJSON("""
            {
                "monthlyPayment": 10000,
                "leaseTerm": 60,
                "discountRate": 0.06
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Lease") || result.text.contains("Liability") || result.text.contains("Present"))
    }
}
