import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

// MARK: - Validation Function Tests

@Suite("Distribution Parameter Validation")
struct DistributionParameterValidationTests {

    // MARK: - Normal

    @Test("Normal: valid params don't throw")
    func normalValid() throws {
        try validateDistributionParameters(type: "normal", params: ["mean": 100, "stdDev": 20])
    }

    @Test("Normal: zero stdDev is valid (degenerate)")
    func normalZeroStdDev() throws {
        try validateDistributionParameters(type: "normal", params: ["mean": 0, "stdDev": 0])
    }

    @Test("Normal: negative stdDev throws")
    func normalNegativeStdDev() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "normal", params: ["mean": 0, "stdDev": -1])
        }
    }

    // MARK: - Uniform

    @Test("Uniform: valid params don't throw")
    func uniformValid() throws {
        try validateDistributionParameters(type: "uniform", params: ["min": 0, "max": 100])
    }

    @Test("Uniform: min >= max throws")
    func uniformMinGeMax() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "uniform", params: ["min": 100, "max": 100])
        }
    }

    @Test("Uniform: min > max throws")
    func uniformMinGtMax() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "uniform", params: ["min": 200, "max": 100])
        }
    }

    // MARK: - Triangular

    @Test("Triangular: valid params don't throw")
    func triangularValid() throws {
        try validateDistributionParameters(type: "triangular", params: ["min": 0, "max": 100, "mode": 50])
    }

    @Test("Triangular: mode at min is valid")
    func triangularModeAtMin() throws {
        try validateDistributionParameters(type: "triangular", params: ["min": 0, "max": 100, "mode": 0])
    }

    @Test("Triangular: mode at max is valid")
    func triangularModeAtMax() throws {
        try validateDistributionParameters(type: "triangular", params: ["min": 0, "max": 100, "mode": 100])
    }

    @Test("Triangular: min >= max throws")
    func triangularMinGeMax() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "triangular", params: ["min": 100, "max": 100, "mode": 100])
        }
    }

    @Test("Triangular: mode below min throws")
    func triangularModeBelowMin() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "triangular", params: ["min": 10, "max": 100, "mode": 5])
        }
    }

    @Test("Triangular: mode above max throws")
    func triangularModeAboveMax() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "triangular", params: ["min": 0, "max": 100, "mode": 150])
        }
    }

    // MARK: - LogNormal

    @Test("LogNormal: valid params don't throw")
    func lognormalValid() throws {
        try validateDistributionParameters(type: "lognormal", params: ["mean": 250000, "stdDev": 400000])
    }

    @Test("LogNormal: zero mean throws")
    func lognormalZeroMean() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "lognormal", params: ["mean": 0, "stdDev": 1])
        }
    }

    @Test("LogNormal: negative mean throws")
    func lognormalNegativeMean() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "lognormal", params: ["mean": -100, "stdDev": 50])
        }
    }

    @Test("LogNormal: negative stdDev throws")
    func lognormalNegativeStdDev() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "lognormal", params: ["mean": 100, "stdDev": -10])
        }
    }

    // MARK: - Exponential

    @Test("Exponential: valid rate doesn't throw")
    func exponentialValid() throws {
        try validateDistributionParameters(type: "exponential", params: ["rate": 0.5])
    }

    @Test("Exponential: zero rate throws")
    func exponentialZeroRate() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "exponential", params: ["rate": 0])
        }
    }

    @Test("Exponential: negative rate throws")
    func exponentialNegativeRate() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "exponential", params: ["rate": -1])
        }
    }

    // MARK: - Beta

    @Test("Beta: valid params don't throw")
    func betaValid() throws {
        try validateDistributionParameters(type: "beta", params: ["alpha": 2, "beta": 5])
    }

    @Test("Beta: zero alpha throws")
    func betaZeroAlpha() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "beta", params: ["alpha": 0, "beta": 5])
        }
    }

    @Test("Beta: negative beta throws")
    func betaNegativeBeta() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "beta", params: ["alpha": 2, "beta": -1])
        }
    }

    // MARK: - Gamma

    @Test("Gamma: valid params don't throw")
    func gammaValid() throws {
        try validateDistributionParameters(type: "gamma", params: ["shape": 3, "scale": 2])
    }

    @Test("Gamma: shape < 1 throws")
    func gammaShapeLessThanOne() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "gamma", params: ["shape": 0, "scale": 2])
        }
    }

    @Test("Gamma: zero scale throws")
    func gammaZeroScale() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "gamma", params: ["shape": 3, "scale": 0])
        }
    }

    // MARK: - Weibull

    @Test("Weibull: valid params don't throw")
    func weibullValid() throws {
        try validateDistributionParameters(type: "weibull", params: ["shape": 1.5, "scale": 100])
    }

    @Test("Weibull: zero shape throws")
    func weibullZeroShape() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "weibull", params: ["shape": 0, "scale": 100])
        }
    }

    @Test("Weibull: negative scale throws")
    func weibullNegativeScale() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "weibull", params: ["shape": 1.5, "scale": -1])
        }
    }

    // MARK: - Chi-Squared

    @Test("ChiSquared: valid df doesn't throw")
    func chiSquaredValid() throws {
        try validateDistributionParameters(type: "chisquared", params: ["degreesOfFreedom": 5])
    }

    @Test("ChiSquared: zero df throws")
    func chiSquaredZeroDf() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "chisquared", params: ["degreesOfFreedom": 0])
        }
    }

    @Test("ChiSquared: negative df throws")
    func chiSquaredNegativeDf() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "chisquared", params: ["degreesOfFreedom": -3])
        }
    }

    // MARK: - F Distribution

    @Test("F: valid params don't throw")
    func fValid() throws {
        try validateDistributionParameters(type: "f", params: ["df1": 5, "df2": 10])
    }

    @Test("F: zero df1 throws")
    func fZeroDf1() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "f", params: ["df1": 0, "df2": 10])
        }
    }

    @Test("F: negative df2 throws")
    func fNegativeDf2() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "f", params: ["df1": 5, "df2": -1])
        }
    }

    // MARK: - T Distribution

    @Test("T: valid df doesn't throw")
    func tValid() throws {
        try validateDistributionParameters(type: "t", params: ["degreesOfFreedom": 30])
    }

    @Test("T: zero df throws")
    func tZeroDf() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "t", params: ["degreesOfFreedom": 0])
        }
    }

    // MARK: - Pareto

    @Test("Pareto: valid params don't throw")
    func paretoValid() throws {
        try validateDistributionParameters(type: "pareto", params: ["scale": 1, "shape": 2])
    }

    @Test("Pareto: zero scale throws")
    func paretoZeroScale() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "pareto", params: ["scale": 0, "shape": 2])
        }
    }

    @Test("Pareto: negative shape throws")
    func paretoNegativeShape() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "pareto", params: ["scale": 1, "shape": -1])
        }
    }

    // MARK: - Logistic

    @Test("Logistic: valid params don't throw")
    func logisticValid() throws {
        try validateDistributionParameters(type: "logistic", params: ["mean": 0, "stdDev": 1])
    }

    @Test("Logistic: zero stdDev throws")
    func logisticZeroStdDev() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "logistic", params: ["mean": 0, "stdDev": 0])
        }
    }

    @Test("Logistic: negative stdDev throws")
    func logisticNegativeStdDev() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "logistic", params: ["mean": 0, "stdDev": -1])
        }
    }

    // MARK: - Geometric

    @Test("Geometric: valid p doesn't throw")
    func geometricValid() throws {
        try validateDistributionParameters(type: "geometric", params: ["p": 0.5])
    }

    @Test("Geometric: p = 1 is valid")
    func geometricPOne() throws {
        try validateDistributionParameters(type: "geometric", params: ["p": 1.0])
    }

    @Test("Geometric: p = 0 throws")
    func geometricPZero() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "geometric", params: ["p": 0])
        }
    }

    @Test("Geometric: p > 1 throws")
    func geometricPGreaterThanOne() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "geometric", params: ["p": 1.5])
        }
    }

    @Test("Geometric: negative p throws")
    func geometricNegativeP() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "geometric", params: ["p": -0.5])
        }
    }

    // MARK: - Rayleigh

    @Test("Rayleigh: valid mean doesn't throw")
    func rayleighValid() throws {
        try validateDistributionParameters(type: "rayleigh", params: ["mean": 10])
    }

    @Test("Rayleigh: zero mean throws")
    func rayleighZeroMean() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "rayleigh", params: ["mean": 0])
        }
    }

    @Test("Rayleigh: negative mean throws")
    func rayleighNegativeMean() throws {
        #expect(throws: ToolError.self) {
            try validateDistributionParameters(type: "rayleigh", params: ["mean": -5])
        }
    }

    // MARK: - Unknown type passes through

    @Test("Unknown distribution type doesn't throw from validator")
    func unknownTypePassesThrough() throws {
        try validateDistributionParameters(type: "unknown_dist", params: [:])
    }
}

// MARK: - Integration Tests via Tool Execution

@Suite("Distribution Validation Integration")
struct DistributionValidationIntegrationTests {

    @Test("create_distribution rejects negative stdDev")
    func createDistributionNegativeStdDev() async throws {
        let tool = CreateDistributionTool()
        let args = try decodeArguments("""
        {"type": "normal", "parameters": {"mean": 100, "stdDev": -10}, "sampleSize": 100}
        """)
        await #expect(throws: ToolError.self) {
            try await tool.execute(arguments: args)
        }
    }

    @Test("run_monte_carlo rejects beta with alpha=0")
    func monteCarloRejectsBetaAlphaZero() async throws {
        let tool = RunMonteCarloTool()
        let args = try decodeArguments("""
        {
            "inputs": [{"name": "X", "distribution": "beta", "parameters": {"alpha": 0, "beta": 5}}],
            "calculation": "{0}",
            "iterations": 100
        }
        """)
        await #expect(throws: ToolError.self) {
            try await tool.execute(arguments: args)
        }
    }

    @Test("run_monte_carlo rejects chi-squared with df=0")
    func monteCarloRejectsChiSquaredDfZero() async throws {
        let tool = RunMonteCarloTool()
        let args = try decodeArguments("""
        {
            "inputs": [{"name": "X", "distribution": "chisquared", "parameters": {"degreesOfFreedom": 0}}],
            "calculation": "{0}",
            "iterations": 100
        }
        """)
        await #expect(throws: ToolError.self) {
            try await tool.execute(arguments: args)
        }
    }

    @Test("run_monte_carlo with valid lognormal(250000, 400000) succeeds")
    func monteCarloLognormalLargeParams() async throws {
        let tool = RunMonteCarloTool()
        let args = try decodeArguments("""
        {
            "inputs": [{"name": "Calls", "distribution": "lognormal", "parameters": {"mean": 250000, "stdDev": 400000}}],
            "calculation": "{0} * 0.799 - 97000",
            "iterations": 100
        }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError, "Valid lognormal should succeed")
        #expect(result.text.contains("Mean") || result.text.contains("Median"))
    }

    @Test("create_distribution rejects geometric p > 1")
    func createDistributionRejectsGeometricP() async throws {
        let tool = CreateDistributionTool()
        let args = try decodeArguments("""
        {"type": "geometric", "parameters": {"p": 1.5}, "sampleSize": 100}
        """)
        await #expect(throws: ToolError.self) {
            try await tool.execute(arguments: args)
        }
    }
}
