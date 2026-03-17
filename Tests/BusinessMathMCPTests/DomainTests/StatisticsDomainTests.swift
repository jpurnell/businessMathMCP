import Testing
import Foundation
@testable import BusinessMathMCP

@Suite("Statistics Domain Tests")
struct StatisticsDomainTests {

    // MARK: - Statistical Tools

    @Test("calculate_correlation computes Pearson correlation")
    func testCorrelation() async throws {
        let tool = CalculateCorrelationTool()
        let args = argsFromJSON("""
            {"x": [1.0, 2.0, 3.0, 4.0, 5.0], "y": [2.0, 4.0, 5.0, 4.0, 5.0]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Correlation") || result.text.contains("correlation"))
    }

    @Test("linear_regression fits line to data")
    func testLinearRegression() async throws {
        let tool = LinearRegressionTool()
        let args = argsFromJSON("""
            {"x": [1.0, 2.0, 3.0, 4.0, 5.0], "y": [2.1, 3.9, 6.2, 7.8, 10.1]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Slope") || result.text.contains("slope") || result.text.contains("Regression"))
    }

    @Test("descriptive_stats_extended computes summary statistics")
    func testDescriptiveStats() async throws {
        let tool = DescriptiveStatsExtendedTool()
        let args = argsFromJSON("""
            {"values": [10.0, 20.0, 30.0, 40.0, 50.0, 60.0, 70.0, 80.0, 90.0, 100.0]}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Mean") || result.text.contains("mean"))
    }

    // MARK: - Hypothesis Testing Tools

    @Test("hypothesis_t_test performs two-sample t-test")
    func testTTest() async throws {
        let tool = HypothesisTTestTool()
        let args = argsFromJSON("""
            {
                "sample1": [85.0, 90.0, 88.0, 92.0, 87.0],
                "sample2": [78.0, 82.0, 80.0, 79.0, 81.0],
                "alpha": 0.05
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.lowercased().contains("t") || result.text.contains("statistic") || result.text.contains("test"))
    }

    @Test("calculate_sample_size determines required sample")
    func testSampleSize() async throws {
        let tool = CalculateSampleSizeTool()
        let args = argsFromJSON("""
            {"confidence": 0.95, "marginOfError": 0.03, "proportion": 0.5, "populationSize": 100000}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Sample") || result.text.contains("sample"))
    }

    // MARK: - Advanced Statistics Tools

    @Test("binomial_probability computes P(X=k)")
    func testBinomialProbability() async throws {
        let tool = BinomialProbabilityTool()
        let args = argsFromJSON("""
            {"n": 10, "k": 3, "p": 0.5}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Probability") || result.text.contains("probability") || result.text.contains("0.1"))
    }

    // MARK: - Bayesian Tools

    @Test("calculate_bayes_theorem updates prior with evidence")
    func testBayesTheorem() async throws {
        let tool = BayesTheoremTool()
        let args = argsFromJSON("""
            {"priorProbability": 0.01, "truePositiveRate": 0.99, "falsePositiveRate": 0.05}
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Posterior") || result.text.contains("posterior"))
    }
}
