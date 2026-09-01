//
//  OperationalMetricsTools.swift
//  BusinessMath MCP Server
//
//  Operational metrics tools for SaaS, E-commerce, and industry-specific KPIs
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

/// Returns all operational metrics tools
public func getOperationalMetricsTools() -> [any MCPToolHandler] {
    return [
        CalculateSaaSMetricsTool(),
        CalculateEcommerceMetricsTool()
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

// MARK: - 1. Calculate SaaS Metrics

/// Calculate comprehensive SaaS operational metrics and KPIs.
///
/// Exposed to clients as the `calculate_saas_metrics` tool.
public struct CalculateSaaSMetricsTool: MCPToolHandler, Sendable {
    /// The `calculate_saas_metrics` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_saas_metrics",
        description: """
        Calculate comprehensive SaaS operational metrics and KPIs.

        Computes critical SaaS metrics including:
        - MRR (Monthly Recurring Revenue) and ARR
        - Net Revenue Retention (NRR) and Gross Revenue Retention (GRR)
        - Customer metrics (CAC, LTV, Churn)
        - Growth metrics (Net New MRR, MRR Growth Rate)
        - Efficiency metrics (LTV:CAC, Magic Number, CAC Payback)
        - Unit economics analysis

        Input Metrics Required:
        • mrr: Current MRR
        • new_mrr: New MRR from new customers (optional)
        • expansion_mrr: Expansion MRR from existing customers (optional)
        • churned_mrr: MRR lost from churned customers (optional)
        • customers: Current customer count (optional)
        • new_customers: New customers added (optional)
        • churned_customers: Customers lost to churn (optional)
        • sales_and_marketing: S&M spend for the period (optional)
        • average_contract_value: ACV per customer (optional, calculated if not provided)

        Benchmarks Applied:
        • NRR > 100%: Excellent (negative churn)
        • LTV:CAC > 3×: Healthy unit economics
        • CAC Payback < 12 months: Good efficiency
        • Magic Number > 0.75: Strong sales efficiency
        • Churn < 5%: Good retention

        Use Cases:
        • SaaS business performance monitoring
        • Investor reporting (ARR, NRR, Magic Number)
        • Unit economics validation
        • Sales efficiency analysis
        • Runway and growth planning

        Example: Company with $500K MRR, 500 customers, 2% churn generates detailed metrics
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "entity": MCPSchemaProperty(
                    type: "string",
                    description: "Company name"
                ),
                "period": MCPSchemaProperty(
                    type: "string",
                    description: "Reporting period (e.g., '2024-Q1', 'January 2024')"
                ),
                "mrr": MCPSchemaProperty(
                    type: "number",
                    description: "Monthly Recurring Revenue"
                ),
                "new_mrr": MCPSchemaProperty(
                    type: "number",
                    description: "New MRR from new customers (optional)"
                ),
                "expansion_mrr": MCPSchemaProperty(
                    type: "number",
                    description: "Expansion MRR from existing customers (upsells, cross-sells) (optional)"
                ),
                "churned_mrr": MCPSchemaProperty(
                    type: "number",
                    description: "MRR lost from churned customers (positive number) (optional)"
                ),
                "contraction_mrr": MCPSchemaProperty(
                    type: "number",
                    description: "MRR lost from downgrades (positive number) (optional)"
                ),
                "customers": MCPSchemaProperty(
                    type: "number",
                    description: "Current customer count (optional)"
                ),
                "new_customers": MCPSchemaProperty(
                    type: "number",
                    description: "New customers added this period (optional)"
                ),
                "churned_customers": MCPSchemaProperty(
                    type: "number",
                    description: "Customers churned this period (optional)"
                ),
                "sales_and_marketing": MCPSchemaProperty(
                    type: "number",
                    description: "Sales & Marketing spend for the period (optional)"
                ),
                "average_contract_value": MCPSchemaProperty(
                    type: "number",
                    description: "Average annual contract value (optional, will be calculated if not provided)"
                )
            ],
            required: ["entity", "period", "mrr"]
        )
    )

    /// Creates the `calculate_saas_metrics` handler.
    public init() {}

    /// Runs `calculate_saas_metrics` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")

        // Required
        let mrr = try args.getDouble("mrr")

        // Optional metrics
        let newMRR = (args.getDoubleOptional("new_mrr")) ?? 0.0
        let expansionMRR = (args.getDoubleOptional("expansion_mrr")) ?? 0.0
        let churnedMRR = (args.getDoubleOptional("churned_mrr")) ?? 0.0
        let contractionMRR = (args.getDoubleOptional("contraction_mrr")) ?? 0.0
        let customers = args.getDoubleOptional("customers")
        let newCustomers = (args.getDoubleOptional("new_customers")) ?? 0.0
        let churnedCustomers = (args.getDoubleOptional("churned_customers")) ?? 0.0
        let salesAndMarketing = args.getDoubleOptional("sales_and_marketing")
        let acv = args.getDoubleOptional("average_contract_value")

        // Calculate ARR
        let arr = mrr * 12

        // Calculate ARPU (Average Revenue Per User)
        // `flatMap` rather than `!`, and the zero check is new: a tenant with zero
        // customers divided by zero and reported an infinite ARPU.
        let arpu = customers.flatMap { $0 > 0 ? mrr / $0 : nil }

        // Calculate Net New MRR
        let netNewMRR = newMRR + expansionMRR - churnedMRR - contractionMRR

        // Calculate MRR Growth Rate
        let previousMRR = mrr - netNewMRR
        let mrrGrowthRate = previousMRR > 0 ? netNewMRR / previousMRR : 0.0

        // Calculate Net Revenue Retention (NRR)
        // NRR = (Starting MRR + Expansion - Churned - Contraction) / Starting MRR
        let nrr = previousMRR > 0 ? (previousMRR + expansionMRR - churnedMRR - contractionMRR) / previousMRR : nil

        // Calculate Gross Revenue Retention (GRR)
        // GRR = (Starting MRR - Churned - Contraction) / Starting MRR
        let grr = previousMRR > 0 ? (previousMRR - churnedMRR - contractionMRR) / previousMRR : nil

        // Calculate Logo Retention (customer retention)
        let previousCustomers = customers.map { $0 - newCustomers + churnedCustomers }
        let logoRetention = previousCustomers.flatMap { $0 > 0 ? ($0 - churnedCustomers) / $0 : nil }

        // Calculate Customer Churn Rate
        let customerChurnRate = previousCustomers.flatMap { $0 > 0 ? churnedCustomers / $0 : nil }

        // Calculate CAC (Customer Acquisition Cost)
        let cac = salesAndMarketing.flatMap { newCustomers > 0 ? $0 / newCustomers : nil }

        // Estimate LTV (Lifetime Value)
        // LTV = ARPU / Churn Rate (simplified model)
        var ltv: Double? = nil
        if let arpu = arpu, let churnRate = customerChurnRate, churnRate > 0 {
            ltv = (arpu * 12) / churnRate  // Annual value / annual churn
        } else if let acv = acv, let churnRate = customerChurnRate, churnRate > 0 {
            ltv = acv / churnRate
        }

        // Calculate LTV:CAC ratio
        // The zero check is new: a zero CAC divided to infinity.
        let ltvCacRatio = ltv.flatMap { l in cac.flatMap { $0 > 0 ? l / $0 : nil } }

        // Calculate CAC Payback Period (in months)
        // CAC Payback = CAC / (ARPU * Gross Margin)
        // Simplified: assuming 80% gross margin
        let grossMargin = 0.8
        let cacPayback = cac.flatMap { c in
            arpu.flatMap { a in a > 0 && grossMargin > 0 ? c / (a * grossMargin) : nil }
        }

        // Calculate Magic Number (Sales Efficiency)
        // Magic Number = Net New ARR / S&M Spend (quarterly)
        let netNewARR = netNewMRR * 12
        let magicNumber = salesAndMarketing.flatMap { $0 > 0 ? netNewARR / $0 : nil }

        // Build output
        var output = """
        SaaS Operational Metrics - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        REVENUE METRICS
          MRR (Monthly Recurring)       \(formatCurrency(mrr, decimals: 0))
          ARR (Annual Recurring)        \(formatCurrency(arr, decimals: 0))
        """

        if let arpu = arpu {
            output += "\n  ARPU (Avg Revenue/User)       \(formatCurrency(arpu, decimals: 0))"
        }

        output += "\n\nGROWTH METRICS"

        if newMRR > 0 {
            output += "\n  New MRR                       \(formatCurrency(newMRR, decimals: 0))"
        }
        if expansionMRR > 0 {
            output += "\n  Expansion MRR                 \(formatCurrency(expansionMRR, decimals: 0))"
        }
        if churnedMRR > 0 {
            output += "\n  Churned MRR                  (\(formatCurrency(churnedMRR, decimals: 0)))"
        }
        if contractionMRR > 0 {
            output += "\n  Contraction MRR              (\(formatCurrency(contractionMRR, decimals: 0)))"
        }

        output += """

          Net New MRR                   \(formatCurrency(netNewMRR, decimals: 0))
          MRR Growth Rate (QoQ)         \(formatPercentage(mrrGrowthRate, decimals: 1))

        """

        output += "RETENTION METRICS"

        if let nrr = nrr {
            let nrrStatus = nrr > 1.0 ? "✅ (>100% = expansion)" : "⚠️"
            output += "\n  Net Revenue Retention      \(formatPercentage(nrr, decimals: 1)) \(nrrStatus)"
        }

        if let grr = grr {
            let grrStatus = grr >= 0.90 ? "✅" : grr >= 0.85 ? "⚠️" : "❌"
            output += "\n  Gross Revenue Retention    \(formatPercentage(grr, decimals: 1)) \(grrStatus)"
        }

        if let logoRetention = logoRetention {
            let logoStatus = logoRetention >= 0.95 ? "✅" : logoRetention >= 0.90 ? "⚠️" : "❌"
            output += "\n  Logo Retention             \(formatPercentage(logoRetention, decimals: 1)) \(logoStatus)"
        }

        if let churnRate = customerChurnRate {
            let churnStatus = churnRate < 0.05 ? "✅" : churnRate < 0.10 ? "⚠️" : "❌"
            output += "\n  Customer Churn Rate        \(formatPercentage(churnRate, decimals: 1)) \(churnStatus)"
        }

        if let customers = customers {
            output += """


            CUSTOMER METRICS
              Total Customers               \(formatNumber(customers, decimals: 0))
            """

            if newCustomers > 0 {
                output += "\n  New Customers                 \(formatNumber(newCustomers, decimals: 0))"
            }
            if churnedCustomers > 0 {
                output += "\n  Churned Customers             \(formatNumber(churnedCustomers, decimals: 0))"
            }
        }

        if cac != nil || ltv != nil {
            output += "\n\nUNIT ECONOMICS"

            if let cac = cac {
                output += "\n  CAC (Customer Acq Cost)       \(formatCurrency(cac, decimals: 0))"
            }

            if let ltv = ltv {
                output += "\n  LTV (Estimated Lifetime)      \(formatCurrency(ltv, decimals: 0))"
            }

            if let ratio = ltvCacRatio {
                let status = ratio > 3.0 ? "✅" : ratio > 1.5 ? "⚠️" : "❌"
                output += "\n  LTV:CAC Ratio                     \(formatNumber(ratio, decimals: 1))× \(status)"
            }

            if let payback = cacPayback {
                let status = payback < 12 ? "✅" : payback < 18 ? "⚠️" : "❌"
                output += "\n  CAC Payback (months)              \(formatNumber(payback, decimals: 1)) \(status)"
            }
        }

        if let magicNumber = magicNumber {
            output += "\n\nEFFICIENCY METRICS"
            let magicStatus = magicNumber > 0.75 ? "✅" : magicNumber > 0.5 ? "⚠️" : "❌"
            output += "\n  Magic Number                      \(formatNumber(magicNumber, decimals: 2)) \(magicStatus)"
            output += "\n    (Net New ARR / S&M Spend)"
        }

        output += "\n\n\(String(repeating: "━", count: 60))\n\nBENCHMARKS & ANALYSIS"

        var benchmarks: [String] = []

        if let nrr = nrr {
            if nrr > 1.0 {
                benchmarks.append("✅ NRR > 100%: Excellent retention with expansion")
            } else if nrr > 0.90 {
                benchmarks.append("⚠️ NRR 90-100%: Good but limited expansion")
            } else {
                benchmarks.append("❌ NRR < 90%: Retention concerns")
            }
        }

        if let ratio = ltvCacRatio {
            if ratio > 3.0 {
                benchmarks.append("✅ LTV:CAC > 3×: Healthy unit economics")
            } else if ratio > 1.5 {
                benchmarks.append("⚠️ LTV:CAC 1.5-3×: Marginal unit economics")
            } else {
                benchmarks.append("❌ LTV:CAC < 1.5×: Unit economics not sustainable")
            }
        }

        if let churn = customerChurnRate {
            if churn < 0.05 {
                benchmarks.append("✅ Churn < 5%: Excellent retention")
            } else if churn < 0.10 {
                benchmarks.append("⚠️ Churn 5-10%: Acceptable but room to improve")
            } else {
                benchmarks.append("❌ Churn > 10%: High churn is a red flag")
            }
        }

        if let magic = magicNumber {
            if magic > 0.75 {
                benchmarks.append("✅ Magic Number > 0.75: Strong sales efficiency")
            } else if magic > 0.5 {
                benchmarks.append("⚠️ Magic Number 0.5-0.75: Moderate efficiency")
            } else {
                benchmarks.append("❌ Magic Number < 0.5: Poor sales efficiency")
            }
        }

        for benchmark in benchmarks {
            output += "\n  \(benchmark)"
        }

        output += """


        Next Steps:
          • Focus on improving NRR through expansion/upsells
          • Reduce churn through customer success initiatives
          • Optimize CAC through more efficient marketing channels
          • Increase sales efficiency (Magic Number) to accelerate growth
        """

        return .success(text: output)
    }
}

// MARK: - 2. Calculate E-commerce Metrics

/// Calculate comprehensive E-commerce operational metrics and KPIs.
///
/// Exposed to clients as the `calculate_ecommerce_metrics` tool.
public struct CalculateEcommerceMetricsTool: MCPToolHandler, Sendable {
    /// The `calculate_ecommerce_metrics` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "calculate_ecommerce_metrics",
        description: """
        Calculate comprehensive E-commerce operational metrics and KPIs.

        Computes critical E-commerce metrics including:
        - GMV (Gross Merchandise Value) and Net Revenue
        - AOV (Average Order Value)
        - Conversion Rate and Customer Acquisition
        - Repeat Purchase Rate and Customer Retention
        - Inventory Turnover
        - Unit Economics (CAC, LTV)

        Input Metrics Required:
        • orders: Total orders placed
        • gmv: Gross Merchandise Value (total order value)
        • revenue: Net revenue (GMV - returns - discounts - fees) (optional)
        • sessions: Website/app sessions (optional)
        • new_customers: New customers acquired (optional)
        • repeat_customers: Customers making repeat purchases (optional)
        • cogs: Cost of Goods Sold (optional)
        • inventory: Average inventory value (optional)
        • marketing_spend: Marketing spend for the period (optional)

        Benchmarks Applied:
        • Conversion Rate > 2%: Good
        • AOV growth: Positive trend
        • Repeat Purchase Rate > 30%: Healthy
        • Inventory Turnover > 6×/year: Efficient
        • LTV:CAC > 3×: Sustainable

        Use Cases:
        • E-commerce business performance tracking
        • Inventory management and optimization
        • Marketing ROI analysis
        • Customer acquisition and retention strategy
        • Unit economics validation

        Example: Store with 1,500 orders, $300K GMV generates detailed metrics
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
                "orders": MCPSchemaProperty(
                    type: "number",
                    description: "Total orders placed"
                ),
                "gmv": MCPSchemaProperty(
                    type: "number",
                    description: "Gross Merchandise Value (total order value)"
                ),
                "revenue": MCPSchemaProperty(
                    type: "number",
                    description: "Net revenue (optional, defaults to GMV)"
                ),
                "sessions": MCPSchemaProperty(
                    type: "number",
                    description: "Website/app sessions (optional)"
                ),
                "new_customers": MCPSchemaProperty(
                    type: "number",
                    description: "New customers acquired (optional)"
                ),
                "repeat_customers": MCPSchemaProperty(
                    type: "number",
                    description: "Customers making repeat purchases (optional)"
                ),
                "total_customers": MCPSchemaProperty(
                    type: "number",
                    description: "Total active customers (optional)"
                ),
                "cogs": MCPSchemaProperty(
                    type: "number",
                    description: "Cost of Goods Sold (optional)"
                ),
                "inventory": MCPSchemaProperty(
                    type: "number",
                    description: "Average inventory value (optional)"
                ),
                "marketing_spend": MCPSchemaProperty(
                    type: "number",
                    description: "Marketing spend (optional)"
                )
            ],
            required: ["entity", "period", "orders", "gmv"]
        )
    )

    /// Creates the `calculate_ecommerce_metrics` handler.
    public init() {}

    /// Runs `calculate_ecommerce_metrics` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let entityName = try args.getString("entity")
        let periodString = try args.getString("period")

        // Required
        let orders = try args.getDouble("orders")
        let gmv = try args.getDouble("gmv")

        // Optional
        let revenue = (args.getDoubleOptional("revenue")) ?? gmv
        let sessions = args.getDoubleOptional("sessions")
        let newCustomers = args.getDoubleOptional("new_customers")
        let repeatCustomers = args.getDoubleOptional("repeat_customers")
        let totalCustomers = args.getDoubleOptional("total_customers")
        let cogs = args.getDoubleOptional("cogs")
        let inventory = args.getDoubleOptional("inventory")
        let marketingSpend = args.getDoubleOptional("marketing_spend")

        // Calculate AOV (Average Order Value)
        let aov = gmv / orders

        // Calculate Conversion Rate
        // Zero sessions divided to infinity before this check existed.
        let conversionRate = sessions.flatMap { $0 > 0 ? orders / $0 : nil }

        // Calculate Gross Margin
        let grossProfit = cogs.map { revenue - $0 }
        let grossMargin = grossProfit.flatMap { revenue > 0 ? $0 / revenue : nil }

        // Calculate Inventory Turnover
        let inventoryTurnover = inventory.flatMap { i in cogs.flatMap { i > 0 ? $0 / i : nil } }

        // Calculate Repeat Purchase Rate
        let repeatRate = totalCustomers.flatMap { t in repeatCustomers.flatMap { t > 0 ? $0 / t : nil } }

        // Calculate CAC
        let cac = newCustomers.flatMap { n in marketingSpend.flatMap { n > 0 ? $0 / n : nil } }

        // Estimate LTV (simplified: AOV * average orders per customer per year)
        // Assuming 3 orders per year on average
        let estimatedOrdersPerYear = 3.0
        let ltv = aov * estimatedOrdersPerYear

        // LTV:CAC ratio
        let ltvCacRatio = cac.flatMap { $0 > 0 ? ltv / $0 : nil }

        // Revenue per Customer
        let revenuePerCustomer = totalCustomers.flatMap { $0 > 0 ? revenue / $0 : nil }

        // Build output
        var output = """
        E-commerce Operational Metrics - \(entityName) - \(periodString)
        \(String(repeating: "━", count: 60))

        SALES METRICS
          GMV (Gross Merchandise Value) \(formatCurrency(gmv, decimals: 0))
          Net Revenue                   \(formatCurrency(revenue, decimals: 0))
          Total Orders                  \(formatNumber(orders, decimals: 0))
          AOV (Average Order Value)     \(formatCurrency(aov, decimals: 2))

        """

        // `sessions` is bound here rather than force unwrapped on the strength of
        // conversionRate being non-nil — that coupling is real today and invisible to
        // anyone changing how conversionRate is derived.
        if let conversion = conversionRate, let sessions {
            output += "CONVERSION METRICS\n"
            let conversionStatus = conversion > 0.02 ? "✅" : conversion > 0.01 ? "⚠️" : "❌"
            output += "  Sessions                      \(formatNumber(sessions, decimals: 0))\n"
            output += "  Conversion Rate               \(formatPercentage(conversion, decimals: 2)) \(conversionStatus)\n\n"
        }

        if newCustomers != nil || repeatCustomers != nil {
            output += "CUSTOMER METRICS"

            if let total = totalCustomers {
                output += "\n  Total Active Customers        \(formatNumber(total, decimals: 0))"
            }
            if let newCust = newCustomers {
                output += "\n  New Customers                 \(formatNumber(newCust, decimals: 0))"
            }
            if let repeatCust = repeatCustomers {
                output += "\n  Repeat Customers              \(formatNumber(repeatCust, decimals: 0))"
            }
            if let rate = repeatRate {
                let repeatStatus = rate > 0.30 ? "✅" : rate > 0.20 ? "⚠️" : "❌"
                output += "\n  Repeat Purchase Rate          \(formatPercentage(rate, decimals: 1)) \(repeatStatus)"
            }
            if let revPerCustomer = revenuePerCustomer {
                output += "\n  Revenue per Customer          \(formatCurrency(revPerCustomer, decimals: 0))"
            }

            output += "\n\n"
        }

        if grossProfit != nil || inventory != nil {
            output += "OPERATIONS METRICS"

            if let profit = grossProfit, let margin = grossMargin, let cogs {
                let marginStatus = margin > 0.40 ? "✅" : margin > 0.25 ? "⚠️" : "❌"
                output += "\n  COGS                          \(formatCurrency(cogs, decimals: 0))"
                output += "\n  Gross Profit                  \(formatCurrency(profit, decimals: 0))"
                output += "\n  Gross Margin                  \(formatPercentage(margin, decimals: 1)) \(marginStatus)"
            }

            if let turnover = inventoryTurnover, let inventory {
                // Annual turnover (if this is a quarterly/monthly period, multiply accordingly)
                let turnoverStatus = turnover > 6.0 ? "✅" : turnover > 4.0 ? "⚠️" : "❌"
                output += "\n  Average Inventory             \(formatCurrency(inventory, decimals: 0))"
                output += "\n  Inventory Turnover            \(formatNumber(turnover, decimals: 1))× \(turnoverStatus)"
            }

            output += "\n\n"
        }

        if let cac {
            output += "UNIT ECONOMICS"
            output += "\n  CAC (Customer Acq Cost)       \(formatCurrency(cac, decimals: 2))"
            output += "\n  Estimated LTV                 \(formatCurrency(ltv, decimals: 2))"

            if let ratio = ltvCacRatio {
                let status = ratio > 3.0 ? "✅" : ratio > 1.5 ? "⚠️" : "❌"
                output += "\n  LTV:CAC Ratio                     \(formatNumber(ratio, decimals: 1))× \(status)"
            }

            output += "\n\n"
        }

        output += "\(String(repeating: "━", count: 60))\n\nBENCHMARKS & ANALYSIS"

        var insights: [String] = []

        if let conversion = conversionRate {
            if conversion > 0.03 {
                insights.append("✅ Conversion rate > 3%: Excellent performance")
            } else if conversion > 0.02 {
                insights.append("✅ Conversion rate > 2%: Good performance")
            } else {
                insights.append("⚠️ Conversion rate < 2%: Optimize checkout and product pages")
            }
        }

        if let rate = repeatRate {
            if rate > 0.30 {
                insights.append("✅ Repeat rate > 30%: Healthy customer retention")
            } else {
                insights.append("⚠️ Repeat rate < 30%: Focus on retention and lifecycle marketing")
            }
        }

        if let margin = grossMargin {
            if margin > 0.40 {
                insights.append("✅ Gross margin > 40%: Strong profitability")
            } else if margin > 0.25 {
                insights.append("⚠️ Gross margin 25-40%: Acceptable but competitive")
            } else {
                insights.append("❌ Gross margin < 25%: Pricing or cost concerns")
            }
        }

        if let turnover = inventoryTurnover {
            if turnover > 6.0 {
                insights.append("✅ Inventory turnover > 6×/year: Efficient inventory mgmt")
            } else {
                insights.append("⚠️ Inventory turnover < 6×/year: May have excess inventory")
            }
        }

        if let ratio = ltvCacRatio {
            if ratio > 3.0 {
                insights.append("✅ LTV:CAC > 3×: Sustainable customer economics")
            } else {
                insights.append("⚠️ LTV:CAC < 3×: Need to improve retention or reduce CAC")
            }
        }

        for insight in insights {
            output += "\n  \(insight)"
        }

        output += """


        Next Steps:
          • Optimize conversion rate through A/B testing
          • Increase AOV via cross-sells and bundles
          • Improve repeat purchase rate with email marketing
          • Reduce CAC through organic channels (SEO, content)
          • Optimize inventory turnover to free up cash
        """

        return .success(text: output)
    }
}
