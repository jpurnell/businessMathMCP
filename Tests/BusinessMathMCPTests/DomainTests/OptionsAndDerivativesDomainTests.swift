import Testing
import Foundation
@testable import BusinessMathMCP

@Suite("Options and Derivatives Domain Tests")
struct OptionsAndDerivativesDomainTests {

    // MARK: - Real Options Tools

    @Test("black_scholes_option prices a European call option")
    func testBlackScholes() async throws {
        let tool = BlackScholesOptionTool()
        let args = argsFromJSON("""
            {
                "spotPrice": 100,
                "strikePrice": 105,
                "timeToExpiry": 1.0,
                "riskFreeRate": 0.05,
                "volatility": 0.20,
                "optionType": "call"
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Option") || result.text.contains("Price") || result.text.contains("Call"))
    }

    @Test("real_options_expansion values option to expand")
    func testRealOptionsExpansion() async throws {
        let tool = RealOptionsExpansionTool()
        let args = argsFromJSON("""
            {
                "baseNPV": 5000000,
                "expansionCost": 2000000,
                "expansionNPV": 8000000,
                "volatility": 0.30,
                "timeToDecision": 2.0,
                "riskFreeRate": 0.05
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Option") || result.text.contains("Expansion") || result.text.contains("Value"))
    }

    // MARK: - Advanced Options Tools

    @Test("calculate_option_greeks computes option sensitivities")
    func testOptionGreeks() async throws {
        let tool = OptionGreeksTool()
        let args = argsFromJSON("""
            {
                "spotPrice": 100,
                "strikePrice": 100,
                "timeToExpiry": 0.5,
                "riskFreeRate": 0.05,
                "volatility": 0.25,
                "optionType": "call"
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Delta") || result.text.contains("Gamma") || result.text.contains("Greeks"))
    }

    // MARK: - Credit Derivatives Tools

    @Test("price_cds prices a credit default swap")
    func testCDSPricing() async throws {
        let tool = CDSPricingTool()
        let args = argsFromJSON("""
            {
                "spread": 150,
                "maturity": 5,
                "hazardRate": 0.02,
                "notional": 10000000,
                "recoveryRate": 0.40,
                "riskFreeRate": 0.03
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("CDS") || result.text.contains("Spread") || result.text.contains("Credit"))
    }

    @Test("merton_model estimates default probability from equity value")
    func testMertonModel() async throws {
        let tool = MertonModelTool()
        let args = argsFromJSON("""
            {
                "assetValue": 80000000,
                "assetVolatility": 0.30,
                "debtFaceValue": 30000000,
                "riskFreeRate": 0.03,
                "maturity": 1.0
            }
        """)
        let result = try await tool.execute(arguments: args)
        #expect(!result.isError)
        #expect(result.text.contains("Default") || result.text.contains("Merton") || result.text.contains("Probability"))
    }
}
