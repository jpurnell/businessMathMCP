import Testing
import Foundation
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Automated schema invariant tests that cover ALL registered tools.
/// Each test iterates every tool handler and asserts a structural property.
@Suite("Schema Contract Tests")
struct SchemaContractTests {

    let handlers = allToolHandlers()

    // MARK: - Name & Description

    @Test("Every tool has a non-empty name")
    func testNonEmptyNames() {
        for handler in handlers {
            #expect(!handler.tool.name.isEmpty,
                    "Tool must have a non-empty name")
        }
    }

    @Test("Every tool has a non-empty description")
    func testNonEmptyDescriptions() {
        for handler in handlers {
            #expect(!handler.tool.description.isEmpty,
                    "Tool \(handler.tool.name) must have a description")
        }
    }

    @Test("Tool names follow snake_case convention")
    func testSnakeCaseNames() {
        let pattern = try! NSRegularExpression(pattern: "^[a-z][a-z0-9_]*$")
        for handler in handlers {
            let name = handler.tool.name
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            #expect(pattern.firstMatch(in: name, range: range) != nil,
                    "Tool name '\(name)' must be snake_case")
        }
    }

    @Test("No duplicate tool names")
    func testNoDuplicateNames() {
        var seen = Set<String>()
        var duplicates: [String] = []
        for handler in handlers {
            let name = handler.tool.name
            if seen.contains(name) {
                duplicates.append(name)
            }
            seen.insert(name)
        }
        #expect(duplicates.isEmpty,
                "Duplicate tool names: \(duplicates)")
    }

    // MARK: - Schema Structure

    @Test("Schema type is always 'object'")
    func testSchemaTypeIsObject() {
        for handler in handlers {
            #expect(handler.tool.inputSchema.type == "object",
                    "Tool \(handler.tool.name): schema type must be 'object', got '\(handler.tool.inputSchema.type)'")
        }
    }

    @Test("All required parameters exist in properties")
    func testRequiredParamsInProperties() {
        for handler in handlers {
            let schema = extractSchema(handler)
            for required in schema.requiredParams {
                #expect(schema.allParams.contains(required),
                        "Tool \(schema.name): required param '\(required)' not found in properties \(schema.allParams)")
            }
        }
    }

    @Test("Property types are valid JSON Schema types")
    func testValidPropertyTypes() {
        let validTypes: Set<String> = ["string", "number", "integer", "boolean", "array", "object", "null"]
        for handler in handlers {
            let schema = extractSchema(handler)
            for (param, type) in schema.paramTypes {
                #expect(validTypes.contains(type),
                        "Tool \(schema.name): param '\(param)' has invalid type '\(type)'")
            }
        }
    }

    @Test("Array properties have items defined")
    func testArrayItemsDefined() {
        for handler in handlers {
            let schema = extractSchema(handler)
            for (param, type) in schema.paramTypes where type == "array" {
                #expect(schema.hasItems[param] != nil,
                        "Tool \(schema.name): array param '\(param)' must have items defined")
            }
        }
    }

    @Test("Enum properties have at least 2 values")
    func testEnumMinimumValues() {
        for handler in handlers {
            let schema = extractSchema(handler)
            for (param, enumVals) in schema.paramEnums {
                #expect(enumVals.count >= 2,
                        "Tool \(schema.name): enum param '\(param)' needs 2+ values, has \(enumVals.count)")
            }
        }
    }

    // MARK: - SDK Conversion

    @Test("All tools convert to SDK ToolDefinition without error")
    func testSDKConversion() throws {
        for handler in handlers {
            #expect(throws: Never.self) {
                let _ = try handler.toToolDefinition()
            }
        }
    }
}
