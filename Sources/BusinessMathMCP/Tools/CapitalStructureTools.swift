//
//  CapitalStructureTools.swift
//  BusinessMath MCP Server
//
//  Capital structure and WACC calculation tools
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all capital structure tools
public func getCapitalStructureTools() -> [any MCPToolHandler] {
    return [
        CalculateWACCTool(),
        CalculateCostOfEquityTool()
    ]
}

private func separator(width: Int = 40) -> String {
    return String(repeating: "─", count: width)
}

// MARK: - 1. Calculate WACC

public struct CalculateWACCTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_wacc",
        description: """
        Calculate the Weighted Average Cost of Capital (WACC).

        WACC represents the average rate a company must pay to finance its assets,
        weighted by the proportion of debt and equity in the capital structure.
        It accounts for the tax deductibility of interest payments.

        Formula:
        WACC = (E/(E+D)) × Re + (D/(E+D)) × Rd × (1-T)

        Where:
        • E = Market value of equity
        • D = Market value of debt (Net Debt = Total Debt - Cash)
        • Re = Cost of equity (calculated via CAPM if not provided)
        • Rd = Cost of debt (pre-tax)
        • T = Corporate tax rate

        Components:
        • Equity Weight (E/V): Proportion of equity financing
        • Debt Weight (D/V): Proportion of debt financing
        • After-tax Cost of Debt: Rd × (1-T)
        • Tax Shield: Annual tax savings from debt

        Use Cases:
        • Evaluate investment projects (hurdle rate)
        • Value companies (DCF discount rate)
        • Optimize capital structure
        • Assess cost of capital across scenarios

        Interpretation:
        • WACC is the minimum return required on investments
        • Projects with IRR > WACC create shareholder value
        • Lower WACC = higher company valuation (all else equal)
        • Optimal capital structure minimizes WACC

        Example: Company with $100M equity, $40M net debt, 11.2% cost of equity,
                 5% cost of debt, 25% tax rate → WACC = 9.27%
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "market_cap": MCPSchemaProperty(
                    type: "number",
                    description: "Market capitalization (market value of equity)"
                ),
                "total_debt": MCPSchemaProperty(
                    type: "number",
                    description: "Total debt (short-term + long-term)"
                ),
                "cash": MCPSchemaProperty(
                    type: "number",
                    description: "Cash and cash equivalents (optional, defaults to 0)"
                ),
                "risk_free_rate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate (e.g., 10-year Treasury yield) as decimal (e.g., 0.04 for 4%)"
                ),
                "market_return": MCPSchemaProperty(
                    type: "number",
                    description: "Expected market return as decimal (e.g., 0.10 for 10%)"
                ),
                "beta": MCPSchemaProperty(
                    type: "number",
                    description: "Company beta (systematic risk relative to market)"
                ),
                "debt_interest_rate": MCPSchemaProperty(
                    type: "number",
                    description: "Interest rate on debt as decimal (e.g., 0.05 for 5%)"
                ),
                "tax_rate": MCPSchemaProperty(
                    type: "number",
                    description: "Corporate tax rate as decimal (e.g., 0.25 for 25%)"
                ),
                "cost_of_equity": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of equity as decimal (optional, will be calculated via CAPM if not provided)"
                )
            ],
            required: ["market_cap", "total_debt", "risk_free_rate", "market_return", "beta", "debt_interest_rate", "tax_rate"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let marketCap = try args.getDouble("market_cap")
        let totalDebt = try args.getDouble("total_debt")
        let cash = (try? args.getDouble("cash")) ?? 0.0
        let riskFreeRate = try args.getDouble("risk_free_rate")
        let marketReturn = try args.getDouble("market_return")
        let beta = try args.getDouble("beta")
        let debtInterestRate = try args.getDouble("debt_interest_rate")
        let taxRate = try args.getDouble("tax_rate")

        // Calculate net debt
        let netDebt = totalDebt - cash

        // Calculate cost of equity (CAPM)
        let costOfEquityProvided = try? args.getDouble("cost_of_equity")
        let costOfEquity = costOfEquityProvided ?? capm(
            riskFreeRate: riskFreeRate,
            beta: beta,
            marketReturn: marketReturn
        )

        // Create CapitalStructure
        let structure = CapitalStructure(
            debtValue: netDebt,
            equityValue: marketCap,
            costOfDebt: debtInterestRate,
            costOfEquity: costOfEquity,
            taxRate: taxRate
        )

        // Calculate metrics
        let waccValue = structure.wacc
        let totalValue = structure.totalValue
        let equityWeight = structure.equityRatio
        let debtWeight = structure.debtRatio
        let afterTaxDebt = structure.afterTaxCostOfDebt
        let taxShield = structure.annualTaxShield
        let interestExpense = structure.annualInterestExpense

        // Build output
        let output = """
        Capital Structure Analysis
        \(String(repeating: "━", count: 60))

        CAPITAL STRUCTURE

          Market Cap (E)                \(marketCap.currency())
          Total Debt                    \(totalDebt.currency())
          Cash                          \(cash.currency())
                                        \(separator(width: 15))
          Net Debt (D)                  \(netDebt.currency())
          Total Value (E+D)             \(totalValue.currency())

        COMPONENT WEIGHTS

          Equity Weight (E/V)               \(equityWeight.percent(1))
          Debt Weight (D/V)                 \(debtWeight.percent(1))

        COST OF CAPITAL COMPONENTS

          Risk-Free Rate (Rf)               \(riskFreeRate.percent(1))
          Market Return (Rm)                \(marketReturn.percent(1))
          Market Risk Premium (Rm-Rf)       \((marketReturn - riskFreeRate).percent(1))
          Beta (β)                              \(beta.number(2))

          Cost of Equity (Re)               \(costOfEquity.percent(2))
            = Rf + β × (Rm - Rf)
            = \(riskFreeRate.percent(1)) + \(beta.number(2)) × \((marketReturn - riskFreeRate).percent(1))

          Debt Interest Rate                \(debtInterestRate.percent(1))
          Tax Rate                          \(taxRate.percent(1))
          After-Tax Cost of Debt            \(afterTaxDebt.percent(2))
            = \(debtInterestRate.percent(1)) × (1 - \(taxRate.percent(1)))

        \(String(repeating: "━", count: 60))

        WACC: \(waccValue.percent(2))

          = E/V × Re + D/V × Rd × (1-T)
          = \(equityWeight.percent(1)) × \(costOfEquity.percent(2)) + \(debtWeight.percent(1)) × \(afterTaxDebt.percent(2))

        \(String(repeating: "━", count: 60))

        TAX BENEFITS OF DEBT

          Annual Interest Expense       \(interestExpense.currency())
          Annual Tax Shield             \(taxShield.currency())
            = Interest × Tax Rate
            = \(interestExpense.currency()) × \(taxRate.percent(1))

          PV of Tax Shield              \(structure.taxShieldValue.currency())
            (assumes perpetual debt)

        \(String(repeating: "━", count: 60))

        INTERPRETATION

          The company should invest in projects with IRR > \(waccValue.percent(2))
          to create shareholder value.

          Current capital structure:
          • \(equityWeight.percent(0)) equity-financed
          • \(debtWeight.percent(0)) debt-financed
          • D/E ratio: \(structure.debtToEquityRatio.number(2))

        Next Steps:
          • Use WACC as discount rate in DCF valuations
          • Compare to peer company WACCs for benchmarking
          • Analyze optimal capital structure scenarios
          • Assess impact of leverage changes on WACC
        """

        return .success(text: output)
    }
}

// MARK: - 2. Calculate Cost of Equity

public struct CalculateCostOfEquityTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_cost_of_equity",
        description: """
        Calculate the cost of equity using CAPM (Capital Asset Pricing Model).

        CAPM estimates the expected return on equity based on systematic risk (beta)
        and the market risk premium. This is the return equity investors require
        for bearing the risk of investing in the company.

        Formula:
        Re = Rf + β × (Rm - Rf)

        Where:
        • Re = Expected return on equity (cost of equity)
        • Rf = Risk-free rate (typically 10-year Treasury yield)
        • β (beta) = Measure of systematic risk relative to market
        • Rm = Expected market return
        • (Rm - Rf) = Market risk premium (equity risk premium)

        Beta Interpretation:
        • β = 1.0: Stock moves with the market
        • β > 1.0: Stock is more volatile than market (amplifies market moves)
        • β < 1.0: Stock is less volatile than market (defensive)
        • β = 0.0: No correlation with market

        Use Cases:
        • Calculate WACC component
        • Evaluate equity investments
        • Assess required returns for equity holders
        • Compare cost of equity across companies
        • Unlever/relever betas for comparable analysis

        Example: Risk-free rate 4%, beta 1.2, market return 10%
                 → Cost of Equity = 4% + 1.2 × 6% = 11.2%
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "risk_free_rate": MCPSchemaProperty(
                    type: "number",
                    description: "Risk-free rate as decimal (e.g., 0.04 for 4%)"
                ),
                "beta": MCPSchemaProperty(
                    type: "number",
                    description: "Company beta (systematic risk)"
                ),
                "market_return": MCPSchemaProperty(
                    type: "number",
                    description: "Expected market return as decimal (e.g., 0.10 for 10%)"
                ),
                "debt_to_equity_ratio": MCPSchemaProperty(
                    type: "number",
                    description: "D/E ratio (optional, for unlevering/relevering beta)"
                ),
                "tax_rate": MCPSchemaProperty(
                    type: "number",
                    description: "Tax rate as decimal (optional, for unlevering/relevering)"
                )
            ],
            required: ["risk_free_rate", "beta", "market_return"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let riskFreeRate = try args.getDouble("risk_free_rate")
        let beta = try args.getDouble("beta")
        let marketReturn = try args.getDouble("market_return")
        let deRatio = try? args.getDouble("debt_to_equity_ratio")
        let taxRate = try? args.getDouble("tax_rate")

        // Calculate cost of equity
        let costOfEquity = capm(
            riskFreeRate: riskFreeRate,
            beta: beta,
            marketReturn: marketReturn
        )

        let marketRiskPremium = marketReturn - riskFreeRate

        // Build output
        var output = """
        Cost of Equity (CAPM) Analysis
        \(String(repeating: "━", count: 60))

        INPUTS

          Risk-Free Rate (Rf)               \(riskFreeRate.percent(2))
          Expected Market Return (Rm)       \(marketReturn.percent(2))
          Beta (β)                              \(beta.number(2))

        CALCULATION

          Market Risk Premium = Rm - Rf
            = \(marketReturn.percent(2)) - \(riskFreeRate.percent(2))
            = \(marketRiskPremium.percent(2))

          Cost of Equity (Re) = Rf + β × (Rm - Rf)
            = \(riskFreeRate.percent(2)) + \(beta.number(2)) × \(marketRiskPremium.percent(2))
            = \(costOfEquity.percent(2))

        \(String(repeating: "━", count: 60))

        COST OF EQUITY: \(costOfEquity.percent(2))

        """

        // Add beta analysis
        output += "\nBETA INTERPRETATION\n\n"

        if beta > 1.2 {
            output += "  β = \(beta.number(2)): High systematic risk\n"
            output += "  • Stock is significantly more volatile than market\n"
            output += "  • Amplifies market moves by \((beta - 1).percent(0))\n"
            output += "  • Suitable for aggressive portfolios\n"
        } else if beta > 1.0 {
            output += "  β = \(beta.number(2)): Above-market risk\n"
            output += "  • Stock is moderately more volatile than market\n"
            output += "  • Amplifies market moves by \((beta - 1).percent(0))\n"
        } else if beta > 0.8 {
            output += "  β = \(beta.number(2)): Near-market risk\n"
            output += "  • Stock moves roughly with the market\n"
            output += "  • Suitable for balanced portfolios\n"
        } else if beta > 0.0 {
            output += "  β = \(beta.number(2)): Below-market risk\n"
            output += "  • Stock is less volatile than market (defensive)\n"
            output += "  • Dampens market moves by \((1 - beta).percent(0))\n"
            output += "  • Suitable for conservative portfolios\n"
        } else {
            output += "  β = \(beta.number(2)): No systematic risk\n"
            output += "  • Stock uncorrelated with market\n"
        }

        // Add unlevering/relevering analysis if D/E provided
        if let de = deRatio, let tax = taxRate {
            let unleveredBeta = unleverBeta(
                leveredBeta: beta,
                debtToEquityRatio: de,
                taxRate: tax
            )

            let unleveredCostOfEquity = capm(
                riskFreeRate: riskFreeRate,
                beta: unleveredBeta,
                marketReturn: marketReturn
            )

            output += """

            \(String(repeating: "━", count: 60))

            UNLEVERED ANALYSIS
            (Removing impact of financial leverage)

              Levered Beta (βL)                 \(beta.number(2))
              Debt-to-Equity Ratio (D/E)        \(de.number(2))
              Tax Rate                          \(tax.percent(1))

              Unlevered Beta (βU)               \(unleveredBeta.number(2))
                = βL / [1 + (1-T) × D/E]
                = \(beta.number(2)) / [1 + (1-\(tax.percent(0))) × \(de.number(2))]

              Unlevered Cost of Equity          \(unleveredCostOfEquity.percent(2))

              Impact of Leverage:
              • Leverage increases beta by       \((beta - unleveredBeta).number(2))
              • Leverage increases cost by       \((costOfEquity - unleveredCostOfEquity).percent(2))
            """
        }

        output += """


        Next Steps:
          • Use as cost of equity component in WACC calculation
          • Compare to industry peer cost of equity
          • Assess if beta reflects company's actual risk profile
          • Consider using unlevered beta for comparable analysis
        """

        return .success(text: output)
    }
}
