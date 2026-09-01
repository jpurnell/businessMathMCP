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
    func testSnakeCaseNames() throws {
        // The pattern is a literal and compiles, but `try!` would turn a typo in it into
        // a crashed suite rather than a failed test that names the pattern.
        let pattern = try NSRegularExpression(pattern: "^[a-z][a-z0-9_]*$")
        for handler in handlers {
            let name = handler.tool.name
            let range = NSRange(name.startIndex..<name.endIndex, in: name)
            // Count rather than test for presence: the anchored pattern must match the
            // whole name exactly once, so anything but 1 means the name is malformed.
            #expect(pattern.numberOfMatches(in: name, range: range) == 1,
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

    /// The primitive types a JSON Schema `items` declaration may name.
    private var validJSONSchemaTypes: Set<String> {
        ["string", "number", "integer", "boolean", "object", "array"]
    }

    @Test("Array properties have items defined")
    func testArrayItemsDefined() {
        for handler in handlers {
            let schema = extractSchema(handler)
            for (param, type) in schema.paramTypes where type == "array" {
                // `hasItems` records the declared element type, so assert it is a real JSON
                // Schema type — a present-but-nonsense value is as broken as an absent one.
                let itemType = schema.hasItems[param]
                #expect(itemType.map(validJSONSchemaTypes.contains) == true,
                        "Tool \(schema.name): array param '\(param)' must declare a valid items type, got \(itemType ?? "none")")
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
