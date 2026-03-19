import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Tests that verify tool response format and quality.
@Suite("Tool Response Format Tests")
struct ToolResponseFormatTests {

    @Test("Successful tool result has non-empty text content")
    func testSuccessfulResultContent() async throws {
        let tool = PresentValueTool()
        let args: [String: AnyCodable] = [
            "futureValue": AnyCodable(1000.0),
            "rate": AnyCodable(0.05),
            "periods": AnyCodable(10)
        ]

        let result = try await tool.execute(arguments: args)
        #expect(!result.isError, "Tool should succeed with valid args")
        #expect(!result.text.isEmpty, "Successful result must have non-empty text")
    }

    @Test("Error result from registry has isError=true and non-empty content")
    func testErrorResultFormat() async throws {
        let registry = ToolDefinitionRegistry()
        let result = try await registry.executeTool(
            name: "nonexistent_tool",
            arguments: nil
        )
        #expect(result.isError == true)
        #expect(!result.content.isEmpty, "Error result must have content")
    }

    @Test("MCPToolCallResult.success produces correct format")
    func testSuccessFactory() {
        let result = MCPToolCallResult.success(text: "test output")
        #expect(!result.isError)
        #expect(result.text == "test output")
    }

    @Test("MCPToolCallResult.error produces correct format")
    func testErrorFactory() {
        let result = MCPToolCallResult.error(message: "something failed")
        #expect(result.isError)
        #expect(result.text == "something failed")
    }

    @Test("ToolError descriptions are human-readable")
    func testToolErrorDescriptions() {
        let missing = ToolError.missingRequiredArgument("rate")
        #expect(missing.localizedDescription.contains("rate"))

        let invalid = ToolError.invalidArguments("must be a number")
        #expect(invalid.localizedDescription.contains("number"))

        let notFound = ToolError.toolNotFound("xyz")
        #expect(notFound.localizedDescription.contains("xyz"))
    }

    @Test("ValueExtractionError descriptions are human-readable")
    func testValueExtractionErrorDescriptions() {
        let missing = ValueExtractionError.missingRequiredArgument("periods")
        #expect(missing.localizedDescription.contains("periods"))

        let invalid = ValueExtractionError.invalidArguments("must be an array")
        #expect(invalid.localizedDescription.contains("array"))
    }

    // MARK: - Layer 7: Protocol Compliance

    @Test("ToolDefinitionRegistry.listTools() returns valid Tool objects for all registered tools")
    func testListToolsCompleteness() async throws {
        let registry = ToolDefinitionRegistry()
        let handlers = allToolHandlers()
        for handler in handlers {
            try await registry.register(handler.toToolDefinition())
        }
        let tools = await registry.listTools()

        for tool in tools {
            #expect(!tool.name.isEmpty, "Listed tool must have non-empty name")
            #expect(!(tool.description ?? "").isEmpty, "Tool \(tool.name) must have non-empty description")
            if case .object(let schemaDict) = tool.inputSchema {
                #expect(schemaDict["type"] != nil, "Tool \(tool.name) schema must have 'type'")
            } else {
                Issue.record("Tool \(tool.name) inputSchema is not a Value.object")
            }
        }

        let uniqueHandlerNames = Set(handlers.map { $0.tool.name })
        #expect(tools.count == uniqueHandlerNames.count,
                "listTools() returned \(tools.count) but \(uniqueHandlerNames.count) unique handlers registered")
    }

    @Test("All tool inputSchemas convert to MCP.Value without error")
    func testSchemaToValueConversion() throws {
        let handlers = allToolHandlers()
        for handler in handlers {
            do {
                let _ = try handler.tool.inputSchema.toValue()
            } catch {
                Issue.record("Tool \(handler.tool.name) schema toValue() failed: \(error)")
            }
        }
    }

    @Test("Full tools/list to tools/call round-trip through registry")
    func testFullRegistryRoundTrip() async throws {
        let registry = ToolDefinitionRegistry()
        let handlers = allToolHandlers()
        for handler in handlers {
            try await registry.register(handler.toToolDefinition())
        }

        // Verify tool is listed
        let tools = await registry.listTools()
        let pvTool = tools.first(where: { $0.name == "calculate_present_value" })
        #expect(pvTool != nil, "calculate_present_value must be in listed tools")

        // Execute via registry with MCP.Value args (the real wire path)
        let result = try await registry.executeTool(
            name: "calculate_present_value",
            arguments: [
                "futureValue": .double(1000),
                "rate": .double(0.05),
                "periods": .int(10)
            ]
        )
        #expect(result.isError != true, "Round-trip execution should succeed")
        #expect(!result.content.isEmpty, "Result must have content")
    }
}
