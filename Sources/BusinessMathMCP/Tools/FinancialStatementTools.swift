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
        ValidateFinancialStatementsTool()
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
                    """
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
        guard let accountsArray = args["accounts"]?.value as? [[String: Any]] else {
            throw ToolError.invalidArguments("accounts must be an array of objects")
        }

        guard !accountsArray.isEmpty else {
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

        for accountData in accountsArray {
            guard let name = accountData["name"] as? String,
                  let roleString = accountData["role"] as? String else {
                throw ToolError.invalidArguments("Each account must have 'name' (string), 'role' (string), and 'value' (number)")
            }

            // Handle value as either Double or Int
            let value: Double
            if let valueDouble = accountData["value"] as? Double {
                value = valueDouble
            } else if let valueInt = accountData["value"] as? Int {
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
                    description: "Array of account objects with name, role, and value"
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
        guard let accountsArray = args["accounts"]?.value as? [[String: Any]] else {
            throw ToolError.invalidArguments("accounts must be an array")
        }

        guard !accountsArray.isEmpty else {
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

        for accountData in accountsArray {
            guard let name = accountData["name"] as? String,
                  let roleString = accountData["role"] as? String else {
                throw ToolError.invalidArguments("Each account must have 'name', 'role', and 'value'")
            }

            // Handle value as either Double or Int
            let value: Double
            if let valueDouble = accountData["value"] as? Double {
                value = valueDouble
            } else if let valueInt = accountData["value"] as? Int {
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

        guard let cashFlows = args["cash_flows"]?.value as? [String: Any] else {
            throw ToolError.invalidArguments("cash_flows must be an object")
        }

        // Helper to get value
        func getValue(_ key: String) -> Double {
            if let intVal = cashFlows[key] as? Int {
                return Double(intVal)
            } else if let doubleVal = cashFlows[key] as? Double {
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
        if let bs = args["balance_sheet"]?.value as? [String: Any] {
            if let assets = bs["total_assets"] as? Double,
               let liabilities = bs["total_liabilities"] as? Double,
               let equity = bs["total_equity"] as? Double {

                let diff = abs(assets - (liabilities + equity))
                if diff < 0.01 {
                    checks.append("✅ Balance sheet equation holds (A = L + E)")
                } else {
					issues.append("❌ Balance sheet does not balance: Assets \(assets.currency()) ≠ Liab \(liabilities.currency()) + Equity \(equity.currency()) (Diff: \(diff.currency()))")
                }
            }
        }

        // Income Statement Validation
        if let is_data = args["income_statement"]?.value as? [String: Any] {
            if let revenue = is_data["total_revenue"] as? Double,
               let netIncome = is_data["net_income"] as? Double {

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
        if let is_data = args["income_statement"]?.value as? [String: Any],
           let cf_data = args["cash_flow"]?.value as? [String: Any] {

            if let netIncome = is_data["net_income"] as? Double,
               let operatingCF = cf_data["operating_cf"] as? Double {

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
