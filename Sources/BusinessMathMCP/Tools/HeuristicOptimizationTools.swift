import Foundation
import MCP
import BusinessMath

// MARK: - Particle Swarm Optimization Tool

public struct ParticleSwarmOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "particle_swarm_optimize",
        description: """
        Global optimization using Particle Swarm Optimization (PSO). Inspired by bird flocking behavior, PSO excels at finding global optima in non-convex, multi-modal landscapes where gradient-based methods fail.

        Perfect for:
        - Non-convex portfolio optimization
        - Neural network training
        - Engineering design optimization
        - Parameter tuning (ML hyperparameters, model calibration)
        - Problems with many local minima
        - Derivative-free optimization

        How PSO Works:
        - Maintains swarm of particles exploring solution space
        - Each particle has position (candidate solution) and velocity
        - Particles influenced by:
          * Personal best position found
          * Global best position found by swarm
          * Inertia (tendency to continue current direction)
        - Swarm converges to global optimum through social interaction

        Example: Optimize 5-asset portfolio with non-convex constraints
        - dimensions: 5
        - numberOfParticles: 40
        - maxIterations: 100
        - searchRegion: {"lower": [0,0,0,0,0], "upper": [1,1,1,1,1]}

        Returns implementation guidance with Swift code and parameter tuning advice.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables (2-100 typical)"
                ),
                "numberOfParticles": MCPSchemaProperty(
                    type: "integer",
                    description: "Swarm size: 20-50 typical, 10×dimensions recommended for complex problems"
                ),
                "maxIterations": MCPSchemaProperty(
                    type: "integer",
                    description: "Maximum iterations (50-200 typical, more for complex problems)"
                ),
                "inertiaWeight": MCPSchemaProperty(
                    type: "number",
                    description: "Inertia parameter ω (0.4-0.9). Higher = more exploration, lower = more exploitation. Default: 0.7"
                ),
                "cognitiveWeight": MCPSchemaProperty(
                    type: "number",
                    description: "Cognitive parameter c₁ (1.5-2.0). Attraction to personal best. Default: 1.5"
                ),
                "socialWeight": MCPSchemaProperty(
                    type: "number",
                    description: "Social parameter c₂ (1.5-2.0). Attraction to global best. Default: 1.5"
                ),
                "searchRegion": MCPSchemaProperty(
                    type: "object",
                    description: "Search bounds: {\"lower\": [...], \"upper\": [...]}"
                ),
                "topology": MCPSchemaProperty(
                    type: "string",
                    description: "Communication topology: 'global' (all particles share info), 'local' (neighborhood only), 'ring'",
                    enum: ["global", "local", "ring"]
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Problem hint for parameter suggestions",
                    enum: ["portfolio", "engineering", "ml_tuning", "scheduling", "general"]
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
            throw ToolError.invalidArguments("Search region bounds must match dimensions (\(dimensions))")
        }

        let numberOfParticles = args.getIntOptional("numberOfParticles") ?? min(40, max(20, dimensions * 10))
        let maxIterations = args.getIntOptional("maxIterations") ?? 100
        let inertiaWeight = args.getDoubleOptional("inertiaWeight") ?? 0.7
        let cognitiveWeight = args.getDoubleOptional("cognitiveWeight") ?? 1.5
        let socialWeight = args.getDoubleOptional("socialWeight") ?? 1.5
        let topology = args.getStringOptional("topology") ?? "global"
        let problemType = args.getStringOptional("problemType") ?? "general"

        let guide = """
        🦅 **Particle Swarm Optimization (PSO)**

        **Problem Configuration:**
        - Variables: \(dimensions)
        - Swarm size: \(numberOfParticles) particles
        - Max iterations: \(maxIterations)
        - Search region: [\(lower.map { String(format: "%.2f", $0) }.joined(separator: ", "))] to [\(upper.map { String(format: "%.2f", $0) }.joined(separator: ", "))]

        **Algorithm Parameters:**
        - Inertia weight (ω): \(String(format: "%.2f", inertiaWeight)) \(explainInertia(inertiaWeight))
        - Cognitive weight (c₁): \(String(format: "%.2f", cognitiveWeight)) \(explainCognitive(cognitiveWeight))
        - Social weight (c₂): \(String(format: "%.2f", socialWeight)) \(explainSocial(socialWeight))
        - Topology: \(topology) \(explainTopology(topology))

        **How PSO Works:**

        **Swarm Intelligence:**
        ```
        Initialize \(numberOfParticles) particles randomly in search space

        Each iteration:
          For each particle i:
            1. Evaluate fitness at current position
            2. Update personal best if improved
            3. Update global best if best in swarm

            4. Update velocity:
               vᵢ = ω·vᵢ + c₁·r₁·(pbestᵢ - xᵢ) + c₂·r₂·(gbest - xᵢ)
               └─┬─┘   └────┬────┘           └─────┬─────┘
                Inertia   Cognitive            Social
               (continue) (own memory)      (swarm knowledge)

            5. Update position:
               xᵢ = xᵢ + vᵢ

            6. Apply boundary constraints

        Return global best found
        ```

        **Why PSO Works:**
        - **Exploration:** Particles spread out to cover search space
        - **Exploitation:** Particles converge toward best regions found
        - **Balance:** Inertia weight controls exploration vs exploitation trade-off
        - **Robustness:** Swarm doesn't get stuck in single local minimum
        - **Derivative-free:** Works on black-box, non-differentiable functions

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create PSO optimizer
        let pso = ParticleSwarmOptimizer<VectorN<Double>>(
            numberOfParticles: \(numberOfParticles),
            maxIterations: \(maxIterations),
            inertiaWeight: \(inertiaWeight),
            cognitiveWeight: \(cognitiveWeight),
            socialWeight: \(socialWeight),
            topology: .\(topology)
        )

        // Define objective function (to minimize)
        let objective: @Sendable (VectorN<Double>) -> Double = { x in
            // Your objective function here
            // Example: Rastrigin function (many local minima)
            let A = 10.0
            let n = Double(x.count)
            return A * n + x.toArray().map { xi in
                xi * xi - A * cos(2.0 * .pi * xi)
            }.reduce(0, +)
        }

        // Define search bounds
        let bounds = (
            lower: VectorN(\(lower)),
            upper: VectorN(\(upper))
        )

        // Run PSO
        let result = try await pso.optimize(
            objective: objective,
            bounds: bounds,
            constraints: []  // Add constraints if needed
        )

        // Analyze results
        print("Best solution: \\(result.bestPosition)")
        print("Objective value: \\(result.bestFitness)")
        print("Iterations: \\(result.iterations)")
        print("Convergence: \\(result.converged)")

        // Swarm statistics
        print("\\nSwarm diversity: \\(result.diversity)")  // How spread out particles are
        print("Convergence rate: \\(result.convergenceHistory)")
        ```

        **Parameter Tuning Guide:**

        \(getParameterGuidance(problemType: problemType, dimensions: dimensions, particles: numberOfParticles))

        **Topology Comparison:**

        | Topology | Communication | Best For | Convergence |
        |----------|--------------|----------|-------------|
        | Global | All particles know global best | Unimodal problems | Fast |
        | Local | Only neighbors share info | Multimodal problems | Slow but thorough |
        | Ring | Circular neighborhood | Balance | Medium |

        **Current Setting: \(topology)**
        \(topologyRecommendation(topology: topology, problemType: problemType))

        **Convergence Diagnostics:**

        **Early Convergence (Bad):**
        ```
        Iteration   Best Fitness   Diversity
        1           10.5          High
        10          2.1           Medium
        20          2.0           Low      ← Converged too fast
        30-100      2.0           Very low ← Stuck in local minimum
        ```
        **Action:** Increase inertia weight or use local topology

        **Good Convergence:**
        ```
        Iteration   Best Fitness   Diversity
        1           10.5          High
        25          5.2           Medium   ← Still exploring
        50          1.8           Medium
        75          0.5           Low      ← Converging to optimum
        100         0.1           Low      ← Found global minimum
        ```

        **Slow Convergence:**
        ```
        Iteration   Best Fitness   Diversity
        1           10.5          High
        50          9.8           High     ← Not making progress
        100         9.2           High     ← Still exploring
        ```
        **Action:** Decrease inertia weight, increase swarm size, or use global topology

        **Common Problem Types:**

        \(getProblemTypeGuidance(problemType: problemType))

        **When to Use PSO:**
        ✅ **Good for:**
        - Non-convex optimization (many local minima)
        - Black-box optimization (no derivatives available)
        - Continuous variables
        - Moderate dimensions (2-100 variables)
        - Noisy or discontinuous objective functions
        - Multi-objective optimization (with modifications)

        ❌ **Not ideal for:**
        - Simple convex problems (use gradient descent instead)
        - Very high dimensions (>1000 variables) - consider Differential Evolution
        - Purely discrete/combinatorial (use Genetic Algorithm instead)
        - When you need guaranteed optimality (PSO is heuristic)
        - Very tight convergence requirements (slow final convergence)

        **PSO vs Other Algorithms:**

        | Algorithm | Best For | Convergence Speed | Ease of Tuning |
        |-----------|----------|-------------------|----------------|
        | PSO | Continuous, non-convex | Fast initially, slow finally | Easy |
        | Genetic Algorithm | Combinatorial | Medium | Medium |
        | Simulated Annealing | Discrete | Slow | Hard |
        | Gradient Descent | Convex, smooth | Very fast | Easy |
        | Differential Evolution | Continuous | Medium | Medium |

        **Troubleshooting:**

        **Problem: Stuck in local minimum**
        - Increase numberOfParticles (try \(numberOfParticles * 2))
        - Increase inertiaWeight to 0.8-0.9 for more exploration
        - Use local or ring topology
        - Increase maxIterations

        **Problem: Not converging**
        - Decrease inertiaWeight to 0.4-0.6 for more exploitation
        - Use global topology
        - Increase cognitiveWeight and socialWeight to 2.0
        - Verify search bounds are reasonable

        **Problem: Premature convergence**
        - Happens when diversity drops too quickly
        - Increase inertiaWeight
        - Use time-varying inertia: start at 0.9, end at 0.4
        - Implement diversity maintenance techniques

        **Problem: Slow performance**
        - PSO requires \(numberOfParticles) × \(maxIterations) = \(numberOfParticles * maxIterations) objective function evaluations
        - Reduce numberOfParticles if objective is expensive
        - Consider parallel PSO (evaluate particles in parallel)
        - Reduce maxIterations with early stopping

        **Advanced Features:**

        **Time-Varying Inertia Weight:**
        ```swift
        // Linearly decrease from 0.9 to 0.4
        let w(t) = 0.9 - (0.9 - 0.4) × t/maxIterations
        // Explore early, exploit late
        ```

        **Constriction Factor (Alternative to ω, c₁, c₂):**
        ```swift
        // Guaranteed convergence (Clerc & Kennedy)
        let φ = c₁ + c₂  // Must be > 4
        let χ = 2.0 / abs(2.0 - φ - sqrt(φ² - 4φ))
        // Use χ to multiply velocity update
        ```

        **Boundary Handling:**
        - **Reflecting:** Particle bounces off boundary
        - **Absorbing:** Particle stops at boundary (default)
        - **Periodic:** Wraps to opposite boundary
        - **Random:** Reinitialize if outside

        **Performance Expectations:**

        | Problem Size | Particles | Iterations | Time Estimate |
        |--------------|-----------|------------|---------------|
        | \(dimensions) vars | \(numberOfParticles) | \(maxIterations) | \(estimatePSOTime(dimensions: dimensions, particles: numberOfParticles, iterations: maxIterations)) |
        | 10 vars | 50 | 100 | 0.1-0.5s |
        | 50 vars | 200 | 200 | 1-5s |
        | 100 vars | 500 | 300 | 10-60s |

        **Quality Indicators:**
        - **Best Fitness:** Lower is better (for minimization)
        - **Diversity:** Should start high, gradually decrease
        - **Convergence Rate:** Fitness should improve each iteration
        - **Final Diversity:** Very low suggests convergence

        **Next Steps:**
        1. Implement the Swift code with your objective function
        2. Run with default parameters first
        3. Monitor convergence history and diversity
        4. Tune parameters based on convergence behavior
        5. Compare with gradient-based methods if applicable

        **Resources:**
        - Original Paper: Kennedy & Eberhart (1995)
        - Tutorial: PSO for Financial Optimization
        - Example: Portfolio optimization with PSO
        - API Reference: ParticleSwarmOptimizer.swift
        - Benchmarks: PSO on standard test functions
        """

        return .success(text: guide)
    }

    // MARK: - Helper Functions

    private func explainInertia(_ w: Double) -> String {
        if w > 0.8 {
            return "← High exploration (particles keep moving)"
        } else if w < 0.5 {
            return "← High exploitation (particles converge quickly)"
        } else {
            return "← Balanced"
        }
    }

    private func explainCognitive(_ c: Double) -> String {
        if c > 1.8 {
            return "← Strong attraction to personal best"
        } else {
            return "← Standard setting"
        }
    }

    private func explainSocial(_ c: Double) -> String {
        if c > 1.8 {
            return "← Strong attraction to global best"
        } else {
            return "← Standard setting"
        }
    }

    private func explainTopology(_ topology: String) -> String {
        switch topology {
        case "global":
            return "← All particles share information (fast convergence)"
        case "local":
            return "← Neighborhood communication (better for multimodal)"
        case "ring":
            return "← Circular neighborhoods (balanced)"
        default:
            return ""
        }
    }

    private func topologyRecommendation(topology: String, problemType: String) -> String {
        let isMultimodal = ["portfolio", "engineering", "general"].contains(problemType)

        if topology == "global" && isMultimodal {
            return "⚠️ Consider 'local' topology for better exploration of multiple peaks"
        } else if topology == "local" && problemType == "ml_tuning" {
            return "✓ Good choice - ML hyperparameter spaces often have multiple good regions"
        } else {
            return "✓ Reasonable choice for this problem type"
        }
    }

    private func getParameterGuidance(problemType: String, dimensions: Int, particles: Int) -> String {
        let recommended = dimensions * 10

        var guidance = """
        **For \(problemType) problems:**

        **Swarm Size:**
        - Current: \(particles) particles
        - Recommended: \(recommended) particles (10× dimensions)
        """

        if particles < recommended {
            guidance += "\n⚠️ Swarm may be too small - consider increasing to \(recommended)"
        } else if particles > recommended * 2 {
            guidance += "\n⚠️ Large swarm - may be slow without much benefit"
        } else {
            guidance += "\n✓ Good swarm size"
        }

        switch problemType {
        case "portfolio":
            guidance += """


            **Portfolio Optimization Settings:**
            - Inertia: 0.6-0.7 (moderate exploration)
            - Topology: local or ring (avoid premature convergence)
            - Iterations: 100-200 (portfolio landscapes are complex)
            """
        case "engineering":
            guidance += """


            **Engineering Design Settings:**
            - Inertia: 0.7-0.8 (good exploration)
            - Topology: global or local depending on constraints
            - Iterations: 150-300 (thorough optimization)
            """
        case "ml_tuning":
            guidance += """


            **ML Hyperparameter Tuning:**
            - Inertia: 0.7 (balanced)
            - Topology: local (multiple good hyperparameter sets)
            - Iterations: 50-100 (quick exploration)
            """
        default:
            guidance += """


            **General Guidelines:**
            - Inertia: Start with 0.7, decrease if not converging
            - Topology: global for quick test, local if many local minima
            - Iterations: 100-200 for most problems
            """
        }

        return guidance
    }

    private func getProblemTypeGuidance(problemType: String) -> String {
        switch problemType {
        case "portfolio":
            return """
            **Portfolio Optimization:**
            - **Objective:** Maximize Sharpe ratio or minimize risk
            - **Constraints:** Weights sum to 1, long-only, sector limits
            - **Challenges:** Non-convex with constraints, many local optima
            - **PSO Benefits:** Handles non-convexity well, can incorporate complex constraints

            Example:
            ```swift
            let objective: @Sendable (VectorN<Double>) -> Double = { weights in
                let returns = expectedReturns.dot(weights)
                let risk = sqrt(weights.transpose() * covMatrix * weights)
                return -returns / risk  // Negative Sharpe ratio (minimize)
            }
            ```
            """
        case "engineering":
            return """
            **Engineering Design:**
            - **Objective:** Minimize cost, weight, or maximize performance
            - **Constraints:** Physical constraints, material limits
            - **Challenges:** Complex physics, multiple objectives
            - **PSO Benefits:** Handles black-box simulations, multi-objective variants

            Example: Structural optimization, antenna design, control systems
            """
        case "ml_tuning":
            return """
            **ML Hyperparameter Tuning:**
            - **Objective:** Minimize validation error
            - **Variables:** Learning rate, regularization, architecture params
            - **Challenges:** Expensive evaluation, noisy objectives
            - **PSO Benefits:** Sample efficient, parallel evaluation possible

            Better than grid search or random search for continuous parameters
            """
        case "scheduling":
            return """
            **Scheduling Problems:**
            - **Note:** PSO better for continuous variables
            - **For discrete scheduling:** Consider Genetic Algorithm instead
            - **Hybrid approach:** PSO for continuous params + GA for discrete
            """
        default:
            return """
            **General Optimization:**
            - PSO works well for most continuous non-convex problems
            - Key advantage: No derivatives needed
            - Good for: 2-100 variables, moderate evaluation cost
            """
        }
    }

    private func estimatePSOTime(dimensions: Int, particles: Int, iterations: Int) -> String {
        let evals = particles * iterations

        if evals < 5000 {
            return "0.1-1s (assuming fast objective)"
        } else if evals < 50000 {
            return "1-10s (assuming fast objective)"
        } else {
            return "10-60s (assuming fast objective)"
        }
    }
}

// MARK: - Genetic Algorithm Tool

public struct GeneticAlgorithmOptimizeTool: MCPToolHandler, Sendable {
    public let tool = MCPTool(
        name: "genetic_algorithm_optimize",
        description: """
        Evolutionary optimization using Genetic Algorithm (GA). Inspired by natural selection, GA excels at combinatorial and discrete optimization where traditional methods struggle.

        Perfect for:
        - Combinatorial optimization (scheduling, routing, assignment)
        - Feature selection (choose best subset of features)
        - Discrete parameter optimization
        - Mixed integer-continuous problems
        - Project portfolio selection
        - Resource allocation with discrete choices

        How GA Works:
        - Maintains population of candidate solutions (chromosomes)
        - Fitness-based selection (survival of the fittest)
        - Crossover (recombination of good solutions)
        - Mutation (random exploration)
        - Elitism (preserve best solutions)
        - Evolves over generations to find optimal solution

        Example: Select 10 best projects from 50 candidates within budget
        - populationSize: 100
        - generations: 50
        - encoding: "binary"
        - crossoverRate: 0.8
        - mutationRate: 0.02

        Returns implementation guidance with Swift code and GA best practices.
        """,
        inputSchema: MCPToolInputSchema(
            properties: [
                "dimensions": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of decision variables"
                ),
                "populationSize": MCPSchemaProperty(
                    type: "integer",
                    description: "Population size (50-200 typical, larger for complex problems)"
                ),
                "generations": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of generations (50-500 typical)"
                ),
                "crossoverRate": MCPSchemaProperty(
                    type: "number",
                    description: "Crossover probability (0.7-0.9). Higher = more recombination. Default: 0.8"
                ),
                "mutationRate": MCPSchemaProperty(
                    type: "number",
                    description: "Mutation probability (0.01-0.1). Higher = more exploration. Default: 0.02"
                ),
                "elitismCount": MCPSchemaProperty(
                    type: "integer",
                    description: "Number of best individuals to preserve each generation. Default: 2"
                ),
                "selectionMethod": MCPSchemaProperty(
                    type: "string",
                    description: "Selection strategy for parents",
                    enum: ["tournament", "roulette", "rank", "stochastic_universal"]
                ),
                "tournamentSize": MCPSchemaProperty(
                    type: "integer",
                    description: "Tournament size if using tournament selection (2-5). Default: 3"
                ),
                "encoding": MCPSchemaProperty(
                    type: "string",
                    description: "Chromosome encoding type",
                    enum: ["binary", "integer", "continuous", "mixed"]
                ),
                "searchRegion": MCPSchemaProperty(
                    type: "object",
                    description: "For continuous/mixed: {\"lower\": [...], \"upper\": [...]}"
                ),
                "problemType": MCPSchemaProperty(
                    type: "string",
                    description: "Problem hint for guidance",
                    enum: ["scheduling", "feature_selection", "routing", "knapsack", "portfolio_selection", "general"]
                )
            ],
            required: ["dimensions", "encoding"]
        )
    )

    public init() {}

    public func execute(arguments: [String: AnyCodable]?) async throws -> MCPToolCallResult {
        guard let args = arguments else {
            throw ToolError.invalidArguments("Missing arguments")
        }

        let dimensions = try args.getInt("dimensions")
        let encoding = try args.getString("encoding")
        let populationSize = args.getIntOptional("populationSize") ?? max(50, dimensions * 5)
        let generations = args.getIntOptional("generations") ?? 100
        let crossoverRate = args.getDoubleOptional("crossoverRate") ?? 0.8
        let mutationRate = args.getDoubleOptional("mutationRate") ?? (1.0 / Double(dimensions))
        let elitismCount = args.getIntOptional("elitismCount") ?? 2
        let selectionMethod = args.getStringOptional("selectionMethod") ?? "tournament"
        let tournamentSize = args.getIntOptional("tournamentSize") ?? 3
        let problemType = args.getStringOptional("problemType") ?? "general"

        let guide = """
        🧬 **Genetic Algorithm (GA) Optimization**

        **Problem Configuration:**
        - Variables: \(dimensions)
        - Encoding: \(encoding.uppercased())
        - Population size: \(populationSize) individuals
        - Generations: \(generations)

        **Evolutionary Parameters:**
        - Crossover rate: \(String(format: "%.2f", crossoverRate)) (\(Int(crossoverRate * 100))% of offspring via recombination)
        - Mutation rate: \(String(format: "%.4f", mutationRate)) (\(String(format: "%.2f", mutationRate * 100))% chance per gene)
        - Elitism: Keep best \(elitismCount) individuals
        - Selection: \(selectionMethod)\(selectionMethod == "tournament" ? " (size \(tournamentSize))" : "")

        **How Genetic Algorithms Work:**

        **Evolutionary Process:**
        ```
        1. INITIALIZATION
           Generate \(populationSize) random solutions (chromosomes)
           Evaluate fitness of each individual

        2. SELECTION (Repeat for \(generations) generations)
           Select parents based on fitness:
           \(getSelectionExplanation(method: selectionMethod, tournamentSize: tournamentSize))

        3. CROSSOVER (\(Int(crossoverRate * 100))% probability)
           Combine two parents to create offspring:
           \(getCrossoverExplanation(encoding: encoding))

        4. MUTATION (\(String(format: "%.2f", mutationRate * 100))% probability per gene)
           Random changes for exploration:
           \(getMutationExplanation(encoding: encoding))

        5. ELITISM
           Copy \(elitismCount) best individuals directly to next generation
           Guarantees: Best solution never lost

        6. REPLACEMENT
           New population replaces old
           (Elites + Selected offspring)

        7. TERMINATION
           Stop after \(generations) generations
           Or when fitness plateaus

        Return best individual found
        ```

        **Why GA Works:**
        - **Selection:** Survival of the fittest (good solutions reproduce more)
        - **Crossover:** Combines successful traits from parents
        - **Mutation:** Introduces diversity, prevents premature convergence
        - **Elitism:** Preserves best solutions found
        - **Population:** Maintains diversity, parallel search

        **Swift Implementation:**
        ```swift
        import BusinessMath

        // Create GA optimizer
        let ga = GeneticAlgorithmOptimizer<\(getChromosomeType(encoding: encoding))>(
            populationSize: \(populationSize),
            maxGenerations: \(generations),
            crossoverRate: \(crossoverRate),
            mutationRate: \(mutationRate),
            elitismCount: \(elitismCount),
            selectionMethod: .\(selectionMethod)\(selectionMethod == "tournament" ? "(size: \(tournamentSize))" : ""),
            encoding: .\(encoding)
        )

        \(getEncodingSetup(encoding: encoding, dimensions: dimensions))

        // Define fitness function (to MAXIMIZE)
        let fitness: @Sendable (\(getChromosomeType(encoding: encoding))) -> Double = { chromosome in
            \(getFitnessExample(problemType: problemType, encoding: encoding))
        }

        // Run GA
        let result = try await ga.evolve(
            fitness: fitness,
            constraints: []  // Add constraints if needed
        )

        // Analyze results
        print("Best solution: \\(result.bestChromosome)")
        print("Best fitness: \\(result.bestFitness)")
        print("Generation found: \\(result.generationFound)")
        print("Final population diversity: \\(result.diversity)")

        // Evolution history
        print("\\nFitness over generations:")
        for (gen, stats) in result.evolutionHistory.enumerated() {
            print("Gen \\(gen): Best=\\(stats.bestFitness), Avg=\\(stats.avgFitness), Diversity=\\(stats.diversity)")
        }
        ```

        **Encoding Guide:**

        \(getEncodingGuide(encoding: encoding))

        **Selection Methods:**

        | Method | How It Works | Best For | Diversity |
        |--------|-------------|----------|-----------|
        | Tournament | Random k individuals compete, best wins | General use, easy to tune | Medium |
        | Roulette | Probability ∝ fitness | Maximization problems | Low |
        | Rank | Based on rank not raw fitness | When fitness varies widely | High |
        | Stochastic Universal | Even spacing on roulette wheel | Maintaining diversity | High |

        **Current: \(selectionMethod)**
        \(getSelectionRecommendation(method: selectionMethod, problemType: problemType))

        **Crossover Operators:**

        \(getCrossoverOperators(encoding: encoding))

        **Mutation Strategies:**

        **Current Rate: \(String(format: "%.4f", mutationRate))**
        \(getMutationGuidance(mutationRate: mutationRate, dimensions: dimensions))

        **Parameter Tuning:**

        \(getGATuningGuide(problemType: problemType, dimensions: dimensions, populationSize: populationSize, generations: generations, mutationRate: mutationRate))

        **Convergence Diagnostics:**

        **Good Evolution:**
        ```
        Gen   Best Fitness   Avg Fitness   Diversity
        0     100           50            High
        20    450           200           Medium    ← Improving
        40    780           450           Medium    ← Still diverse
        60    920           750           Low       ← Converging
        80    985           900           Low       ← Near optimum
        100   998           950           Very Low  ← Converged
        ```

        **Premature Convergence (Bad):**
        ```
        Gen   Best Fitness   Avg Fitness   Diversity
        0     100           50            High
        10    450           400           Low       ← Lost diversity too fast!
        20    470           465           Very Low  ← Stuck
        100   475           473           Very Low  ← No improvement
        ```
        **Fix:** Increase mutation rate, reduce selection pressure (larger tournament)

        **Problem Types:**

        \(getProblemTypeGuidanceGA(problemType: problemType))

        **When to Use GA:**
        ✅ **Good for:**
        - Combinatorial optimization (TSP, scheduling, bin packing)
        - Discrete or mixed integer-continuous problems
        - Feature selection (subset selection)
        - Problems where you can define good fitness function
        - Multi-objective optimization (with NSGA-II variant)
        - Moderate dimensions (10-1000 variables)

        ❌ **Not ideal for:**
        - Simple continuous optimization (use gradient descent or PSO)
        - Very high dimensions (>10,000) without structure
        - When you need exact optimality guarantees
        - Real-time optimization (GA is iterative)
        - When evaluation is extremely expensive

        **GA vs Other Algorithms:**

        | Algorithm | Best For | Solution Quality | Speed |
        |-----------|----------|-----------------|-------|
        | GA | Combinatorial, discrete | Good | Medium |
        | PSO | Continuous, non-convex | Good | Fast |
        | Simulated Annealing | Discrete | Very good | Slow |
        | Branch-and-Bound | Integer programming | Optimal | Fast for small problems |
        | Greedy | Quick approximation | Fair | Very fast |

        **Troubleshooting:**

        **Problem: Premature convergence**
        - Increase population size to \(populationSize * 2)
        - Increase mutation rate to \(String(format: "%.4f", mutationRate * 2))
        - Use rank or stochastic universal selection
        - Reduce elitism count

        **Problem: Not finding good solutions**
        - Increase generations to \(generations * 2)
        - Check fitness function is correctly defined (maximization)
        - Verify encoding matches problem structure
        - Try different crossover/mutation operators

        **Problem: Too slow**
        - GA requires \(populationSize) × \(generations) = \(populationSize * generations) fitness evaluations
        - Reduce population size (minimum: \(max(30, dimensions * 2)))
        - Reduce generations
        - Implement early stopping if fitness plateaus
        - Parallelize fitness evaluation

        **Problem: Solutions violate constraints**
        - Use penalty function in fitness
        - Implement repair operator after crossover/mutation
        - Use specialized crossover that preserves feasibility
        - Add constraint handling to GA

        **Advanced Techniques:**

        **Adaptive Parameters:**
        ```swift
        // Adaptive mutation rate
        mutationRate(gen) = maxRate × (1 - gen/maxGenerations)
        // High early (exploration), low late (exploitation)
        ```

        **Island Model:**
        ```swift
        // Multiple populations evolve independently
        // Periodic migration of best individuals between islands
        // Better diversity, can parallelize
        ```

        **Hybrid GA:**
        ```swift
        // Combine GA with local search
        // GA for global exploration
        // Hill climbing for local refinement
        // Often called "memetic algorithm"
        ```

        **Multi-Objective GA (NSGA-II):**
        ```swift
        // Optimize multiple objectives simultaneously
        // Returns Pareto front of trade-off solutions
        // Example: Maximize return AND minimize risk
        ```

        **Performance Expectations:**

        | Problem Size | Population | Generations | Evaluations | Time Estimate |
        |--------------|-----------|-------------|-------------|---------------|
        | \(dimensions) vars | \(populationSize) | \(generations) | \(populationSize * generations) | \(estimateGATime(populationSize: populationSize, generations: generations)) |
        | 10 (binary) | 50 | 100 | 5,000 | 0.5-2s |
        | 50 (binary) | 200 | 200 | 40,000 | 5-20s |
        | 100 (continuous) | 500 | 500 | 250,000 | 30-120s |

        **Quality Indicators:**
        - **Best Fitness:** Should improve over generations
        - **Average Fitness:** Should converge toward best
        - **Diversity:** Should start high, gradually decrease
        - **Improvement Rate:** Early gens improve fast, later slow

        **Real-World Example - Project Selection:**
        ```swift
        // Select best 10 projects from 50 candidates
        // Budget constraint, maximize NPV

        let ga = GeneticAlgorithmOptimizer<BinaryChromosome>(
            populationSize: 100,
            maxGenerations: 50,
            encoding: .binary  // Each gene = select (1) or not (0)
        )

        let fitness: @Sendable (BinaryChromosome) -> Double = { chromosome in
            let selectedProjects = chromosome.genes.enumerated()
                .filter { $0.element == 1 }
                .map { projectList[$0.offset] }

            let totalCost = selectedProjects.map { $0.cost }.reduce(0, +)
            let totalNPV = selectedProjects.map { $0.npv }.reduce(0, +)

            // Penalty for violating budget
            if totalCost > budget {
                return totalNPV - 1000000 * (totalCost - budget)
            }

            return totalNPV
        }

        let result = try await ga.evolve(fitness: fitness)
        print("Selected projects: \\(result.bestChromosome.selectedIndices)")
        print("Total NPV: $\\(result.bestFitness)")
        ```

        **Next Steps:**
        1. Implement fitness function (remember: GA MAXIMIZES fitness)
        2. Choose appropriate encoding for your problem
        3. Start with default parameters
        4. Monitor evolution: fitness should improve over generations
        5. Tune parameters based on convergence behavior
        6. Consider hybrid approaches for large problems

        **Resources:**
        - Classic: Goldberg "Genetic Algorithms in Search, Optimization, and Machine Learning"
        - Tutorial: GA for Combinatorial Optimization
        - Example: Feature Selection with GA
        - API Reference: GeneticAlgorithmOptimizer.swift
        - Benchmarks: GA on standard problems (TSP, knapsack, scheduling)
        """

        return .success(text: guide)
    }

    // MARK: - Helper Functions

    private func getSelectionExplanation(method: String, tournamentSize: Int) -> String {
        switch method {
        case "tournament":
            return """
            Select \(tournamentSize) random individuals
                   Pick best from tournament as parent
                   Repeat for each parent needed
            """
        case "roulette":
            return """
            Probability of selection ∝ fitness
                   Spin roulette wheel to select parent
                   Higher fitness = larger slice
            """
        case "rank":
            return """
            Rank individuals by fitness
                   Selection probability based on rank, not raw fitness
                   Reduces selection pressure
            """
        case "stochastic_universal":
            return """
            Evenly spaced pointers on roulette wheel
                   More uniform selection
                   Maintains population diversity better
            """
        default:
            return "Unknown selection method"
        }
    }

    private func getCrossoverExplanation(encoding: String) -> String {
        switch encoding {
        case "binary":
            return """
            Parent 1: [1,0,1,1,0,1,0,0]
                   Parent 2: [0,1,0,1,1,0,1,1]
                            ↓ (crossover at position 4)
                   Child 1:  [1,0,1,1|1,0,1,1]
                   Child 2:  [0,1,0,1|0,1,0,0]
            """
        case "continuous":
            return """
            Parent 1: [1.5, 2.3, 0.8]
                   Parent 2: [2.1, 1.7, 1.2]
                            ↓ (blend crossover, α=0.5)
                   Child:    [1.8, 2.0, 1.0]
            """
        default:
            return """
            Combine genetic material from two parents
                   Create new offspring with mixed traits
            """
        }
    }

    private func getMutationExplanation(encoding: String) -> String {
        switch encoding {
        case "binary":
            return """
            Before: [1,0,1,1,0,1,0,0]
                              ↓ (flip bit 4)
                   After:  [1,0,1,1,1,1,0,0]
            """
        case "continuous":
            return """
            Before: [1.5, 2.3, 0.8]
                              ↓ (add Gaussian noise to gene 1)
                   After:  [1.5, 2.6, 0.8]
            """
        default:
            return """
            Random perturbation of genes
                   Maintains genetic diversity
            """
        }
    }

    private func getChromosomeType(encoding: String) -> String {
        switch encoding {
        case "binary": return "BinaryChromosome"
        case "integer": return "IntegerChromosome"
        case "continuous": return "VectorN<Double>"
        case "mixed": return "MixedChromosome"
        default: return "Chromosome"
        }
    }

    private func getEncodingSetup(encoding: String, dimensions: Int) -> String {
        switch encoding {
        case "binary":
            return """
        // Binary encoding: each gene is 0 or 1
                // Example: [1,0,1,0,1] = select items 0, 2, 4
                // Chromosome length: \(dimensions) genes
        """
        case "continuous":
            return """
        // Continuous encoding: real-valued genes
                // Define bounds for each variable
                let bounds = (
                    lower: VectorN(Array(repeating: 0.0, count: \(dimensions))),
                    upper: VectorN(Array(repeating: 1.0, count: \(dimensions)))
                )
        """
        case "integer":
            return """
        // Integer encoding: each gene is an integer
                // Define range for each variable
                let ranges = (0..<\(dimensions)).map { _ in 0...100 }
        """
        default:
            return "// Define encoding-specific setup"
        }
    }

    private func getFitnessExample(problemType: String, encoding: String) -> String {
        switch (problemType, encoding) {
        case ("feature_selection", "binary"):
            return """
                     // chromosome.genes[i] = 1 if feature i selected, 0 otherwise
                     let selectedFeatures = chromosome.genes.enumerated()
                        .filter { $0.element == 1 }
                        .map { featureList[$0.offset] }

                    let accuracy = trainModel(features: selectedFeatures)
                    let complexity = Double(selectedFeatures.count) * 0.01

                    return accuracy - complexity  // Maximize accuracy, penalize complexity
                    """
        case ("knapsack", "binary"):
            return """
                    // chromosome.genes[i] = 1 if item i included, 0 otherwise
                    var totalValue = 0.0
                    var totalWeight = 0.0

                    for (i, gene) in chromosome.genes.enumerated() {
                        if gene == 1 {
                            totalValue += items[i].value
                            totalWeight += items[i].weight
                        }
                    }

                    // Penalty if over capacity
                    if totalWeight > capacity {
                        return totalValue - 1000 * (totalWeight - capacity)
                    }

                    return totalValue
            """
        default:
            return """
                    // Your fitness function (to MAXIMIZE)
                    // Example: maximize some objective
                    let objective = calculateObjective(chromosome)
                    return objective
            """
        }
    }

    private func getEncodingGuide(encoding: String) -> String {
        switch encoding {
        case "binary":
            return """
            **Binary Encoding:**
            - Each gene is 0 or 1
            - Perfect for: Yes/no decisions, subset selection, feature selection
            - Chromosome: [1,0,1,1,0] = select items 0, 2, 3
            - Crossover: One-point, two-point, uniform
            - Mutation: Bit flip
            - Example: Knapsack, project selection, feature selection
            """
        case "continuous":
            return """
            **Continuous Encoding:**
            - Each gene is a real number
            - Perfect for: Continuous optimization, parameter tuning
            - Chromosome: [1.23, 4.56, 7.89]
            - Crossover: Blend (BLX-α), simulated binary (SBX)
            - Mutation: Gaussian, polynomial
            - Example: Portfolio weights, neural network training
            """
        case "integer":
            return """
            **Integer Encoding:**
            - Each gene is an integer
            - Perfect for: Discrete choices, permutations, scheduling
            - Chromosome: [2, 5, 1, 3, 4] (e.g., task order)
            - Crossover: Order crossover (OX), partially matched (PMX)
            - Mutation: Swap, insert, scramble
            - Example: TSP, job shop scheduling, assignment problems
            """
        case "mixed":
            return """
            **Mixed Encoding:**
            - Combines binary, integer, and continuous genes
            - Perfect for: Complex real-world problems
            - Chromosome: {binary: [1,0,1], integer: [3,5], continuous: [2.3, 4.5]}
            - Crossover: Type-specific per segment
            - Mutation: Type-specific per gene
            - Example: System design with discrete and continuous choices
            """
        default:
            return "Unknown encoding type"
        }
    }

    private func getSelectionRecommendation(method: String, problemType: String) -> String {
        switch (method, problemType) {
        case ("tournament", _):
            return "✓ Good general-purpose selection, easy to tune"
        case ("roulette", "knapsack"), ("roulette", "portfolio_selection"):
            return "✓ Works well for maximization problems with positive fitness"
        case ("rank", _):
            return "✓ Good when fitness values vary widely or have negative values"
        default:
            return ""
        }
    }

    private func getCrossoverOperators(encoding: String) -> String {
        switch encoding {
        case "binary":
            return """
            **Binary Crossover:**
            - **One-point:** Cut at one position, swap tails
            - **Two-point:** Cut at two positions, swap middle
            - **Uniform:** Each gene randomly from either parent

            Recommended: Uniform crossover for independent genes
            """
        case "continuous":
            return """
            **Continuous Crossover:**
            - **Blend (BLX-α):** Children in range [p1-α(p2-p1), p2+α(p2-p1)]
            - **Simulated Binary (SBX):** Mimics single-point for reals
            - **Arithmetic:** Weighted average of parents

            Recommended: BLX-0.5 for general problems
            """
        case "integer":
            return """
            **Integer/Permutation Crossover:**
            - **Order (OX):** Preserve relative order from parents
            - **Partially Mapped (PMX):** Preserve as much info as possible
            - **Cycle:** Create cycles of gene exchanges

            Recommended: OX for permutation problems (TSP, scheduling)
            """
        default:
            return "Crossover depends on encoding type"
        }
    }

    private func getMutationGuidance(mutationRate: Double, dimensions: Int) -> String {
        let recommended = 1.0 / Double(dimensions)

        var guidance = """
        **Mutation Rate Analysis:**
        - Current: \(String(format: "%.4f", mutationRate)) (\(String(format: "%.2f", mutationRate * 100))%)
        - Rule of thumb: 1/L = \(String(format: "%.4f", recommended)) where L=chromosome length
        """

        if mutationRate < recommended * 0.5 {
            guidance += "\n⚠️ Low mutation rate may cause premature convergence"
        } else if mutationRate > recommended * 2 {
            guidance += "\n⚠️ High mutation rate may prevent convergence"
        } else {
            guidance += "\n✓ Mutation rate in recommended range"
        }

        guidance += """


        **Mutation Impact:**
        - Expected mutations per child: \(String(format: "%.1f", mutationRate * Double(dimensions)))
        - With population \(100), expect ~\(Int(mutationRate * Double(dimensions) * 100)) mutations per generation
        """

        return guidance
    }

    private func getGATuningGuide(problemType: String, dimensions: Int, populationSize: Int, generations: Int, mutationRate: Double) -> String {
        let recommendedPop = dimensions * 5

        var guidance = """
        **Current Configuration:**
        - Population: \(populationSize) (recommended: ~\(recommendedPop))
        - Generations: \(generations) (typical: 50-200)
        - Mutation rate: \(String(format: "%.4f", mutationRate))
        """

        if populationSize < recommendedPop {
            guidance += "\n⚠️ Small population may lack diversity - consider increasing"
        }

        guidance += """


        **Tuning Strategy:**
        1. Start with defaults (current settings)
        2. Run and check convergence
        3. If premature convergence: ↑ population, ↑ mutation rate
        4. If too slow: ↓ generations, ↑ selection pressure
        5. If poor solutions: ↑ generations, ↑ population

        **For \(problemType) problems:**
        \(getProblemSpecificTuning(problemType: problemType))
        """

        return guidance
    }

    private func getProblemSpecificTuning(problemType: String) -> String {
        switch problemType {
        case "scheduling":
            return """
            - Use order/permutation encoding
                - Large population (200-500) due to combinatorial nature
                - Specialized crossover (OX, PMX)
                - Lower mutation rate (0.01-0.02)
            """
        case "feature_selection":
            return """
            - Binary encoding (1=select feature, 0=exclude)
                - Moderate population (50-100)
                - High crossover rate (0.8-0.9)
                - Low mutation rate to preserve good feature sets
            """
        case "knapsack":
            return """
            - Binary encoding
                - Penalty function for capacity constraint
                - Elitism important to preserve feasible solutions
                - Can use greedy initialization for better starting point
            """
        default:
            return """
            - Standard settings are a good starting point
                - Monitor fitness and diversity
                - Adjust based on convergence behavior
            """
        }
    }

    private func getProblemTypeGuidanceGA(problemType: String) -> String {
        switch problemType {
        case "scheduling":
            return """
                   **Scheduling Problems:**
                   - **Encoding:** Permutation (job order) or priority-based
                   - **Objective:** Minimize makespan, tardiness, or cost
                   - **Constraints:** Precedence, resource limits, deadlines
                   - **GA Benefits:** Handles complex constraints, finds good solutions quickly

                   Example: Job shop scheduling, employee rostering, course timetabling
                   ```
                   """
        case "feature_selection":
            return """
                   **Feature Selection:**
                   - **Encoding:** Binary (1=include feature, 0=exclude)
                   - **Objective:** Maximize accuracy, minimize features (multi-objective)
                   - **Evaluation:** Train ML model with selected features
                   - **GA Benefits:** Evaluates feature subsets holistically

                   Better than forward/backward selection for feature interactions
                   ```
                   """
        case "knapsack", "portfolio_selection":
            return """
                   **Selection Problems:**
                   - **Encoding:** Binary (1=select, 0=don't select)
                   - **Objective:** Maximize value subject to constraint
                   - **Challenge:** Maintaining feasibility
                   - **GA Benefits:** Naturally handles combinatorial nature

                   Can use repair operators or penalty functions for constraints
                   ```
                   """
        default:
            return """
            **General Combinatorial Optimization:**
            - GA excels when problem has discrete decisions
            - Works well with complex constraints
            - Good when gradient information unavailable
            """
        }
    }

    private func estimateGATime(populationSize: Int, generations: Int) -> String {
        let evals = populationSize * generations

        if evals < 10000 {
            return "1-5s (assuming fast fitness)"
        } else if evals < 100000 {
            return "10-60s (assuming fast fitness)"
        } else {
            return "1-10min (assuming fast fitness)"
        }
    }
}

// MARK: - Tool Registration

public func getHeuristicOptimizationTools() -> [any MCPToolHandler] {
    return [
        ParticleSwarmOptimizeTool(),
        GeneticAlgorithmOptimizeTool()
    ]
}
