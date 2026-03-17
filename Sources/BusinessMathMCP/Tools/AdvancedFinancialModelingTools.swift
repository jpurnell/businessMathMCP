//
//  AdvancedFinancialModelingTools.swift
//  BusinessMath MCP Server
//
//  Advanced financial modeling and scenario analysis tools
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all advanced financial modeling tools
public func getAdvancedFinancialModelingTools() -> [any MCPToolHandler] {
    return [
        ScenarioFinancialStatementsTool()
    ]
}

// MARK: - Helper Functions

private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

private func formatPercentage(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

private func formatCurrency(_ value: Double, decimals: Int = 0) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
    return "$" + (formatter.string(from: NSNumber(value: value)) ?? "0")
}

private func separator(width: Int = 60) -> String {
    return String(repeating: "─", count: width)
}

// MARK: - Scenario Financial Statements

public struct ScenarioFinancialStatementsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "scenario_financial_statements",
        description: """
        Run scenario analysis on financial statements with sensitivity analysis.

        Creates Base, Upside, and Downside scenarios by adjusting key assumptions:
        • Revenue growth rate
        • Gross margin
        • Operating expenses
        • Tax rate

        Outputs:
        • Scenario comparison (Base vs Upside vs Downside)
        • Impact on Net Income, EBITDA, margins
        • ROE and profitability metrics
        • Sensitivity analysis

        Use Cases:
        • Budget planning and forecasting
        • Investment decision-making
        • Risk assessment
        • Board presentations
        • Fundraising scenarios

        Example: Base case: $10M revenue, 60% GM
                 Upside: +20% revenue, +5pp GM
                 Downside: -10% revenue, -5pp GM
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company name"
                ),
                "base_case": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Base case assumptions:
                    - revenue: Base revenue
                    - gross_margin: Gross margin as decimal (e.g., 0.60)
                    - opex: Operating expenses
                    - tax_rate: Tax rate as decimal
                    - equity: Total equity (for ROE)
                    """
                ),
                "upside_adjustments": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Upside scenario adjustments:
                    - revenue_growth: Revenue increase (e.g., 0.20 for +20%)
                    - margin_improvement: GM increase in pp (e.g., 0.05 for +5pp)
                    - opex_leverage: OpEx reduction (e.g., -0.10 for -10%)
                    """
                ),
                "downside_adjustments": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Downside scenario adjustments (typically negative):
                    - revenue_growth: Revenue change (e.g., -0.10 for -10%)
                    - margin_deterioration: GM decrease in pp (e.g., -0.05 for -5pp)
                    - opex_increase: OpEx increase (e.g., 0.10 for +10%)
                    """
                )
            ],
            required: ["entity", "base_case"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")

        guard let baseCase = args["base_case"]?.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("base_case required")
        }

        // Extract base case
        let baseRevenue = (baseCase["revenue"]?.value as? Double) ?? Double((baseCase["revenue"]?.value as? Int) ?? 0)
        let baseGM = (baseCase["gross_margin"]?.value as? Double) ?? 0.0
        let baseOpex = (baseCase["opex"]?.value as? Double) ?? Double((baseCase["opex"]?.value as? Int) ?? 0)
        let baseTaxRate = (baseCase["tax_rate"]?.value as? Double) ?? 0.25
        let equity = (baseCase["equity"]?.value as? Double) ?? Double((baseCase["equity"]?.value as? Int) ?? 0)

        // Calculate base case
        let baseGrossProfit = baseRevenue * baseGM
        let baseEBITDA = baseGrossProfit - baseOpex
        let baseNetIncome = baseEBITDA * (1.0 - baseTaxRate)
        let baseROE = equity > 0 ? baseNetIncome / equity : 0.0

        // Upside scenario
        let upsideAdjustments = args["upside_adjustments"]?.value as? [String: AnyCodable]
        let upsideRevGrowth = (upsideAdjustments?["revenue_growth"]?.value as? Double) ?? 0.15
        let upsideMarginImp = (upsideAdjustments?["margin_improvement"]?.value as? Double) ?? 0.03
        let upsideOpexLeverage = (upsideAdjustments?["opex_leverage"]?.value as? Double) ?? -0.05

        let upsideRevenue = baseRevenue * (1.0 + upsideRevGrowth)
        let upsideGM = baseGM + upsideMarginImp
        let upsideOpex = baseOpex * (1.0 + upsideOpexLeverage)
        let upsideGrossProfit = upsideRevenue * upsideGM
        let upsideEBITDA = upsideGrossProfit - upsideOpex
        let upsideNetIncome = upsideEBITDA * (1.0 - baseTaxRate)
        let upsideROE = equity > 0 ? upsideNetIncome / equity : 0.0

        // Downside scenario
        let downsideAdjustments = args["downside_adjustments"]?.value as? [String: AnyCodable]
        let downsideRevGrowth = (downsideAdjustments?["revenue_growth"]?.value as? Double) ?? -0.10
        let downsideMarginDet = (downsideAdjustments?["margin_deterioration"]?.value as? Double) ?? -0.03
        let downsideOpexInc = (downsideAdjustments?["opex_increase"]?.value as? Double) ?? 0.05

        let downsideRevenue = baseRevenue * (1.0 + downsideRevGrowth)
        let downsideGM = baseGM + downsideMarginDet
        let downsideOpex = baseOpex * (1.0 + downsideOpexInc)
        let downsideGrossProfit = downsideRevenue * downsideGM
        let downsideEBITDA = downsideGrossProfit - downsideOpex
        let downsideNetIncome = downsideEBITDA * (1.0 - baseTaxRate)
        let downsideROE = equity > 0 ? downsideNetIncome / equity : 0.0

        // Build output
        let output = """
        Scenario Analysis - \(entityName)
        \(String(repeating: "━", count: 80))

        SCENARIO COMPARISON

                                    Base Case       Upside          Downside
        \(separator(width: 80))

        Revenue                  \(formatCurrency(baseRevenue).paddingLeft(toLength: 15)) \(formatCurrency(upsideRevenue).paddingLeft(toLength: 15)) \(formatCurrency(downsideRevenue).paddingLeft(toLength: 15))
        Gross Margin             \(formatPercentage(baseGM, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(upsideGM, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(downsideGM, decimals: 1).paddingLeft(toLength: 15))
        Gross Profit             \(formatCurrency(baseGrossProfit).paddingLeft(toLength: 15)) \(formatCurrency(upsideGrossProfit).paddingLeft(toLength: 15)) \(formatCurrency(downsideGrossProfit).paddingLeft(toLength: 15))

        Operating Expenses       \(formatCurrency(baseOpex).paddingLeft(toLength: 15)) \(formatCurrency(upsideOpex).paddingLeft(toLength: 15)) \(formatCurrency(downsideOpex).paddingLeft(toLength: 15))

        EBITDA                   \(formatCurrency(baseEBITDA).paddingLeft(toLength: 15)) \(formatCurrency(upsideEBITDA).paddingLeft(toLength: 15)) \(formatCurrency(downsideEBITDA).paddingLeft(toLength: 15))
        EBITDA Margin            \(formatPercentage(baseEBITDA/baseRevenue, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(upsideEBITDA/upsideRevenue, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(downsideEBITDA/downsideRevenue, decimals: 1).paddingLeft(toLength: 15))

        Net Income               \(formatCurrency(baseNetIncome).paddingLeft(toLength: 15)) \(formatCurrency(upsideNetIncome).paddingLeft(toLength: 15)) \(formatCurrency(downsideNetIncome).paddingLeft(toLength: 15))
        Net Margin               \(formatPercentage(baseNetIncome/baseRevenue, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(upsideNetIncome/upsideRevenue, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(downsideNetIncome/downsideRevenue, decimals: 1).paddingLeft(toLength: 15))

        ROE                      \(formatPercentage(baseROE, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(upsideROE, decimals: 1).paddingLeft(toLength: 15)) \(formatPercentage(downsideROE, decimals: 1).paddingLeft(toLength: 15))

        \(separator(width: 80))

        VARIANCE FROM BASE CASE

                                                Upside              Downside
        \(separator(width: 80))

        Revenue                              \(formatPercentage(upsideRevGrowth, decimals: 0).paddingLeft(toLength: 15)) \(formatPercentage(downsideRevGrowth, decimals: 0).paddingLeft(toLength: 15))
        Net Income (absolute)                \(formatCurrency(upsideNetIncome - baseNetIncome).paddingLeft(toLength: 15)) \(formatCurrency(downsideNetIncome - baseNetIncome).paddingLeft(toLength: 15))
        Net Income (%)                       \(formatPercentage((upsideNetIncome - baseNetIncome)/baseNetIncome, decimals: 0).paddingLeft(toLength: 15)) \(formatPercentage((downsideNetIncome - baseNetIncome)/baseNetIncome, decimals: 0).paddingLeft(toLength: 15))

        \(separator(width: 80))

        KEY INSIGHTS

        Upside Scenario (\(formatPercentage(upsideRevGrowth, decimals: 0)) revenue growth):
          • Net income increases by \(formatCurrency(upsideNetIncome - baseNetIncome)) (\(formatPercentage((upsideNetIncome - baseNetIncome)/baseNetIncome, decimals: 0)))
          • EBITDA margin expands to \(formatPercentage(upsideEBITDA/upsideRevenue, decimals: 1))
          • ROE improves to \(formatPercentage(upsideROE, decimals: 1))

        Downside Scenario (\(formatPercentage(downsideRevGrowth, decimals: 0)) revenue growth):
          • Net income decreases by \(formatCurrency(baseNetIncome - downsideNetIncome)) (\(formatPercentage((baseNetIncome - downsideNetIncome)/baseNetIncome, decimals: 0)))
          • EBITDA margin compresses to \(formatPercentage(downsideEBITDA/downsideRevenue, decimals: 1))
          • ROE declines to \(formatPercentage(downsideROE, decimals: 1))

        Next Steps:
          • Assess probability of each scenario
          • Identify key drivers and sensitivities
          • Develop mitigation strategies for downside risks
          • Capitalize on upside opportunities
        """

        return .success(text: output)
    }
}
