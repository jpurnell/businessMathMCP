//
//  EnhancedCovenantTools.swift
//  BusinessMath MCP Server
//
//  Enhanced debt covenant monitoring tools
//

import Foundation
import BusinessMath
import Numerics
import MCP

// MARK: - Tool Registration

/// Returns all enhanced covenant monitoring tools
public func getEnhancedCovenantTools() -> [any MCPToolHandler] {
    return [
        MonitorDebtCovenantsComprehensiveTool()
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

// MARK: - Monitor Debt Covenants (Comprehensive)

public struct MonitorDebtCovenantsComprehensiveTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "monitor_debt_covenants",
        description: """
        Comprehensive debt covenant monitoring dashboard with headroom analysis.

        Monitors multiple financial covenants and calculates compliance, headroom,
        and risk levels. Provides actionable warnings for covenants approaching violation.

        Supported Covenant Types:
        • Current Ratio: Current Assets / Current Liabilities
        • Quick Ratio: (Current Assets - Inventory) / Current Liabilities
        • Debt-to-Equity: Total Debt / Total Equity
        • Interest Coverage: EBIT / Interest Expense
        • Debt Service Coverage (DSCR): EBITDA / (Interest + Principal)
        • Debt-to-EBITDA: Net Debt / EBITDA
        • Minimum EBITDA: EBITDA >= Threshold
        • Minimum Tangible Net Worth: (Equity - Intangibles) >= Threshold

        Headroom Analysis:
        • Headroom = Distance from covenant threshold
        • > 20%: Comfortable (✅)
        • 10-20%: Caution (⚠️)
        • < 10%: Warning (⚠️⚠️)
        • < 0%: Violated (❌)

        Use Cases:
        • Quarterly covenant compliance reporting
        • Lender reporting and audit preparation
        • Early warning system for potential violations
        • Capital structure planning
        • Debt refinancing decisions

        Example: Monitor 4 covenants, identify that Debt-to-EBITDA has only 5% headroom
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company name"
                ),
                "period": MCPSchemaProperty(
                    type: "string",
                    description: "Reporting period"
                ),
                "financials": MCPSchemaProperty(
                    type: "object",
                    description: """
                    Financial data for covenant calculations:
                    - current_assets, current_liabilities
                    - inventory (for quick ratio)
                    - total_debt, equity
                    - intangibles (for tangible net worth)
                    - ebitda, ebit
                    - interest_expense, principal_payment
                    """
                ),
                "covenants": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of covenant objects, each with:
                    - type: Covenant type (e.g., "current_ratio", "debt_to_equity")
                    - threshold: Required value
                    - direction: "minimum" or "maximum"
                    """,
                    items: MCPSchemaItems(type: "object")
                )
            ],
            required: ["entity", "period", "financials", "covenants"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")

        guard let financials = args["financials"]?.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("financials must be an object")
        }

        guard let covenantsAnyCodable = args["covenants"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("covenants must be an array")
        }

        // Extract financials
        func getFinValue(_ key: String) -> Double? {
            if let intVal = financials[key]?.value as? Int {
                return Double(intVal)
            } else if let doubleVal = financials[key]?.value as? Double {
                return doubleVal
            }
            return nil
        }

        let currentAssets = getFinValue("current_assets") ?? 0
        let currentLiabilities = getFinValue("current_liabilities") ?? 0
        let inventory = getFinValue("inventory") ?? 0
        let totalDebt = getFinValue("total_debt") ?? 0
        let equity = getFinValue("equity") ?? 0
        let intangibles = getFinValue("intangibles") ?? 0
        let ebitda = getFinValue("ebitda") ?? 0
        let ebit = getFinValue("ebit") ?? 0
        let interestExpense = getFinValue("interest_expense") ?? 0
        let principalPayment = getFinValue("principal_payment") ?? 0

        // Calculate all metrics
        let currentRatio = currentLiabilities > 0 ? currentAssets / currentLiabilities : 0.0
        let quickAssets = currentAssets - inventory
        let quickRatio = currentLiabilities > 0 ? quickAssets / currentLiabilities : 0.0
        let debtToEquity = equity > 0 ? totalDebt / equity : Double.infinity
        let interestCoverage = interestExpense > 0 ? ebit / interestExpense : Double.infinity
        let debtServiceCoverage = (interestExpense + principalPayment) > 0 ?
            ebitda / (interestExpense + principalPayment) : Double.infinity
        let debtToEBITDA = ebitda > 0 ? totalDebt / ebitda : Double.infinity
        let tangibleNetWorth = equity - intangibles

        // Build covenant results
        var results: [(name: String, actual: Double, threshold: Double, direction: String, compliant: Bool, headroom: Double)] = []

        for covenant in covenantsAnyCodable {
            guard let covenantData = covenant.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each covenant must be an object")
            }

            guard let covenantType = covenantData["type"]?.value as? String,
                  let direction = covenantData["direction"]?.value as? String else {
                throw ToolError.invalidArguments("Each covenant must have type, threshold, and direction")
            }

            // Handle threshold as either Double or Int
            let threshold: Double
            if let thresholdDouble = covenantData["threshold"]?.value as? Double {
                threshold = thresholdDouble
            } else if let thresholdInt = covenantData["threshold"]?.value as? Int {
                threshold = Double(thresholdInt)
            } else {
                throw ToolError.invalidArguments("threshold must be a number")
            }

            // Get actual value based on type
            let actual: Double
            let name: String

            switch covenantType.lowercased().replacingOccurrences(of: " ", with: "_") {
            case "current_ratio":
                actual = currentRatio
                name = "Current Ratio"
            case "quick_ratio":
                actual = quickRatio
                name = "Quick Ratio"
            case "debt_to_equity", "debt/equity":
                actual = debtToEquity
                name = "Debt-to-Equity"
            case "interest_coverage":
                actual = interestCoverage
                name = "Interest Coverage"
            case "debt_service_coverage", "dscr":
                actual = debtServiceCoverage
                name = "DSCR"
            case "debt_to_ebitda", "debt/ebitda":
                actual = debtToEBITDA
                name = "Debt-to-EBITDA"
            case "minimum_ebitda", "ebitda":
                actual = ebitda
                name = "Minimum EBITDA"
            case "tangible_net_worth", "net_worth":
                actual = tangibleNetWorth
                name = "Tangible Net Worth"
            default:
                throw ToolError.invalidArguments("Unknown covenant type: \(covenantType)")
            }

            // Check compliance
            let compliant: Bool
            let headroomValue: Double
            let headroomPercent: Double

            if direction.lowercased() == "minimum" {
                compliant = actual >= threshold
                headroomValue = actual - threshold
                headroomPercent = threshold > 0 ? headroomValue / threshold : 0.0
            } else {
                compliant = actual <= threshold
                headroomValue = threshold - actual
                headroomPercent = threshold > 0 ? headroomValue / threshold : 0.0
            }

            results.append((name, actual, threshold, direction, compliant, headroomPercent))
        }

        // Build output
        var output = """
        Covenant Monitoring Dashboard - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        """

        // Count status
        let compliantCount = results.filter { $0.compliant }.count
        let violatedCount = results.count - compliantCount
        let warningCount = results.filter { !$0.compliant || $0.headroom < 0.10 }.count

        // Overall status
        let overallStatus = violatedCount == 0 ? "✅ COMPLIANT" : "❌ VIOLATIONS DETECTED"

        output += """
        OVERALL STATUS: \(overallStatus)
        • \(compliantCount)/\(results.count) covenants met
        """

        if violatedCount > 0 {
            output += "\n• \(violatedCount) covenant(s) violated"
        }
        if warningCount > 0 {
            output += "\n• \(warningCount) covenant(s) at risk"
        }

        output += "\n\n\(separator())\n\nCOVENANT DETAILS\n\n"

        // Table header
        output += "Covenant".padding(toLength: 25, withPad: " ", startingAt: 0)
            + "Actual".paddingLeft(toLength: 10)
            + "Threshold".paddingLeft(toLength: 11)
            + "Status".paddingLeft(toLength: 9)
            + "Headroom".paddingLeft(toLength: 11) + "\n"
        output += separator() + "\n"

        // Covenant rows
        for result in results {
            let statusIcon: String
            let headroomStr: String

            if !result.compliant {
                statusIcon = "❌"
                headroomStr = formatPercentage(result.headroom, decimals: 0)
            } else if result.headroom < 0.10 {
                statusIcon = "⚠️⚠️"
                headroomStr = formatPercentage(result.headroom, decimals: 0)
            } else if result.headroom < 0.20 {
                statusIcon = "⚠️"
                headroomStr = formatPercentage(result.headroom, decimals: 0)
            } else {
                statusIcon = "✅"
                headroomStr = formatPercentage(result.headroom, decimals: 0)
            }

            let actualStr: String
            let thresholdStr: String

            // Format based on covenant type
            if result.name.contains("EBITDA") || result.name.contains("Net Worth") {
                actualStr = formatCurrency(result.actual, decimals: 0)
                thresholdStr = result.direction == "minimum" ? "≥\(formatCurrency(result.threshold, decimals: 0))" : "≤\(formatCurrency(result.threshold, decimals: 0))"
            } else {
                actualStr = formatNumber(result.actual, decimals: 2)
                thresholdStr = result.direction == "minimum" ? "≥\(formatNumber(result.threshold, decimals: 2))" : "≤\(formatNumber(result.threshold, decimals: 2))"
            }

            output += result.name.padding(toLength: 25, withPad: " ", startingAt: 0)
                + actualStr.paddingLeft(toLength: 10)
                + thresholdStr.paddingLeft(toLength: 11)
                + "  " + statusIcon.paddingLeft(toLength: 5)
                + headroomStr.paddingLeft(toLength: 11) + "\n"
        }

        output += "\n\(separator())\n\nWARNINGS & RECOMMENDATIONS\n"

        var warnings: [String] = []

        for result in results {
            if !result.compliant {
                warnings.append("❌ \(result.name) is VIOLATED (actual: \(formatNumber(result.actual, decimals: 2)), required: \(result.direction) \(formatNumber(result.threshold, decimals: 2)))")
                warnings.append("   → Immediate action required. Contact lender.")
            } else if result.headroom < 0.05 {
                warnings.append("⚠️⚠️ \(result.name) has <5% headroom - CRITICAL RISK")
                warnings.append("   → Take immediate corrective action")
            } else if result.headroom < 0.10 {
                warnings.append("⚠️ \(result.name) has <10% headroom - HIGH RISK")
                warnings.append("   → Monitor closely and develop contingency plan")
            } else if result.headroom < 0.20 {
                warnings.append("⚠️ \(result.name) has <20% headroom - MODERATE RISK")
                warnings.append("   → Consider proactive measures")
            }
        }

        if warnings.isEmpty {
            output += "\n  ✅ All covenants have comfortable headroom (>20%)\n"
        } else {
            for warning in warnings {
                output += "\n  \(warning)"
            }
        }

        output += """


        \(separator())

        NEXT REVIEW DATE: [Next Quarter End]

        Actions to Improve Covenant Compliance:
          • Increase liquidity (Current/Quick Ratio)
          • Reduce debt or increase equity (D/E, Debt/EBITDA)
          • Improve profitability (Interest Coverage, DSCR)
          • Defer capex or dividends to preserve cash
          • Negotiate covenant modifications with lenders
        """

        return .success(text: output)
    }
}
