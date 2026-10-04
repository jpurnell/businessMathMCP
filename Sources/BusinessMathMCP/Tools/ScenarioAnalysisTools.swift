import Foundation
import MCP
import SwiftMCPServer
import BusinessMath

// MARK: - Scenario Analysis Tool

/// The `analyze_scenarios` MCP tool.
///
/// Exposed to clients as the `analyze_scenarios` tool.
public struct ScenarioAnalysisTool: MCPToolHandler, Sendable {
    /// The `analyze_scenarios` tool definition: name, description and input schema.
    public let tool = MCPTool(
        name: "analyze_scenarios",
        description: """
        Run discrete scenario analysis with distributions within scenarios.

        **Key Features:**
        - Run multiple named scenarios (Base Case, Best Case, Worst Case, etc.)
        - Mix fixed values and probability distributions within each scenario
        - Clear distinction between setValue() (deterministic) and setDistribution() (probabilistic)
        - Compare scenarios across multiple metrics
        - Identify best/worst case outcomes
        - Calculate probabilities of specific outcomes

        **Perfect for:**
        - What-if analysis and scenario planning
        - **Stress testing business models** (multi-component P&L with cascading effects)
        - Comparing strategic alternatives
        - Risk assessment across different conditions
        - Recession/disruption scenario modeling (correlated shocks across inputs)

        **setValue() vs setDistribution():**
        - setValue: Use a fixed, known value (deterministic assumption)
        - setDistribution: Sample from a distribution each iteration (uncertain assumption)

        **Example: Three-scenario business model**
        ```json
        {
          "inputNames": ["volume", "price", "margin"],
          "model": "volume * price * (1 - margin)",
          "iterations": 5000,
          "scenarios": [
            {
              "name": "Base Case",
              "inputs": {
                "volume": {"distribution": {"type": "normal", "mean": 50000, "stdDev": 2500}},
                "price": {"distribution": {"type": "normal", "mean": 25.0, "stdDev": 1.0}},
                "margin": {"value": 0.45}
              }
            },
            {
              "name": "Recession",
              "inputs": {
                "volume": {"distribution": {"type": "normal", "mean": 35000, "stdDev": 5000}},
                "price": {"distribution": {"type": "normal", "mean": 22.0, "stdDev": 2.0}},
                "margin": {"distribution": {"type": "normal", "mean": 0.50, "stdDev": 0.03}}
              }
            }
          ],
          "thresholds": [0, 100000]
        }
        ```

        **Returns:**
        - Statistics for each scenario (mean, median, std dev, percentiles)
        - Best/worst scenario identification
        - Probability analysis (above/below thresholds)
        - Risk-adjusted metrics (Sharpe-like ratios)
        - Scenario comparison table

        **Based on:** Part4-Simulation.md validated stress testing patterns
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "inputNames": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Names of all input variables (order matters for model evaluation).
                    The model refers to inputs by these names. Each name must be an identifier: a letter or underscore, then letters, digits and underscores. No spaces, and no name twice.
                    Example: ["revenue", "costs", "growth_rate"]
                    """,
                    items: MCPSchemaItems(type: "string")
                ),
                "model": MCPSchemaProperty(
                    type: "string",
                    description: """
                    Model expression using input variables.
                    Can reference inputs by name, or by position as {0}, {1}, … (inputs[0], inputs[1], … is accepted as another spelling of the same thing).
                    Examples:
                    - "revenue - costs"
                    - "volume * price * (1 - margin)"
                    - "{0} * (1 + {1}) - {2}"

                    \(CallerFormula.syntaxSummary)
                    """
                ),
                "iterations": MCPSchemaProperty(
                    type: "number",
                    description: """
                    Number of Monte Carlo iterations per scenario.
                    Typical values: 1,000 (fast), 5,000 (balanced), 10,000 (precise)
                    """
                ),
                "scenarios": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Array of scenario definitions. Each scenario must configure all inputs.

                    Each scenario has:
                    - name: Scenario label (e.g., "Base Case", "Best Case")
                    - inputs: Object mapping input names to configurations

                    Each input can be:
                    - Fixed value: {"value": 100}
                    - Distribution: {"distribution": {"type": "normal", "mean": 100, "stdDev": 10}}

                    Supported distributions:
                    - normal: {"type": "normal", "mean": μ, "stdDev": σ}
                    - uniform: {"type": "uniform", "min": a, "max": b}
                    - triangular: {"type": "triangular", "min": a, "mode": b, "max": c}
                    """,
                    items: MCPSchemaItems(type: "object")
                ),
                "thresholds": MCPSchemaProperty(
                    type: "array",
                    description: """
                    Optional thresholds for probability analysis.
                    Tool will calculate P(outcome > threshold) for each value.
                    Example: [0, 100000] checks probability of profit and exceeding $100K
                    """,
                    items: MCPSchemaItems(type: "number")
                )
            ],
            required: ["inputNames", "model", "iterations", "scenarios"]
        )
    )

    /// Creates the `analyze_scenarios` handler.
    public init() {}

    /// Runs `analyze_scenarios` against the caller's arguments.
    /// - Parameter arguments: Values keyed by the input schema's property names.
    /// - Returns: The tool's formatted result.
    /// - Throws: If a required argument is missing or the computation fails.
    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        // Parse input names
        let inputNames = try args.getStringArray("inputNames")
        guard !inputNames.isEmpty else {
            throw ToolError.invalidArguments("inputNames must not be empty")
        }

        // Parse model expression
        let modelExpression = try args.getString("model")

        // Parse iterations
        let iterations = try args.getInt("iterations")
        guard iterations > 0 && iterations <= 100_000 else {
            throw ToolError.invalidArguments("iterations must be between 1 and 100,000")
        }

        // Parse scenarios
        guard let scenariosArray = args["scenarios"]?.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("scenarios must be an array")
        }

        guard !scenariosArray.isEmpty else {
            throw ToolError.invalidArguments("At least one scenario is required")
        }

        // Parse optional thresholds
        var thresholds: [Double] = []
        if let thresholdsValue = args["thresholds"]?.value {
            if let doubleArray = thresholdsValue as? [Double] {
                thresholds = doubleArray
            } else if let anyArray = thresholdsValue as? [AnyCodable] {
                thresholds = try anyArray.map { value -> Double in
                    if let d = value.value as? Double {
                        return d
                    } else if let i = value.value as? Int {
                        return Double(i)
                    }
                    throw ToolError.invalidArguments("thresholds must contain only numbers")
                }
            }
        }

        // The model refers to inputs by name, so every name has to be one a formula can
        // contain, and has to mean one input.
        for (index, name) in inputNames.enumerated() {
            guard CallerFormula.isIdentifier(name) else {
                throw ToolError.invalidArguments(
                    "inputNames[\(index)] '\(name)' is not a valid variable name. A name must start with a letter or underscore and contain only letters, digits and underscores (for example 'sales_volume').")
            }
        }
        guard Set(inputNames).count == inputNames.count else {
            throw ToolError.invalidArguments("inputNames must not repeat a name")
        }

        // Check the model before any scenario runs. The model callback cannot throw, so a
        // failure is recorded and the analysis fails with it.
        let formula = try CallerFormula(
            CallerFormula.replacingIndexedInputs(in: modelExpression),
            argument: "model", names: inputNames)
        let model: @Sendable ([Double]) -> Double = { inputs in
            formula.recordedValue(at: inputs)
        }

        // Create scenario analysis
        var analysis = ScenarioAnalysis(
            inputNames: inputNames,
            model: model,
            iterations: iterations
        )

        // Parse and add scenarios
        for (index, scenarioValue) in scenariosArray.enumerated() {
            guard let scenarioDict = scenarioValue.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Scenario \(index) must be an object")
            }

            guard let scenarioName = scenarioDict["name"]?.value as? String else {
                throw ToolError.invalidArguments("Scenario \(index) must have a 'name' field")
            }

            guard let inputsDict = scenarioDict["inputs"]?.value as? [String: AnyCodable] else {
                throw ToolError.invalidArguments("Scenario '\(scenarioName)' must have an 'inputs' field")
            }

            // Resolve every input before building the Scenario. The closure below cannot
            // throw, so a malformed distribution used to `return` from it — abandoning the
            // scenario's *remaining* inputs, not just the bad one — and a distribution of an
            // unsupported type was dropped with no error at all. Resolving here lets both
            // report themselves.
            var resolvedInputs: [(name: String, value: ResolvedScenarioInput)] = []
            for inputName in inputNames {
                guard let inputConfig = inputsDict[inputName]?.value as? [String: AnyCodable] else {
                    // Absent from this scenario; ScenarioAnalysis validation names it.
                    continue
                }

                // Check if it's a fixed value or distribution
                if let fixedValue = inputConfig["value"]?.value as? Double {
                    resolvedInputs.append((inputName, .fixed(fixedValue)))
                } else if let fixedValue = inputConfig["value"]?.value as? Int {
                    resolvedInputs.append((inputName, .fixed(Double(fixedValue))))
                } else if let distDict = inputConfig["distribution"]?.value as? [String: AnyCodable] {
                    let distribution = try parseDistribution(distDict)
                    // Type-erase the distribution to match setDistribution's generic constraint
                    if let normalDist = distribution as? DistributionNormal {
                        resolvedInputs.append((inputName, .normal(normalDist)))
                    } else if let uniformDist = distribution as? DistributionUniform {
                        resolvedInputs.append((inputName, .uniform(uniformDist)))
                    } else if let triangularDist = distribution as? DistributionTriangular {
                        resolvedInputs.append((inputName, .triangular(triangularDist)))
                    } else {
                        throw ToolError.invalidArguments(
                            "Scenario '\(scenarioName)' input '\(inputName)': unsupported distribution type — use normal, uniform, or triangular")
                    }
                }
            }

            let scenario = Scenario(name: scenarioName) { config in
                for (inputName, resolved) in resolvedInputs {
                    switch resolved {
                    case .fixed(let value):
                        config.setValue(value, forInput: inputName)
                    case .normal(let distribution):
                        config.setDistribution(distribution, forInput: inputName)
                    case .uniform(let distribution):
                        config.setDistribution(distribution, forInput: inputName)
                    case .triangular(let distribution):
                        config.setDistribution(distribution, forInput: inputName)
                    }
                }
            }

            analysis.addScenario(scenario)
        }

        // Run analysis
        let results: [String: SimulationResults]
        do {
            results = try analysis.run()
        } catch let error as any CallerVisibleError {
            // If the model is what failed, that is the answer.
            try formula.throwIfFailed()
            return .error(message: """
                Scenario Analysis Failed

                Could not complete scenario analysis.

                Error: \(error.callerMessage)

                Common issues:
                • Scenario missing configuration for one or more inputs
                • Distribution parameters out of valid range
                """)
        } catch {
            try formula.throwIfFailed()
            throw error
        }
        try formula.throwIfFailed()

        // Generate output
        let comparison = ScenarioComparison(results: results)
        var output = """
        🎯 **Scenario Analysis Results**

        **Configuration:**
        - Inputs: \(inputNames.joined(separator: ", "))
        - Model: \(modelExpression)
        - Iterations per scenario: \(iterations)
        - Total scenarios: \(results.count)

        """

        // Section 1: Scenario Statistics
        output += """
        ## Scenario Statistics

        """

        for (name, result) in results.sorted(by: { $0.key < $1.key }) {
            let mean = result.statistics.mean
            let median = result.statistics.median
            let stdDev = result.statistics.stdDev
            let p5 = result.percentiles.p5
            let p95 = result.percentiles.p95

            output += """

            **\(name):**
            - Mean: \(mean.number(2))
            - Median: \(median.number(2))
            - Std Dev: \(stdDev.number(2))
            - 90% CI: [\(p5.number(2))), \(p95.number(2))]

            """
        }

        // Section 2: Best/Worst Scenarios
        output += """

        ## Scenario Comparison

        """

        let bestByMean = comparison.bestScenario(by: .mean)
        let worstByMean = comparison.worstScenario(by: .mean)
        let bestByP5 = comparison.bestScenario(by: .p5)
        let worstByP5 = comparison.worstScenario(by: .p5)

        output += """
        **Best/Worst by Mean:**
        - Best: \(bestByMean.name) (\(bestByMean.results.statistics.mean.number(2))
        - Worst: \(worstByMean.name) (\(worstByMean.results.statistics.mean.number(2))

        **Best/Worst by 5th Percentile (Downside Risk):**
        - Best: \(bestByP5.name) (\(bestByP5.results.percentiles.p5.number(2))
        - Worst: \(worstByP5.name) (\(worstByP5.results.percentiles.p5.number(2))

        """

        // Section 3: Threshold Analysis
        if !thresholds.isEmpty {
            output += """
            ## Probability Analysis

            """

            for threshold in thresholds {
                output += """

                **Probability of Exceeding \(threshold.number(0)):**
                """

                for (name, result) in results.sorted(by: { $0.key < $1.key }) {
                    let prob = result.probabilityAbove(threshold)
                    output += """

                    - \(name): \(prob.percent(1))
                    """
                }
            }

            output += "\n"
        }

        // Section 4: Risk-Adjusted Metrics
        output += """

        ## Risk-Adjusted Metrics

        **Sharpe-like Ratios (Mean / Std Dev):**
        """

        for (name, result) in results.sorted(by: { $0.key < $1.key }) {
            let mean = result.statistics.mean
            let stdDev = result.statistics.stdDev
            let sharpe = stdDev > 0 ? mean / stdDev : 0
            output += """

            - \(name): \(sharpe.number(3))
            """
        }

        output += """


        **Interpretation:**
        Each scenario was run \(iterations) times, sampling from configured distributions.
        Higher Sharpe ratios indicate better risk-adjusted returns.
        The 90% confidence interval shows the range containing 90% of outcomes.

        **Note:** This analysis uses discrete scenarios. Each scenario represents a different
        set of assumptions about the future. Results help compare alternatives and assess risks.
        """

        return .success(text: output)
    }
}

// MARK: - Helper Functions

/// Parse a distribution from JSON configuration
/// One scenario input, resolved to a concrete value or distribution.
///
/// `Scenario`'s configuration closure is non-throwing, so inputs are resolved before it
/// runs and the closure only applies what is already known to be valid.
private enum ResolvedScenarioInput: Sendable {
    /// A deterministic value held constant across iterations.
    case fixed(Double)
    /// A normally distributed input.
    case normal(DistributionNormal)
    /// A uniformly distributed input.
    case uniform(DistributionUniform)
    /// A triangularly distributed input.
    case triangular(DistributionTriangular)
}

private func parseDistribution(_ dict: [String: AnyCodable]) throws -> any DistributionRandom & Sendable {
    guard let typeStr = dict["type"]?.value as? String else {
        throw ToolError.invalidArguments("Distribution must have 'type' field")
    }

    switch typeStr.lowercased() {
    case "normal":
        guard let mean = extractDouble(dict["mean"]) else {
            throw ToolError.invalidArguments("Normal distribution requires 'mean' parameter")
        }
        guard let stdDev = extractDouble(dict["stdDev"]) ?? extractDouble(dict["stddev"]) else {
            throw ToolError.invalidArguments("Normal distribution requires 'stdDev' parameter")
        }
        guard stdDev > 0 else {
            throw ToolError.invalidArguments("Normal distribution stdDev must be positive")
        }
        return DistributionNormal(mean, stdDev)

    case "uniform":
        guard let min = extractDouble(dict["min"]) else {
            throw ToolError.invalidArguments("Uniform distribution requires 'min' parameter")
        }
        guard let max = extractDouble(dict["max"]) else {
            throw ToolError.invalidArguments("Uniform distribution requires 'max' parameter")
        }
        guard min < max else {
            throw ToolError.invalidArguments("Uniform distribution min must be less than max")
        }
        return DistributionUniform(min, max)

    case "triangular":
        guard let min = extractDouble(dict["min"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'min' parameter")
        }
        guard let mode = extractDouble(dict["mode"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'mode' parameter")
        }
        guard let max = extractDouble(dict["max"]) else {
            throw ToolError.invalidArguments("Triangular distribution requires 'max' parameter")
        }
        guard min <= mode && mode <= max else {
            throw ToolError.invalidArguments("Triangular distribution requires min ≤ mode ≤ max")
        }
        return DistributionTriangular(low: min, high: max, base: mode)

    default:
        throw ToolError.invalidArguments("Unknown distribution type: \(typeStr)")
    }
}

/// Extract a Double from AnyCodable
private func extractDouble(_ value: AnyCodable?) -> Double? {
    if let d = value?.value as? Double {
        return d
    } else if let i = value?.value as? Int {
        return Double(i)
    }
    return nil
}

// MARK: - Tool Registration

/// Every scenario analysis tool this server exposes.
public func getScenarioAnalysisTools() -> [MCPToolHandler] {
    return [
        ScenarioAnalysisTool()
    ]
}
