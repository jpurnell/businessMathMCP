//
//  FinancialStatementTools.swift
//  BusinessMath MCP Server
//
//  Financial statement construction tools for BusinessMath MCP Server
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all financial statement construction tools
public func getFinancialStatementTools() -> [any MCPToolHandler] {
    return [
        CreateIncomeStatementTool(),
        CreateBalanceSheetTool(),
        CreateCashFlowStatementTool(),
        ValidateFinancialStatementsTool(),
        LeaseVsBuyTool(),
        RatioSummaryTool(),
        CapTableTool()
    ]
}

// MARK: - Helper Functions
/// Create a separator line
private func separator(width: Int = 40, char: Character = "─") -> String {
    return String(repeating: char, count: width)
}

// MARK: - 1. Create Income Statement

public struct CreateIncomeStatementTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_income_statement",
        description: """
        Create a comprehensive Income Statement from account-level data.

        Builds a complete Income Statement with automatic aggregation and calculation of:
        - Total Revenue (all revenue streams)
        - Gross Profit and Gross Margin
        - Operating Income and Operating Margin
        - EBITDA and EBITDA Margin
        - Net Income and Net Margin

        Supported Account Roles:
        Revenue:
        • "revenue" - Generic revenue
        • "product_revenue" - Product sales
        • "service_revenue" - Service fees
        • "subscription_revenue" - Recurring subscription
        • "licensing_revenue" - IP licensing
        • "interest_income" - Interest income
        • "other_revenue" - Other revenue

        Cost of Revenue:
        • "cost_of_goods_sold" - Manufacturing/product costs
        • "cost_of_services" - Service delivery costs

        Operating Expenses:
        • "research_and_development" - R&D expenses
        • "sales_and_marketing" - S&M expenses
        • "general_and_administrative" - G&A expenses
        • "operating_expense_other" - Other operating expenses

        Non-Cash Charges:
        • "depreciation_amortization" - D&A expense
        • "impairment_charges" - Asset impairments
        • "stock_based_compensation" - Stock-based comp
        • "restructuring_charges" - One-time restructuring

        Non-Operating:
        • "interest_expense" - Interest expense
        • "income_tax_expense" - Tax expense

        Use Cases:
        • Build financial models from scratch
        • Consolidate multi-entity statements
        • Scenario analysis and forecasting
        • Professional financial reporting

        Example: Tech company with $8M revenue, $3M COGS, $4.3M OpEx generates detailed P&L
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company or entity name (e.g., 'Acme Corp')"
                ),
                "period": MCPSchemaProperty(
                    type: "string",
                    description: "Reporting period (e.g., '2024-Q1', '2024', 'FY2024', 'Q4 2024')"
                ),
                "accounts": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of account objects, each containing:
                    - name: Account name (e.g., "Product Sales")
                    - role: Account role (see supported roles above)
                    - value: Dollar amount (can be negative for contra accounts)
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "currency": MCPSchemaProperty(
                    type: "string",
                    description: "Currency code (e.g., 'USD', 'EUR', 'GBP'). Defaults to 'USD'"
                )
            ],
            required: ["entity", "period", "accounts"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")
        let currency = try? args.getString("currency")

        // Parse accounts array
        guard let accountsAnyCodable = args["accounts"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("accounts must be an array of objects")
        }

        guard !accountsAnyCodable.isEmpty else {
            throw ToolError.invalidArguments("At least one account is required")
        }

        // Create entity
        let entity = Entity(
            id: entityName.replacingOccurrences(of: " ", with: "_").uppercased(),
            primaryType: .internal,
            name: entityName,
            currency: currency
        )

        // Create period (we'll use a simple year-based period for single-period statements)
        let period = Period.year(2024) // Default period, will be shown as periodString in output

        // Parse accounts and create Account objects
        var accounts: [Account<Double>] = []

        for account in accountsAnyCodable {
            guard let accountData = account.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each account must be an object")
            }

            guard let name = accountData["name"]?.value as? String,
                  let roleString = accountData["role"]?.value as? String else {
                throw ToolError.invalidArguments("Each account must have 'name' (string), 'role' (string), and 'value' (number)")
            }

            // Handle value as either Double or Int
            let value: Double
            if let valueDouble = accountData["value"]?.value as? Double {
                value = valueDouble
            } else if let valueInt = accountData["value"]?.value as? Int {
                value = Double(valueInt)
            } else {
                throw ToolError.invalidArguments("Account value must be a number")
            }

            // Map role string to IncomeStatementRole
            guard let role = mapStringToIncomeStatementRole(roleString) else {
                throw ToolError.invalidArguments("Invalid role '\(roleString)'. See tool description for valid roles.")
            }

            // Create TimeSeries with single value
            let timeSeries = TimeSeries<Double>(
                periods: [period],
                values: [value]
            )

            // Create Account
            let account = try Account<Double>(
                entity: entity,
                name: name,
                incomeStatementRole: role,
                timeSeries: timeSeries
            )

            accounts.append(account)
        }

        // Create IncomeStatement
        let incomeStatement = try IncomeStatement(
            entity: entity,
            periods: [period],
            accounts: accounts
        )

        // Extract metrics
        let totalRevenue = incomeStatement.totalRevenue.valuesArray[0]
        let totalExpenses = incomeStatement.totalExpenses.valuesArray[0]
        let netIncome = incomeStatement.netIncome.valuesArray[0]
        let grossProfit = incomeStatement.grossProfit.valuesArray[0]
        let operatingIncome = incomeStatement.operatingIncome.valuesArray[0]
        let ebitda = incomeStatement.ebitda.valuesArray[0]

        let grossMargin = incomeStatement.grossMargin.valuesArray[0]
        let operatingMargin = incomeStatement.operatingMargin.valuesArray[0]
        let netMargin = incomeStatement.netMargin.valuesArray[0]
        let ebitdaMargin = incomeStatement.ebitdaMargin.valuesArray[0]

        // Build formatted output
        var output = """
        Income Statement - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        REVENUE
        """

        // Revenue accounts
        for account in incomeStatement.revenueAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Revenue                     \(totalRevenue.currency(0).paddingLeft(toLength: 15))

        """

        // Cost of Revenue
        let costOfRevenueAccounts = incomeStatement.costOfRevenueAccounts
        if !costOfRevenueAccounts.isEmpty {
            output += "COST OF REVENUE\n"
            for account in costOfRevenueAccounts {
                let value = account.timeSeries.valuesArray[0]
				output += "  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))\n"
            }
            output += """
                                              \(separator(width: 15))
            Gross Profit                      \(grossProfit.currency(0).paddingLeft(toLength: 15))
            Gross Margin                      \(grossMargin.percent(1).paddingLeft(toLength: 15))

            """
        }

        // Operating Expenses
        let opexAccounts = incomeStatement.operatingExpenseAccounts
        if !opexAccounts.isEmpty {
            output += "OPERATING EXPENSES\n"
            for account in opexAccounts {
                let value = account.timeSeries.valuesArray[0]
				output += "  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))\n"
            }
            output += """
                                              \(separator(width: 15))
            Total Operating Expenses          \(incomeStatement.operatingExpenses.valuesArray[0].currency(0).paddingLeft(toLength: 15))

            """
        }

        // Operating Income
        output += """
        Operating Income                  \(operatingIncome.currency(0).paddingLeft(toLength: 15))
        Operating Margin                  \(operatingMargin.percent(1).paddingLeft(toLength: 15))

        """

        // Non-Cash Charges
        let nonCashAccounts = incomeStatement.nonCashChargeAccounts
        if !nonCashAccounts.isEmpty {
            output += "NON-CASH CHARGES\n"
            for account in nonCashAccounts {
                let value = account.timeSeries.valuesArray[0]
				output += "  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))\n"
            }
            output += "\n"
        }

        // EBITDA
        output += """
        EBITDA                            \(ebitda.currency(0).paddingLeft(toLength: 15))
        EBITDA Margin                     \(ebitdaMargin.percent(1).paddingLeft(toLength: 15))

        """

        // Interest and Taxes
        let interestAccounts = incomeStatement.interestExpenseAccounts
        if !interestAccounts.isEmpty {
            output += "INTEREST EXPENSE\n"
            for account in interestAccounts {
                let value = account.timeSeries.valuesArray[0]
				output += "  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))\n"
            }
            output += "\n"
        }

        let taxAccounts = incomeStatement.taxAccounts
        if !taxAccounts.isEmpty {
            output += "INCOME TAX EXPENSE\n"
            for account in taxAccounts {
                let value = account.timeSeries.valuesArray[0]
				output += "  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))\n"
            }
            let effectiveTaxRate = taxAccounts.map { $0.timeSeries.valuesArray[0] }.reduce(0, +) / (operatingIncome - (interestAccounts.map { $0.timeSeries.valuesArray[0] }.reduce(0, +)))
            if !effectiveTaxRate.isNaN && !effectiveTaxRate.isInfinite {
				output += "Effective Tax Rate                \(effectiveTaxRate.percent(1).paddingLeft(toLength: 15))\n"
            }
            output += "\n"
        }

        // Net Income
        output += """
                                          \(separator(width: 15))
        NET INCOME                        \(netIncome.currency(0).paddingLeft(toLength: 15))
        Net Margin                        \(netMargin.percent(1).paddingLeft(toLength: 15))

        \(String(repeating: "━", count: 60))

        Next Steps:
          • Use create_balance_sheet to build Balance Sheet
          • Use create_cash_flow_statement to build Cash Flow Statement
          • Use calculate_roe, calculate_roa for profitability analysis
        """

        return .success(text: output)
    }
}

// MARK: - Role Mapping Helpers

/// Map string to IncomeStatementRole
private func mapStringToIncomeStatementRole(_ roleString: String) -> IncomeStatementRole? {
    let normalized = roleString.lowercased().replacingOccurrences(of: " ", with: "_")

    switch normalized {
    case "revenue": return .revenue
    case "product_revenue": return .productRevenue
    case "service_revenue": return .serviceRevenue
    case "subscription_revenue": return .subscriptionRevenue
    case "licensing_revenue": return .licensingRevenue
    case "interest_income": return .interestIncome
    case "other_revenue": return .otherRevenue
    case "cost_of_goods_sold", "cogs": return .costOfGoodsSold
    case "cost_of_services": return .costOfServices
    case "research_and_development", "r&d", "rd", "rnd": return .researchAndDevelopment
    case "sales_and_marketing", "s&m", "sm": return .salesAndMarketing
    case "general_and_administrative", "g&a", "ga", "sga": return .generalAndAdministrative
    case "operating_expense_other", "other_operating_expense": return .operatingExpenseOther
    case "depreciation_amortization", "d&a", "da": return .depreciationAmortization
    case "impairment_charges": return .impairmentCharges
    case "stock_based_compensation", "sbc": return .stockBasedCompensation
    case "restructuring_charges": return .restructuringCharges
    case "interest_expense": return .interestExpense
    case "income_tax_expense", "tax_expense", "taxes": return .incomeTaxExpense
    default: return nil
    }
}

/// Map string to BalanceSheetRole
private func mapStringToBalanceSheetRole(_ roleString: String) -> BalanceSheetRole? {
    let normalized = roleString.lowercased().replacingOccurrences(of: " ", with: "_")

    switch normalized {
    // Current Assets
    case "cash_and_equivalents", "cash": return .cashAndEquivalents
    case "short_term_investments": return .shortTermInvestments
    case "accounts_receivable", "receivables", "ar": return .accountsReceivable
    case "inventory": return .inventory
    case "prepaid_expenses", "prepaid": return .prepaidExpenses
    case "other_current_assets": return .otherCurrentAssets

    // Non-Current Assets
    case "property_plant_equipment", "pp&e", "ppe": return .propertyPlantEquipment
    case "accumulated_depreciation": return .accumulatedDepreciation
    case "intangible_assets", "intangibles": return .intangibleAssets
    case "goodwill": return .goodwill
    case "long_term_investments": return .longTermInvestments
    case "deferred_tax_assets": return .deferredTaxAssets
    case "right_of_use_assets", "rou_assets": return .rightOfUseAssets
    case "other_non_current_assets": return .otherNonCurrentAssets

    // Current Liabilities
    case "accounts_payable", "payables", "ap": return .accountsPayable
    case "accrued_liabilities", "accruals": return .accruedLiabilities
    case "short_term_debt": return .shortTermDebt
    case "current_portion_long_term_debt", "cpltd": return .currentPortionLongTermDebt
    case "deferred_revenue", "unearned_revenue": return .deferredRevenue
    case "other_current_liabilities": return .otherCurrentLiabilities

    // Non-Current Liabilities
    case "long_term_debt", "ltd": return .longTermDebt
    case "deferred_tax_liabilities": return .deferredTaxLiabilities
    case "pension_liabilities": return .pensionLiabilities
    case "lease_liabilities": return .leaseLiabilities
    case "other_non_current_liabilities": return .otherNonCurrentLiabilities

    // Equity
    case "common_stock": return .commonStock
    case "preferred_stock": return .preferredStock
    case "additional_paid_in_capital", "apic": return .additionalPaidInCapital
    case "retained_earnings": return .retainedEarnings
    case "accumulated_other_comprehensive_income", "aoci": return .accumulatedOtherComprehensiveIncome
    case "treasury_stock": return .treasuryStock

    default: return nil
    }
}

// MARK: - 2. Create Balance Sheet

public struct CreateBalanceSheetTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_balance_sheet",
        description: """
        Create a comprehensive Balance Sheet from account-level data.

        Builds a complete Balance Sheet with automatic classification and validation:
        - Current vs Non-Current Assets
        - Current vs Non-Current Liabilities
        - Stockholders' Equity
        - Accounting equation validation (Assets = Liabilities + Equity)
        - Key liquidity and leverage ratios

        Supported Account Roles:

        Current Assets:
        • "cash_and_equivalents" - Cash and cash equivalents
        • "short_term_investments" - Short-term investments
        • "accounts_receivable" - Customer receivables
        • "inventory" - Inventory (raw materials, WIP, finished goods)
        • "prepaid_expenses" - Prepaid expenses
        • "other_current_assets" - Other current assets

        Non-Current Assets:
        • "property_plant_equipment" - PP&E (gross)
        • "accumulated_depreciation" - Accumulated depreciation (negative/contra)
        • "intangible_assets" - Patents, trademarks, software
        • "goodwill" - Goodwill from acquisitions
        • "long_term_investments" - Long-term investments
        • "deferred_tax_assets" - Deferred tax assets
        • "right_of_use_assets" - ROU assets (leases)
        • "other_non_current_assets" - Other non-current assets

        Current Liabilities:
        • "accounts_payable" - Supplier payables
        • "accrued_liabilities" - Accrued expenses
        • "short_term_debt" - Short-term debt
        • "current_portion_long_term_debt" - Current portion of LTD
        • "deferred_revenue" - Deferred/unearned revenue
        • "other_current_liabilities" - Other current liabilities

        Non-Current Liabilities:
        • "long_term_debt" - Long-term debt
        • "deferred_tax_liabilities" - Deferred tax liabilities
        • "pension_liabilities" - Pension obligations
        • "lease_liabilities" - Lease liabilities
        • "other_non_current_liabilities" - Other non-current liabilities

        Equity:
        • "common_stock" - Common stock
        • "preferred_stock" - Preferred stock
        • "additional_paid_in_capital" - APIC
        • "retained_earnings" - Retained earnings
        • "accumulated_other_comprehensive_income" - AOCI
        • "treasury_stock" - Treasury stock (negative/contra)

        Use Cases:
        • Financial modeling and scenario analysis
        • Liquidity and solvency analysis
        • Credit analysis and lending decisions
        • Covenant compliance monitoring

        Example: Company with $21.5M assets = $11M liabilities + $10.5M equity
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company or entity name"
                ),
                "period": MCPSchemaProperty(
                    type: "string",
                    description: "Reporting period (e.g., '2024-Q1', 'FY2024')"
                ),
                "accounts": MCPSchemaProperty(
                    type: "array",
                    description: "Array of account objects with name, role, and value",
                    items: MCPSchemaItems(type: "object")
                ),
                "currency": MCPSchemaProperty(
                    type: "string",
                    description: "Currency code (defaults to 'USD')"
                )
            ],
            required: ["entity", "period", "accounts"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")
        let currency = try? args.getString("currency")

        // Parse accounts
        guard let accountsAnyCodable = args["accounts"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("accounts must be an array")
        }

        guard !accountsAnyCodable.isEmpty else {
            throw ToolError.invalidArguments("At least one account is required")
        }

        // Create entity and period
        let entity = Entity(
            id: entityName.replacingOccurrences(of: " ", with: "_").uppercased(),
            primaryType: .internal,
            name: entityName,
            currency: currency
        )
        let period = Period.year(2024)

        // Parse and create accounts
        var accounts: [Account<Double>] = []

        for account in accountsAnyCodable {
            guard let accountData = account.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each account must be an object")
            }

            guard let name = accountData["name"]?.value as? String,
                  let roleString = accountData["role"]?.value as? String else {
                throw ToolError.invalidArguments("Each account must have 'name', 'role', and 'value'")
            }

            // Handle value as either Double or Int
            let value: Double
            if let valueDouble = accountData["value"]?.value as? Double {
                value = valueDouble
            } else if let valueInt = accountData["value"]?.value as? Int {
                value = Double(valueInt)
            } else {
                throw ToolError.invalidArguments("Account value must be a number")
            }

            guard let role = mapStringToBalanceSheetRole(roleString) else {
                throw ToolError.invalidArguments("Invalid role '\(roleString)'")
            }

            let timeSeries = TimeSeries<Double>(periods: [period], values: [value])
            let account = try Account<Double>(
                entity: entity,
                name: name,
                balanceSheetRole: role,
                timeSeries: timeSeries
            )
            accounts.append(account)
        }

        // Create BalanceSheet
        let balanceSheet = try BalanceSheet(
            entity: entity,
            periods: [period],
            accounts: accounts
        )

        // Extract metrics
        let totalAssets = balanceSheet.totalAssets.valuesArray[0]
        let currentAssets = balanceSheet.currentAssets.valuesArray[0]
        let nonCurrentAssets = balanceSheet.nonCurrentAssets.valuesArray[0]
        let totalLiabilities = balanceSheet.totalLiabilities.valuesArray[0]
        let currentLiabilities = balanceSheet.currentLiabilities.valuesArray[0]
        let nonCurrentLiabilities = balanceSheet.nonCurrentLiabilities.valuesArray[0]
        let totalEquity = balanceSheet.totalEquity.valuesArray[0]

        // Calculate key ratios
        let workingCapital = balanceSheet.workingCapital.valuesArray[0]
        let currentRatio = currentAssets / currentLiabilities
        let quickAssets = currentAssets - (balanceSheet.accounts.first(where: { $0.balanceSheetRole == .inventory })?.timeSeries.valuesArray[0] ?? 0)
        let quickRatio = quickAssets / currentLiabilities
        let debtToEquity = totalLiabilities / totalEquity
        let equityRatio = totalEquity / totalAssets
        let totalDebt = (balanceSheet.accounts.first(where: { $0.balanceSheetRole == .shortTermDebt })?.timeSeries.valuesArray[0] ?? 0) +
                       (balanceSheet.accounts.first(where: { $0.balanceSheetRole == .currentPortionLongTermDebt })?.timeSeries.valuesArray[0] ?? 0) +
                       (balanceSheet.accounts.first(where: { $0.balanceSheetRole == .longTermDebt })?.timeSeries.valuesArray[0] ?? 0)
        let cash = balanceSheet.accounts.first(where: { $0.balanceSheetRole == .cashAndEquivalents })?.timeSeries.valuesArray[0] ?? 0
        let netDebt = totalDebt - cash

        // Build output
        var output = """
        Balance Sheet - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        ASSETS

        Current Assets
        """

        for account in balanceSheet.currentAssetAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Current Assets              \(currentAssets.currency(0).paddingLeft(toLength: 15))

        Non-Current Assets
        """

        for account in balanceSheet.nonCurrentAssetAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Non-Current Assets          \(nonCurrentAssets.currency(0).paddingLeft(toLength: 15))

        TOTAL ASSETS                      \(totalAssets.currency(0).paddingLeft(toLength: 15))


        LIABILITIES & EQUITY

        Current Liabilities
        """

        for account in balanceSheet.currentLiabilityAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0)).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Current Liabilities         \(currentLiabilities.currency(0).paddingLeft(toLength: 15))

        Non-Current Liabilities
        """

        for account in balanceSheet.nonCurrentLiabilityAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0)).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Non-Current Liabilities     \(nonCurrentLiabilities.currency(0).paddingLeft(toLength: 15))

        Total Liabilities                 \(totalLiabilities.currency(0).paddingLeft(toLength: 15))

        Stockholders' Equity
        """

        for account in balanceSheet.equityAccounts {
            let value = account.timeSeries.valuesArray[0]
			output += "\n  \(account.name.padding(toLength: 30, withPad: " ", startingAt: 0))\(value.currency(0).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Total Equity                      \(totalEquity.currency(0).paddingLeft(toLength: 15))

        TOTAL LIAB & EQUITY               \((totalLiabilities + totalEquity).currency(0).paddingLeft(toLength: 15))

        \(String(repeating: "━", count: 60))

        Balance Check:
        """

        let balanced = abs(totalAssets - (totalLiabilities + totalEquity)) < 0.01
        output += balanced ? "✅" : "❌"
        output += " Assets = Liabilities + Equity\n"
		output += "   \(totalAssets.currency()) = \(totalLiabilities.currency()) + \(totalEquity.currency())\n\n"

        output += """
        Key Metrics:
          Working Capital:              \(workingCapital.currency())
          Current Ratio:                    \(currentRatio.number(2))
          Quick Ratio:                      \(quickRatio.number(2))
          Debt-to-Equity:                   \(debtToEquity.number(2))
          Equity Ratio:                 \(equityRatio.percent(1))
          Total Debt:                   \(totalDebt.currency())
          Net Debt:                     \(netDebt.currency())

        Next Steps:
          • Use create_income_statement for P&L analysis
          • Use calculate_roe, calculate_roa for profitability
          • Use monitor_debt_covenants for covenant compliance
        """

        return .success(text: output)
    }
}

// MARK: - 3. Create Cash Flow Statement

public struct CreateCashFlowStatementTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "create_cash_flow_statement",
        description: """
        Create a Cash Flow Statement from account-level data.

        Builds a comprehensive Cash Flow Statement organized by:
        - Operating Activities (net income adjustments, working capital changes)
        - Investing Activities (capex, acquisitions, asset sales)
        - Financing Activities (debt, equity, dividends)
        - Free Cash Flow calculation

        This tool accepts simplified inputs and constructs the statement automatically.

        Supported Inputs:
        - net_income: Net income from operations
        - depreciation_amortization: D&A add-back
        - stock_based_compensation: SBC add-back
        - change_in_receivables: Change in AR (negative = increase)
        - change_in_inventory: Change in inventory (negative = increase)
        - change_in_payables: Change in AP (positive = increase)
        - capital_expenditures: Capex (negative number)
        - acquisitions: Cash paid for acquisitions (negative)
        - asset_sales: Proceeds from asset sales (positive)
        - debt_issuance: Debt issued (positive)
        - debt_repayment: Debt repaid (negative)
        - equity_issuance: Equity issued (positive)
        - dividends_paid: Dividends paid (negative)

        Use Cases:
        • Analyze cash generation capabilities
        • Calculate free cash flow
        • Understand working capital efficiency
        • Monitor cash burn rate for startups

        Example: Company generates $5M operating cash, spends $2M on capex, FCF = $3M
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company or entity name"
                ),
                "period": MCPSchemaProperty(
                    type: "string",
                    description: "Reporting period"
                ),
                "cash_flows": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Object containing cash flow items. All values in dollars.
                    Operating: net_income, depreciation_amortization, stock_based_compensation,
                               change_in_receivables, change_in_inventory, change_in_payables
                    Investing: capital_expenditures, acquisitions, asset_sales
                    Financing: debt_issuance, debt_repayment, equity_issuance, dividends_paid
                    """
                ),
                "currency": MCPSchemaProperty(
                    type: "string",
                    description: "Currency code (defaults to 'USD')"
                )
            ],
            required: ["entity", "period", "cash_flows"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")
		var currencyValue = "USD"
		if let cv = try? args.getString("currency") {
			currencyValue = cv
		}
        let currency = currencyValue

        guard let cashFlows = args["cash_flows"]?.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("cash_flows must be an object")
        }

        // Helper to get value
        func getValue(_ key: String) -> Double {
            if let intVal = cashFlows[key]?.value as? Int {
                return Double(intVal)
            } else if let doubleVal = cashFlows[key]?.value as? Double {
                return doubleVal
            }
            return 0.0
        }

        // Operating Activities
        let netIncome = getValue("net_income")
        let da = getValue("depreciation_amortization")
        let sbc = getValue("stock_based_compensation")
        let changeAR = getValue("change_in_receivables")
        let changeInv = getValue("change_in_inventory")
        let changeAP = getValue("change_in_payables")
        let otherOperating = getValue("other_operating")

        let operatingCF = netIncome + da + sbc + changeAR + changeInv + changeAP + otherOperating

        // Investing Activities
        let capex = getValue("capital_expenditures")
        let acquisitions = getValue("acquisitions")
        let assetSales = getValue("asset_sales")
        let otherInvesting = getValue("other_investing")

        let investingCF = capex + acquisitions + assetSales + otherInvesting

        // Financing Activities
        let debtIssuance = getValue("debt_issuance")
        let debtRepayment = getValue("debt_repayment")
        let equityIssuance = getValue("equity_issuance")
        let dividends = getValue("dividends_paid")
        let otherFinancing = getValue("other_financing")

        let financingCF = debtIssuance + debtRepayment + equityIssuance + dividends + otherFinancing

        // Net Change
        let netChange = operatingCF + investingCF + financingCF

        // Free Cash Flow
        let freeCashFlow = operatingCF + capex

        // Build output
        var output = """
        Cash Flow Statement - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        OPERATING ACTIVITIES

          Net Income                      \(netIncome.currency(0, currency).paddingLeft(toLength: 15))

          Adjustments to reconcile net income:
        """

        if da != 0 {
			output += "\n    Depreciation & Amortization   \(da.currency(0, currency).paddingLeft(toLength: 15))"
        }
        if sbc != 0 {
			output += "\n    Stock-Based Compensation      \(sbc.currency(0, currency).paddingLeft(toLength: 15))"
        }

        output += "\n\n  Changes in working capital:"

        if changeAR != 0 {
			output += "\n    Change in Receivables         \(changeAR.currency(0, currency).paddingLeft(toLength: 15))"
        }
        if changeInv != 0 {
			output += "\n    Change in Inventory           \(changeInv.currency(0, currency).paddingLeft(toLength: 15))"
        }
        if changeAP != 0 {
			output += "\n    Change in Payables            \(changeAP.currency(0, currency).paddingLeft(toLength: 15))"
        }
        if otherOperating != 0 {
			output += "\n    Other Operating Activities    \(otherOperating.currency(0, currency).paddingLeft(toLength: 15))"
        }

        output += """

                                          \(separator(width: 15))
        Net Cash from Operating           \(operatingCF.currency(0, currency).paddingLeft(toLength: 15))

        INVESTING ACTIVITIES

        """

        if capex != 0 {
			output += "  Capital Expenditures            \(capex.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if acquisitions != 0 {
			output += "  Acquisitions                    \(acquisitions.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if assetSales != 0 {
			output += "  Proceeds from Asset Sales       \(assetSales.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if otherInvesting != 0 {
			output += "  Other Investing Activities      \(otherInvesting.currency(0, currency).paddingLeft(toLength: 15))\n"
        }

        output += """
                                          \(separator(width: 15))
        Net Cash from Investing           \(investingCF.currency(0, currency).paddingLeft(toLength: 15))

        FINANCING ACTIVITIES

        """

        if debtIssuance != 0 {
			output += "  Debt Issuance                   \(debtIssuance.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if debtRepayment != 0 {
			output += "  Debt Repayment                  \(debtRepayment.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if equityIssuance != 0 {
			output += "  Equity Issuance                 \(equityIssuance.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if dividends != 0 {
			output += "  Dividends Paid                  \(dividends.currency(0, currency).paddingLeft(toLength: 15))\n"
        }
        if otherFinancing != 0 {
			output += "  Other Financing Activities      \(otherFinancing.currency(0, currency).paddingLeft(toLength: 15))\n"
        }

        output += """
                                          \(separator(width: 15))
        Net Cash from Financing           \(financingCF.currency(0, currency).paddingLeft(toLength: 15))

        \(String(repeating: "━", count: 60))

        NET CHANGE IN CASH                \(netChange.currency(0, currency).paddingLeft(toLength: 15))

        \(String(repeating: "━", count: 60))

        Key Metrics:
          Free Cash Flow:               \(freeCashFlow.currency(0, currency))
            (Operating CF + Capex)

          Cash Conversion:              \((operatingCF / netIncome).percent(1))
            (Operating CF / Net Income)

        Next Steps:
          • Compare FCF to Net Income for quality of earnings
          • Analyze working capital efficiency (AR, Inventory, AP changes)
          • Monitor cash burn rate for runway analysis
        """

        return .success(text: output)
    }
}

// MARK: - 4. Validate Financial Statements

public struct ValidateFinancialStatementsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "validate_financial_statements",
        description: """
        Validate financial statements for consistency and completeness.

        Performs comprehensive validation checks:
        - Balance sheet equation (Assets = Liabilities + Equity)
        - Income statement to cash flow reconciliation
        - Cross-statement consistency
        - Reasonableness checks (margins, ratios)
        - Data quality assessment

        Use Cases:
        • Quality assurance for financial models
        • Audit preparation
        • Data integrity verification
        • Identify modeling errors

        Example: Validates that net income ties to cash flow statement
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "balance_sheet": MCPSchemaProperty(
                    type: "object",
                    description: "Balance sheet data (total_assets, total_liabilities, total_equity)"
                ),
                "income_statement": MCPSchemaProperty(
                    type: "object",
                    description: "Income statement data (total_revenue, net_income, etc.)"
                ),
                "cash_flow": MCPSchemaProperty(
                    type: "object",
                    description: "Cash flow data (operating_cf, investing_cf, financing_cf)"
                )
            ],
            required: []
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        var issues: [String] = []
        var warnings: [String] = []
        var checks: [String] = []

        // Balance Sheet Validation
        if let bs = args["balance_sheet"]?.value as? [String: AnyCodable] {
            if let assets = bs["total_assets"]?.value as? Double,
               let liabilities = bs["total_liabilities"]?.value as? Double,
               let equity = bs["total_equity"]?.value as? Double {

                let diff = abs(assets - (liabilities + equity))
                if diff < 0.01 {
                    checks.append("✅ Balance sheet equation holds (A = L + E)")
                } else {
					issues.append("❌ Balance sheet does not balance: Assets \(assets.currency()) ≠ Liab \(liabilities.currency()) + Equity \(equity.currency()) (Diff: \(diff.currency()))")
                }
            }
        }

        // Income Statement Validation
        if let is_data = args["income_statement"]?.value as? [String: AnyCodable] {
            if let revenue = is_data["total_revenue"]?.value as? Double,
               let netIncome = is_data["net_income"]?.value as? Double {

                let netMargin = netIncome / revenue
				checks.append("✅ Net margin: \(netMargin.percent(1))")

                if netMargin < -0.50 {
					warnings.append("⚠️ Very negative net margin (\(netMargin.percent(1)))")
                } else if netMargin > 0.50 {
					warnings.append("⚠️ Unusually high net margin (\(netMargin.percent(1)))")
                }
            }
        }

        // Cross-Statement Validation
        if let is_data = args["income_statement"]?.value as? [String: AnyCodable],
           let cf_data = args["cash_flow"]?.value as? [String: AnyCodable] {

            if let netIncome = is_data["net_income"]?.value as? Double,
               let operatingCF = cf_data["operating_cf"]?.value as? Double {

                let cashConversion = operatingCF / netIncome
				checks.append("✅ Cash conversion ratio: \(cashConversion.percent(1))")

                if cashConversion < 0.5 {
					warnings.append("⚠️ Low cash conversion (\(cashConversion.percent(1))) - investigate working capital")
                }
            }
        }

        var output = """
        Financial Statement Validation Report
        \(String(repeating: "━", count: 60))

        """

        if !checks.isEmpty {
            output += "PASSED CHECKS:\n"
            for check in checks {
                output += "  \(check)\n"
            }
            output += "\n"
        }

        if !warnings.isEmpty {
            output += "WARNINGS:\n"
            for warning in warnings {
                output += "  \(warning)\n"
            }
            output += "\n"
        }

        if !issues.isEmpty {
            output += "ISSUES FOUND:\n"
            for issue in issues {
                output += "  \(issue)\n"
            }
            output += "\n"
        }

        let status = issues.isEmpty ? "✅ VALID" : "❌ ISSUES FOUND"
        output += """
        \(String(repeating: "━", count: 60))
        Overall Status: \(status)
        """

        return .success(text: output)
    }
}

// MARK: - Lease vs Buy Analysis Tool

public struct LeaseVsBuyTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_lease_vs_buy",
        description: """
        Compare leasing vs purchasing an asset using NPV analysis.

        Calculates the present value of both lease and purchase options and
        determines the Net Advantage to Leasing (NAL).

        Lease PV: PV of all lease payments
        Buy PV: Purchase price + PV of maintenance - PV of salvage value
        NAL: Buy PV - Lease PV (positive = leasing is better)

        Use Cases:
        - Equipment financing decisions
        - Real estate lease-vs-buy
        - Vehicle fleet management
        - Capital budgeting

        Example: $5,000/mo lease vs $150,000 purchase with $30,000 salvage
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "leasePayment": MCPSchemaProperty(
                    type: "number",
                    description: "Periodic lease payment amount"
                ),
                "leasePeriods": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of lease payment periods"
                ),
                "purchasePrice": MCPSchemaProperty(
                    type: "number",
                    description: "Asset purchase price"
                ),
                "salvageValue": MCPSchemaProperty(
                    type: "number",
                    description: "Expected salvage/residual value at end of holding period"
                ),
                "holdingPeriod": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of periods if purchasing (same period unit as lease)"
                ),
                "discountRate": MCPSchemaProperty(
                    type: "number",
                    description: "Annual discount rate for NPV calculation (as decimal)"
                ),
                "maintenanceCost": MCPSchemaProperty(
                    type: "number",
                    description: "Periodic maintenance cost if buying (default 0)"
                )
            ],
            required: ["leasePayment", "leasePeriods", "purchasePrice",
                       "salvageValue", "holdingPeriod", "discountRate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let leasePayment = try args.getDouble("leasePayment")
        let leasePeriods = try args.getInt("leasePeriods")
        let purchasePrice = try args.getDouble("purchasePrice")
        let salvageValue = try args.getDouble("salvageValue")
        let holdingPeriod = try args.getInt("holdingPeriod")
        let annualRate = try args.getDouble("discountRate")
        let maintenanceCost = args.getDoubleOptional("maintenanceCost") ?? 0.0

        guard annualRate > 0 else {
            throw ToolError.invalidArguments("discountRate must be positive")
        }

        guard leasePeriods > 0 && holdingPeriod > 0 else {
            throw ToolError.invalidArguments("leasePeriods and holdingPeriod must be positive")
        }

        // Calculate monthly rate (assuming monthly periods)
        let periodicRate = annualRate / 12.0

        // Lease PV: annuity PV
        let leasePV: Double
        if periodicRate > 0 {
            leasePV = leasePayment * (1 - pow(1 + periodicRate, Double(-leasePeriods))) / periodicRate
        } else {
            leasePV = leasePayment * Double(leasePeriods)
        }

        // Buy PV: purchase + PV of maintenance - PV of salvage
        let maintenancePV: Double
        if periodicRate > 0 && maintenanceCost > 0 {
            maintenancePV = maintenanceCost * (1 - pow(1 + periodicRate, Double(-holdingPeriod))) / periodicRate
        } else {
            maintenancePV = maintenanceCost * Double(holdingPeriod)
        }
        let salvagePV = salvageValue / pow(1 + periodicRate, Double(holdingPeriod))
        let buyPV = purchasePrice + maintenancePV - salvagePV

        // Net Advantage to Leasing
        let nal = buyPV - leasePV
        let recommendation = nal > 0 ? "LEASE" : "BUY"
        let savingsPercent = abs(nal) / max(leasePV, buyPV) * 100

        let result = """
        Lease vs Buy Analysis
        ======================

        Lease Option:
          Payment: \(leasePayment.currency())/period
          Periods: \(leasePeriods)
          Lease PV: \(leasePV.currency())

        Buy Option:
          Purchase Price: \(purchasePrice.currency())
          Salvage Value: \(salvageValue.currency()) (PV: \(salvagePV.currency()))
          Maintenance: \(maintenanceCost.currency())/period (PV: \(maintenancePV.currency()))
          Holding Period: \(holdingPeriod) periods
          Buy PV: \(buyPV.currency())

        Discount Rate: \(annualRate.percent()) annual (\((periodicRate * 100).formatDecimal(decimals: 3))%/period)

        Decision:
          Net Advantage to Leasing (NAL): \(nal.currency())
          Recommendation: \(recommendation)
          Savings: \(savingsPercent.formatDecimal(decimals: 1))%

        NAL = Buy PV - Lease PV = \(buyPV.currency()) - \(leasePV.currency()) = \(nal.currency())
        \(nal > 0 ? "Leasing saves \(nal.currency()) in present value terms." : "Buying saves \((-nal).currency()) in present value terms.")
        """

        return .success(text: result)
    }
}

// MARK: - Financial Ratio Summary Tool

public struct RatioSummaryTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_ratio_summary",
        description: """
        Compute all key financial ratios from statement data in a single call.

        Accepts raw financial statement line items as arrays (one value per period)
        and computes comprehensive ratios across four categories.

        Categories:
        • Profitability: Gross margin, operating margin, net margin, ROE, ROA
        • Liquidity: Current ratio, quick ratio, cash ratio
        • Solvency: Debt-to-equity, debt-to-assets, interest coverage
        • Efficiency: Asset turnover, inventory turnover, receivables turnover

        Replaces 10+ individual ratio tool calls with a single comprehensive analysis.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "revenue": MCPSchemaProperty(type: "array", description: "Revenue per period", items: MCPSchemaItems(type: "number")),
                "cogs": MCPSchemaProperty(type: "array", description: "Cost of goods sold per period", items: MCPSchemaItems(type: "number")),
                "operatingExpenses": MCPSchemaProperty(type: "array", description: "Operating expenses per period", items: MCPSchemaItems(type: "number")),
                "interestExpense": MCPSchemaProperty(type: "array", description: "Interest expense per period", items: MCPSchemaItems(type: "number")),
                "taxExpense": MCPSchemaProperty(type: "array", description: "Tax expense per period", items: MCPSchemaItems(type: "number")),
                "totalAssets": MCPSchemaProperty(type: "array", description: "Total assets per period", items: MCPSchemaItems(type: "number")),
                "totalLiabilities": MCPSchemaProperty(type: "array", description: "Total liabilities per period", items: MCPSchemaItems(type: "number")),
                "totalEquity": MCPSchemaProperty(type: "array", description: "Total equity per period", items: MCPSchemaItems(type: "number")),
                "currentAssets": MCPSchemaProperty(type: "array", description: "Current assets per period", items: MCPSchemaItems(type: "number")),
                "currentLiabilities": MCPSchemaProperty(type: "array", description: "Current liabilities per period", items: MCPSchemaItems(type: "number")),
                "cash": MCPSchemaProperty(type: "array", description: "Cash and equivalents per period", items: MCPSchemaItems(type: "number")),
                "inventory": MCPSchemaProperty(type: "array", description: "Inventory per period", items: MCPSchemaItems(type: "number")),
                "accountsReceivable": MCPSchemaProperty(type: "array", description: "Accounts receivable per period", items: MCPSchemaItems(type: "number")),
                "categories": MCPSchemaProperty(type: "array", description: "Which ratio groups: profitability, liquidity, solvency, efficiency (default: all)", items: MCPSchemaItems(type: "string"))
            ],
            required: ["revenue", "totalAssets", "totalEquity"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let revenue = try args.getDoubleArray("revenue")
        let cogs = (try? args.getDoubleArray("cogs")) ?? revenue.map { _ in 0.0 }
        let opex = (try? args.getDoubleArray("operatingExpenses")) ?? revenue.map { _ in 0.0 }
        let interest = (try? args.getDoubleArray("interestExpense")) ?? revenue.map { _ in 0.0 }
        let tax = (try? args.getDoubleArray("taxExpense")) ?? revenue.map { _ in 0.0 }
        let totalAssets = try args.getDoubleArray("totalAssets")
        let totalLiabilities = (try? args.getDoubleArray("totalLiabilities")) ?? totalAssets.map { _ in 0.0 }
        let totalEquity = try args.getDoubleArray("totalEquity")
        let currentAssets = (try? args.getDoubleArray("currentAssets")) ?? totalAssets
        let currentLiabilities = (try? args.getDoubleArray("currentLiabilities")) ?? totalLiabilities
        let cash = (try? args.getDoubleArray("cash")) ?? currentAssets.map { _ in 0.0 }
        let inventory = (try? args.getDoubleArray("inventory")) ?? currentAssets.map { _ in 0.0 }
        let ar = (try? args.getDoubleArray("accountsReceivable")) ?? currentAssets.map { _ in 0.0 }

        let categoryStrs = (try? args.getStringArray("categories")) ?? ["profitability", "liquidity", "solvency", "efficiency"]
        let categories = Set(categoryStrs.map { $0.lowercased() })

        let periods = revenue.count
        var output = "Financial Ratio Summary (\(periods) period\(periods == 1 ? "" : "s"))\n"
        output += String(repeating: "=", count: 50) + "\n"

        for p in 0..<periods {
            output += "\nPeriod \(p + 1):\n"

            let grossProfit = revenue[p] - cogs[p]
            let operatingIncome = grossProfit - opex[p]
            let netIncome = operatingIncome - interest[p] - tax[p]

            if categories.contains("profitability") {
                let grossMargin = revenue[p] > 0 ? grossProfit / revenue[p] : 0
                let opMargin = revenue[p] > 0 ? operatingIncome / revenue[p] : 0
                let netMargin = revenue[p] > 0 ? netIncome / revenue[p] : 0
                let roe = totalEquity[p] > 0 ? netIncome / totalEquity[p] : 0
                let roa = totalAssets[p] > 0 ? netIncome / totalAssets[p] : 0

                output += """
                  Profitability:
                    Gross Margin: \(grossMargin.percent())
                    Operating Margin: \(opMargin.percent())
                    Net Margin: \(netMargin.percent())
                    Return on Equity (ROE): \(roe.percent())
                    Return on Assets (ROA): \(roa.percent())

                """
            }

            if categories.contains("liquidity") {
                let currentRatio = currentLiabilities[p] > 0 ? currentAssets[p] / currentLiabilities[p] : 0
                let quickRatio = currentLiabilities[p] > 0 ? (currentAssets[p] - inventory[p]) / currentLiabilities[p] : 0
                let cashRatio = currentLiabilities[p] > 0 ? cash[p] / currentLiabilities[p] : 0

                output += """
                  Liquidity:
                    Current Ratio: \(currentRatio.formatDecimal(decimals: 2))x
                    Quick Ratio: \(quickRatio.formatDecimal(decimals: 2))x
                    Cash Ratio: \(cashRatio.formatDecimal(decimals: 2))x

                """
            }

            if categories.contains("solvency") {
                let debtToEquity = totalEquity[p] > 0 ? totalLiabilities[p] / totalEquity[p] : 0
                let debtToAssets = totalAssets[p] > 0 ? totalLiabilities[p] / totalAssets[p] : 0
                let interestCoverage = interest[p] > 0 ? operatingIncome / interest[p] : 0

                output += """
                  Solvency:
                    Debt-to-Equity: \(debtToEquity.formatDecimal(decimals: 2))x
                    Debt-to-Assets: \(debtToAssets.percent())
                    Interest Coverage: \(interestCoverage.formatDecimal(decimals: 2))x

                """
            }

            if categories.contains("efficiency") {
                let assetTurnover = totalAssets[p] > 0 ? revenue[p] / totalAssets[p] : 0
                let inventoryTurnover = inventory[p] > 0 ? cogs[p] / inventory[p] : 0
                let receivablesTurnover = ar[p] > 0 ? revenue[p] / ar[p] : 0

                output += """
                  Efficiency:
                    Asset Turnover: \(assetTurnover.formatDecimal(decimals: 2))x
                    Inventory Turnover: \(inventoryTurnover.formatDecimal(decimals: 2))x
                    Receivables Turnover: \(receivablesTurnover.formatDecimal(decimals: 2))x

                """
            }
        }

        return .success(text: output)
    }
}

// MARK: - Cap Table Tool

public struct CapTableTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "model_cap_table",
        description: """
        Model startup capitalization table — ownership, funding rounds, and liquidation waterfall.

        Actions:
        • ownership: Show current ownership percentages
        • modelRound: Model a new funding round with dilution
        • grantOptions: Grant options from the pool
        • liquidationWaterfall: Distribute exit proceeds by preference

        Supports ISO 8601 dates for investment dates.

        Example: 2 founders (4M shares each), seed investor (1M shares),
        1M option pool → model Series A at $20M pre-money.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "shareholders": MCPSchemaProperty(
                    type: "array",
                    description: "Array of shareholder objects: {name, shares, pricePerShare, investmentDate?, liquidationPreference?}",
                    items: MCPSchemaItems(type: "object")
                ),
                "optionPool": MCPSchemaProperty(
                    type: "number",
                    description: "Number of shares in option pool"
                ),
                "action": MCPSchemaProperty(
                    type: "string",
                    description: "Action: ownership, modelRound, grantOptions, liquidationWaterfall",
                    enum: ["ownership", "modelRound", "grantOptions", "liquidationWaterfall"]
                ),
                "roundParams": MCPSchemaProperty(
                    type: "object",
                    description: "For modelRound: {newInvestment, preMoneyValuation, investorName}"
                ),
                "grantParams": MCPSchemaProperty(
                    type: "object",
                    description: "For grantOptions: {recipient, shares, strikePrice}"
                ),
                "exitValue": MCPSchemaProperty(
                    type: "number",
                    description: "For liquidationWaterfall: total exit proceeds"
                )
            ],
            required: ["shareholders", "optionPool", "action"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let action = try args.getString("action")
        let optionPool = try args.getDouble("optionPool")

        // Parse shareholders
        guard let shareholdersValue = args["shareholders"],
              let shareholdersList = shareholdersValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("shareholders must be an array")
        }

        let dateFormatter = ISO8601DateFormatter()
        var shareholders: [CapTable.Shareholder] = []

        for (i, item) in shareholdersList.enumerated() {
            guard let dict = item.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("shareholders[\(i)] must be an object")
            }
            guard let nameValue = dict["name"], let name = nameValue.value as? String else {
                throw ToolError.invalidArguments("shareholders[\(i)].name is required")
            }
            guard let sharesValue = dict["shares"] else {
                throw ToolError.invalidArguments("shareholders[\(i)].shares is required")
            }
            let shares: Double
            if let d = sharesValue.value as? Double { shares = d }
            else if let n = sharesValue.value as? Int { shares = Double(n) }
            else { throw ToolError.invalidArguments("shareholders[\(i)].shares must be a number") }

            guard let ppsValue = dict["pricePerShare"] else {
                throw ToolError.invalidArguments("shareholders[\(i)].pricePerShare is required")
            }
            let pps: Double
            if let d = ppsValue.value as? Double { pps = d }
            else if let n = ppsValue.value as? Int { pps = Double(n) }
            else { throw ToolError.invalidArguments("shareholders[\(i)].pricePerShare must be a number") }

            var investmentDate = Date()
            if let dateValue = dict["investmentDate"], let dateStr = dateValue.value as? String {
                if let parsed = dateFormatter.date(from: dateStr) {
                    investmentDate = parsed
                }
            }

            var liquidationPreference: Double?
            if let lpValue = dict["liquidationPreference"] {
                if let d = lpValue.value as? Double { liquidationPreference = d }
                else if let n = lpValue.value as? Int { liquidationPreference = Double(n) }
            }

            shareholders.append(CapTable.Shareholder(
                name: name,
                shares: shares,
                investmentDate: investmentDate,
                pricePerShare: pps,
                liquidationPreference: liquidationPreference
            ))
        }

        let capTable = CapTable(shareholders: shareholders, optionPool: optionPool)

        switch action {
        case "ownership":
            let ownership = capTable.ownership()
            let totalShares = shareholders.reduce(0.0) { $0 + $1.shares } + optionPool

            var output = "Cap Table — Ownership\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            for sh in shareholders {
                let pct = ownership[sh.name] ?? 0
                output += "  \(sh.name): \(sh.shares.formatDecimal(decimals: 0)) shares (\((pct * 100).formatDecimal(decimals: 2))%)\n"
            }
            if optionPool > 0 {
                let poolPct = optionPool / totalShares * 100
                output += "  Option Pool: \(optionPool.formatDecimal(decimals: 0)) shares (\(poolPct.formatDecimal(decimals: 2))%)\n"
            }
            output += "\n  Total Fully Diluted: \(totalShares.formatDecimal(decimals: 0)) shares\n"

            return .success(text: output)

        case "modelRound":
            guard let rpValue = args["roundParams"],
                  let rpDict = rpValue.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("roundParams required for modelRound action")
            }

            let investment: Double
            if let key = rpDict["newInvestment"] {
                if let d = key.value as? Double { investment = d }
                else if let n = key.value as? Int { investment = Double(n) }
                else { throw ToolError.invalidArguments("roundParams.newInvestment must be a number") }
            } else {
                throw ToolError.invalidArguments("roundParams.newInvestment is required")
            }

            let preMoney: Double
            if let key = rpDict["preMoneyValuation"] {
                if let d = key.value as? Double { preMoney = d }
                else if let n = key.value as? Int { preMoney = Double(n) }
                else { throw ToolError.invalidArguments("roundParams.preMoneyValuation must be a number") }
            } else {
                throw ToolError.invalidArguments("roundParams.preMoneyValuation is required")
            }

            var investorName = "New Investor"
            if let nameValue = rpDict["investorName"], let n = nameValue.value as? String {
                investorName = n
            }

            let postTable = capTable.modelRound(
                newInvestment: investment,
                preMoneyValuation: preMoney,
                optionPoolIncrease: 0,
                investorName: investorName
            )

            let postOwnership = postTable.ownership()
            let postTotal = postTable.shareholders.reduce(0.0) { $0 + $1.shares } + postTable.optionPool

            var output = "Cap Table — Post-\(investorName) Round\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            output += "  Pre-Money Valuation: \(preMoney.currency())\n"
            output += "  Investment: \(investment.currency())\n"
            output += "  Post-Money Valuation: \((preMoney + investment).currency())\n\n"

            for sh in postTable.shareholders {
                let pct = postOwnership[sh.name] ?? 0
                output += "  \(sh.name): \(sh.shares.formatDecimal(decimals: 0)) shares (\((pct * 100).formatDecimal(decimals: 2))%)\n"
            }
            if postTable.optionPool > 0 {
                let poolPct = postTable.optionPool / postTotal * 100
                output += "  Option Pool: \(postTable.optionPool.formatDecimal(decimals: 0)) shares (\(poolPct.formatDecimal(decimals: 2))%)\n"
            }
            output += "\n  Total Fully Diluted: \(postTotal.formatDecimal(decimals: 0)) shares\n"

            return .success(text: output)

        case "grantOptions":
            guard let gpValue = args["grantParams"],
                  let gpDict = gpValue.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("grantParams required for grantOptions action")
            }
            guard let recipientValue = gpDict["recipient"], let recipient = recipientValue.value as? String else {
                throw ToolError.invalidArguments("grantParams.recipient is required")
            }
            let grantShares: Double
            if let key = gpDict["shares"] {
                if let d = key.value as? Double { grantShares = d }
                else if let n = key.value as? Int { grantShares = Double(n) }
                else { throw ToolError.invalidArguments("grantParams.shares must be a number") }
            } else {
                throw ToolError.invalidArguments("grantParams.shares is required")
            }
            let strikePrice: Double
            if let key = gpDict["strikePrice"] {
                if let d = key.value as? Double { strikePrice = d }
                else if let n = key.value as? Int { strikePrice = Double(n) }
                else { strikePrice = 0.0 }
            } else {
                strikePrice = 0.0
            }

            let postGrant = capTable.grantOptions(
                recipient: recipient, shares: grantShares, strikePrice: strikePrice
            )

            var output = "Cap Table — Option Grant\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            output += "  Granted \(grantShares.formatDecimal(decimals: 0)) options to \(recipient) at \(strikePrice.currency()) strike\n\n"

            let postOwnership = postGrant.ownership()
            for sh in postGrant.shareholders {
                let pct = postOwnership[sh.name] ?? 0
                output += "  \(sh.name): \(sh.shares.formatDecimal(decimals: 0)) shares (\((pct * 100).formatDecimal(decimals: 2))%)\n"
            }
            output += "  Remaining Option Pool: \(postGrant.optionPool.formatDecimal(decimals: 0)) shares\n"

            return .success(text: output)

        case "liquidationWaterfall":
            guard let exitValue = args.getDoubleOptional("exitValue") else {
                throw ToolError.invalidArguments("exitValue required for liquidationWaterfall action")
            }

            let distribution = capTable.liquidationWaterfall(exitValue: exitValue)

            var output = "Liquidation Waterfall Distribution\n"
            output += String(repeating: "=", count: 50) + "\n\n"
            output += "  Exit Value: \(exitValue.currency())\n\n"

            for (name, amount) in distribution.sorted(by: { $0.value > $1.value }) {
                let pct = exitValue > 0 ? amount / exitValue * 100 : 0
                output += "  \(name): \(amount.currency()) (\(pct.formatDecimal(decimals: 2))%)\n"
            }

            let totalDistributed = distribution.values.reduce(0.0, +)
            output += "\n  Total Distributed: \(totalDistributed.currency())\n"

            return .success(text: output)

        default:
            throw ToolError.invalidArguments("Unknown action '\(action)'. Valid: ownership, modelRound, grantOptions, liquidationWaterfall")
        }
    }
}
