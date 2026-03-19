import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Smoke tests that exercise every tool with nil and empty arguments.
/// These catch tools that crash instead of returning errors on bad input.
@Suite("Schema Smoke Tests", .serialized)
struct SchemaSmokeTests {

    let handlers = allToolHandlers()

    @Test("Every tool handles nil arguments without crashing")
    func testNilArguments() async {
        // Tools with no required params (e.g., guide/help tools) may legitimately
        // succeed with nil args. We only check that nothing crashes.
        for handler in handlers {
            let schema = extractSchema(handler)
            do {
                let result = try await handler.execute(arguments: nil)
                if !schema.requiredParams.isEmpty {
                    #expect(result.isError,
                            "Tool \(handler.tool.name) has required params but succeeded with nil arguments")
                }
                // Tools with no required params are allowed to succeed
            } catch {
                // Throwing is acceptable — validation caught the issue
            }
        }
    }

    @Test("Every tool handles empty arguments without crashing")
    func testEmptyArguments() async {
        for handler in handlers {
            let schema = extractSchema(handler)
            // Only tools with required params should error on empty args
            guard !schema.requiredParams.isEmpty else { continue }

            do {
                let result = try await handler.execute(arguments: [:])
                #expect(result.isError,
                        "Tool \(handler.tool.name) has required params but didn't error on empty args")
            } catch {
                // Throwing is acceptable
            }
        }
    }

    @Test("Every tool handles auto-generated minimal valid arguments without crashing")
    func testMinimalValidArguments() async {
        for handler in handlers {
            let schema = extractSchema(handler)
            // Skip tools with no required params — already tested by nil args test
            guard !schema.requiredParams.isEmpty else { continue }

            let args = generateMinimalValidArgs(schema)
            do {
                let result = try await handler.execute(arguments: args)
                // Either success or isError=true — both acceptable.
                // The key assertion: we got here without an unhandled crash.
                _ = result
            } catch {
                // Any thrown error is acceptable — it means the tool validated
                // its inputs and rejected them. Auto-generated defaults may not
                // satisfy domain-specific constraints (e.g., rate < 1.0, matching
                // array lengths, structured object formats). The goal of this test
                // is to catch unhandled crashes (force unwraps, index out of bounds),
                // not domain validation errors.
            }
        }
    }

    @Test("Tool count matches expected registration total")
    func testToolCount() {
        // This test catches forgotten get*Tools() calls in allToolHandlers().
        // Update the expected count when adding new tool categories.
        let count = handlers.count
        #expect(count > 140,
                "Expected 140+ tools but got \(count). Did you add a new get*Tools() to allToolHandlers()?")
    }
}
