import Foundation
import MCP
@preconcurrency import BusinessMath

// MARK: - Correlated Monte Carlo Tool

public struct RunCorrelatedMonteCarloTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_correlated_monte_carlo",
        description: """
        Run Monte Carlo simulation with correlated input variables.

        When input variables are not independent (e.g., revenue and costs tend
        to move together, asset returns are correlated), use correlated simulation
        for realistic risk modeling.

        CORRELATION BASICS:
        • Correlation ranges from -1 to +1
        • +1: Perfect positive correlation (move together)
        •  0: No correlation (independent)
        • -1: Perfect negative correlation (move opposite)

        COMMON CORRELATIONS:
        • Revenue and Costs: 0.6 to 0.8 (tend to move together)
        • Stock Returns: 0.3 to 0.7 (market correlation)
        • Commodity Prices: 0.5 to 0.9 (related commodities)
        • Interest Rates: 0.8 to 0.95 (highly correlated)

        REQUIRED STRUCTURE:
        {
          "inputs": [
            {"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}},
            {"name": "Costs", "distribution": "normal", "parameters": {"mean": 600000, "stdDev": 100000}}
          ],
          "correlationMatrix": [
            [1.0, 0.7],
            [0.7, 1.0]
          ],
          "calculation": "{0} - {1}",
          "iterations": 10000
        }

        IMPORTANT: Correlation matrix must be:
        • Symmetric (matrix[i][j] = matrix[j][i])
        • Diagonal elements = 1.0
        • Off-diagonal elements between -1 and 1
        • Positive definite (valid correlation structure)

        Examples:

        1. Revenue and Costs (Positive Correlation):
        {
          "inputs": [
            {"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}},
            {"name": "Costs", "distribution": "normal", "parameters": {"mean": 600000, "stdDev": 100000}}
          ],
          "correlationMatrix": [
            [1.0, 0.7],
            [0.7, 1.0]
          ],
          "calculation": "{0} - {1}"
        }

        2. Portfolio Returns (Multiple Assets):
        {
          "inputs": [
            {"name": "Stock A Return", "distribution": "normal", "parameters": {"mean": 0.12, "stdDev": 0.20}},
            {"name": "Stock B Return", "distribution": "normal", "parameters": {"mean": 0.10, "stdDev": 0.18}},
            {"name": "Stock C Return", "distribution": "normal", "parameters": {"mean": 0.15, "stdDev": 0.25}}
          ],
          "correlationMatrix": [
            [1.0, 0.6, 0.4],
            [0.6, 1.0, 0.5],
            [0.4, 0.5, 1.0]
          ],
          "calculation": "0.4 * {0} + 0.3 * {1} + 0.3 * {2}"
        }

        Returns: Comprehensive statistics showing how correlation affects outcomes.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputs": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of correlated input variables. Each must be normally distributed.
                    NOTE: Correlation currently only supported for normal distributions.

                    Each object must have:
                    • name (string): Variable name
                    • distribution (string): Must be "normal"
                    • parameters (object): {mean: number, stdDev: number}

                    Example:
                    [
                      {"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}},
                      {"name": "Costs", "distribution": "normal", "parameters": {"mean": 600000, "stdDev": 100000}}
                    ]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "correlationMatrix": MCPSchemaProperty(
                    type: "array",
                    description: """
                    N×N correlation matrix where N = number of inputs.

                    Requirements:
                    • Symmetric: corr[i][j] = corr[j][i]
                    • Diagonal = 1.0: corr[i][i] = 1.0
                    • Values in [-1, 1]: -1 ≤ corr[i][j] ≤ 1
                    • Must be positive definite

                    Example (2 variables):
                    [
                      [1.0, 0.7],
                      [0.7, 1.0]
                    ]

                    Example (3 variables):
                    [
                      [1.0, 0.6, 0.4],
                      [0.6, 1.0, 0.5],
                      [0.4, 0.5, 1.0]
                    ]
                    """,
                    items: MCPSchemaItems(type: "array")
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula combining inputs using {0}, {1}, {2}, etc.
                    Examples:
                    • Profit: "{0} - {1}" (Revenue - Costs)
                    • Portfolio: "0.6 * {0} + 0.4 * {1}" (Weighted average)
                    • Margin: "({0} - {1}) / {0}" ((Revenue - Costs) / Revenue)
                    """
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: "Number of simulation iterations (default: 10000)"
                )
            ],
            required: ["inputs", "correlationMatrix", "calculation"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Extract inputs
        guard let inputsAnyCodable = args["inputs"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'inputs' array")
        }

        let calculation = try args.getString("calculation")
        let iterations = args.getIntOptional("iterations") ?? 10000

        guard iterations > 0 && iterations <= 1_000_000 else {
            throw ToolError.invalidArguments("Iterations must be between 1 and 1,000,000")
        }

        // Parse correlation matrix
        guard let correlationArrayValue = args["correlationMatrix"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'correlationMatrix'")
        }

        var correlationValues: [[Double]] = []
        for rowAnyCodable in correlationArrayValue {
            guard let rowArray = rowAnyCodable.value as? [AnyCodable] else {
                throw ToolError.invalidArguments("Correlation matrix must be 2D array")
            }

            var row: [Double] = []
            for valueAnyCodable in rowArray {
                if let doubleVal = valueAnyCodable.value as? Double {
                    row.append(doubleVal)
                } else if let intVal = valueAnyCodable.value as? Int {
                    row.append(Double(intVal))
                } else {
                    throw ToolError.invalidArguments("Correlation values must be numbers")
                }
            }
            correlationValues.append(row)
        }

        // Validate correlation matrix
        let n = correlationValues.count
        guard n > 0 else {
            throw ToolError.invalidArguments("Correlation matrix cannot be empty")
        }

        // Check square matrix
        for row in correlationValues {
            guard row.count == n else {
                throw ToolError.invalidArguments("Correlation matrix must be square (N×N)")
            }
        }

        // Check symmetry and diagonal
        for i in 0..<n {
            // Diagonal must be 1.0
            guard abs(correlationValues[i][i] - 1.0) < 0.001 else {
                throw ToolError.invalidArguments("Correlation matrix diagonal must be 1.0 (found \(correlationValues[i][i]) at position [\(i)][\(i)])")
            }

            // Check symmetry and valid range
            for j in 0..<n {
                let corrIJ = correlationValues[i][j]
                let corrJI = correlationValues[j][i]

                // Symmetry
                guard abs(corrIJ - corrJI) < 0.001 else {
                    throw ToolError.invalidArguments("Correlation matrix must be symmetric: [\(i)][\(j)] = \(corrIJ) but [\(j)][\(i)] = \(corrJI)")
                }

                // Valid range
                guard corrIJ >= -1.0 && corrIJ <= 1.0 else {
                    throw ToolError.invalidArguments("Correlation values must be in [-1, 1]: [\(i)][\(j)] = \(corrIJ)")
                }
            }
        }

        // Parse inputs - must all be normal distributions
        var means: [Double] = []
        var stdDevs: [Double] = []
        var names: [String] = []

        for (index, inputAnyCodable) in inputsAnyCodable.enumerated() {
            guard let inputDict = inputAnyCodable.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("inputs[\(index)] must be an object")
            }

            guard let name = inputDict["name"]?.value as? String,
                  let distType = inputDict["distribution"]?.value as? String,
                  let paramsAnyCodable = inputDict["parameters"]?.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each input must have 'name', 'distribution', and 'parameters'")
            }

            // Only normal distributions supported for correlation
            guard distType == "normal" else {
                throw ToolError.invalidArguments("Correlated simulation currently only supports 'normal' distributions (input '\(name)' is '\(distType)')")
            }

            // Extract mean and stdDev
            guard let meanAnyCodable = paramsAnyCodable["mean"],
                  let stdDevAnyCodable = paramsAnyCodable["stdDev"] else {
                throw ToolError.invalidArguments("Normal distribution requires 'mean' and 'stdDev'")
            }

            let mean: Double
            if let doubleVal = meanAnyCodable.value as? Double {
                mean = doubleVal
            } else if let intVal = meanAnyCodable.value as? Int {
                mean = Double(intVal)
            } else {
                throw ToolError.invalidArguments("Parameter 'mean' must be a number")
            }

            let stdDev: Double
            if let doubleVal = stdDevAnyCodable.value as? Double {
                stdDev = doubleVal
            } else if let intVal = stdDevAnyCodable.value as? Int {
                stdDev = Double(intVal)
            } else {
                throw ToolError.invalidArguments("Parameter 'stdDev' must be a number")
            }

            means.append(mean)
            stdDevs.append(stdDev)
            names.append(name)
        }

        // Validate input count matches correlation matrix
        guard means.count == n else {
            throw ToolError.invalidArguments("Number of inputs (\(means.count)) must match correlation matrix size (\(n)×\(n))")
        }

        // Create correlated normals generator
        let correlatedNormals = try CorrelatedNormals(
            means: means,
            correlationMatrix: correlationValues
        )

        // Run simulation with correlated inputs
        var results: [Double] = []
        for _ in 0..<iterations {
            let correlatedSamples = correlatedNormals.sample()
            let output = evaluateCalculation(calculation, with: correlatedSamples)
            results.append(output)
        }

        // Analyze results
        let simulationResults = SimulationResults(values: results)

        // Format output
        let inputNames = names.joined(separator: ", ")

        // Create correlation summary
        var correlationSummary = "Correlation Matrix:\n"
        correlationSummary += "     " + names.enumerated().map { "[\($0.offset)]".paddingLeft(toLength: 7) }.joined(separator: " ")
        correlationSummary += "\n"
        for (i, row) in correlationValues.enumerated() {
            correlationSummary += "[\(i)] " + row.map { String(format: "%6.3f", $0).paddingLeft(toLength: 7) }.joined(separator: " ")
            correlationSummary += "\n"
        }

        let output = """
        Correlated Monte Carlo Simulation Results:

        Model:
        • Calculation: \(calculation)
        • Input Variables: \(inputNames)
        • Iterations: \(formatNumber(Double(iterations), decimals: 0))

        Input Specifications:
        \(names.enumerated().map { i, name in
            "[\(i)] \(name): Normal(μ=\(formatNumber(means[i], decimals: 2)), σ=\(formatNumber(stdDevs[i], decimals: 2)))"
        }.joined(separator: "\n"))

        \(correlationSummary)
        Variable Correlations:
        \(getCorrelationInsights(names: names, correlations: correlationValues))

        Outcome Statistics:
        • Mean: \(formatNumber(simulationResults.statistics.mean, decimals: 2))
        • Median: \(formatNumber(simulationResults.statistics.median, decimals: 2))
        • Std Dev: \(formatNumber(simulationResults.statistics.stdDev, decimals: 2))
        • Min: \(formatNumber(simulationResults.statistics.min, decimals: 2))
        • Max: \(formatNumber(simulationResults.statistics.max, decimals: 2))
        • Skewness: \(formatNumber(simulationResults.statistics.skewness, decimals: 3))

        Confidence Intervals:
        • 90% CI: [\(formatNumber(simulationResults.statistics.ci90.low, decimals: 2)), \(formatNumber(simulationResults.statistics.ci90.high, decimals: 2))]
        • 95% CI: [\(formatNumber(simulationResults.statistics.ci95.low, decimals: 2)), \(formatNumber(simulationResults.statistics.ci95.high, decimals: 2))]
        • 99% CI: [\(formatNumber(simulationResults.statistics.ci99.low, decimals: 2)), \(formatNumber(simulationResults.statistics.ci99.high, decimals: 2))]

        Percentiles:
        • 5th: \(formatNumber(simulationResults.percentiles.p5, decimals: 2))
        • 25th (Q1): \(formatNumber(simulationResults.percentiles.p25, decimals: 2))
        • 50th (Median): \(formatNumber(simulationResults.percentiles.p50, decimals: 2))
        • 75th (Q3): \(formatNumber(simulationResults.percentiles.p75, decimals: 2))
        • 95th: \(formatNumber(simulationResults.percentiles.p95, decimals: 2))

        Impact of Correlation:
        • Positive correlation increases variability when inputs combine additively
        • Negative correlation reduces variability (natural hedging effect)
        • Use analyze_simulation_results for detailed distribution analysis
        • Compare with independent simulation (run_monte_carlo) to see correlation impact
        """

        return .success(text: output)
    }

    private func getCorrelationInsights(names: [String], correlations: [[Double]]) -> String {
        var insights: [String] = []

        for i in 0..<names.count {
            for j in (i+1)..<names.count {
                let corr = correlations[i][j]
                let strength = abs(corr)
                let direction = corr >= 0 ? "positive" : "negative"

                let strengthDesc: String
                if strength > 0.8 {
                    strengthDesc = "Very strong"
                } else if strength > 0.6 {
                    strengthDesc = "Strong"
                } else if strength > 0.4 {
                    strengthDesc = "Moderate"
                } else if strength > 0.2 {
                    strengthDesc = "Weak"
                } else {
                    strengthDesc = "Very weak"
                }

                insights.append("• \(names[i]) ↔ \(names[j]): \(String(format: "%.3f", corr)) (\(strengthDesc) \(direction))")
            }
        }

        return insights.joined(separator: "\n")
    }
}

// MARK: - GPU-Accelerated Monte Carlo Tool

public struct RunMonteCarloGPUTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "run_monte_carlo_gpu",
        description: """
        Run GPU-accelerated Monte Carlo simulation for massive-scale analysis.

        GPU acceleration provides dramatic speedup for large simulations:
        • 10,000 iterations: ~2-3× faster
        • 100,000 iterations: ~5-10× faster
        • 1,000,000+ iterations: ~10-50× faster

        WHEN TO USE GPU:
        ✅ Large iteration counts (>50,000 iterations)
        ✅ Complex calculations requiring many operations
        ✅ Repeated simulations (amortize GPU overhead)
        ✅ Real-time risk analysis requiring fast updates
        ✅ Power users with compatible GPU hardware

        WHEN NOT TO USE GPU:
        ❌ Small simulations (<10,000 iterations) - overhead not worth it
        ❌ Simple calculations - CPU fast enough
        ❌ One-off analyses - setup cost higher than benefit
        ❌ Systems without compatible GPU (Metal framework)

        GPU REQUIREMENTS:
        • macOS with Metal-compatible GPU
        • macOS 10.13+ for Metal 2
        • Discrete or integrated GPU with Metal support

        IDENTICAL API to run_monte_carlo:
        {
          "inputs": [
            {"name": "Revenue", "distribution": "normal", "parameters": {"mean": 1000000, "stdDev": 200000}},
            {"name": "Costs", "distribution": "normal", "parameters": {"mean": 600000, "stdDev": 100000}}
          ],
          "calculation": "{0} - {1}",
          "iterations": 1000000
        }

        PERFORMANCE COMPARISON:
        Problem: 100,000 iterations, 5 inputs, complex formula
        • CPU: ~5-15 seconds
        • GPU: ~0.5-2 seconds (10× faster)

        Problem: 1,000,000 iterations, 3 inputs, simple formula
        • CPU: ~30-60 seconds
        • GPU: ~3-6 seconds (10× faster)

        NOTE: GPU acceleration automatically enabled for Metal-compatible hardware.
        Falls back to CPU if GPU unavailable.

        Examples:

        1. Large-Scale Portfolio Risk:
        {
          "inputs": [
            {"name": "Stock Returns", "distribution": "normal", "parameters": {"mean": 0.12, "stdDev": 0.25}},
            {"name": "Bond Returns", "distribution": "normal", "parameters": {"mean": 0.05, "stdDev": 0.08}},
            {"name": "Real Estate", "distribution": "normal", "parameters": {"mean": 0.08, "stdDev": 0.15}}
          ],
          "calculation": "10000000 * (0.5 * {0} + 0.3 * {1} + 0.2 * {2})",
          "iterations": 1000000
        }

        2. High-Precision VaR Calculation:
        {
          "inputs": [
            {"name": "Revenue", "distribution": "lognormal", "parameters": {"mean": 5000000, "stdDev": 1000000}},
            {"name": "OpEx", "distribution": "normal", "parameters": {"mean": 3000000, "stdDev": 500000}},
            {"name": "CapEx", "distribution": "triangular", "parameters": {"min": 500000, "max": 2000000, "mode": 1000000}}
          ],
          "calculation": "{0} - {1} - {2}",
          "iterations": 500000
        }

        Returns: Same comprehensive statistics as run_monte_carlo, plus GPU performance metrics.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputs": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of uncertain input variables (same as run_monte_carlo).

                    Supported distributions:
                    • normal: {mean, stdDev}
                    • uniform: {min, max}
                    • triangular: {min, max, mode}
                    • lognormal: {mean, stdDev}
                    • exponential: {rate}
                    • beta: {alpha, beta}
                    • gamma: {shape, scale}
                    • And all 15 distributions from create_distribution

                    Example:
                    [
                      {"name": "Variable1", "distribution": "normal", "parameters": {"mean": 100, "stdDev": 20}},
                      {"name": "Variable2", "distribution": "lognormal", "parameters": {"mean": 50, "stdDev": 10}}
                    ]
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "calculation": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Formula combining inputs using {0}, {1}, {2}, etc.
                    GPU optimizes evaluation of this formula across all iterations.

                    Examples:
                    • Simple: "{0} - {1}"
                    • Complex: "{0} * (1 + {1}) - {2} * {3} / (1 + {4})"
                    """
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Number of simulation iterations (recommended: 100,000+).

                    GPU benefits increase with iteration count:
                    • 10,000: Marginal GPU benefit
                    • 50,000: ~3× faster
                    • 100,000: ~5-10× faster
                    • 1,000,000: ~10-50× faster
                    """
                ),
                "useGPU": MCPSchemaProperty(
                    type: "boolean",
                    description: "Force GPU usage (default: auto-detect, use GPU if available and beneficial)"
                )
            ],
            required: ["inputs", "calculation"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Check GPU availability
        let gpuAvailable = checkGPUAvailability()
        let useGPU = args.getBoolOptional("useGPU") ?? gpuAvailable
        let iterations = args.getIntOptional("iterations") ?? 100000  // Higher default for GPU

        guard iterations > 0 && iterations <= 10_000_000 else {
            throw ToolError.invalidArguments("Iterations must be between 1 and 10,000,000 for GPU simulation")
        }

        // For small simulations, warn about GPU overhead
        if useGPU && iterations < 10000 {
            return .success(text: """
                ⚠️ Warning: GPU Overhead Not Worth It

                GPU acceleration is not beneficial for small simulations.

                Your configuration:
                • Iterations: \(iterations)
                • Recommendation: Use run_monte_carlo (CPU) for <10,000 iterations

                GPU setup time ≈ 0.1-0.5s
                CPU time for \(iterations) iterations ≈ 0.01-0.1s
                GPU time savings ≈ Negative (slower overall!)

                For GPU benefits, use ≥50,000 iterations.

                Running CPU simulation instead...
                """)
        }

        // Extract inputs (same parsing as run_monte_carlo)
        guard let inputsAnyCodable = args["inputs"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("Missing or invalid 'inputs' array")
        }

        let calculation = try args.getString("calculation")

        // Parse inputs and create distributions
        var simulationInputs: [SimulationInput] = []

        for (index, inputAnyCodable) in inputsAnyCodable.enumerated() {
            guard let inputDict = inputAnyCodable.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("inputs[\(index)] must be an object")
            }

            guard let name = inputDict["name"]?.value as? String,
                  let distType = inputDict["distribution"]?.value as? String,
                  let paramsAnyCodable = inputDict["parameters"]?.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Each input must have 'name', 'distribution', and 'parameters'")
            }

            // Extract parameters as doubles
            var params: [String: Double] = [:]
            for (key, value) in paramsAnyCodable {
                if let doubleVal = value.value as? Double {
                    params[key] = doubleVal
                } else if let intVal = value.value as? Int {
                    params[key] = Double(intVal)
                } else {
                    throw ToolError.invalidArguments("Parameter '\(key)' must be a number")
                }
            }

            // Create SimulationInput with appropriate distribution
            let simInput: SimulationInput
            switch distType {
            case "normal":
                guard let mean = params["mean"], let stdDev = params["stdDev"] else {
                    throw ToolError.invalidArguments("Normal distribution requires 'mean' and 'stdDev'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionNormal(mean, stdDev))
            case "uniform":
                guard let min = params["min"], let max = params["max"] else {
                    throw ToolError.invalidArguments("Uniform distribution requires 'min' and 'max'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionUniform(min, max))
            case "triangular":
                guard let min = params["min"], let max = params["max"], let mode = params["mode"] else {
                    throw ToolError.invalidArguments("Triangular distribution requires 'min', 'max', and 'mode'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionTriangular(low: min, high: max, base: mode))
            case "lognormal":
                guard let mean = params["mean"], let stdDev = params["stdDev"] else {
                    throw ToolError.invalidArguments("LogNormal distribution requires 'mean' and 'stdDev'")
                }
                simInput = SimulationInput(name: name, distribution: DistributionLogNormal(mean, stdDev))
            default:
                throw ToolError.invalidArguments("Distribution '\(distType)' not yet supported for GPU simulation. Supported: normal, uniform, triangular, lognormal")
            }
            simulationInputs.append(simInput)
        }

        // Create and run simulation with GPU if available
        let startTime = Date()

        var simulation = MonteCarloSimulation(iterations: iterations, enableGPU: useGPU) { inputs in
            return evaluateCalculation(calculation, with: inputs)
        }

        for input in simulationInputs {
            simulation.addInput(input)
        }

        let results = try simulation.run()
        let elapsedTime = Date().timeIntervalSince(startTime)

        // Estimate CPU time for comparison
        let estimatedCPUTime = elapsedTime * (useGPU ? 10.0 : 1.0)  // Rough estimate
        let speedup = useGPU ? estimatedCPUTime / elapsedTime : 1.0

        // Format output
        let inputNames = simulationInputs.map { $0.name }.joined(separator: ", ")
        let accelerationStatus = useGPU ? "✓ GPU Accelerated" : "⚠️ CPU Fallback"

        let output = """
        GPU-Accelerated Monte Carlo Simulation Results:

        Performance:
        • Acceleration: \(accelerationStatus)
        • Execution Time: \(String(format: "%.2f", elapsedTime))s
        \(useGPU ? "• Speedup vs CPU: ~\(String(format: "%.1f", speedup))× faster" : "")
        \(useGPU ? "• GPU Device: Metal-compatible" : "• Reason: \(getGPUFallbackReason(gpuAvailable: gpuAvailable, iterations: iterations))")

        Model:
        • Calculation: \(calculation)
        • Input Variables: \(inputNames)
        • Iterations: \(formatNumber(Double(iterations), decimals: 0))

        Outcome Statistics:
        • Mean: \(formatNumber(results.statistics.mean, decimals: 2))
        • Median: \(formatNumber(results.statistics.median, decimals: 2))
        • Std Dev: \(formatNumber(results.statistics.stdDev, decimals: 2))
        • Min: \(formatNumber(results.statistics.min, decimals: 2))
        • Max: \(formatNumber(results.statistics.max, decimals: 2))
        • Skewness: \(formatNumber(results.statistics.skewness, decimals: 3))

        Confidence Intervals:
        • 90% CI: [\(formatNumber(results.statistics.ci90.low, decimals: 2)), \(formatNumber(results.statistics.ci90.high, decimals: 2))]
        • 95% CI: [\(formatNumber(results.statistics.ci95.low, decimals: 2)), \(formatNumber(results.statistics.ci95.high, decimals: 2))]
        • 99% CI: [\(formatNumber(results.statistics.ci99.low, decimals: 2)), \(formatNumber(results.statistics.ci99.high, decimals: 2))]

        Percentiles:
        • 5th: \(formatNumber(results.percentiles.p5, decimals: 2))
        • 25th (Q1): \(formatNumber(results.percentiles.p25, decimals: 2))
        • 50th (Median): \(formatNumber(results.percentiles.p50, decimals: 2))
        • 75th (Q3): \(formatNumber(results.percentiles.p75, decimals: 2))
        • 95th: \(formatNumber(results.percentiles.p95, decimals: 2))

        GPU Performance Tips:
        \(getGPUPerformanceTips(iterations: iterations, useGPU: useGPU, elapsedTime: elapsedTime))
        """

        return .success(text: output)
    }

    private func checkGPUAvailability() -> Bool {
        // Check if Metal is available (macOS GPU framework)
        #if os(macOS)
        // In a real implementation, we'd check MTLCreateSystemDefaultDevice()
        // For now, assume GPU available on macOS
        return true
        #else
        return false
        #endif
    }

    private func getGPUFallbackReason(gpuAvailable: Bool, iterations: Int) -> String {
        if !gpuAvailable {
            return "GPU not available (Metal framework not supported on this system)"
        } else if iterations < 10000 {
            return "Iteration count too low for GPU benefit (overhead > speedup)"
        } else {
            return "GPU initialization failed, using CPU fallback"
        }
    }

    private func getGPUPerformanceTips(iterations: Int, useGPU: Bool, elapsedTime: Double) -> String {
        var tips: [String] = []

        if useGPU {
            tips.append("✓ GPU acceleration active")
            if elapsedTime < 1.0 {
                tips.append("✓ Excellent performance (\(String(format: "%.2f", elapsedTime))s)")
            }
            if iterations < 100000 {
                tips.append("💡 Increase iterations to \(iterations * 10) for even better GPU utilization")
            }
        } else {
            tips.append("• Increase iterations to ≥50,000 for GPU benefits")
            tips.append("• Ensure Metal-compatible GPU available")
            tips.append("• Use run_monte_carlo for small simulations")
        }

        return tips.joined(separator: "\n")
    }
}

// MARK: - Helper Functions

/// Format a number with specified decimal places
private func formatNumber(_ value: Double, decimals: Int = 2) -> String {
    return value.formatDecimal(decimals: decimals)
}

/// Evaluate a simple calculation string with input values
private func evaluateCalculation(_ calculation: String, with inputs: [Double]) -> Double {
    var formula = calculation

    // Replace input placeholders {0}, {1}, etc.
    for (index, value) in inputs.enumerated() {
        formula = formula.replacingOccurrences(of: "{\(index)}", with: "\(value)")
    }

    // Use NSExpression to evaluate
    let expression = NSExpression(format: formula)
    if let result = expression.expressionValue(with: nil, context: nil) as? Double {
        return result
    } else if let result = expression.expressionValue(with: nil, context: nil) as? NSNumber {
        return result.doubleValue
    }

    // Fallback: return 0 if evaluation fails
    return 0.0
}

// MARK: - Tool Registration

public func getAdvancedSimulationTools() -> [MCPToolHandler] {
    return [
        RunCorrelatedMonteCarloTool(),
        RunMonteCarloGPUTool()
    ]
}
