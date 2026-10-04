import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// `Int(x)` stops the process when `x` is NaN, infinite or too large for an `Int`, and several
/// tools converted a number that came straight from a caller's argument, or from arithmetic on
/// one. Each of those is now either refused where the argument is read — with a message naming
/// the argument and the range it accepts — or computed without the conversion.
@Suite("Int conversions of caller-supplied numbers")
struct IntConversionGuardTests {

    private func call(
        _ handler: any MCPToolHandler, _ arguments: [String: MCP.Value]
    ) async throws -> (text: String, isError: Bool) {
        let registry = ToolDefinitionRegistry()
        try await registry.register(handler.toToolDefinition())
        let result = try await registry.executeTool(name: handler.tool.name, arguments: arguments)
        guard case .text(let text, _, _) = result.content.first else {
            throw MCPTestError.unexpectedResult("no text content")
        }
        return (text, result.isError ?? false)
    }

    private func call(
        _ handler: any MCPToolHandler, _ json: String
    ) async throws -> (text: String, isError: Bool) {
        let value = try JSONDecoder().decode(MCP.Value.self, from: Data(json.utf8))
        guard case .object(let arguments) = value else {
            throw MCPTestError.decodingFailed("arguments must be a JSON object")
        }
        return try await call(handler, arguments)
    }

    // MARK: - Genetic algorithm

    @Test("A crossover rate that is not a probability is refused",
          arguments: [-0.1, 1.5, 1e300, Double.nan, Double.infinity])
    func crossoverRateOutOfRange(rate: Double) async throws {
        let result = try await call(GeneticAlgorithmOptimizeTool(), [
            "dimensions": .int(10), "encoding": .string("binary"), "crossoverRate": .double(rate),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: crossoverRate must be a probability from 0 to 1")
    }

    @Test("A mutation rate that is not a probability is refused",
          arguments: [-0.1, 2, 1e300, Double.nan, Double.infinity])
    func mutationRateOutOfRange(rate: Double) async throws {
        let result = try await call(GeneticAlgorithmOptimizeTool(), [
            "dimensions": .int(10), "encoding": .string("binary"), "mutationRate": .double(rate),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: mutationRate must be a probability from 0 to 1")
    }

    @Test("An ordinary genetic algorithm reads as it did")
    func geneticAlgorithmUnchanged() async throws {
        let result = try await call(GeneticAlgorithmOptimizeTool(), """
            {"dimensions": 10, "encoding": "binary", "crossoverRate": 0.8, "mutationRate": 0.02}
            """)
        #expect(!result.isError)
        #expect(result.text.contains(
            "- Crossover rate: 0.80 (80% of offspring via recombination)\n"))
        #expect(result.text.contains("3. CROSSOVER (80% probability)\n"))
        #expect(result.text.contains(
            "- With population 100, expect ~20 mutations per generation"))
    }

    // MARK: - Particle swarm

    @Test("An inertia weight that is not a number is refused",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func inertiaWeightNotFinite(weight: Double) async throws {
        let result = try await call(ParticleSwarmOptimizeTool(), [
            "dimensions": .int(2),
            "searchRegion": .object(["lower": .array([.int(0), .int(0)]),
                                     "upper": .array([.int(1), .int(1)])]),
            "inertiaWeight": .double(weight),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: inertiaWeight must be a finite number")
    }

    // MARK: - Simulated annealing

    @Test("A cooling rate outside (0, 1) is refused", arguments: [-0.5, 0, 1.5, Double.nan])
    func coolingRateOutOfRange(rate: Double) async throws {
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .int(1000),
            "coolingSchedule": .string("exponential"), "coolingRate": .double(rate),
        ])
        #expect(result.isError)
        #expect(result.text
                == "Invalid arguments: coolingRate must be a number greater than 0 and less than 1")
    }

    @Test("A final temperature that is not below the initial one is refused",
          arguments: [1000, 5000, 0, -1, Double.nan])
    func finalTemperatureOutOfRange(temperature: Double) async throws {
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .int(1000),
            "coolingSchedule": .string("linear"), "finalTemperature": .double(temperature),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: finalTemperature must be a number "
                + "greater than 0 and less than initialTemperature")
    }

    @Test("An ordinary annealing schedule counts its steps as it did")
    func annealingUnchanged() async throws {
        let result = try await call(SimulatedAnnealingOptimizeTool(), """
            {"dimensions": 10, "initialTemperature": 1000, "coolingSchedule": "exponential"}
            """)
        #expect(!result.isError)
        // ceil(log(0.01 / 1000) / log(0.95)) = 225
        #expect(result.text.contains("- Estimated temperature steps: ~225\n"))
        #expect(result.text.contains("- Total iterations: ~22500 (max: 10000)\n"))
        #expect(result.text.contains("- Cooling rate (α): 0.950 ← Standard cooling rate\n"))
    }

    // MARK: - Differential evolution

    private static let deRegion: MCP.Value = .object([
        "lower": .array([.int(0), .int(0)]), "upper": .array([.int(1), .int(1)]),
    ])

    @Test("A differential weight outside 0...2 is refused",
          arguments: [-0.1, 2.5, Double.nan, Double.infinity])
    func differentialWeightOutOfRange(weight: Double) async throws {
        let result = try await call(DifferentialEvolutionOptimizeTool(), [
            "dimensions": .int(2), "searchRegion": Self.deRegion,
            "differentialWeight": .double(weight),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: differentialWeight must be a number from 0 to 2")
    }

    @Test("A DE crossover rate that is not a probability is refused",
          arguments: [-0.1, 1.5, Double.nan])
    func differentialCrossoverOutOfRange(rate: Double) async throws {
        let result = try await call(DifferentialEvolutionOptimizeTool(), [
            "dimensions": .int(2), "searchRegion": Self.deRegion, "crossoverRate": .double(rate),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: crossoverRate must be a probability from 0 to 1")
    }

    // MARK: - Hazard rate

    @Test("A negative time horizon is refused")
    func negativeTimeHorizon() async throws {
        let result = try await call(HazardRateAnalysisTool(), """
            {"hazardRate": 0.02, "timeHorizon": -1}
            """)
        #expect(result.isError)
        #expect(result.text
                == "Invalid arguments: timeHorizon must be a number of years from 0 to 100")
    }

    @Test("An ordinary hazard analysis reads as it did")
    func hazardUnchanged() async throws {
        let result = try await call(HazardRateAnalysisTool(), """
            {"hazardRate": 0.02, "timeHorizon": 5}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("| 1Y | "))
        #expect(result.text.contains("| 10Y | "))
        #expect(result.text.contains("- 5Y Survival: "))
        #expect(result.text.contains("- Expected Loss (5Y): "))
    }

    // MARK: - Distributions

    @Test("A gamma shape beyond a million is refused")
    func gammaShapeTooLarge() async throws {
        let result = try await call(CreateDistributionTool(), """
            {"type": "gamma", "parameters": {"shape": 2000000, "scale": 1}, "sampleSize": 1}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: Gamma shape must be a number from 1 to 1000000")
    }

    @Test("Degrees of freedom beyond a million are refused")
    func degreesOfFreedomTooLarge() async throws {
        let chi = try await call(CreateDistributionTool(), """
            {"type": "chisquared", "parameters": {"degreesOfFreedom": 2000000}, "sampleSize": 1}
            """)
        #expect(chi.isError)
        #expect(chi.text == "Invalid arguments: Chi-Squared degreesOfFreedom must be "
                + "a number from 1 to 1000000")

        let student = try await call(CreateDistributionTool(), """
            {"type": "t", "parameters": {"degreesOfFreedom": 2000000}, "sampleSize": 1}
            """)
        #expect(student.isError)
        #expect(student.text == "Invalid arguments: T distribution degreesOfFreedom must be "
                + "a number from 1 to 1000000")

        let first = try await call(CreateDistributionTool(), """
            {"type": "f", "parameters": {"df1": 2000000, "df2": 5}, "sampleSize": 1}
            """)
        #expect(first.isError)
        #expect(first.text
                == "Invalid arguments: F distribution df1 must be a number from 1 to 1000000")

        let second = try await call(CreateDistributionTool(), """
            {"type": "f", "parameters": {"df1": 5, "df2": 2000000}, "sampleSize": 1}
            """)
        #expect(second.isError)
        #expect(second.text
                == "Invalid arguments: F distribution df2 must be a number from 1 to 1000000")
    }

    // MARK: - Sample size

    @Test("An ordinary sample size reads as it did")
    func sampleSizeUnchanged() async throws {
        let result = try await call(CalculateSampleSizeTool(), """
            {"confidence": 0.95, "marginOfError": 0.05, "proportion": 0.5, "populationSize": 10000}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("- **Required Sample Size: 370**\n"))
        #expect(result.text.contains("You need to collect 370 responses to achieve"))
        #expect(result.text.contains("• Recommended target: 426 (with 15% buffer)"))
    }

    // MARK: - Inputs that used to stop the process
    //
    // None of these could be seen failing: before the fix each one trapped inside `Int(_:)`
    // (or inside a `Range` initialiser) and took the test process down with it.

    @Test("A genetic algorithm too large to count its mutations in an Int is still described")
    func mutationCountBeyondInt() async throws {
        let result = try await call(GeneticAlgorithmOptimizeTool(), """
            {"dimensions": 100000000000000000, "encoding": "binary", "populationSize": 100,
             "mutationRate": 1}
            """)
        #expect(!result.isError)
        // 1 × 1e17 × 100 = 1e19, past Int.max (about 9.22e18).
        #expect(result.text.contains(
            "- With population 100, expect ~10000000000000000000 mutations per generation"))
    }

    @Test("A cooling schedule that never cools is refused", arguments: [1, 1e300, Double.infinity])
    func coolingRateOfOneOrMore(rate: Double) async throws {
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .int(1000),
            "coolingSchedule": .string("exponential"), "coolingRate": .double(rate),
        ])
        #expect(result.isError)
        #expect(result.text
                == "Invalid arguments: coolingRate must be a number greater than 0 and less than 1")
    }

    @Test("An initial temperature that is not positive is refused",
          arguments: [0, -5, Double.nan, Double.infinity])
    func initialTemperatureOutOfRange(temperature: Double) async throws {
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .double(temperature),
            "coolingSchedule": .string("exponential"),
        ])
        #expect(result.isError)
        #expect(result.text
                == "Invalid arguments: initialTemperature must be a number greater than 0")
    }

    @Test("A cooling rate within an ulp of 1 needs more steps than can be counted")
    func temperatureStepsBeyondInt() async throws {
        // log(5e-324 / 1e308) / log(1 − 2⁻⁵³) is about 1.3e19, past Int.max.
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .double(1e308),
            "coolingSchedule": .string("exponential"), "finalTemperature": .double(5e-324),
            "coolingRate": .double(1.0.nextDown),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: the temperature schedule needs more steps "
                + "than can be counted: lower coolingRate or raise finalTemperature")
    }

    @Test("Total iterations past Int.max are refused")
    func totalIterationsBeyondInt() async throws {
        // 225 temperature steps × Int.max iterations at each.
        let result = try await call(SimulatedAnnealingOptimizeTool(), [
            "dimensions": .int(10), "initialTemperature": .int(1000),
            "coolingSchedule": .string("exponential"), "iterationsPerTemperature": .int(Int.max),
        ])
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: iterationsPerTemperature is too large: "
                + "the schedule's total iterations cannot be counted")
    }

    @Test("A time horizon beyond a century is refused", arguments: [100.5, 1e300])
    func timeHorizonTooLong(years: Double) async throws {
        let result = try await call(HazardRateAnalysisTool(), [
            "hazardRate": .double(0.02), "timeHorizon": .double(years),
        ])
        #expect(result.isError)
        #expect(result.text
                == "Invalid arguments: timeHorizon must be a number of years from 0 to 100")
    }

    @Test("A whole-number distribution parameter that is no number an Int holds is refused",
          arguments: [1e300, Double.nan, Double.infinity])
    func wholeParameterNotRepresentable(value: Double) async throws {
        let gamma = try await call(CreateDistributionTool(), [
            "type": .string("gamma"), "sampleSize": .int(1),
            "parameters": .object(["shape": .double(value), "scale": .int(1)]),
        ])
        #expect(gamma.isError)
        #expect(gamma.text == "Invalid arguments: Gamma shape must be a number from 1 to 1000000")

        let chi = try await call(CreateDistributionTool(), [
            "type": .string("chisquared"), "sampleSize": .int(1),
            "parameters": .object(["degreesOfFreedom": .double(value)]),
        ])
        #expect(chi.isError)
        #expect(chi.text == "Invalid arguments: Chi-Squared degreesOfFreedom must be "
                + "a number from 1 to 1000000")

        let student = try await call(CreateDistributionTool(), [
            "type": .string("t"), "sampleSize": .int(1),
            "parameters": .object(["degreesOfFreedom": .double(value)]),
        ])
        #expect(student.isError)
        #expect(student.text == "Invalid arguments: T distribution degreesOfFreedom must be "
                + "a number from 1 to 1000000")

        let fisher = try await call(CreateDistributionTool(), [
            "type": .string("f"), "sampleSize": .int(1),
            "parameters": .object(["df1": .int(5), "df2": .double(value)]),
        ])
        #expect(fisher.isError)
        #expect(fisher.text
                == "Invalid arguments: F distribution df2 must be a number from 1 to 1000000")
    }

    @Test("A simulation input with degrees of freedom no Int holds is refused")
    func simulationInputNotRepresentable() async throws {
        let result = try await call(RunMonteCarloTool(), """
            {"inputs": [{"name": "X", "distribution": "t",
                         "parameters": {"degreesOfFreedom": 1e300}}],
             "calculation": "{0}", "iterations": 10}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: T distribution degreesOfFreedom must be "
                + "a number from 1 to 1000000")
    }

    @Test("A sample too large to count is refused")
    func sampleSizeBeyondInt() async throws {
        // z² · p(1 − p) / margin² is about 1e300 responses, and the population allows it.
        let result = try await call(CalculateSampleSizeTool(), """
            {"confidence": 0.95, "marginOfError": 1e-150, "proportion": 0.5,
             "populationSize": 1e308}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: confidence, marginOfError and populationSize "
                + "ask for a sample too large to count")
    }

    @Test("Values too far apart to bin are refused")
    func histogramSpreadNotFinite() async throws {
        let result = try await call(AnalyzeSimulationResultsTool(), """
            {"values": [-1e308, 1e308]}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: values must be finite numbers whose spread "
                + "(max - min) is also a finite number")
    }

    @Test("A tornado in which no variable moves the output draws no bars")
    func tornadoWithoutImpact() async throws {
        let result = try await call(TornadoAnalysisTool(), """
            {"variables": [{"name": "Rate", "baseValue": 5, "lowValue": 5, "highValue": 5}],
             "calculation": "{0} * 2"}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("""
            1. Rate
               Low:  10.00  \n   High: 10.00
               Range: 0.00 (
            """))
    }

    @Test("Tornado outputs further apart than a Double holds are refused")
    func tornadoRangeNotFinite() async throws {
        let result = try await call(TornadoAnalysisTool(), """
            {"variables": [{"name": "Rate", "baseValue": 0, "lowValue": -1e308, "highValue": 1e308}],
             "calculation": "{0}"}
            """)
        #expect(result.isError)
        #expect(result.text == "Invalid arguments: calculation gives outputs for 'Rate' whose "
                + "difference (high - low) is not a finite number")
    }
}
