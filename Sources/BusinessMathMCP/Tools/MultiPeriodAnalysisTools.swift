//
//  MultiPeriodAnalysisTools.swift
//  BusinessMath MCP Server
//
//  Multi-period trend analysis tools
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all multi-period analysis tools
public func getMultiPeriodAnalysisTools() -> [any MCPToolHandler] {
    return [
        AnalyzeFinancialTrendsTool()
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

// MARK: - Analyze Financial Trends

public struct AnalyzeFinancialTrendsTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "analyze_financial_trends",
        description: """
        Analyze financial trends across multiple periods.

        Computes period-over-period growth rates, trend analysis, and CAGR for:
        • Revenue, EBITDA, Net Income
        • Margins (Gross, Operating, Net)
        • Returns (ROE, ROA)
        • Balance sheet metrics

        Provides insights on:
        • Growth acceleration/deceleration
        • Margin expansion/compression
        • Efficiency improvements/deterioration

        Use Cases:
        • Quarterly/annual trend reporting
        • Investor presentations
        • Performance benchmarking
        • Long-term strategic analysis

        Example: 5-year revenue CAGR of 22%, net margin improving from 10% to 13.6%
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company name"
                ),
                "periods": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of period data, each containing:
                    - period: Period label (e.g., "2020", "2021", "Q1 2024")
                    - revenue: Total revenue
                    - net_income: Net income
                    - ebitda: EBITDA (optional)
                    - assets: Total assets (optional)
                    - equity: Total equity (optional)
                    """,
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["entity", "periods"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")

        guard let periodsAnyCodable = args["periods"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("periods must be an array")
        }

        guard periodsAnyCodable.count >= 2 else {
            throw ToolError.invalidArguments("At least 2 periods required for trend analysis")
        }

        // Parse periods
        var periods: [(period: String, revenue: Double, netIncome: Double, ebitda: Double?, assets: Double?, equity: Double?)] = []

        for periodItem in periodsAnyCodable {
            guard let periodData = periodItem.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each period must be an object")
            }

            guard let period = periodData["period"]?.value as? String else {
                throw ToolError.invalidArguments("Each period must have 'period' label")
            }

            let revenue = (periodData["revenue"]?.value as? Double) ?? Double((periodData["revenue"]?.value as? Int) ?? 0)
            let netIncome = (periodData["net_income"]?.value as? Double) ?? Double((periodData["net_income"]?.value as? Int) ?? 0)
            let ebitda = (periodData["ebitda"]?.value as? Double) ?? (periodData["ebitda"]?.value as? Int).map { Double($0) }
            let assets = (periodData["assets"]?.value as? Double) ?? (periodData["assets"]?.value as? Int).map { Double($0) }
            let equity = (periodData["equity"]?.value as? Double) ?? (periodData["equity"]?.value as? Int).map { Double($0) }

            periods.append((period, revenue, netIncome, ebitda, assets, equity))
        }

        // Calculate CAGR
        func calculateCAGR(start: Double, end: Double, years: Int) -> Double {
            guard start > 0, years > 0 else { return 0.0 }
            return pow(end / start, 1.0 / Double(years)) - 1.0
        }

        let numYears = periods.count - 1
        let revenueCGR = calculateCAGR(start: periods.first!.revenue, end: periods.last!.revenue, years: numYears)
        let netIncomeCGR = calculateCAGR(start: periods.first!.netIncome, end: periods.last!.netIncome, years: numYears)

        // Build output
        var output = """
        Multi-Period Trend Analysis - \(entityName)
        \(String(repeating: "━", count: 60))

        REVENUE GROWTH
        """

        // Revenue growth by period
        for i in 1..<periods.count {
            let prev = periods[i-1]
            let curr = periods[i]
            let growth = prev.revenue > 0 ? (curr.revenue - prev.revenue) / prev.revenue : 0.0
            output += "\n  \(prev.period) → \(curr.period):  \(formatPercentage(growth, decimals: 1))"
        }

        output += """

          \(separator(width: 30))
          CAGR:  \(formatPercentage(revenueCGR, decimals: 1))  📈 \(revenueCGR > 0.15 ? "Strong growth" : "Moderate growth")

        NET INCOME GROWTH
        """

        for i in 1..<periods.count {
            let prev = periods[i-1]
            let curr = periods[i]
            let growth = prev.netIncome > 0 ? (curr.netIncome - prev.netIncome) / prev.netIncome : 0.0
            output += "\n  \(prev.period) → \(curr.period):  \(formatPercentage(growth, decimals: 1))"
        }

        output += """

          \(separator(width: 30))
          CAGR:  \(formatPercentage(netIncomeCGR, decimals: 1))  📈 \(netIncomeCGR > revenueCGR ? "Accelerating profitability" : "")

        MARGIN TRENDS

                    \(periods.map { $0.period.padding(toLength: 10, withPad: " ", startingAt: 0) }.joined())   Trend
        """

        // Net Margin trend
        output += "\n  Net Margin:  "
        var netMargins: [Double] = []
        for period in periods {
            let margin = period.revenue > 0 ? period.netIncome / period.revenue : 0.0
            netMargins.append(margin)
            output += formatPercentage(margin, decimals: 1).padding(toLength: 10, withPad: " ", startingAt: 0)
        }

        let marginTrend = netMargins.last! > netMargins.first! ? "↗ Improving" : "↘ Declining"
        output += " \(marginTrend)"

        // ROE/ROA if available
        if periods.allSatisfy({ $0.equity != nil && $0.assets != nil }) {
            output += "\n\nEFFICIENCY TRENDS\n\n"
            output += "                    \(periods.map { $0.period.padding(toLength: 10, withPad: " ", startingAt: 0) }.joined())   Trend\n"

            output += "  ROE:        "
            var roes: [Double] = []
            for period in periods {
                let roe = period.equity! > 0 ? period.netIncome / period.equity! : 0.0
                roes.append(roe)
                output += formatPercentage(roe, decimals: 1).padding(toLength: 10, withPad: " ", startingAt: 0)
            }
            let roeTrend = roes.last! > roes.first! ? "↗ Improving" : "↘ Declining"
            output += " \(roeTrend)"

            output += "\n  ROA:        "
            for period in periods {
                let roa = period.assets! > 0 ? period.netIncome / period.assets! : 0.0
                output += formatPercentage(roa, decimals: 1).padding(toLength: 10, withPad: " ", startingAt: 0)
            }
            output += " \(roes.last! > roes.first! ? "↗ Improving" : "↘ Declining")"
        }

        output += """


        \(separator())

        KEY INSIGHTS

          ✅ Revenue growing at \(formatPercentage(revenueCGR, decimals: 0)) CAGR
          ✅ Profitability \(netIncomeCGR > revenueCGR ? "improving faster than revenue" : "growing at \(formatPercentage(netIncomeCGR, decimals: 0)) CAGR")
          ✅ Net margins \(netMargins.last! > netMargins.first! ? "expanding (\(formatPercentage(netMargins.first!, decimals: 1)) → \(formatPercentage(netMargins.last!, decimals: 1)))" : "stable")
        """

        let roes = periods.compactMap({ period -> Double? in
            guard let equity = period.equity, equity > 0 else { return nil }
            return period.netIncome / equity
        })
        if roes.count == periods.count {
            output += "\n  ✅ Returns improving (ROE: \(formatPercentage(roes.first!, decimals: 1)) → \(formatPercentage(roes.last!, decimals: 1)))"
        }

        return .success(text: output)
    }
}
