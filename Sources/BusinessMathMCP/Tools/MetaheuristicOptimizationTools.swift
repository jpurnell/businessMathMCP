import Foundation
import MCP
import SwiftMCPServer
import BusinessMath

// MARK: - Simulated Annealing Tool

public struct SimulatedAnnealingOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "simulated_annealing_optimize",
        description: """
        Global optimization using Simulated Annealing (SA). Inspired by the metallurgical annealing process, SA probabilistically accepts worse solutions to escape local minima.

        Perfect for:
        - Traveling Salesman Problem (TSP)
        - VLSI circuit design and layout
        - Protein folding and molecular design
        - Job shop scheduling
        - Discrete combinatorial optimization
        - Graph coloring and partitioning

        How SA Works:
        - Starts at high "temperature" accepting many worse solutions (exploration)
        - Gradually "cools down" becoming more selective (exploitation)
        - Accepts worse solution with probability exp(-ΔE/T)
        - Eventually "freezes" at low temperature, converging to solution
        - Theoretical guarantee of finding global optimum (with right schedule)

        Example: TSP with 50 cities
        - initialTemperature: 1000
        - coolingSchedule: "exponential"
        - coolingRate: 0.95
        - maxIterations: 10000

        Returns implementation guidance with Swift code and cooling schedule analysis.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Problem size (e.g., number of cities in TSP)"
                ),
                "initialTemperature": MCPSchemaProperty(
                    type: "number",
                    description: "Starting temperature (high value, 100-10000). Higher = more initial exploration"
                ),
                "finalTemperature": MCPSchemaProperty(
                    type: "number",
                    description: "Ending temperature (low value, 0.01-1.0). When to stop. Default: 0.01"
                ),
                "coolingSchedule": MCPSchemaProperty(
                    type: "string",
                    description: "Temperature reduction strategy",
                    enum: ["exponential", "linear", "logarithmic", "geometric"]
                ),
                "coolingRate": MCPSchemaProperty(
                    type: "number",
                    description: "For exponential: α in T = T₀ × α^k (0.8-0.99). Default: 0.95"
                ),
                "iterationsPerTemperature": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of iterations at each temperature level. Default: 100"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "integer",
                    description: "Total iteration limit (safety). Default: 10000"
                ),
                "neighborhoodType": MCPSchemaProperty(
                    type: "string",
                    description: "How to generate neighbor solutions",
                    enum: ["swap", "insert", "reverse", "perturbation"]
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Problem hint for guidance",
                    enum: ["tsp", "scheduling", "layout", "partitioning", "continuous", "general"]
                )
            ],
            required: ["dimensions", "initialTemperature", "coolingSchedule"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dimensions = try args.getInt("dimensions")
        let initialTemp = try args.getDouble("initialTemperature")
        let coolingSchedule = try args.getString("coolingSchedule")
        let finalTemp = args.getDoubleOptional("finalTemperature") ?? 0.01
        let coolingRate = args.getDoubleOptional("coolingRate") ?? 0.95
        let itersPerTemp = args.getIntOptional("iterationsPerTemperature") ?? 100
        let maxIterations = args.getIntOptional("maxIterations") ?? 10000
        let neighborhoodType = args.getStringOptional("neighborhoodType") ?? "swap"
        let problemType = args.getStringOptional("problemType") ?? "general"

        let totalTemperatureSteps = estimateTemperatureSteps(initial: initialTemp, final: finalTemp, rate: coolingRate, schedule: coolingSchedule)

        let guide = """
        🌡️ **Simulated Annealing (SA) Optimization**

        **Problem Configuration:**
        - Problem size: \(dimensions)
        - Problem type: \(problemType)
        - Neighborhood: \(neighborhoodType)

        **Temperature Schedule:**
        - Initial temperature (T₀): \(String(format: "%.1f", initialTemp)) \(explainTemperature(initialTemp, type: "initial"))
        - Final temperature (Tf): \(String(format: "%.4f", finalTemp))
        - Cooling schedule: \(coolingSchedule)
        - Cooling rate (α): \(String(format: "%.3f", coolingRate)) \(explainCoolingRate(coolingRate, schedule: coolingSchedule))
        - Iterations per temperature: \(itersPerTemp)
        - Estimated temperature steps: ~\(totalTemperatureSteps)
        - Total iterations: ~\(totalTemperatureSteps * itersPerTemp) (max: \(maxIterations))

        **How Simulated Annealing Works:**

        **The Annealing Metaphor:**
        ```
        Metallurgy:
        1. Heat metal to high temperature (atoms move freely)
        2. Slowly cool down (atoms settle into low-energy configuration)
        3. Result: Strong crystalline structure (global minimum energy)

        Optimization:
        1. Start at high T (accept many worse solutions)
        2. Slowly cool (become more selective)
        3. Result: High-quality solution (near global optimum)
        ```

        **SA Algorithm:**
        ```
        1. INITIALIZATION
           current_solution = random_solution()
           best_solution = current_solution
           T = \(initialTemp)  // High temperature

        2. MAIN LOOP (while T > \(finalTemp))
           Repeat \(itersPerTemp) times at current T:

             a) Generate neighbor solution
                neighbor = \(neighborhoodType)(current_solution)

             b) Calculate energy difference
                ΔE = energy(neighbor) - energy(current)

             c) Acceptance decision
                if ΔE < 0:  // Better solution
                   current = neighbor  // Always accept
                   if energy(neighbor) < energy(best):
                      best = neighbor

                else:  // Worse solution
                   probability = exp(-ΔE / T)
                   if random() < probability:
                      current = neighbor  // Probabilistically accept

           d) Cool down
              T = \(getCoolingFormula(schedule: coolingSchedule, rate: coolingRate))

        3. RETURN best_solution
        ```

        **Acceptance Probability:**
        ```
        P(accept worse) = exp(-ΔE / T)

        At T = \(initialTemp) (hot):
          ΔE = 10  → P = exp(-10/\(initialTemp)) = \(String(format: "%.4f", exp(-10.0/initialTemp)))  ← High acceptance
          ΔE = 100 → P = exp(-100/\(initialTemp)) = \(String(format: "%.4f", exp(-100.0/initialTemp)))

        At T = 1.0 (cool):
          ΔE = 10  → P = exp(-10/1) = \(String(format: "%.4f", exp(-10.0)))  ← Low acceptance
          ΔE = 100 → P = exp(-100/1) ≈ 0.0000...  ← Almost never

        As T → 0: Only better solutions accepted (like greedy hill climbing)
        ```

        **Swift Implementation:**
        """

        // Add Swift code implementation
        let swiftCode = """

        import BusinessMath

        // Create SA optimizer
        let sa = SimulatedAnnealingOptimizer<\(getSolutionType(problemType: problemType))>(
            initialTemperature: \(initialTemp),
            finalTemperature: \(finalTemp),
            coolingSchedule: .\(coolingSchedule),
            coolingRate: \(coolingRate),
            iterationsPerTemperature: \(itersPerTemp),
            maxIterations: \(maxIterations)
        )

        \(getNeighborSetup(problemType: problemType, neighborhoodType: neighborhoodType, dimensions: dimensions))

        // Define energy function (to MINIMIZE - lower is better)
        let energy: @Sendable (\(getSolutionType(problemType: problemType))) -> Double = { solution in
            \(getEnergyExample(problemType: problemType))
        }

        // Define neighbor generation
        let generateNeighbor: @Sendable (\(getSolutionType(problemType: problemType))) -> \(getSolutionType(problemType: problemType)) = { current in
            \(getNeighborExample(problemType: problemType, neighborhoodType: neighborhoodType))
        }

        // Run SA
        let result = try await sa.optimize(
            energy: energy,
            generateNeighbor: generateNeighbor,
            initialSolution: \(getInitialSolution(problemType: problemType))
        )

        // Analyze results
        print("Best solution: \\(result.bestSolution)")
        print("Best energy: \\(result.bestEnergy)")
        print("Final temperature: \\(result.finalTemperature)")
        print("Total iterations: \\(result.iterations)")
        print("Acceptance ratio: \\(String(format: "%.2f%%", result.acceptanceRatio * 100))")

        // Cooling curve
        print("\\nCooling history:")
        for (step, temp, energy) in result.coolingHistory {
            print("Step \\(step): T=\\(String(format: "%.2f", temp)), E=\\(String(format: "%.2f", energy))")
        }
        """

        let continuedGuide = """

        **Cooling Schedules:**

        \(getCoolingScheduleComparison(currentSchedule: coolingSchedule))

        **Current Schedule: \(coolingSchedule)**
        \(getCoolingScheduleAnalysis(schedule: coolingSchedule, initialTemp: initialTemp, finalTemp: finalTemp, rate: coolingRate, steps: totalTemperatureSteps))

        **Neighborhood Functions:**

        \(getNeighborhoodComparison(problemType: problemType))

        **Current: \(neighborhoodType)**
        \(getNeighborhoodAnalysis(neighborhoodType: neighborhoodType, problemType: problemType))

        **Parameter Tuning Guide:**

        \(getSATuningGuide(problemType: problemType, initialTemp: initialTemp, coolingRate: coolingRate, itersPerTemp: itersPerTemp))

        **Problem-Specific Guidance:**

        \(getProblemGuidanceSA(problemType: problemType))

        **When to Use SA:**
        ✅ **Good for:**
        - Discrete/combinatorial optimization (TSP, scheduling)
        - When stuck in local minima with other methods
        - Problems with complex energy landscapes
        - When theoretical convergence guarantees desired
        - VLSI design, layout problems
        - Graph problems (coloring, partitioning)

        ❌ **Not ideal for:**
        - Simple convex problems (use gradient descent)
        - Continuous optimization with gradients available (use PSO or gradient methods)
        - When speed is critical (SA is slow)
        - Very high-dimensional continuous problems (>1000 vars)
        - Real-time optimization

        **SA vs Other Algorithms:**

        | Algorithm | Best For | Convergence | Speed | Theory |
        |-----------|----------|-------------|-------|--------|
        | Simulated Annealing | Discrete, combinatorial | Guaranteed (slow cooling) | Slow | Strong |
        | Genetic Algorithm | Combinatorial | Good | Medium | Empirical |
        | PSO | Continuous | Good | Fast | Empirical |
        | Hill Climbing | Local search | Local only | Very fast | None |
        | Tabu Search | Combinatorial | Good | Medium | Heuristic |

        **Troubleshooting:**

        **Problem: Poor solutions**
        - Initial temperature too low (increase to \(initialTemp * 2))
        - Cooling too fast (reduce cooling rate to \(coolingRate * 0.9))
        - Not enough iterations per temperature (increase to \(itersPerTemp * 2))
        - Try different cooling schedule

        **Problem: Too slow / not converging**
        - Initial temperature too high
        - Cooling too slow (increase cooling rate to \(min(0.99, coolingRate * 1.1)))
        - Too many iterations per temperature
        - Set lower final temperature to stop sooner

        **Problem: Getting stuck in local minimum**
        - This is what SA is supposed to prevent!
        - Initial temperature may be too low
        - Cooling rate may be too high (cooling too fast)
        - Need longer equilibration at each temperature

        **Problem: Accepting too many worse solutions**
        - Temperature still too high
        - Energy differences may be too small
        - Try scaling energy function

        **Advanced Techniques:**

        **Adaptive Cooling:**
        Instead of fixed schedule, adapt based on acceptance ratio:
        - If acceptance ratio > 0.8: Cool faster (T = α₁ × T, α₁ = 0.9)
        - If acceptance ratio < 0.2: Cool slower (T = α₂ × T, α₂ = 0.995)

        **Reheating:**
        If stuck, occasionally increase temperature:
        - Detect plateau in best energy
        - Reheat: T = T × 1.5
        - Continue from there

        **Very Fast SA:**
        Use Cauchy distribution for perturbations:
        - T(k) = T₀ / k (faster than exponential)
        - Good for quick approximate solutions

        **Threshold Accepting:**
        Deterministic variant:
        - Accept if ΔE < threshold
        - Gradually decrease threshold
        - Faster than probabilistic SA

        **Performance Expectations:**

        | Problem Size | Iterations | Time Estimate | Solution Quality |
        |--------------|-----------|---------------|------------------|
        | \(dimensions) | \(totalTemperatureSteps * itersPerTemp) | \(estimateSATime(problemType: problemType, iterations: totalTemperatureSteps * itersPerTemp)) | \(estimateQuality(coolingRate: coolingRate)) |
        | TSP 50 cities | 100,000 | 5-30s | 1-3% from optimal |
        | TSP 100 cities | 500,000 | 30-180s | 2-5% from optimal |
        | Scheduling 200 jobs | 1,000,000 | 60-300s | Good (no exact optimal known) |

        **Convergence Indicators:**
        - **Acceptance Ratio:** Should start high (0.8-0.9), end low (< 0.1)
        - **Energy:** Should decrease (with some uphill moves early)
        - **Temperature:** Should smoothly decrease from \(initialTemp) to \(finalTemp)
        - **Best Energy:** Should improve throughout run

        **Real-World Example - TSP:**
        Given: 50 cities, find shortest tour

        Configuration:
        - Initial T: 1000 (accept tours ~100% longer)
        - Cooling: Exponential, α = 0.95
        - Iterations per T: 100
        - Neighborhood: 2-opt (reverse segment)

        Typical run:
        - Iteration 0: Random tour, length = 5000
        - Iteration 1000 (T=500): Improved to 3500, accepting 70% of worse
        - Iteration 5000 (T=100): Length = 2800, accepting 40% of worse
        - Iteration 10000 (T=20): Length = 2500, accepting 10% of worse
        - Iteration 20000 (T=1): Length = 2450, accepting 1% of worse
        - Final (T=0.01): Length = 2445 (within 2% of optimal)

        **Next Steps:**
        1. Implement energy function and neighbor generation
        2. Start with recommended temperature schedule
        3. Run and monitor acceptance ratio and energy
        4. Tune cooling schedule if convergence not satisfactory
        5. Try different neighborhood functions
        6. Consider hybrid: SA for global search + local optimizer for refinement

        **Resources:**
        - Classic: Kirkpatrick et al. (1983) "Optimization by Simulated Annealing"
        - Tutorial: SA for Combinatorial Optimization
        - Example: TSP solving with SA
        - API Reference: SimulatedAnnealingOptimizer.swift
        - Benchmarks: SA on standard test problems
        """

        return .success(text: guide + swiftCode + continuedGuide)
    }

    // MARK: - Helper Functions

    private func estimateTemperatureSteps(initial: Double, final: Double, rate: Double, schedule: String) -> Int {
        switch schedule {
        case "exponential", "geometric":
            // T_k = T_0 × α^k
            // Solve: T_f = T_0 × α^k for k
            return Int(ceil(log(final / initial) / log(rate)))
        case "linear":
            // Rough estimate
            return Int(ceil((initial - final) / (initial * (1 - rate))))
        case "logarithmic":
            return 100 // Typical
        default:
            return 100
        }
    }

    private func explainTemperature(_ temp: Double, type: String) -> String {
        if type == "initial" {
            if temp > 1000 {
                return "← Very high (aggressive exploration)"
            } else if temp > 100 {
                return "← High (good exploration)"
            } else {
                return "← May be too low for good exploration"
            }
        }
        return ""
    }

    private func explainCoolingRate(_ rate: Double, schedule: String) -> String {
        guard schedule == "exponential" || schedule == "geometric" else {
            return ""
        }

        if rate > 0.98 {
            return "← Very slow cooling (thorough but slow)"
        } else if rate > 0.90 {
            return "← Standard cooling rate"
        } else if rate > 0.80 {
            return "← Fast cooling"
        } else {
            return "← Very fast (may converge prematurely)"
        }
    }

    private func getCoolingFormula(schedule: String, rate: Double) -> String {
        switch schedule {
        case "exponential", "geometric":
            return "T × \(rate)  // T_{k+1} = \(rate) × T_k"
        case "linear":
            return "T - ΔT  // Constant decrement"
        case "logarithmic":
            return "T₀ / log(1 + k)  // Slow cooling"
        default:
            return "Custom cooling function"
        }
    }

    private func getSolutionType(problemType: String) -> String {
        switch problemType {
        case "tsp", "scheduling":
            return "[Int]"  // Permutation
        case "layout", "partitioning":
            return "GraphSolution"
        case "continuous":
            return "VectorN<Double>"
        default:
            return "Solution"
        }
    }

    private func getNeighborSetup(problemType: String, neighborhoodType: String, dimensions: Int) -> String {
        switch problemType {
        case "tsp":
            return """
        // TSP-specific setup
                // Cities numbered 0..<\(dimensions)
                // Tour is permutation of cities
        """
        case "scheduling":
            return """
                // Scheduling-specific setup
                // Jobs numbered 0..<\(dimensions)
                // Solution is job order
        """
        default:
            return "// Problem-specific setup"
        }
    }

    private func getEnergyExample(problemType: String) -> String {
        switch problemType {
        case "tsp":
            return """
                     // Total tour length
                    var length = 0.0
                    for i in 0..<solution.count {
                        let from = solution[i]
                        let to = solution[(i + 1) % solution.count]
                        length += distance[from][to]
                    }
                    return length
            """
        case "scheduling":
            return """
                    // Total tardiness or makespan
                    var makespan = 0.0
                    var currentTime = 0.0
                    for jobIndex in solution {
                        currentTime += processingTime[jobIndex]
                        makespan = max(makespan, currentTime - dueDate[jobIndex])
                    }
                    return makespan
            """
        default:
            return """
                    // Your energy function (to minimize)
                    return calculateObjective(solution)
            """
        }
    }

    private func getNeighborExample(problemType: String, neighborhoodType: String) -> String {
        switch (problemType, neighborhoodType) {
        case ("tsp", "swap"):
            return """
                    // 2-opt: Swap two edges
                    var neighbor = current
                    let i = Int.random(in: 0..<current.count)
                    let j = Int.random(in: 0..<current.count)
                    neighbor.swapAt(i, j)
                    return neighbor
            """
        case ("tsp", "reverse"):
            return """
                    // 2-opt: Reverse segment
                    var neighbor = current
                    let i = Int.random(in: 0..<current.count)
                    let j = Int.random(in: i..<current.count)
                    neighbor[i...j].reverse()
                    return neighbor
            """
        default:
            return """
                    // Generate neighbor solution
                    var neighbor = current
                    // Apply random perturbation
                    return neighbor
            """
        }
    }

    private func getInitialSolution(problemType: String) -> String {
        switch problemType {
        case "tsp", "scheduling":
            return "Array(0..<dimensions).shuffled()"
        default:
            return "randomSolution()"
        }
    }

    private func getCoolingScheduleComparison(currentSchedule: String) -> String {
        """
        | Schedule | Formula | Cooling Speed | Best For |
        |----------|---------|---------------|----------|
        | Exponential | T_{k+1} = α × T_k | Medium (α=0.95) | General use ✓ |
        | Linear | T_k = T₀ - k × ΔT | Fast | Quick solutions |
        | Logarithmic | T_k = T₀ / log(1+k) | Very slow | Theoretical guarantees |
        | Geometric | T_k = T₀ × α^k | Adjustable | Most versatile |
        """
    }

    private func getCoolingScheduleAnalysis(schedule: String, initialTemp: Double, finalTemp: Double, rate: Double, steps: Int) -> String {
        switch schedule {
        case "exponential", "geometric":
            return """
            **Analysis:**
            - Starts at T₀ = \(initialTemp)
            - Multiplies by α = \(rate) each step
            - Reaches Tf = \(finalTemp) in ~\(steps) steps
            - Total cooling time: ~\(steps) temperature levels × \(100) iterations = \(steps * 100) iterations

            **Cooling curve:**
            Step 0: T = \(String(format: "%.1f", initialTemp))
            Step \(steps/4): T = \(String(format: "%.1f", initialTemp * pow(rate, Double(steps/4))))
            Step \(steps/2): T = \(String(format: "%.1f", initialTemp * pow(rate, Double(steps/2))))
            Step \(3*steps/4): T = \(String(format: "%.1f", initialTemp * pow(rate, Double(3*steps/4))))
            Step \(steps): T = \(String(format: "%.4f", finalTemp))
            """
        default:
            return "Cooling analysis for \(schedule) schedule"
        }
    }

    private func getNeighborhoodComparison(problemType: String) -> String {
        switch problemType {
        case "tsp":
            return """
            | Neighborhood | Operation | Exploration | TSP Quality |
            |--------------|-----------|-------------|-------------|
            | Swap | Exchange two cities | Medium | Good |
            | Insert | Move city to new position | Medium | Good |
            | Reverse (2-opt) | Reverse tour segment | Large | Excellent ✓ |
            | 3-opt | Complex rearrangement | Very large | Best (slow) |
            """
        case "scheduling":
            return """
            | Neighborhood | Operation | Exploration |
            |--------------|-----------|-------------|
            | Swap | Exchange two jobs | Medium |
            | Insert | Move job to new position | Medium |
            | Reverse | Reverse job sequence | Large |
            """
        default:
            return """
            | Neighborhood | Description |
            |--------------|-------------|
            | Swap | Exchange two elements |
            | Perturbation | Random small change |
            | Large move | Significant change |
            """
        }
    }

    private func getNeighborhoodAnalysis(neighborhoodType: String, problemType: String) -> String {
        switch neighborhoodType {
        case "swap":
            return "✓ Good balance of exploration and preservation"
        case "reverse":
            return "✓ Excellent for TSP - 2-opt is classic neighborhood"
        case "insert":
            return "✓ Good for sequencing problems"
        default:
            return ""
        }
    }

    private func getSATuningGuide(problemType: String, initialTemp: Double, coolingRate: Double, itersPerTemp: Int) -> String {
        """
        **Tuning Guidelines:**

        **Initial Temperature:**
        - Current: \(initialTemp)
        - Rule of thumb: Set so ~90% of worse solutions accepted initially
        - Test: Generate random neighbor, calculate average ΔE, set T₀ = -ΔE_avg / ln(0.9)
        - Too high: Wastes time in random walk
        - Too low: Converges to local minimum

        **Cooling Rate:**
        - Current: \(coolingRate)
        - Slower (0.99): More thorough, much slower
        - Standard (0.95): Good balance ✓
        - Faster (0.90): Quicker results, may miss optimum

        **Iterations Per Temperature:**
        - Current: \(itersPerTemp)
        - Should allow equilibration at each T
        - Rule: 100-500 × problem_size
        - For \(problemType): \(getIterationsRecommendation(problemType: problemType))

        **Quick Tuning Protocol:**
        1. Start with these defaults
        2. Run and monitor acceptance ratio
        3. If accepting > 90% at end: Increase final temperature
        4. If accepting < 10% at start: Decrease initial temperature
        5. If oscillating: Increase iterations per temperature
        """
    }

    private func getIterationsRecommendation(problemType: String) -> String {
        switch problemType {
        case "tsp":
            return "100-200 recommended (need to explore neighborhood thoroughly)"
        case "scheduling":
            return "50-150 recommended"
        default:
            return "100 is standard"
        }
    }

    private func getProblemGuidanceSA(problemType: String) -> String {
        switch problemType {
        case "tsp":
            return """
            **Traveling Salesman Problem:**
            - **Encoding:** Permutation of cities
            - **Energy:** Total tour length
            - **Neighborhood:** 2-opt (reverse segment) - classic and effective
            - **Initial T:** ~Mean edge length × 10
            - **SA Benefits:** Excellent results, simple to implement

            Classic SA application with well-studied parameters
            """
        case "scheduling":
            return """
            **Job Shop Scheduling:**
            - **Encoding:** Job sequence/permutation
            - **Energy:** Makespan, tardiness, or weighted objectives
            - **Neighborhood:** Swap adjacent jobs, insert job elsewhere
            - **SA Benefits:** Handles complex constraints naturally

            One of the best methods for large scheduling problems
            """
        case "layout":
            return """
            **VLSI Layout / Floorplanning:**
            - **Encoding:** Slicing tree or sequence pair
            - **Energy:** Area, wirelength, overlap penalty
            - **Neighborhood:** Swap modules, rotate, resize
            - **SA Benefits:** Industry standard for chip design

            SA invented for this application!
            """
        default:
            return """
            **General Discrete Optimization:**
            - Define clear energy function (lower = better)
            - Choose neighborhood that preserves feasibility
            - Tune temperature schedule based on energy scale
            """
        }
    }

    private func estimateSATime(problemType: String, iterations: Int) -> String {
        // Very rough estimates
        if iterations < 10000 {
            return "< 1s"
        } else if iterations < 100000 {
            return "1-10s"
        } else if iterations < 1000000 {
            return "10-120s"
        } else {
            return "> 2min"
        }
    }

    private func estimateQuality(coolingRate: Double) -> String {
        if coolingRate > 0.98 {
            return "Excellent (slow cooling)"
        } else if coolingRate > 0.92 {
            return "Very good"
        } else if coolingRate > 0.85 {
            return "Good"
        } else {
            return "Fair (fast cooling)"
        }
    }
}

// MARK: - Differential Evolution Tool

public struct DifferentialEvolutionOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "differential_evolution_optimize",
        description: """
        Global optimization using Differential Evolution (DE). Simple yet powerful population-based method for continuous optimization.

        Perfect for:
        - Continuous global optimization
        - Parameter estimation and calibration
        - Antenna and filter design
        - Chemical engineering optimization
        - Machine learning hyperparameter tuning
        - Problems where PSO is too slow or GA is inappropriate

        How DE Works:
        - Maintains population of candidate solutions
        - Creates trial vectors via differential mutation
        - Crossover combines mutant with current
        - Selection keeps better solution
        - Simple, few parameters, robust performance

        Example: Optimize 10-parameter model
        - populationSize: 50
        - differentialWeight: 0.8
        - crossoverRate: 0.9
        - strategy: "best1bin"

        Returns implementation guidance with Swift code and strategy comparison.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of parameters to optimize"
                ),
                "populationSize": MCPSchemaProperty(
                    type: "integer",
                    description: "Population size. Recommended: 10× dimensions. Default: max(40, 10×D)"
                ),
                "differentialWeight": MCPSchemaProperty(
                    type: "number",
                    description: "F parameter (0.5-1.0). Controls mutation amplification. Default: 0.8"
                ),
                "crossoverRate": MCPSchemaProperty(
                    type: "number",
                    description: "CR parameter (0.5-0.9). Probability of using mutant. Default: 0.9"
                ),
                "strategy": MCPSchemaProperty(
                    type: "string",
                    description: "DE mutation strategy",
                    enum: ["rand1bin", "best1bin", "currentToBest1bin", "rand2bin", "best2bin"]
                ),
                "maxGenerations": MCPSchemaProperty(
                    type: "integer",
                    description: "Maximum generations. Default: 1000"
                ),
                "searchRegion": MCPSchemaProperty(
                    type: "object",
                    description: "Search bounds: {\"lower\": [...], \"upper\": [...]}"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Problem hint",
                    enum: ["parameter_estimation", "engineering", "ml_tuning", "general"]
                )
            ],
            required: ["dimensions", "searchRegion"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dimensions = try args.getInt("dimensions")

        // Parse search region
        guard let searchRegionValue = args["searchRegion"],
              let searchRegionDict = searchRegionValue.value as? [String: AnyCodable],
              let lowerValue = searchRegionDict["lower"],
              let upperValue = searchRegionDict["upper"],
              let lowerArray = lowerValue.value as? [AnyCodable],
              let upperArray = upperValue.value as? [AnyCodable] else {
            throw ToolError.invalidArguments("searchRegion must have 'lower' and 'upper' arrays")
        }

        let lower = try lowerArray.map { value -> Double in
            if let num = value.value as? Double { return num }
            else if let num = value.value as? Int { return Double(num) }
            else { throw ToolError.invalidArguments("Search bounds must be numbers") }
        }

        let upper = try upperArray.map { value -> Double in
            if let num = value.value as? Double { return num }
            else if let num = value.value as? Int { return Double(num) }
            else { throw ToolError.invalidArguments("Search bounds must be numbers") }
        }

        guard lower.count == dimensions && upper.count == dimensions else {
            throw ToolError.invalidArguments("Search region bounds must match dimensions")
        }

        let populationSize = args.getIntOptional("populationSize") ?? max(40, dimensions * 10)
        let differentialWeight = args.getDoubleOptional("differentialWeight") ?? 0.8
        let crossoverRate = args.getDoubleOptional("crossoverRate") ?? 0.9
        let strategy = args.getStringOptional("strategy") ?? "best1bin"
        let maxGenerations = args.getIntOptional("maxGenerations") ?? 1000
        let problemType = args.getStringOptional("problemType") ?? "general"

        let guide = """
        🧬 **Differential Evolution (DE) Optimization**

        **Problem Configuration:**
        - Dimensions: \(dimensions)
        - Population size: \(populationSize) (\(populationSize/dimensions)× dimensions)
        - Max generations: \(maxGenerations)
        - Search bounds: [\(lower.map { String(format: "%.2f", $0) }.joined(separator: ", "))] to [\(upper.map { String(format: "%.2f", $0) }.joined(separator: ", "))]

        **DE Parameters:**
        - Differential weight (F): \(String(format: "%.2f", differentialWeight)) \(explainDEWeight(differentialWeight))
        - Crossover rate (CR): \(String(format: "%.2f", crossoverRate)) \(explainDECrossover(crossoverRate))
        - Strategy: \(strategy) \(explainDEStrategy(strategy))

        **How Differential Evolution Works:**

        **Core Idea:**
        Use difference vectors between population members to explore search space.
        Simple yet surprisingly effective!

        **DE Algorithm (\(strategy)):**
        """

        // Add algorithm explanation based on strategy
        let algorithmExplanation = getDEAlgorithmExplanation(strategy: strategy, F: differentialWeight, CR: crossoverRate, populationSize: populationSize)

        let swiftCode = """

        **Swift Implementation:**

        import BusinessMath

        // Create DE optimizer
        let de = DifferentialEvolutionOptimizer<VectorN<Double>>(
            populationSize: \(populationSize),
            maxGenerations: \(maxGenerations),
            differentialWeight: \(differentialWeight),  // F parameter
            crossoverRate: \(crossoverRate),            // CR parameter
            strategy: .\(strategy)
        )

        // Define objective function (to MINIMIZE)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            \(getDEObjectiveExample(problemType: problemType))
        }

        // Define bounds
        let bounds = (
            lower: VectorN(\(lower)),
            upper: VectorN(\(upper))
        )

        // Run DE
        let result = try await de.optimize(
            objective: objective,
            bounds: bounds
        )

        // Analyze results
        print("Best solution: \\(result.bestSolution)")
        print("Best fitness: \\(result.bestFitness)")
        print("Generation found: \\(result.generationFound)")
        print("Final population diversity: \\(result.diversity)")

        // Evolution history
        print("\\nFitness over generations:")
        for (gen, stats) in result.evolutionHistory.enumerated() {
            print("Gen \\(gen): Best=\\(stats.bestFitness), Mean=\\(stats.meanFitness), Std=\\(stats.stdFitness)")
        }
        """

        let strategyComparison = """

        **DE Strategies:**

        | Strategy | Mutation Formula | Exploration | Best For |
        |----------|-----------------|-------------|----------|
        | rand1bin | xᵣ₁ + F×(xᵣ₂ - xᵣ₃) | High | Multimodal ✓ |
        | best1bin | x_best + F×(xᵣ₁ - xᵣ₂) | Low | Unimodal, fast |
        | currentToBest1bin | xᵢ + F×(x_best - xᵢ) + F×(xᵣ₁ - xᵣ₂) | Medium | General purpose |
        | rand2bin | xᵣ₁ + F×(xᵣ₂ - xᵣ₃) + F×(xᵣ₄ - xᵣ₅) | Very high | Hard problems |
        | best2bin | x_best + F×(xᵣ₁ - xᵣ₂) + F×(xᵣ₃ - xᵣ₄) | Low | Exploitation |

        **Current: \(strategy)**
        \(getStrategyRecommendation(strategy: strategy, problemType: problemType))

        **Parameter Tuning:**

        **Differential Weight (F = \(differentialWeight)):**
        - Range: 0.5-1.0 (rarely outside)
        - Low (0.5-0.6): Conservative, good for smooth landscapes
        - Medium (0.7-0.8): Standard, works well generally ✓
        - High (0.9-1.0): Aggressive, good for rugged landscapes
        \(getFTuningAdvice(F: differentialWeight))

        **Crossover Rate (CR = \(crossoverRate)):**
        - Range: 0.0-1.0
        - Low (0.1-0.3): Preserve parent structure
        - Medium (0.5-0.7): Balanced
        - High (0.8-1.0): Favor mutant vector ✓
        \(getCRTuningAdvice(CR: crossoverRate))

        **Population Size (\(populationSize)):**
        - Current: \(populationSize) individuals
        - Rule of thumb: 10 × D = \(dimensions * 10)
        - Minimum: ~4 × D = \(dimensions * 4)
        - You have: \(populationSize / dimensions) × D
        \(getPopSizeAdvice(popSize: populationSize, dimensions: dimensions))

        **Problem-Specific Guidance:**

        \(getDEProblemGuidance(problemType: problemType))

        **When to Use DE:**
        ✅ **Good for:**
        - Continuous optimization (DE's strength)
        - Parameter estimation and model fitting
        - Engineering design optimization
        - Medium dimensions (5-100 variables)
        - When PSO converges too quickly
        - Problems with many local minima
        - When you want simplicity (few parameters to tune)

        ❌ **Not ideal for:**
        - Discrete/combinatorial problems (use GA)
        - Very high dimensions (>1000) without structure
        - When gradients are available (use gradient methods)
        - Real-time applications (iterative process)
        - Single-objective convex problems (use Newton or gradient descent)

        **DE vs Other Algorithms:**

        | Algorithm | Best Domain | Parameters to Tune | Convergence | Simplicity |
        |-----------|-------------|-------------------|-------------|------------|
        | DE | Continuous | 2 (F, CR) ✓ | Good | Very simple ✓ |
        | PSO | Continuous | 3 (ω, c₁, c₂) | Fast | Simple |
        | GA | Discrete/continuous | 4+ (crossover, mutation, etc.) | Medium | Complex |
        | CMA-ES | Continuous | 0 (self-adaptive) | Excellent | Complex |

        **Troubleshooting:**

        **Problem: Slow convergence**
        - Increase crossover rate to 0.95
        - Switch to best1bin strategy
        - Reduce population size
        - Increase F to 0.9

        **Problem: Premature convergence (stuck in local minimum)**
        - Use rand1bin or rand2bin strategy
        - Increase population size to \(populationSize * 2)
        - Decrease crossover rate to 0.7
        - Reduce F to 0.6

        **Problem: Population diversity lost**
        - Indicates convergence (may be good or bad)
        - If fitness still improving: Normal convergence
        - If fitness plateaued: Stuck in local minimum
        - Solution: Restart with higher F or different strategy

        **Problem: Oscillating without improving**
        - F may be too high (reduce to 0.6-0.7)
        - Try best1bin for more directed search
        - Check if objective function is noisy

        **Advanced Techniques:**

        **Adaptive DE:**
        Automatically adjust F and CR based on success:
        - Track which (F, CR) pairs produce improvements
        - Adapt parameters per individual
        - Example: jDE, SaDE variants

        **Self-adaptive DE:**
        Encode F and CR in individuals:
        - Each individual has its own F and CR
        - Good parameters propagate through evolution
        - Reduces manual tuning

        **Hybrid DE:**
        Combine with local search:
        - DE for global exploration
        - Nelder-Mead or BFGS for local refinement
        - Apply local search to best individuals periodically

        **Constraint Handling:**
        For constrained problems:
        - Penalty functions
        - Feasibility rules (prefer feasible over infeasible)
        - Repair operators
        - ε-constrained method

        **Performance Expectations:**

        | Problem Size | Population | Generations | Evaluations | Time Estimate |
        |--------------|-----------|-------------|-------------|---------------|
        | \(dimensions) vars | \(populationSize) | \(maxGenerations) | \(populationSize * maxGenerations) | \(estimateDETime(popSize: populationSize, gens: maxGenerations)) |
        | 10 vars | 100 | 500 | 50,000 | 5-20s |
        | 30 vars | 300 | 1000 | 300,000 | 30-120s |
        | 100 vars | 1000 | 2000 | 2,000,000 | 3-15min |

        **Convergence Indicators:**
        - **Best Fitness:** Should steadily improve (with plateaus)
        - **Mean Fitness:** Should approach best fitness
        - **Standard Deviation:** Should decrease (indicates convergence)
        - **Diversity:** High early, low late

        **Real-World Example - Model Calibration:**

        Problem: Fit model parameters to observed data

        ```swift
        // Fit exponential model: y = a × exp(b × x) + c
        // Find best a, b, c to match observations

        let observations: [(x: Double, y: Double)] = loadData()

        let objective: @Sendable (VectorN<Double>) -> Double = { params in
            let a = params[0]
            let b = params[1]
            let c = params[2]

            // Sum of squared errors
            let sse = observations.map { obs in
                let predicted = a * exp(b * obs.x) + c
                let error = predicted - obs.y
                return error * error
            }.reduce(0, +)

            return sse
        }

        let bounds = (
            lower: VectorN([0.1, -2.0, -10.0]),    // Reasonable param ranges
            upper: VectorN([10.0, 2.0, 10.0])
        )

        let de = DifferentialEvolutionOptimizer<VectorN<Double>>(
            populationSize: 60,  // 20× for 3 parameters
            strategy: .best1bin  // Fast convergence for smooth objective
        )

        let result = try await de.optimize(objective: objective, bounds: bounds)
        print("Best fit: a=\\(result.bestSolution[0]), b=\\(result.bestSolution[1]), c=\\(result.bestSolution[2])")
        print("SSE: \\(result.bestFitness)")
        ```

        **Next Steps:**
        1. Implement objective function
        2. Start with default parameters (F=0.8, CR=0.9, best1bin)
        3. Run and monitor convergence
        4. If stuck in local minimum: Switch to rand1bin
        5. If too slow: Use best1bin and increase CR
        6. For difficult problems: Increase population size

        **Resources:**
        - Classic: Storn & Price (1997) "Differential Evolution - A Simple and Efficient Heuristic"
        - Tutorial: DE for Global Optimization
        - Example: Parameter Estimation with DE
        - API Reference: DifferentialEvolutionOptimizer.swift
        - Benchmarks: DE on CEC test suite
        """

        return .success(text: guide + algorithmExplanation + swiftCode + strategyComparison)
    }

    // MARK: - Helper Functions

    private func getDEAlgorithmExplanation(strategy: String, F: Double, CR: Double, populationSize: Int) -> String {
        let baseAlgorithm = """

        1. INITIALIZATION
           Create \(populationSize) random vectors in search space
           Evaluate fitness of each

        2. FOR EACH GENERATION
           FOR EACH individual xᵢ in population:

             a) MUTATION: Create mutant vector vᵢ
        """

        let mutationStep: String
        switch strategy {
        case "rand1bin":
            mutationStep = """
                   Select 3 random distinct individuals: r1, r2, r3
                   vᵢ = xᵣ₁ + F × (xᵣ₂ - xᵣ₃)
                   Where F = \(F)
            """
        case "best1bin":
            mutationStep = """
                   Select 2 random individuals: r1, r2
                   vᵢ = x_best + F × (xᵣ₁ - xᵣ₂)
                   Where F = \(F), x_best = current best solution
            """
        case "currentToBest1bin":
            mutationStep = """
                   Select 2 random individuals: r1, r2
                   vᵢ = xᵢ + F × (x_best - xᵢ) + F × (xᵣ₁ - xᵣ₂)
                   Where F = \(F)
            """
        default:
            mutationStep = "Strategy-specific mutation"
        }

        let crossoverStep = """

             b) CROSSOVER: Create trial vector uᵢ
                FOR each dimension j:
                  if random() < CR or j == jrand:
                    uᵢⱼ = vᵢⱼ  // From mutant
                  else:
                    uᵢⱼ = xᵢⱼ  // From current
                Where CR = \(CR), jrand ensures at least one dimension from mutant

             c) SELECTION: Keep better solution
                if fitness(uᵢ) < fitness(xᵢ):
                  xᵢ₊₁ = uᵢ     // Trial wins
                  Update best if uᵢ is new best
                else:
                  xᵢ₊₁ = xᵢ     // Current survives

        3. RETURN best solution found
        """

        return baseAlgorithm + mutationStep + crossoverStep
    }

    private func explainDEWeight(_ F: Double) -> String {
        if F > 0.9 {
            return "← High amplification (aggressive)"
        } else if F < 0.6 {
            return "← Low amplification (conservative)"
        } else {
            return "← Standard setting ✓"
        }
    }

    private func explainDECrossover(_ CR: Double) -> String {
        if CR > 0.85 {
            return "← High (favor mutant vector) ✓"
        } else if CR < 0.5 {
            return "← Low (preserve current)"
        } else {
            return "← Medium (balanced)"
        }
    }

    private func explainDEStrategy(_ strategy: String) -> String {
        switch strategy {
        case "rand1bin":
            return "← Exploration-focused ✓"
        case "best1bin":
            return "← Exploitation-focused, fast"
        case "currentToBest1bin":
            return "← Balanced approach"
        default:
            return ""
        }
    }

    private func getDEObjectiveExample(problemType: String) -> String {
        switch problemType {
        case "parameter_estimation":
            return """
                // Model fitting: minimize prediction error
                let predictions = model(parameters: x)
                let errors = zip(predictions, observations).map { pred, obs in
                    (pred - obs) * (pred - obs)
                }
                return errors.reduce(0, +)  // Sum of squared errors
            """
        case "engineering":
            return """
                // Engineering design: minimize cost subject to constraints
                let cost = calculateCost(design: x)
                let constraintViolations = checkConstraints(design: x)
                return cost + 1000 * constraintViolations  // Penalty method
            """
        default:
            return """
                // Your objective function (to minimize)
                return calculateObjective(x)
            """
        }
    }

    private func getStrategyRecommendation(strategy: String, problemType: String) -> String {
        switch (strategy, problemType) {
        case ("best1bin", _):
            return "✓ Fast convergence, good for smooth problems"
        case ("rand1bin", _):
            return "✓ Better exploration, good for multimodal problems"
        case ("currentToBest1bin", "general"):
            return "✓ Good general-purpose choice"
        default:
            return ""
        }
    }

    private func getFTuningAdvice(F: Double) -> String {
        if F > 0.85 {
            return "⚠️ High F may cause instability - reduce if oscillating"
        } else if F < 0.6 {
            return "⚠️ Low F may be too conservative - increase if stuck"
        } else {
            return "✓ Good F value"
        }
    }

    private func getCRTuningAdvice(CR: Double) -> String {
        if CR > 0.95 {
            return "⚠️ Very high CR - may converge too quickly"
        } else if CR < 0.5 {
            return "⚠️ Low CR - convergence may be slow"
        } else {
            return "✓ Good CR value"
        }
    }

    private func getPopSizeAdvice(popSize: Int, dimensions: Int) -> String {
        let recommended = dimensions * 10

        if popSize < recommended / 2 {
            return "⚠️ Population may be too small - consider increasing to \(recommended)"
        } else if popSize > recommended * 2 {
            return "⚠️ Large population - may be slow without much benefit"
        } else {
            return "✓ Good population size"
        }
    }

    private func getDEProblemGuidance(problemType: String) -> String {
        switch problemType {
        case "parameter_estimation":
            return """
            **Parameter Estimation / Model Fitting:**
            - DE excellent for this application
            - Use best1bin for smooth least-squares objectives
            - Use rand1bin if many local minima
            - CR = 0.9, F = 0.8 works well
            - Population: 10-20 × number of parameters

            Example: Fit Michaelis-Menten kinetics, estimate activation energies
            """
        case "engineering":
            return """
            **Engineering Design Optimization:**
            - DE handles nonlinear constraints well with penalties
            - Use best1bin for smooth design spaces
            - Higher population for complex constraints
            - Consider constraint-handling variants (ε-DE, feasibility rules)

            Example: Antenna design, structural optimization, chemical processes
            """
        case "ml_tuning":
            return """
            **ML Hyperparameter Tuning:**
            - DE efficient for continuous hyperparameters
            - Can handle categorical via discretization
            - Population: 5-10 × number of hyperparameters
            - CR = 0.7, F = 0.8 recommended

            Better than grid search, comparable to Bayesian optimization
            """
        default:
            return """
            **General Continuous Optimization:**
            - Start with best1bin, F=0.8, CR=0.9
            - If stuck: Switch to rand1bin
            - Monitor diversity - should decrease over time
            """
        }
    }

    private func estimateDETime(popSize: Int, gens: Int) -> String {
        let evals = popSize * gens

        if evals < 50000 {
            return "5-30s (assuming fast objective)"
        } else if evals < 500000 {
            return "30s-5min (assuming fast objective)"
        } else {
            return "5-30min (assuming fast objective)"
        }
    }
}

// MARK: - Tool Registration

public func getMetaheuristicOptimizationTools() -> [any MCPToolHandler] {
    return [
        SimulatedAnnealingOptimizeTool(),
        DifferentialEvolutionOptimizeTool()
    ]
}
