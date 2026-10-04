import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// A bond tool builds one cash flow per coupon period and, for a yield, prices the bond once
/// per solver iteration. A maturity the caller chooses freely is therefore a request for as
/// much work as they care to ask for — a 100,000-year bond held a core for minutes — and a
/// maturity too large for `Int` stopped the process. Both are refused.
@Suite("Bond maturity bounds")
struct BondMaturityBoundTests {

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

    private static let yearsMessage =
        "Invalid arguments: yearsToMaturity must be a number of years from 0 to 100"
    private static let callMessage =
        "Invalid arguments: callYears must be a number of years from 0 to 100"

    @Test("A maturity beyond a century is refused by every bond tool that takes one",
          arguments: [100.5, 100_000, 1e300])
    func maturityTooLong(years: Double) async throws {
        let price = try await call(BondPriceTool(), """
            {"couponRate": 0.06, "yearsToMaturity": \(years), "yieldToMaturity": 0.05}
            """)
        #expect(price.isError)
        #expect(price.text == Self.yearsMessage)

        let ytm = try await call(BondYieldToMaturityTool(), """
            {"couponRate": 0.06, "yearsToMaturity": \(years), "marketPrice": 950}
            """)
        #expect(ytm.isError)
        #expect(ytm.text == Self.yearsMessage)

        let duration = try await call(BondDurationTool(), """
            {"couponRate": 0.06, "yearsToMaturity": \(years), "yieldToMaturity": 0.05}
            """)
        #expect(duration.isError)
        #expect(duration.text == Self.yearsMessage)

        let callable = try await call(CallableBondPriceTool(), """
            {"couponRate": 0.06, "yearsToMaturity": \(years), "callYears": 3, "callPrice": 1020,
             "riskFreeRate": 0.03, "creditSpread": 0.02, "volatility": 0.15}
            """)
        #expect(callable.isError)
        #expect(callable.text == Self.yearsMessage)

        let oas = try await call(OptionAdjustedSpreadTool(), """
            {"couponRate": 0.06, "yearsToMaturity": \(years), "callYears": 3, "callPrice": 1020,
             "marketPrice": 980, "riskFreeRate": 0.03, "volatility": 0.15}
            """)
        #expect(oas.isError)
        #expect(oas.text == Self.yearsMessage)
    }

    @Test("A negative maturity is refused")
    func negativeMaturity() async throws {
        let result = try await call(BondPriceTool(), """
            {"couponRate": 0.06, "yearsToMaturity": -1, "yieldToMaturity": 0.05}
            """)
        #expect(result.isError)
        #expect(result.text == Self.yearsMessage)
    }

    @Test("A call date beyond a century is refused", arguments: [101, 1e300])
    func callDateTooFar(years: Double) async throws {
        let callable = try await call(CallableBondPriceTool(), """
            {"couponRate": 0.06, "yearsToMaturity": 10, "callYears": \(years), "callPrice": 1020,
             "riskFreeRate": 0.03, "creditSpread": 0.02, "volatility": 0.15}
            """)
        #expect(callable.isError)
        #expect(callable.text == Self.callMessage)

        let oas = try await call(OptionAdjustedSpreadTool(), """
            {"couponRate": 0.06, "yearsToMaturity": 10, "callYears": \(years), "callPrice": 1020,
             "marketPrice": 980, "riskFreeRate": 0.03, "volatility": 0.15}
            """)
        #expect(oas.isError)
        #expect(oas.text == Self.callMessage)
    }

    @Test("A century bond is still priced")
    func centuryBond() async throws {
        let result = try await call(BondPriceTool(), """
            {"couponRate": 0.05, "yearsToMaturity": 100, "yieldToMaturity": 0.05}
            """)
        #expect(!result.isError)
        #expect(result.text.contains("Years to Maturity: 100.0"))
    }
}
