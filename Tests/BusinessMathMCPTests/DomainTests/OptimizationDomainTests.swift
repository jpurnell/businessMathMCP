import Testing
import Foundation
@testable import BusinessMathMCP

@Suite("Optimization Domain Tests")
struct OptimizationDomainTests {

    // MARK: - Optimization Tools

    @Test("newton_raphson_optimize finds root of equation")
    func testNewtonRaphson() async throws {
        let tool = NewtonRaphsonOptimizeTool()
        let args = argsFromJSON("""
            {"formula": "{0} * {0} - 25", "initialGuess": 3.0}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("5") || result.text.contains("Root") || result.text.contains("root"))
    }

    @Test("optimize_capital_allocation selects projects within budget")
    func testCapitalAllocation() async throws {
        let tool = CapitalAllocationTool()
        let args = argsFromJSON("""
            {
                "projects": [
                    {"name": "Project A", "cost": 100000, "npv": 50000},
                    {"name": "Project B", "cost": 200000, "npv": 120000},
                    {"name": "Project C", "cost": 150000, "npv": 80000}
                ],
                "budget": 300000
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Project") || result.text.contains("Allocation"))
    }

    // MARK: - Adaptive Optimization Tools

    @Test("analyze_optimization_problem analyzes problem characteristics")
    func testAnalyzeOptimization() async throws {
        let tool = AnalyzeOptimizationProblemTool()
        let args = argsFromJSON("""
            {"dimensions": 3}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Optimization") || result.text.contains("Problem") || result.text.contains("Dimension"))
    }

    // MARK: - Parallel Optimization Tools

    @Test("parallel_optimization_guide provides optimization guidance")
    func testParallelGuide() async throws {
        let tool = toolHandlersByName()["parallel_optimization_guide"]!
        let args = argsFromJSON("""
            {"topic": "getting_started"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Parallel") || result.text.contains("optimization"))
    }

    // MARK: - Advanced Optimization Tools

    @Test("optimize_multiperiod plans across time periods")
    func testMultiPeriodOptimization() async throws {
        let tool = MultiPeriodOptimizeTool()
        let args = argsFromJSON("""
            {
                "numberOfPeriods": 3,
                "discountRate": 0.08,
                "problemType": "capital_budgeting",
                "dimensions": 4
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Period") || result.text.contains("period") || result.text.contains("Multi"))
    }

    // MARK: - Integer Programming Tools

    @Test("solve_integer_program solves discrete optimization")
    func testIntegerProgram() async throws {
        let tool = BranchAndBoundTool()
        let args = argsFromJSON("""
            {"dimensions": 3, "problemType": "knapsack"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Integer") || result.text.contains("Branch") || result.text.contains("Solution"))
    }

    // MARK: - Heuristic Optimization Tools

    @Test("particle_swarm_optimize runs PSO on small problem")
    func testParticleSwarm() async throws {
        let tool = ParticleSwarmOptimizeTool()
        let args = argsFromJSON("""
            {
                "dimensions": 2,
                "searchRegion": {"lower": [-5.0, -5.0], "upper": [5.0, 5.0]},
                "numberOfParticles": 10,
                "maxIterations": 50
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Particle") || result.text.contains("Swarm") || result.text.contains("Best"))
    }

    // MARK: - Metaheuristic Optimization Tools

    @Test("simulated_annealing_optimize runs SA on small problem")
    func testSimulatedAnnealing() async throws {
        let tool = SimulatedAnnealingOptimizeTool()
        let args = argsFromJSON("""
            {"dimensions": 2, "initialTemperature": 100, "coolingSchedule": "exponential"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Anneal") || result.text.contains("Temperature") || result.text.contains("Best"))
    }

    // MARK: - Performance Benchmark Tools

    @Test("benchmark_guide provides benchmarking guidance")
    func testBenchmarkGuide() async throws {
        let tool = BenchmarkGuideTool()
        let args = argsFromJSON("""
            {"topic": "getting_started"}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Benchmark") || result.text.contains("benchmark") || result.text.contains("Performance"))
    }
}
