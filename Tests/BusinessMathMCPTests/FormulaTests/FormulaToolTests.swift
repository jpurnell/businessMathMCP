import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Every tool that takes a formula, against the SwiftMCPServer 5.0.0 grammar: `^` is power,
/// `/` is floating-point, inputs are variables rather than pasted text, and a formula that
/// cannot be evaluated is an error the caller can read — not a crash, and not a zero.
@Suite("Formula tools")
struct FormulaToolTests {

    /// Runs a handler the way the server does, so that what is asserted is what a caller
    /// receives: the registry's disclosure decides what a thrown error may say.
    private func call(
        _ handler: any MCPToolHandler, _ json: String
    ) async throws -> (text: String, isError: Bool) {
        let registry = ToolDefinitionRegistry()
        try await registry.register(handler.toToolDefinition())
        let value = try JSONDecoder().decode(MCP.Value.self, from: Data(json.utf8))
        guard case .object(let arguments) = value else {
            throw MCPTestError.decodingFailed("arguments must be a JSON object")
        }
        let result = try await registry.executeTool(name: handler.tool.name, arguments: arguments)
        guard case .text(let text, _, _) = result.content.first else {
            throw MCPTestError.unexpectedResult("no text content")
        }
        return (text, result.isError ?? false)
    }

    // MARK: - newton_raphson_optimize

    @Test("newton_raphson_optimize: ^ is power")
    func newtonPower() async throws {
        let result = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "x ^ 2", "target": 16, "initialGuess": 3, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• x = 4.00000000"))
        #expect(result.text.contains("• f(x) = 16.00000000"))
    }

    @Test("newton_raphson_optimize: / is floating-point, through a positional placeholder")
    func newtonDivision() async throws {
        let result = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "{0} / 4", "target": 2.5, "initialGuess": 1, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• x = 10.00000000"))
        #expect(result.text.contains("• f(x) = 2.50000000"))
    }

    @Test("newton_raphson_optimize: x beside exp(x) and max(x, 1)")
    func newtonXBesideFunctions() async throws {
        // Below x = 1 this is exp(x) + 1, which is 3 at x = ln 2.
        let result = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "exp(x) + max(x, 1)", "target": 3, "initialGuess": 0.5, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• x = 0.69314718"))
        #expect(result.text.contains("• f(x) = 3.00000000"))
    }

    @Test("newton_raphson_optimize: a bad formula says what is wrong with it")
    func newtonBadFormula() async throws {
        let result = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "x +* 2", "initialGuess": 3}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: formula is not a valid formula. Unexpected '*' at position 3.")
    }

    @Test("newton_raphson_optimize: no value at the initial guess is the caller's error")
    func newtonUndefinedAtGuess() async throws {
        let result = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "1 / x", "initialGuess": 0, "target": 2}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: formula has no value at x = 0.0. The formula divides by zero.")
    }

    @Test("newton_raphson_optimize: a failure during the solve fails the solve with the formula's error")
    func newtonFailsMidRun() async throws {
        // sqrt(x) = -1 has no solution; from x = 1 the first Newton step lands at x = -3,
        // where sqrt has no value. That is the answer — not "did not converge", and not a
        // root found by treating the failure as zero.
        let tool = NewtonRaphsonOptimizeTool()
        let arguments = try decodeArguments("""
            {"formula": "sqrt(x) + 1", "initialGuess": 1, "target": 0}
            """)
        let failure = await #expect(throws: FormulaFailure.self) {
            _ = try await tool.execute(arguments: arguments)
        }
        guard case .undefined(let argument, let reason, let inputs) = failure else {
            Issue.record("expected an undefined-value failure, got \(String(describing: failure))")
            return
        }
        #expect(argument == "formula")
        #expect(reason == .notFinite)
        #expect(inputs.map(\.label) == ["x"])
        #expect(inputs.allSatisfy { $0.value < 0 })
    }

    @Test("newton_raphson_optimize and goal_seek refuse an iteration limit the solver would trap on",
          arguments: [-1, 0])
    func solversRefuseNonPositiveIterationLimit(limit: Int) async throws {
        let newton = try await call(NewtonRaphsonOptimizeTool(), """
            {"formula": "x - 1", "initialGuess": 3, "maxIterations": \(limit)}
            """)
        #expect(newton.isError)
        #expect(newton.text == "Invalid arguments: maxIterations must be greater than zero")

        let goalSeek = try await call(GoalSeekTool(), """
            {"calculation": "x - 1", "target": 0, "initialGuess": 3, "maxIterations": \(limit)}
            """)
        #expect(goalSeek.isError)
        #expect(goalSeek.text == "Invalid arguments: maxIterations must be greater than zero")
    }

    // MARK: - gradient_descent_optimize

    @Test("gradient_descent_optimize: ^ and / with positional placeholders")
    func gradientDescent() async throws {
        let result = try await call(GradientDescentOptimizeTool(), """
            {"formula": "({0} - 3) ^ 2 + ({1} / 2 - 1) ^ 2", "initialValues": [0, 0],
             "sense": "minimize", "learningRate": 0.1, "maxIterations": 5000, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• Values: [3.0000, 2.0000]"))
        #expect(result.text.contains("• Objective Value: 0.000000 (minimized)"))
    }

    @Test("gradient_descent_optimize: a placeholder with no value is refused before optimizing")
    func gradientDescentBadPlaceholder() async throws {
        let result = try await call(GradientDescentOptimizeTool(), """
            {"formula": "{0} + {5}", "initialValues": [1, 2], "sense": "minimize"}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: formula is not a valid formula. Placeholder {5} has no value: 2 positional value(s) were supplied.")
    }

    @Test("gradient_descent_optimize: no value at the starting point is the caller's error")
    func gradientDescentUndefinedAtStart() async throws {
        let result = try await call(GradientDescentOptimizeTool(), """
            {"formula": "1 / ({0} - {1})", "initialValues": [2, 2], "sense": "minimize"}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: formula has no value at {0} = 2.0, {1} = 2.0. The formula divides by zero.")
    }

    // MARK: - goal_seek

    @Test("goal_seek: ^ is power")
    func goalSeekPower() async throws {
        let result = try await call(GoalSeekTool(), """
            {"calculation": "{0} ^ 2", "target": 16, "initialGuess": 3, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• Input Value: 4.000000"))
        #expect(result.text.contains("• Achieves Output: 16.000000"))
    }

    @Test("goal_seek: / is floating-point, and x names the input")
    func goalSeekDivision() async throws {
        let result = try await call(GoalSeekTool(), """
            {"calculation": "x / 4", "target": 2.5, "initialGuess": 1, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• Input Value: 10.000000"))
        #expect(result.text.contains("• Achieves Output: 2.500000"))
    }

    @Test("goal_seek: x beside exp(x) and max(x, 1)")
    func goalSeekXBesideFunctions() async throws {
        let result = try await call(GoalSeekTool(), """
            {"calculation": "exp(x) + max(x, 1)", "target": 3, "initialGuess": 0.5, "tolerance": 1e-12}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("• Input Value: 0.693147"))
        #expect(result.text.contains("• Achieves Output: 3.000000"))
    }

    @Test("goal_seek: ** is not an operator, and the caller is told where")
    func goalSeekBadFormula() async throws {
        let result = try await call(GoalSeekTool(), """
            {"calculation": "{0} ** 2", "target": 16, "initialGuess": 3}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. Unexpected '*' at position 5.")
    }

    // MARK: - run_monte_carlo

    /// One input, fixed at 10 by a normal distribution with no spread, so the outcome of every
    /// iteration is the formula's value at 10.
    private func monteCarlo(_ calculation: String) -> String {
        """
        {"inputs": [{"name": "demand", "distribution": "normal",
                     "parameters": {"mean": 10, "stdDev": 0}}],
         "calculation": "\(calculation)", "iterations": 50}
        """
    }

    @Test("run_monte_carlo: ^, /, a named input, a placeholder, and x-bearing functions",
          arguments: [
            ("{0} ^ 2", "• Mean: 100.00"),
            ("{0} / 4", "• Mean: 2.50"),
            ("demand / 4 + {0}", "• Mean: 12.50"),
            ("max(demand, 1) + exp(0)", "• Mean: 11.00"),
          ])
    func runMonteCarlo(calculation: String, expected: String) async throws {
        let result = try await call(RunMonteCarloTool(), monteCarlo(calculation))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
        #expect(result.text.contains("• Std Dev: 0.00"))
    }

    @Test("run_monte_carlo: an unknown name is refused before any iteration")
    func runMonteCarloBadFormula() async throws {
        let result = try await call(RunMonteCarloTool(), monteCarlo("{0} + supply"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. 'supply' has no value. It is not a supplied variable or a constant.")
    }

    @Test("run_monte_carlo: an iteration with no value fails the run; it is not a zero")
    func runMonteCarloFailsMidRun() async throws {
        let result = try await call(RunMonteCarloTool(), monteCarlo("1 / (demand - 10)"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation has no value at demand = 10.0. The formula divides by zero.")
    }

    // MARK: - sensitivity_analysis

    @Test("sensitivity_analysis: ^, /, x and a placeholder",
          arguments: [
            ("{0} ^ 2", "• Output: 16.00", "  6.00 → 36.00"),
            ("x / 4", "• Output: 1.00", "  6.00 → 1.50"),
            ("exp(x - x) + max(x, 1)", "• Output: 5.00", "  6.00 → 7.00"),
          ])
    func sensitivity(calculation: String, base: String, last: String) async throws {
        let result = try await call(SensitivityAnalysisTool(), """
            {"baseValue": 4, "variableRange": {"min": 2, "max": 6}, "steps": 3,
             "calculation": "\(calculation)"}
            """)
        #expect(!result.isError)
        #expect(result.text.contains(base))
        #expect(result.text.contains(last))
    }

    @Test("sensitivity_analysis: a point with no value fails the sweep and names the point")
    func sensitivityUndefined() async throws {
        let result = try await call(SensitivityAnalysisTool(), """
            {"baseValue": 4, "variableRange": {"min": 2, "max": 6}, "steps": 3,
             "calculation": "1 / ({0} - 4)"}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation has no value at x = 4.0. The formula divides by zero.")
    }

    @Test("sensitivity_analysis: an unsupported function lists the supported ones")
    func sensitivityBadFormula() async throws {
        let result = try await call(SensitivityAnalysisTool(), """
            {"baseValue": 4, "variableRange": {"min": 2, "max": 6}, "steps": 3,
             "calculation": "sum({0}, 1)"}
            """)
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. 'sum' is not a supported function. Supported: abs, ceiling, cos, exp, floor, ln, log, log10, max, min, pow, sin, sqrt, tan, trunc.")
    }

    // MARK: - tornado_analysis

    private func tornado(_ calculation: String) -> String {
        """
        {"variables": [
            {"name": "price", "baseValue": 10, "lowValue": 8, "highValue": 12},
            {"name": "units", "baseValue": 4, "lowValue": 2, "highValue": 8}],
         "calculation": "\(calculation)"}
        """
    }

    @Test("tornado_analysis: ^, /, named variables and placeholders",
          arguments: [
            ("price ^ 2 / units", "Base Case Output: 25.00"),
            ("{0} / {1}", "Base Case Output: 2.50"),
            ("max(price, 1) + exp(units - {1})", "Base Case Output: 11.00"),
          ])
    func tornadoAnalysis(calculation: String, expected: String) async throws {
        let result = try await call(TornadoAnalysisTool(), tornado(calculation))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
    }

    @Test("tornado_analysis: a bad formula is refused")
    func tornadoBadFormula() async throws {
        let result = try await call(TornadoAnalysisTool(), tornado("price - "))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. The formula ends where a value or a closing bracket was expected.")
    }

    // MARK: - run_scenario_analysis

    private func scenarioAnalysis(_ calculation: String, values: String = "[10, 4]") -> String {
        """
        {"inputNames": ["Revenue", "Costs"], "calculation": "\(calculation)", "iterations": 20,
         "scenarios": [{"name": "Only", "values": \(values)}]}
        """
    }

    @Test("run_scenario_analysis: ^, /, named inputs and placeholders",
          arguments: [
            ("{0} ^ 2", "• Best Scenario (by mean): Only - 100.00"),
            ("Revenue / Costs", "• Best Scenario (by mean): Only - 2.50"),
            ("max(Revenue, 1) + exp({1} - Costs)", "• Best Scenario (by mean): Only - 11.00"),
          ])
    func runScenarioAnalysis(calculation: String, expected: String) async throws {
        let result = try await call(RunScenarioAnalysisTool(), scenarioAnalysis(calculation))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
    }

    @Test("run_scenario_analysis: a scenario with no value fails the analysis")
    func runScenarioAnalysisFailsMidRun() async throws {
        let result = try await call(
            RunScenarioAnalysisTool(),
            scenarioAnalysis("1 / (Revenue - Costs)", values: "[100, 100]"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation has no value at Revenue = 100.0, Costs = 100.0. The formula divides by zero.")
    }

    @Test("run_scenario_analysis: a bad formula is refused before any scenario runs")
    func runScenarioAnalysisBadFormula() async throws {
        let result = try await call(RunScenarioAnalysisTool(), scenarioAnalysis("Revenue - Cost"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. 'Cost' has no value. It is not a supplied variable or a constant.")
    }

    // MARK: - analyze_scenarios

    private func analyzeScenarios(
        _ model: String, names: String = #"["volume", "price"]"#,
        inputs: String = #"{"volume": {"value": 10}, "price": {"value": 4}}"#
    ) -> String {
        """
        {"inputNames": \(names), "model": "\(model)", "iterations": 20,
         "scenarios": [{"name": "Only", "inputs": \(inputs)}]}
        """
    }

    @Test("analyze_scenarios: ^, /, names, inputs[n], {n}, and x-bearing functions",
          arguments: [
            ("volume ^ 2", "- Mean: 100.00"),
            ("volume / price", "- Mean: 2.50"),
            ("inputs[0] * (1 + inputs[1])", "- Mean: 50.00"),
            ("{0} - {1}", "- Mean: 6.00"),
            ("max(volume, 1) + exp(price - price)", "- Mean: 11.00"),
          ])
    func analyzeScenarios(model: String, expected: String) async throws {
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios(model))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
    }

    @Test("analyze_scenarios: a name inside another name is a different variable")
    func analyzeScenariosSubstringNames() async throws {
        // Substituted as text, "rate" was replaced inside "rate_cap" as well.
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios(
            "rate_cap - rate", names: #"["rate", "rate_cap"]"#,
            inputs: #"{"rate": {"value": 0.25}, "rate_cap": {"value": 1}}"#))
        #expect(!result.isError)
        #expect(result.text.contains("- Mean: 0.75"))
    }

    @Test("analyze_scenarios: an input name with a space is refused, with the rule")
    func analyzeScenariosNameWithSpace() async throws {
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios(
            "inputs[0]", names: #"["Sales Volume"]"#,
            inputs: #"{"Sales Volume": {"value": 10}}"#))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: inputNames[0] 'Sales Volume' is not a valid variable name. A name must start with a letter or underscore and contain only letters, digits and underscores (for example 'sales_volume').")
    }

    @Test("analyze_scenarios: a repeated input name is refused")
    func analyzeScenariosRepeatedName() async throws {
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios(
            "volume", names: #"["volume", "volume"]"#, inputs: #"{"volume": {"value": 10}}"#))
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: inputNames must not repeat a name")
    }

    @Test("analyze_scenarios: a model naming something that is not an input is refused")
    func analyzeScenariosBadModel() async throws {
        let result = try await call(
            ScenarioAnalysisTool(), analyzeScenarios("volume * price * (1 - margin)"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: model is not a valid formula. 'margin' has no value. It is not a supplied variable or a constant.")
    }

    @Test("analyze_scenarios: an error position counts characters in the model as it was sent")
    func analyzeScenariosErrorPosition() async throws {
        // `inputs[0]` is rewritten to `{0}` before evaluation; the '$' is still at 12.
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios("inputs[0] + $"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: model is not a valid formula. Unexpected character '$' at position 12. A formula may contain numbers, names, + - * / ^, parentheses, commas and {n} placeholders.")
    }

    @Test("analyze_scenarios: a scenario with no value fails the analysis; it is not a zero")
    func analyzeScenariosFailsMidRun() async throws {
        let result = try await call(ScenarioAnalysisTool(), analyzeScenarios(
            "1 / (volume - price)", inputs: #"{"volume": {"value": 4}, "price": {"value": 4}}"#))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: model has no value at volume = 4.0, price = 4.0. The formula divides by zero.")
    }

    // MARK: - run_correlated_monte_carlo, run_monte_carlo_gpu

    private func correlated(_ calculation: String) -> String {
        """
        {"inputs": [
            {"name": "revenue", "distribution": "normal", "parameters": {"mean": 10, "stdDev": 1}},
            {"name": "costs", "distribution": "normal", "parameters": {"mean": 4, "stdDev": 1}}],
         "correlationMatrix": [[1, 0.5], [0.5, 1]],
         "calculation": "\(calculation)", "iterations": 50}
        """
    }

    @Test("run_correlated_monte_carlo: ^, /, names and placeholders",
          arguments: [
            ("2 ^ 3 + revenue * 0", "• Mean: 8.00"),
            ("10 / 4 + {1} * 0", "• Mean: 2.50"),
            ("max(revenue - revenue, 1) + exp(costs - {1})", "• Mean: 2.00"),
          ])
    func correlatedMonteCarlo(calculation: String, expected: String) async throws {
        let result = try await call(RunCorrelatedMonteCarloTool(), correlated(calculation))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
    }

    @Test("run_correlated_monte_carlo: a bad formula is refused before any iteration")
    func correlatedMonteCarloBadFormula() async throws {
        let result = try await call(RunCorrelatedMonteCarloTool(), correlated("{0} - {2}"))
        #expect(result.isError)
        #expect(result.text
            == "Invalid arguments: calculation is not a valid formula. Placeholder {2} has no value: 2 positional value(s) were supplied.")
    }

    @Test("run_correlated_monte_carlo: a sample with no value fails the run")
    func correlatedMonteCarloFailsMidRun() async throws {
        let result = try await call(RunCorrelatedMonteCarloTool(), correlated("1 / (revenue - {0})"))
        #expect(result.isError)
        #expect(result.text.hasPrefix("Invalid arguments: calculation has no value at revenue = "))
        #expect(result.text.hasSuffix(". The formula divides by zero."))
    }

    private func gpu(_ calculation: String) -> String {
        """
        {"inputs": [{"name": "demand", "distribution": "normal",
                     "parameters": {"mean": 10, "stdDev": 0}}],
         "calculation": "\(calculation)", "iterations": 50, "useGPU": false}
        """
    }

    @Test("run_monte_carlo_gpu: ^, /, a named input and a placeholder",
          arguments: [
            ("{0} ^ 2", "• Mean: 100.00"),
            ("demand / 4", "• Mean: 2.50"),
            ("max(demand, 1) + exp({0} - demand)", "• Mean: 11.00"),
          ])
    func gpuMonteCarlo(calculation: String, expected: String) async throws {
        let result = try await call(RunMonteCarloGPUTool(), gpu(calculation))
        #expect(!result.isError)
        #expect(result.text.contains(expected))
    }

    @Test("run_monte_carlo_gpu: a bad formula is refused, and a failing iteration fails the run")
    func gpuMonteCarloErrors() async throws {
        let bad = try await call(RunMonteCarloGPUTool(), gpu("random()"))
        #expect(bad.isError)
        #expect(bad.text
            == "Invalid arguments: calculation is not a valid formula. 'random' is not a supported function. Supported: abs, ceiling, cos, exp, floor, ln, log, log10, max, min, pow, sin, sqrt, tan, trunc.")

        let undefined = try await call(RunMonteCarloGPUTool(), gpu("1 / (demand - 10)"))
        #expect(undefined.isError)
        #expect(undefined.text
            == "Invalid arguments: calculation has no value at demand = 10.0. The formula divides by zero.")
    }

    // MARK: - What the schemas advertise

    @Test("Every formula argument's description states the real grammar",
          arguments: [
            ("newton_raphson_optimize", "formula"),
            ("gradient_descent_optimize", "formula"),
            ("goal_seek", "calculation"),
            ("run_monte_carlo", "calculation"),
            ("sensitivity_analysis", "calculation"),
            ("tornado_analysis", "calculation"),
            ("run_scenario_analysis", "calculation"),
            ("analyze_scenarios", "model"),
            ("run_correlated_monte_carlo", "calculation"),
            ("run_monte_carlo_gpu", "calculation"),
          ])
    func schemaStatesGrammar(toolName: String, argument: String) throws {
        let handlers: [any MCPToolHandler] = allToolHandlers() + getAdvancedSimulationTools()
        let handler = try #require(handlers.first { $0.tool.name == toolName })
        let property = try #require(handler.tool.inputSchema.properties?[argument])
        let description = try #require(property.description)
        #expect(description.contains(CallerFormula.syntaxSummary))
    }

    @Test("analyze_scenarios advertises names that are identifiers, and a model that uses them")
    func analyzeScenariosExample() throws {
        let tool = ScenarioAnalysisTool().tool
        let description = tool.description
        #expect(description.contains(#""inputNames": ["volume", "price", "margin"]"#))
        #expect(description.contains(#""model": "volume * price * (1 - margin)""#))
        #expect(!description.contains("Sales Volume"))

        let names = try #require(tool.inputSchema.properties?["inputNames"]?.description)
        #expect(names.contains(
            "Each name must be an identifier: a letter or underscore, then letters, digits and underscores."))
    }
}
