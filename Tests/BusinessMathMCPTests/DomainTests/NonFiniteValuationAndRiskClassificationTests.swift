import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Several tools sort a number into words with a chain of comparisons. Every comparison with a
/// NaN is false, so a NaN fell through to the last arm and was reported as whatever that arm
/// says — a 0/0 Altman Z-Score read "Distress Zone - High bankruptcy risk" — and an overflowed
/// infinity took the first arm and read as the best case. Each chain now names the value that
/// is not a number, and says nothing else about it.
///
/// JSON cannot carry NaN or infinity, so the handlers are reached through overflow and 0/0 where
/// their arguments allow it. Three classifications cannot be reached that way and are tested
/// directly: the Bayes change (its inputs are range-checked first), the correlation strength
/// (the matrix is validated first) and the concordance p-value (BusinessMath clamps it).
@Suite("A value that is not a number is not classified as one")
struct NonFiniteValuationAndRiskClassificationTests {

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

    /// The first line of `text` that begins with `prefix`, without its indentation.
    private func line(_ text: String, startingWith prefix: String) -> String {
        for raw in text.split(whereSeparator: \.isNewline) {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix(prefix) {
                return trimmed
            }
        }
        return "<no line starting with \(prefix)>"
    }

    /// The line after the first one that begins with `prefix`, without its indentation.
    private func line(_ text: String, after prefix: String) -> String {
        let lines = text.split(whereSeparator: \.isNewline).map { $0.trimmingCharacters(in: .whitespaces) }
        guard let index = lines.firstIndex(where: { $0.hasPrefix(prefix) }),
              lines.indices.contains(index + 1) else {
            return "<no line after \(prefix)>"
        }
        return lines[index + 1]
    }

    // MARK: - calculate_dscr

    @Test("An overflowed DSCR is not rated")
    func dscrOverflow() async throws {
        let result = try await call(DebtServiceCoverageRatioTool(), """
            {"netOperatingIncome": 1e308, "totalDebtService": 1e-10}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "DSCR:") == "DSCR: ∞x")
        #expect(line(result.text, startingWith: "Assessment:")
                == "Assessment: Undefined - DSCR is not a finite number")
        #expect(line(result.text, startingWith: "Credit Risk:") == "Credit Risk: Not assessed")
    }

    @Test("A finite DSCR is rated as before", arguments: [
        (200.0, "Excellent - Very strong ability to service debt", "Very Low Risk"),
        (150.0, "Good - Strong ability to service debt", "Low Risk"),
        (125.0, "Adequate - Meets typical lender requirements", "Acceptable Risk"),
        (100.0, "Marginal - Below typical lender requirements", "Higher Risk"),
        (99.0, "Poor - Insufficient income to cover debt service", "High Risk / Default Risk"),
        (-50.0, "Poor - Insufficient income to cover debt service", "High Risk / Default Risk")
    ])
    func dscrFinite(income: Double, assessment: String, rating: String) async throws {
        let result = try await call(DebtServiceCoverageRatioTool(), """
            {"netOperatingIncome": \(income), "totalDebtService": 100}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "Assessment:") == "Assessment: \(assessment)")
        #expect(line(result.text, startingWith: "Credit Risk:") == "Credit Risk: \(rating)")
    }

    // MARK: - calculate_altman_z_score

    @Test("A Z-Score of 0/0 is not a distress zone, and an infinite one is not a safe zone",
          arguments: [(0.0, "NaN"), (5.0, "∞"), (-5.0, "-∞")])
    func altmanNonFinite(equity: Double, rendered: String) async throws {
        let result = try await call(AltmanZScoreTool(), """
            {"workingCapital": 1, "retainedEarnings": 1, "ebit": 1, "marketValueEquity": \(equity),
             "totalLiabilities": 0, "totalAssets": 10, "sales": 5}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "Z-Score:") == "Z-Score: \(rendered)")
        #expect(line(result.text, startingWith: "Prediction:")
                == "Prediction: Undefined - Z-Score is not a finite number")
        #expect(line(result.text, startingWith: "Bankruptcy Risk:") == "Bankruptcy Risk: Not assessed")
        #expect(line(result.text, startingWith: "Recommendation:")
                == "Recommendation: Check the inputs - a component ratio is not a finite number")
    }

    @Test("A finite Z-Score is zoned as before", arguments: [
        (30.0, "Safe Zone - Low bankruptcy risk", "Low", "Company appears financially healthy"),
        (20.0, "Gray Zone - Possible bankruptcy risk", "Medium", "Monitor closely, investigate further"),
        (5.0, "Distress Zone - High bankruptcy risk", "High", "Significant financial distress indicated")
    ])
    func altmanFinite(sales: Double, prediction: String, risk: String, recommendation: String) async throws {
        // Every other ratio is zero, so Z = sales / totalAssets: 3.0, 2.0 and 0.5.
        let result = try await call(AltmanZScoreTool(), """
            {"workingCapital": 0, "retainedEarnings": 0, "ebit": 0, "marketValueEquity": 0,
             "totalLiabilities": 10, "totalAssets": 10, "sales": \(sales)}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "Prediction:") == "Prediction: \(prediction)")
        #expect(line(result.text, startingWith: "Bankruptcy Risk:") == "Bankruptcy Risk: \(risk)")
        #expect(line(result.text, startingWith: "Recommendation:") == "Recommendation: \(recommendation)")
    }

    // MARK: - calculate_profitability_index

    @Test("A profitability index that is not a number is neither accepted nor rejected", arguments: [
        ("[-1, 1e308, 1e308]", "∞"),
        ("[-1e308, -1e308, 1e308, 1e308]", "NaN")
    ])
    func profitabilityIndexNonFinite(cashFlows: String, rendered: String) async throws {
        let result = try await call(ProfitabilityIndexTool(), """
            {"discountRate": 0, "cashFlows": \(cashFlows)}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "• Profitability Index:")
                == "• Profitability Index: \(rendered)")
        #expect(line(result.text, startingWith: "Decision:") == "Decision: Undefined")
        #expect(line(result.text, after: "Interpretation:")
                == "Profitability index is not a finite number - no decision can be drawn from it")
    }

    @Test("A finite profitability index is decided as before", arguments: [
        (130.0, "Strong Accept", "Excellent investment - generates significant value per dollar invested"),
        (110.0, "Accept", "Good investment - creates positive value"),
        (95.0, "Marginal", "Close to break-even - consider risk and alternatives"),
        (50.0, "Reject", "Poor investment - destroys value")
    ])
    func profitabilityIndexFinite(inflow: Double, decision: String, interpretation: String) async throws {
        let result = try await call(ProfitabilityIndexTool(), """
            {"discountRate": 0, "cashFlows": [-100, \(inflow)]}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "Decision:") == "Decision: \(decision)")
        #expect(line(result.text, after: "Interpretation:") == interpretation)
    }

    // MARK: - calculate_mirr

    @Test("An infinite gap between MIRR and IRR is not an unusual cash flow pattern")
    func mirrDifferenceOverflow() async throws {
        let result = try await call(MIRRTool(), """
            {"cashFlows": [-1, 1e308, 1e308], "financeRate": 0.1, "reinvestmentRate": 0.5}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "• Difference:") == "• Difference: ∞% higher")
        #expect(line(result.text, after: "• Difference:")
                == "• MIRR and IRR cannot be compared - the difference is not a finite number")
    }

    @Test("A finite gap between MIRR and IRR is explained as before")
    func mirrDifferenceFinite() async throws {
        let result = try await call(MIRRTool(), """
            {"cashFlows": [-1000, 300, 400, 500, 600], "financeRate": 0.08, "reinvestmentRate": 0.06}
            """)
        #expect(!result.isError)
        #expect(line(result.text, after: "• Difference:")
                == "• MIRR is significantly lower - IRR likely overstates realistic returns")
    }

    // MARK: - calculate_option_greeks

    @Test("Moneyness over a zero strike is neither in nor out of the money",
          arguments: [(100.0, "∞"), (0.0, "NaN")])
    func moneynessNonFinite(spot: Double, rendered: String) async throws {
        let result = try await call(OptionGreeksTool(), """
            {"optionType": "call", "spotPrice": \(spot), "strikePrice": 0, "timeToExpiry": 1,
             "riskFreeRate": 0.05, "volatility": 0.2}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "• Moneyness:")
                == "• Moneyness: Undefined (Spot/Strike = \(rendered))")
    }

    @Test("Finite moneyness is described as before", arguments: [
        (110.0, "• Moneyness: In-the-money (ITM) (Spot/Strike = 1.10)"),
        (100.0, "• Moneyness: At-the-money (ATM) (Spot/Strike = 1.00)"),
        (90.0, "• Moneyness: Out-of-the-money (OTM) (Spot/Strike = 0.90)")
    ])
    func moneynessFinite(spot: Double, expected: String) async throws {
        let result = try await call(OptionGreeksTool(), """
            {"optionType": "call", "spotPrice": \(spot), "strikePrice": 100, "timeToExpiry": 1,
             "riskFreeRate": 0.05, "volatility": 0.2}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "• Moneyness:") == expected)
    }

    // MARK: - analyze_credit_spread

    @Test("A Z-Score argument that is not a finite number is refused",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func creditSpreadZScoreNotFinite(zScore: Double) async {
        // JSON cannot say this; a caller inside the process can.
        let arguments: [String: AnyCodable] = [
            "zScore": AnyCodable(zScore), "maturityYears": AnyCodable(5.0)
        ]
        var message = "did not throw"
        do {
            _ = try await CreditSpreadAnalysisTool().execute(arguments: arguments)
        } catch {
            message = error.localizedDescription
        }
        #expect(message == "Invalid arguments: zScore must be a finite number")
    }

    @Test("A finite Z-Score argument is zoned as before", arguments: [
        (3.5, "Credit Zone: SAFE ZONE (Investment Grade)"),
        (2.99, "Credit Zone: GREY ZONE (Moderate Risk)"),
        (1.81, "Credit Zone: DISTRESS ZONE (High Risk)"),
        (-4.0, "Credit Zone: DISTRESS ZONE (High Risk)")
    ])
    func creditSpreadZScoreFinite(zScore: Double, expected: String) async throws {
        let result = try await call(CreditSpreadAnalysisTool(), """
            {"zScore": \(zScore), "maturityYears": 5}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "Credit Zone:") == expected)
    }

    // MARK: - calculate_bayes_theorem (not reachable from arguments)

    @Test("A change in probability that is not a number is not a substantial decrease",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func bayesChangeNotFinite(change: Double) {
        #expect(BayesTheoremTool.changeDescription(for: change)
                == "Undefined - change is not a finite number")
    }

    @Test("A finite change in probability is described as before", arguments: [
        (0.25, "Substantial increase"), (0.20, "Moderate increase"), (0.10, "Moderate increase"),
        (0.05, "Slight increase"), (0.01, "Slight increase"), (0.0, "Slight decrease"),
        (-0.01, "Slight decrease"), (-0.05, "Moderate decrease"), (-0.10, "Moderate decrease"),
        (-0.20, "Substantial decrease"), (-0.50, "Substantial decrease")
    ])
    func bayesChangeFinite(change: Double, expected: String) {
        #expect(BayesTheoremTool.changeDescription(for: change) == expected)
    }

    @Test("The Bayes tool reports the change it reported before")
    func bayesThroughHandler() async throws {
        let result = try await call(BayesTheoremTool(), """
            {"priorProbability": 0.01, "truePositiveRate": 0.95, "falsePositiveRate": 0.05}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "• Change from Prior:")
                == "• Change from Prior: +15.10% (Moderate increase)")
    }

    // MARK: - run_correlated_monte_carlo (not reachable from arguments)

    @Test("A correlation that is not a number has no strength and no direction")
    func correlationNotFinite() {
        let insights = RunCorrelatedMonteCarloTool().getCorrelationInsights(
            names: ["Revenue", "Costs"], correlations: [[1.0, .nan], [.nan, 1.0]])
        #expect(insights == "• Revenue ↔ Costs: n/a (not a finite number - strength and direction undefined)")
    }

    @Test("A finite correlation is described as before", arguments: [
        (0.85, "• Revenue ↔ Costs: 0.850 (Very strong positive)"),
        (0.8, "• Revenue ↔ Costs: 0.800 (Strong positive)"),
        (-0.7, "• Revenue ↔ Costs: -0.700 (Strong negative)"),
        (0.5, "• Revenue ↔ Costs: 0.500 (Moderate positive)"),
        (-0.3, "• Revenue ↔ Costs: -0.300 (Weak negative)"),
        (0.0, "• Revenue ↔ Costs: 0.000 (Very weak positive)")
    ])
    func correlationFinite(correlation: Double, expected: String) {
        let insights = RunCorrelatedMonteCarloTool().getCorrelationInsights(
            names: ["Revenue", "Costs"], correlations: [[1.0, correlation], [correlation, 1.0]])
        #expect(insights == expected)
    }

    // MARK: - concordance_analysis (not reached from arguments)

    @Test("A p-value that is not a number is not 'not significant'",
          arguments: [Double.nan, Double.infinity, -Double.infinity])
    func pValueNotFinite(pValue: Double) {
        #expect(ConcordanceAnalysisTool.significanceLine(pValue: pValue)
                == "✗ Significance could not be determined (p-value is not a finite number)")
    }

    @Test("A finite p-value is reported as before", arguments: [
        (0.0005, "✓ Highly significant (p < 0.001)"),
        (0.001, "✓ Very significant (p < 0.01)"),
        (0.005, "✓ Very significant (p < 0.01)"),
        (0.01, "✓ Significant (p < 0.05)"),
        (0.03, "✓ Significant (p < 0.05)"),
        (0.05, "✗ Not significant at α = 0.05 (p = 0.0500)"),
        (0.1353, "✗ Not significant at α = 0.05 (p = 0.1353)")
    ])
    func pValueFinite(pValue: Double, expected: String) {
        #expect(ConcordanceAnalysisTool.significanceLine(pValue: pValue) == expected)
    }

    @Test("The concordance tool reports the significance it reported before")
    func concordanceThroughHandler() async throws {
        let result = try await call(ConcordanceAnalysisTool(), """
            {"rank_sums": [2, 4, 6], "judges": 2, "items": 3}
            """)
        #expect(!result.isError)
        #expect(line(result.text, startingWith: "✗")
                == "✗ Not significant at α = 0.05 (p = 0.1353)")
    }
}
