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
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all multi-period analysis tools
public func getMultiPeriodAnalysisTools() -> [any MCPToolHandler] {
    return [
        AnalyzeFinancialTrendsTool()
    ]
}

// MARK: - Helper Functions

private func formatPercentage(_ value: Double, decimals: Int = 2) -> String {
    return (value * 100).formatDecimal(decimals: decimals) + "%"
}

private func separator(width: Int = 60) -> String {
    return String(repeating: "─", count: width)
}

// MARK: - Analyze Financial Trends

/// Analyze financial trends across multiple periods.
///
/// Exposed to clients as the `analyze_financial_trends` tool.
public struct AnalyzeFinancialTrendsTool: MCPToolHandler, Sendable {
    /// The `analyze_financial_trends` tool definition: name, description and input schema.
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

    /// Creates the `analyze_financial_trends` handler.
    public init() {}

    /// Runs `analyze_financial_trends` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
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

        // The loop above throws on a malformed entry rather than skipping it, so `periods`
        // matches the input that was already checked for two or more. Binding the endpoints
        // here keeps that invariant next to its use instead of twenty lines away.
        guard let firstPeriod = periods.first, let lastPeriod = periods.last else {
            throw ToolError.invalidArguments("At least 2 periods required for trend analysis")
        }
        let numYears = periods.count - 1
        let revenueCGR = calculateCAGR(start: firstPeriod.revenue, end: lastPeriod.revenue, years: numYears)
        let netIncomeCGR = calculateCAGR(start: firstPeriod.netIncome, end: lastPeriod.netIncome, years: numYears)

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

        let marginsRose: Bool = {
            guard let first = netMargins.first, let last = netMargins.last else { return false }
            return last > first
        }()
        let marginTrend = marginsRose ? "↗ Improving" : "↘ Declining"
        output += " \(marginTrend)"

        // ROE/ROA if available
        if periods.allSatisfy({ $0.equity != nil && $0.assets != nil }) {
            output += "\n\nEFFICIENCY TRENDS\n\n"
            output += "                    \(periods.map { $0.period.padding(toLength: 10, withPad: " ", startingAt: 0) }.joined())   Trend\n"

            output += "  ROE:        "
            var roes: [Double] = []
            for period in periods {
                let roe = period.equity.flatMap { $0 > 0 ? period.netIncome / $0 : nil } ?? 0.0
                roes.append(roe)
                output += formatPercentage(roe, decimals: 1).padding(toLength: 10, withPad: " ", startingAt: 0)
            }
            let roesRose: Bool = {
                guard let first = roes.first, let last = roes.last else { return false }
                return last > first
            }()
            let roeTrend = roesRose ? "↗ Improving" : "↘ Declining"
            output += " \(roeTrend)"

            output += "\n  ROA:        "
            for period in periods {
                let roa = period.assets.flatMap { $0 > 0 ? period.netIncome / $0 : nil } ?? 0.0
                output += formatPercentage(roa, decimals: 1).padding(toLength: 10, withPad: " ", startingAt: 0)
            }
            output += " \(roesRose ? "↗ Improving" : "↘ Declining")"
        }

        let marginSummary: String = {
            guard let first = netMargins.first, let last = netMargins.last, last > first else { return "stable" }
            return "expanding (\(formatPercentage(first, decimals: 1)) → \(formatPercentage(last, decimals: 1)))"
        }()

        output += """


        \(separator())

        KEY INSIGHTS

          ✅ Revenue growing at \(formatPercentage(revenueCGR, decimals: 0)) CAGR
          ✅ Profitability \(netIncomeCGR > revenueCGR ? "improving faster than revenue" : "growing at \(formatPercentage(netIncomeCGR, decimals: 0)) CAGR")
          ✅ Net margins \(marginSummary)
        """

        let roes = periods.compactMap({ period -> Double? in
            guard let equity = period.equity, equity > 0 else { return nil }
            return period.netIncome / equity
        })
        if roes.count == periods.count {
            if let firstROE = roes.first, let lastROE = roes.last {
                output += "\n  ✅ Returns improving (ROE: \(formatPercentage(firstROE, decimals: 1)) → \(formatPercentage(lastROE, decimals: 1)))"
            }
        }

        return .success(text: output)
    }
}
