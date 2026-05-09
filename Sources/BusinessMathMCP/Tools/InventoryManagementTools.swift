//
//  InventoryManagementTools.swift
//  BusinessMath MCP Server
//
//  Inventory management tools: safety stock, EOQ, newsvendor, reorder point,
//  simulation, and advisor.
//

import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - Tool Registration

public func getInventoryManagementTools() -> [any MCPToolHandler] {
    return [
        CalculateSafetyStockTool(),
        CalculateEOQTool(),
        CalculateNewsvendorTool(),
        CalculateReorderPointTool(),
        RunInventorySimulationTool(),
        RecommendInventoryModelTool()
    ]
}

// MARK: - Formatting Helpers

private func fmtNum(_ value: Double, decimals: Int = 2) -> String {
    value.formatDecimal(decimals: decimals)
}

private func fmtPct(_ value: Double, decimals: Int = 1) -> String {
    (value * 100).formatDecimal(decimals: decimals) + "%"
}

private func divider(_ width: Int = 45) -> String {
    String(repeating: "─", count: width)
}

// MARK: - 1. Safety Stock

public struct CalculateSafetyStockTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_safety_stock",
        description: """
        Calculate safety stock using standard operations management formulas.

        Three methods available:
        • demand_only: SS = z × σ_d × √L (demand variability only)
        • demand_and_lead_time: SS = z × √(L×σ_d² + d̄²×σ_L²) (both sources of uncertainty)
        • forecast_error: SS = z × RMSE × √L (forecast-driven)

        Parameters:
        • method: "demand_only" | "demand_and_lead_time" | "forecast_error"
        • service_level: Target cycle service level (0–1, e.g., 0.95 for 95%)
        • average_demand: Mean demand per period
        • demand_std_dev: Standard deviation of demand per period
        • lead_time: Replenishment lead time in periods
        • lead_time_std_dev: Std dev of lead time (required for demand_and_lead_time)
        • forecast_rmse: Forecast RMSE (required for forecast_error)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Safety stock method: demand_only, demand_and_lead_time, or forecast_error"
                ),
                "service_level": MCPSchemaProperty(
                    type: "number",
                    description: "Target service level (0–1), e.g. 0.95"
                ),
                "average_demand": MCPSchemaProperty(
                    type: "number",
                    description: "Average demand per period"
                ),
                "demand_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Standard deviation of demand per period"
                ),
                "lead_time": MCPSchemaProperty(
                    type: "number",
                    description: "Replenishment lead time in periods"
                ),
                "lead_time_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Standard deviation of lead time (for demand_and_lead_time method)"
                ),
                "forecast_rmse": MCPSchemaProperty(
                    type: "number",
                    description: "Forecast root mean square error (for forecast_error method)"
                )
            ],
            required: ["method", "service_level", "average_demand", "demand_std_dev", "lead_time"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let methodStr = try args.getString("method")
        let serviceLevel = try args.getDouble("service_level")
        let avgDemand = try args.getDouble("average_demand")
        let demandStdDev = try args.getDouble("demand_std_dev")
        let leadTime = try args.getDouble("lead_time")
        let ltStdDev = args.getDoubleOptional("lead_time_std_dev") ?? 0.0
        let rmse = args.getDoubleOptional("forecast_rmse")

        let method: SafetyStockModel<Double>.Method
        switch methodStr.lowercased() {
        case "demand_only": method = .demandOnly
        case "demand_and_lead_time": method = .demandAndLeadTime
        case "forecast_error": method = .forecastError
        default: throw ToolError.invalidArguments("method must be demand_only, demand_and_lead_time, or forecast_error")
        }

        let ss = try SafetyStockModel<Double>.safetyStock(
            method: method,
            serviceLevel: serviceLevel,
            averageDemand: avgDemand,
            demandStdDev: demandStdDev,
            leadTime: leadTime,
            leadTimeStdDev: ltStdDev,
            forecastRMSE: rmse
        )

        let z = try SafetyStockModel<Double>.zScore(for: serviceLevel)

        var output = """
        Safety Stock Calculation
        \(divider())
        Method:          \(methodStr)
        Service Level:   \(fmtPct(serviceLevel))
        z-Score:         \(fmtNum(z, decimals: 4))
        \(divider())
        Average Demand:  \(fmtNum(avgDemand)) per period
        Demand Std Dev:  \(fmtNum(demandStdDev))
        Lead Time:       \(fmtNum(leadTime)) periods
        """

        if method == .demandAndLeadTime {
            output += "\nLead Time StdDev: \(fmtNum(ltStdDev))"
        }
        if method == .forecastError, let r = rmse {
            output += "\nForecast RMSE:   \(fmtNum(r))"
        }

        output += """

        \(divider())
        Safety Stock:    \(fmtNum(ss)) units
        \(divider())
        """

        return .success(text: output)
    }
}

// MARK: - 2. EOQ

public struct CalculateEOQTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_eoq",
        description: """
        Calculate the Economic Order Quantity (EOQ) and total inventory cost.

        Uses the Harris-Wilson formula: Q* = √(2SD/H)
        At Q*, annual ordering cost equals annual holding cost.

        Parameters:
        • annual_demand: Total units demanded per year (D)
        • ordering_cost: Fixed cost per order placed (S)
        • holding_cost_per_unit: Annual holding cost per unit (H)
        • unit_cost: Purchase cost per unit (optional, for total cost)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "annual_demand": MCPSchemaProperty(
                    type: "number",
                    description: "Annual demand in units (D)"
                ),
                "ordering_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Fixed cost per order (S)"
                ),
                "holding_cost_per_unit": MCPSchemaProperty(
                    type: "number",
                    description: "Annual holding cost per unit (H)"
                ),
                "unit_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Purchase cost per unit (optional)"
                )
            ],
            required: ["annual_demand", "ordering_cost", "holding_cost_per_unit"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let annualDemand = try args.getDouble("annual_demand")
        let orderingCost = try args.getDouble("ordering_cost")
        let holdingCost = try args.getDouble("holding_cost_per_unit")
        let unitCost = args.getDoubleOptional("unit_cost") ?? 0.0

        let result = try EOQModel<Double>.calculate(
            annualDemand: annualDemand,
            orderingCost: orderingCost,
            holdingCostPerUnit: holdingCost
        )

        let totalWithPurchasing = unitCost > 0
            ? EOQModel<Double>.totalCost(
                orderQuantity: result.orderQuantity,
                annualDemand: annualDemand,
                orderingCost: orderingCost,
                holdingCostPerUnit: holdingCost,
                unitCost: unitCost
            )
            : result.totalAnnualCost

        var output = """
        Economic Order Quantity (EOQ)
        \(divider())
        Annual Demand:       \(fmtNum(annualDemand, decimals: 0)) units
        Ordering Cost:       $\(fmtNum(orderingCost)) per order
        Holding Cost:        $\(fmtNum(holdingCost)) per unit/year
        """

        if unitCost > 0 {
            output += "\nUnit Cost:           $\(fmtNum(unitCost))"
        }

        output += """

        \(divider())
        Optimal Order Qty:   \(fmtNum(result.orderQuantity)) units
        Orders Per Year:     \(fmtNum(result.ordersPerYear))
        Days Between Orders: \(fmtNum(result.daysBetweenOrders, decimals: 1))
        \(divider())
        Annual Ordering:     $\(fmtNum(result.annualOrderingCost))
        Annual Holding:      $\(fmtNum(result.annualHoldingCost))
        Total Annual Cost:   $\(fmtNum(totalWithPurchasing))
        \(divider())
        """

        return .success(text: output)
    }
}

// MARK: - 3. Newsvendor

public struct CalculateNewsvendorTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_newsvendor",
        description: """
        Calculate the optimal order quantity for perishable or single-period items
        using the newsvendor (newsboy) model.

        Uses the critical fractile: p_c = c_u / (c_u + c_o)
        Optimal quantity: Q* = μ + z* × σ

        Parameters:
        • mean_demand: Mean of the demand distribution (μ)
        • demand_std_dev: Standard deviation of demand (σ)
        • underage_cost: Per-unit cost of stocking too few (c_u)
        • overage_cost: Per-unit cost of stocking too many (c_o)
        • selling_price: Revenue per unit sold (optional, for profit analysis)
        • unit_cost: Cost per unit ordered (optional, for profit analysis)
        • salvage_value: Value per unsold unit (optional, for profit analysis)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "mean_demand": MCPSchemaProperty(
                    type: "number",
                    description: "Mean demand (μ)"
                ),
                "demand_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Demand standard deviation (σ)"
                ),
                "underage_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Per-unit cost of under-stocking (c_u)"
                ),
                "overage_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Per-unit cost of over-stocking (c_o)"
                ),
                "selling_price": MCPSchemaProperty(
                    type: "number",
                    description: "Revenue per unit sold (optional)"
                ),
                "unit_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Cost per unit ordered (optional)"
                ),
                "salvage_value": MCPSchemaProperty(
                    type: "number",
                    description: "Recovery value per unsold unit (optional)"
                )
            ],
            required: ["mean_demand", "demand_std_dev", "underage_cost", "overage_cost"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let meanDemand = try args.getDouble("mean_demand")
        let demandStdDev = try args.getDouble("demand_std_dev")
        let underageCost = try args.getDouble("underage_cost")
        let overageCost = try args.getDouble("overage_cost")

        let result = try NewsvendorModel<Double>.optimalQuantity(
            meanDemand: meanDemand,
            demandStdDev: demandStdDev,
            underageCost: underageCost,
            overageCost: overageCost
        )

        var output = """
        Newsvendor Model
        \(divider())
        Mean Demand:        \(fmtNum(meanDemand)) units
        Demand Std Dev:     \(fmtNum(demandStdDev))
        Underage Cost (c_u): $\(fmtNum(underageCost))
        Overage Cost (c_o):  $\(fmtNum(overageCost))
        \(divider())
        Critical Fractile:  \(fmtPct(result.criticalFractile))
        z-Score:            \(fmtNum(result.zScore, decimals: 4))
        \(divider())
        Optimal Quantity:   \(fmtNum(result.optimalQuantity)) units
        Expected Overstock: \(fmtNum(result.expectedOverstock))
        Expected Understock: \(fmtNum(result.expectedUnderstock))
        Service Level:      \(fmtPct(result.serviceLevel))
        Expected Profit:    $\(fmtNum(result.expectedProfit))
        \(divider())
        """

        if let price = args.getDoubleOptional("selling_price"),
           let cost = args.getDoubleOptional("unit_cost") {
            let salvage = args.getDoubleOptional("salvage_value") ?? 0.0
            let profit = NewsvendorModel<Double>.expectedProfit(
                quantity: result.optimalQuantity,
                meanDemand: meanDemand,
                demandStdDev: demandStdDev,
                sellingPrice: price,
                unitCost: cost,
                salvageValue: salvage
            )
            output += """

            Profit Analysis at Q*
            \(divider())
            Selling Price:   $\(fmtNum(price))
            Unit Cost:       $\(fmtNum(cost))
            Salvage Value:   $\(fmtNum(salvage))
            Expected Profit: $\(fmtNum(profit))
            \(divider())
            """
        }

        return .success(text: output)
    }
}

// MARK: - 4. Reorder Point

public struct CalculateReorderPointTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "calculate_reorder_point",
        description: """
        Calculate the reorder point from demand history.

        Formula: r = d̄ × L + SS
        Also computes stockout probability for a given current stock level.

        Parameters:
        • demand_history: Array of demand observations per period
        • lead_time: Replenishment lead time in periods
        • service_level: Target cycle service level (0–1)
        • lead_time_std_dev: Standard deviation of lead time (optional)
        • method: Safety stock method (optional): demand_only, demand_and_lead_time
        • current_stock: Current on-hand inventory (optional, for stockout probability)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "demand_history": MCPSchemaProperty(
                    type: "array",
                    description: "Historical demand observations per period"
                ),
                "lead_time": MCPSchemaProperty(
                    type: "number",
                    description: "Lead time in periods"
                ),
                "service_level": MCPSchemaProperty(
                    type: "number",
                    description: "Target service level (0–1)"
                ),
                "lead_time_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Standard deviation of lead time (optional)"
                ),
                "method": MCPSchemaProperty(
                    type: "string",
                    description: "Safety stock method: demand_only or demand_and_lead_time (default: demand_only)"
                ),
                "current_stock": MCPSchemaProperty(
                    type: "number",
                    description: "Current on-hand stock (optional, for stockout probability)"
                )
            ],
            required: ["demand_history", "lead_time", "service_level"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let demandHistory = try args.getDoubleArray("demand_history")
        let leadTime = try args.getDouble("lead_time")
        let serviceLevel = try args.getDouble("service_level")
        let ltStdDev = args.getDoubleOptional("lead_time_std_dev") ?? 0.0

        let methodStr = args.getStringOptional("method") ?? "demand_only"
        let method: SafetyStockModel<Double>.Method
        switch methodStr.lowercased() {
        case "demand_and_lead_time": method = .demandAndLeadTime
        default: method = .demandOnly
        }

        let result = try ReorderPointModel<Double>.calculate(
            demandHistory: demandHistory,
            leadTime: leadTime,
            serviceLevel: serviceLevel,
            leadTimeStdDev: ltStdDev,
            method: method
        )

        var output = """
        Reorder Point Analysis
        \(divider())
        Observations:        \(demandHistory.count) periods
        Average Daily Demand: \(fmtNum(result.averageDailyDemand))
        Demand Std Dev:      \(fmtNum(result.demandStdDev))
        Lead Time:           \(fmtNum(leadTime)) periods
        Service Level:       \(fmtPct(serviceLevel))
        Method:              \(methodStr)
        \(divider())
        Demand During LT:   \(fmtNum(result.demandDuringLeadTime)) units
        Safety Stock:        \(fmtNum(result.safetyStock)) units
        Reorder Point:       \(fmtNum(result.reorderPoint)) units
        z-Score:             \(fmtNum(result.zScore, decimals: 4))
        \(divider())
        """

        if let currentStock = args.getDoubleOptional("current_stock") {
            let prob = ReorderPointModel<Double>.stockoutProbability(
                currentStock: currentStock,
                averageDemand: result.averageDailyDemand,
                demandStdDev: result.demandStdDev,
                leadTime: leadTime,
                leadTimeStdDev: ltStdDev
            )
            output += """

            Stockout Analysis
            \(divider())
            Current Stock:       \(fmtNum(currentStock)) units
            Stockout Probability: \(fmtPct(prob))
            \(divider())
            """
        }

        return .success(text: output)
    }
}

// MARK: - 5. Inventory Simulation

public struct RunInventorySimulationTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_inventory_simulation",
        description: """
        Run a Monte Carlo inventory simulation to estimate reorder point and safety stock.

        Builds an empirical distribution of demand-during-lead-time (DDLT) by sampling
        demand over random lead time windows. Captures non-normal demand patterns.

        Parameters:
        • demand_history: Array of historical demand observations
        • mean_lead_time: Average replenishment lead time
        • service_level: Target cycle service level (0–1)
        • lead_time_std_dev: Standard deviation of lead time (optional)
        • strategy: Sampling strategy: "empirical" or "normal" (default: empirical)
        • iterations: Number of simulation paths (default: 10000)
        • seed: Random seed for reproducibility (optional)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "demand_history": MCPSchemaProperty(
                    type: "array",
                    description: "Historical demand observations per period"
                ),
                "mean_lead_time": MCPSchemaProperty(
                    type: "number",
                    description: "Mean lead time in periods"
                ),
                "service_level": MCPSchemaProperty(
                    type: "number",
                    description: "Target service level (0–1)"
                ),
                "lead_time_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Lead time standard deviation (optional)"
                ),
                "strategy": MCPSchemaProperty(
                    type: "string",
                    description: "Sampling strategy: empirical or normal (default: empirical)"
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: "Number of simulation paths (default: 10000)"
                ),
                "seed": MCPSchemaProperty(
                    type: "number",
                    description: "Random seed for reproducibility (optional)"
                )
            ],
            required: ["demand_history", "mean_lead_time", "service_level"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let demandHistory = try args.getDoubleArray("demand_history")
        let meanLeadTime = try args.getDouble("mean_lead_time")
        let serviceLevel = try args.getDouble("service_level")
        let ltStdDev = args.getDoubleOptional("lead_time_std_dev") ?? 0.0

        let strategyStr = args.getStringOptional("strategy") ?? "empirical"
        let strategy: InventorySimulator.SamplingStrategy
        switch strategyStr.lowercased() {
        case "normal": strategy = .normal
        default: strategy = .empirical
        }

        let iterations = args.getIntOptional("iterations") ?? 10_000
        let seed: UInt64? = args.getIntOptional("seed").map { UInt64($0) }

        let result = try InventorySimulator.simulate(
            demandHistory: demandHistory,
            meanLeadTime: meanLeadTime,
            leadTimeStdDev: ltStdDev,
            serviceLevel: serviceLevel,
            strategy: strategy,
            iterations: iterations,
            seed: seed
        )

        let simStats = result.simulationResults.statistics

        let output = """
        Inventory Simulation Results
        \(divider())
        Demand History:      \(demandHistory.count) observations
        Mean Lead Time:      \(fmtNum(meanLeadTime)) periods
        LT Std Dev:          \(fmtNum(ltStdDev))
        Service Level:       \(fmtPct(serviceLevel))
        Strategy:            \(result.samplingStrategy)
        Iterations:          \(result.pathCount)
        \(divider())
        DDLT Mean:           \(fmtNum(result.demandDuringLeadTimeMean))
        DDLT Std Dev:        \(fmtNum(result.demandDuringLeadTimeStdDev))
        DDLT Min:            \(fmtNum(simStats.min))
        DDLT Max:            \(fmtNum(simStats.max))
        \(divider())
        Reorder Point:       \(fmtNum(result.reorderPoint)) units
        Safety Stock:        \(fmtNum(result.safetyStock)) units
        \(divider())
        Percentiles (DDLT):
          P5:  \(fmtNum(result.simulationResults.percentiles.p5))
          P25: \(fmtNum(result.simulationResults.percentiles.p25))
          P50: \(fmtNum(result.simulationResults.percentiles.p50))
          P75: \(fmtNum(result.simulationResults.percentiles.p75))
          P95: \(fmtNum(result.simulationResults.percentiles.p95))
        \(divider())
        """

        return .success(text: output)
    }
}

// MARK: - 6. Inventory Advisor

public struct RecommendInventoryModelTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "recommend_inventory_model",
        description: """
        Analyze available data and recommend the appropriate inventory model.

        Examines data availability and product characteristics to recommend:
        • Which inventory model to use (reorder point vs. newsvendor)
        • Which safety stock method (demand-only, demand+lead-time, forecast-error)
        • Whether Monte Carlo simulation is beneficial
        • Whether EOQ analysis applies
        • Plain-language reasoning for each decision

        Parameters:
        • demand_history: Array of historical demand observations
        • lead_time_mean: Mean replenishment lead time
        • lead_time_std_dev: Lead time standard deviation (optional)
        • forecast_rmse: Forecast RMSE (optional)
        • underage_cost: Per-unit stockout cost (optional)
        • overage_cost: Per-unit overage cost (optional)
        • is_perishable: Whether the item is perishable/seasonal (optional)
        • annual_demand: Annual demand for EOQ (optional)
        • ordering_cost: Fixed cost per order for EOQ (optional)
        • holding_cost_per_unit: Holding cost per unit/year for EOQ (optional)
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "demand_history": MCPSchemaProperty(
                    type: "array",
                    description: "Historical demand observations per period"
                ),
                "lead_time_mean": MCPSchemaProperty(
                    type: "number",
                    description: "Mean lead time in periods"
                ),
                "lead_time_std_dev": MCPSchemaProperty(
                    type: "number",
                    description: "Lead time std dev (optional)"
                ),
                "forecast_rmse": MCPSchemaProperty(
                    type: "number",
                    description: "Forecast RMSE (optional)"
                ),
                "underage_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Per-unit stockout cost (optional)"
                ),
                "overage_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Per-unit overage cost (optional)"
                ),
                "is_perishable": MCPSchemaProperty(
                    type: "boolean",
                    description: "Whether the item is perishable/seasonal (default: false)"
                ),
                "annual_demand": MCPSchemaProperty(
                    type: "number",
                    description: "Annual demand in units (optional, for EOQ)"
                ),
                "ordering_cost": MCPSchemaProperty(
                    type: "number",
                    description: "Fixed cost per order (optional, for EOQ)"
                ),
                "holding_cost_per_unit": MCPSchemaProperty(
                    type: "number",
                    description: "Annual holding cost per unit (optional, for EOQ)"
                )
            ],
            required: ["demand_history", "lead_time_mean"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let demandHistory = try args.getDoubleArray("demand_history")
        let leadTimeMean = try args.getDouble("lead_time_mean")

        let profile = InventoryAdvisor.DataProfile(
            demandHistory: demandHistory,
            leadTimeMean: leadTimeMean,
            leadTimeStdDev: args.getDoubleOptional("lead_time_std_dev"),
            forecastRMSE: args.getDoubleOptional("forecast_rmse"),
            underageCost: args.getDoubleOptional("underage_cost"),
            overageCost: args.getDoubleOptional("overage_cost"),
            isPerishable: args.getBoolOptional("is_perishable") ?? false,
            annualDemand: args.getDoubleOptional("annual_demand"),
            orderingCost: args.getDoubleOptional("ordering_cost"),
            holdingCostPerUnit: args.getDoubleOptional("holding_cost_per_unit")
        )

        let rec = InventoryAdvisor.recommended(for: profile)

        var output = """
        Inventory Model Recommendation
        \(divider())
        Data Summary:
          Demand Observations: \(demandHistory.count)
          Mean Lead Time:      \(fmtNum(leadTimeMean)) periods
        \(divider())

        Recommended Model: \(rec.recommendedModel.rawValue)
        """

        if let ssMethod = rec.safetyStockMethod {
            output += "\nSafety Stock Method: \(ssMethodLabel(ssMethod))"
        }

        output += "\nSimulation Recommended: \(rec.simulationRecommended ? "Yes" : "No")"

        if let strat = rec.samplingStrategy {
            output += "\nSampling Strategy: \(stratLabel(strat))"
        }

        output += "\nEOQ Applicable: \(rec.eoqApplicable ? "Yes" : "No")"

        output += "\n\(divider())\nReasoning:\n"
        for (i, reason) in rec.reasoning.enumerated() {
            output += "\n\(i + 1). \(reason)"
        }
        output += "\n\(divider())"

        return .success(text: output)
    }

    private func ssMethodLabel(_ method: SafetyStockModel<Double>.Method) -> String {
        switch method {
        case .demandOnly: return "demand_only"
        case .demandAndLeadTime: return "demand_and_lead_time"
        case .forecastError: return "forecast_error"
        }
    }

    private func stratLabel(_ strategy: InventorySimulator.SamplingStrategy) -> String {
        switch strategy {
        case .empirical: return "empirical"
        case .normal: return "normal"
        }
    }
}
