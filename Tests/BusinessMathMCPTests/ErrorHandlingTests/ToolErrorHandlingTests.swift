import Testing
import Foundation
@testable import BusinessMathMCP

/// Error handling tests using representative tools from different parameter patterns.
/// Rather than testing every tool, we sample one tool per pattern type.
@Suite("Tool Error Handling Tests")
struct ToolErrorHandlingTests {

    // MARK: - Simple Numeric Tool Errors

    @Suite("Simple Numeric Tool Errors")
    struct SimpleNumericErrors {

        @Test("calculate_present_value rejects nil arguments")
        func testNilArgs() async {
            let tool = PresentValueTool()
            do {
                let result = try await tool.execute(arguments: nil)
                #expect(result.isError, "Should error on nil arguments")
            } catch {
                // Throwing is acceptable
            }
        }

        @Test("calculate_present_value rejects wrong type for number param")
        func testWrongTypeForNumber() async {
            let tool = PresentValueTool()
            let args = try! decodeArguments("""
                {"futureValue": "not a number", "rate": 0.05, "periods": 10}
            """)
            do {
                let result = try await tool.execute(arguments: args)
                #expect(result.isError, "Should error on string where number expected")
            } catch {
                // Throwing is acceptable
            }
        }

        @Test("calculate_present_value rejects missing required param")
        func testMissingRequired() async {
            let tool = PresentValueTool()
            let args: [String: AnyCodable] = [
                "futureValue": AnyCodable(1000.0)
                // Missing "rate" and "periods"
            ]
            do {
                let result = try await tool.execute(arguments: args)
                #expect(result.isError, "Should error on missing required params")
            } catch {
                // Throwing is acceptable
            }
        }
    }

    // MARK: - Array Tool Errors

    @Suite("Array Tool Errors")
    struct ArrayErrors {

        @Test("NPV tool rejects missing cashFlows")
        func testMissingArray() async {
            let tool = NPVTool()
            let args: [String: AnyCodable] = [
                "rate": AnyCodable(0.10)
                // Missing "cashFlows"
            ]
            do {
                let result = try await tool.execute(arguments: args)
                #expect(result.isError, "Should error on missing array param")
            } catch {
                // Throwing is acceptable
            }
        }
    }

    // MARK: - Enum Parameter Errors

    @Suite("Enum Parameter Errors")
    struct EnumErrors {

        @Test("create_distribution rejects invalid distribution type")
        func testInvalidEnum() async {
            let tool = CreateDistributionTool()
            let args = try! decodeArguments("""
                {
                    "type": "invalid_distribution",
                    "parameters": {"mean": 0.0, "stdDev": 1.0}
                }
            """)
            do {
                let result = try await tool.execute(arguments: args)
                #expect(result.isError,
                        "Should reject invalid distribution type")
            } catch {
                // Throwing is acceptable
            }
        }
    }

    // MARK: - Registry Error Wrapping

    @Suite("Registry Error Wrapping")
    struct RegistryErrorWrapping {

        @Test("Registry wraps thrown errors into CallTool.Result")
        func testErrorWrapping() async throws {
            let registry = ToolDefinitionRegistry()
            for handler in getTVMTools() {
                try await registry.register(handler.toToolDefinition())
            }

            // Call with missing required args — should return error result, not throw
            let result = try await registry.executeTool(
                name: "calculate_present_value",
                arguments: [:]
            )
            #expect(result.isError == true,
                    "Registry should wrap extraction errors into error results")
            // Verify it didn't throw — the fact we got here means it didn't
        }
    }
}
