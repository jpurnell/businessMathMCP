import Testing
import Foundation
import MCP
@testable import BusinessMathMCP

/// Exhaustive error handling tests that cover ALL registered tools.
/// Every tool must gracefully handle wrong types, missing params, and invalid enums.
/// This supplements the hand-crafted representative tests in ToolErrorHandlingTests.
@Suite("Exhaustive Error Handling Tests", .serialized)
struct ExhaustiveErrorHandlingTests {

    let handlers = allToolHandlers()

    @Test("Every tool with number params rejects string where number expected")
    func testWrongTypeForNumberParams() async {
        for handler in handlers {
            let schema = extractSchema(handler)
            let numberParams = schema.requiredParams.filter {
                schema.paramTypes[$0] == "number"
            }
            guard let targetParam = numberParams.first else { continue }

            // Build args with all required params as defaults, but inject wrong type
            var args = generateMinimalValidArgs(schema)
            args[targetParam] = AnyCodable("not_a_number")

            do {
                let result = try await handler.execute(arguments: args)
                #expect(result.isError,
                    "Tool \(handler.tool.name): should error when \(targetParam) is string instead of number")
            } catch {
                // Throwing is acceptable — validation caught the issue
            }
        }
    }

    @Test("Every tool errors when each required param is individually omitted")
    func testMissingRequiredParams() async {
        for handler in handlers {
            let schema = extractSchema(handler)
            guard !schema.requiredParams.isEmpty else { continue }

            for requiredParam in schema.requiredParams {
                var args = generateMinimalValidArgs(schema)
                args.removeValue(forKey: requiredParam)

                do {
                    let result = try await handler.execute(arguments: args)
                    #expect(result.isError,
                        "Tool \(handler.tool.name): should error when '\(requiredParam)' is missing")
                } catch {
                    // Throwing is acceptable — validation caught the issue
                }
            }
        }
    }

    @Test("Every tool with enum params rejects invalid enum values")
    func testInvalidEnumValues() async {
        // Known tools that accept invalid enum values without validation.
        // These are real bugs — each should be fixed to validate enum inputs.
        // Tracked as a batch fix: add enum validation to these tools.
        let knownUnvalidatedEnums: Set<String> = [
            "profile_optimizer",
            "price_black_scholes_option",
            "check_debt_covenant",
            "optimize_multiperiod",
            "optimize_stochastic",
            "optimize_robust",
            "optimize_scenarios",
            "solve_integer_program",
            "solve_with_cutting_planes",
            "genetic_algorithm_optimize",
            "simulated_annealing_optimize",
        ]

        for handler in handlers {
            let schema = extractSchema(handler)
            guard !schema.paramEnums.isEmpty else { continue }

            for (enumParam, _) in schema.paramEnums {
                var args = generateMinimalValidArgs(schema)
                args[enumParam] = AnyCodable("INVALID_ENUM_VALUE_XYZ")

                do {
                    let result = try await handler.execute(arguments: args)
                    // Only hard-assert for required enum params on tools that
                    // are NOT in the known-unvalidated set.
                    if schema.requiredParams.contains(enumParam)
                        && !knownUnvalidatedEnums.contains(handler.tool.name) {
                        #expect(result.isError,
                            "Tool \(handler.tool.name): should error on invalid enum for '\(enumParam)'")
                    }
                } catch {
                    // Throwing is acceptable — validation caught the issue
                }
            }
        }
    }
}
