import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// Unit tests for both value extraction systems:
/// - [String: MCP.Value] extensions (ValueExtensions.swift)
/// - [String: AnyCodable] extensions (MCPCompat.swift)
@Suite("Value Extraction Tests")
struct ValueExtractionTests {

    // MARK: - MCP.Value Path (ValueExtensions.swift)

    @Suite("MCP.Value Extraction")
    struct MCPValueExtractionTests {

        @Test("getString extracts string value")
        func testGetString() throws {
            let dict: [String: MCP.Value] = ["key": .string("hello")]
            let result = try dict.getString("key")
            #expect(result == "hello")
        }

        @Test("getString throws on missing key")
        func testGetStringMissing() {
            let dict: [String: MCP.Value] = [:]
            #expect(throws: ValueExtractionError.self) {
                let _ = try dict.getString("missing")
            }
        }

        @Test("getString throws on wrong type")
        func testGetStringWrongType() {
            let dict: [String: MCP.Value] = ["key": .int(42)]
            #expect(throws: ValueExtractionError.self) {
                let _ = try dict.getString("key")
            }
        }

        @Test("getDouble extracts double value")
        func testGetDouble() throws {
            let dict: [String: MCP.Value] = ["key": .double(3.14)]
            let result = try dict.getDouble("key")
            #expect(abs(result - 3.14) < 1e-10)
        }

        @Test("getDouble coerces int to double")
        func testGetDoubleFromInt() throws {
            let dict: [String: MCP.Value] = ["key": .int(42)]
            let result = try dict.getDouble("key")
            #expect(result == 42.0)
        }

        @Test("getDouble throws on string")
        func testGetDoubleWrongType() {
            let dict: [String: MCP.Value] = ["key": .string("nope")]
            #expect(throws: ValueExtractionError.self) {
                let _ = try dict.getDouble("key")
            }
        }

        @Test("getInt extracts integer value")
        func testGetInt() throws {
            let dict: [String: MCP.Value] = ["key": .int(7)]
            let result = try dict.getInt("key")
            #expect(result == 7)
        }

        @Test("getBool extracts boolean value")
        func testGetBool() throws {
            let dict: [String: MCP.Value] = ["key": .bool(true)]
            let result = try dict.getBool("key")
            #expect(result == true)
        }

        @Test("getDoubleOptional returns nil for missing key")
        func testGetDoubleOptionalMissing() {
            let dict: [String: MCP.Value] = [:]
            #expect(dict.getDoubleOptional("missing") == nil)
        }

        @Test("getDoubleOptional coerces int")
        func testGetDoubleOptionalInt() {
            let dict: [String: MCP.Value] = ["key": .int(5)]
            #expect(dict.getDoubleOptional("key") == 5.0)
        }

        @Test("getDoubleArray handles mixed int and double")
        func testGetDoubleArrayMixed() throws {
            let dict: [String: MCP.Value] = [
                "arr": .array([.int(1), .double(2.5), .int(3)])
            ]
            let result = try dict.getDoubleArray("arr")
            #expect(result == [1.0, 2.5, 3.0])
        }

        @Test("getDoubleArray throws on non-numeric element")
        func testGetDoubleArrayBadElement() {
            let dict: [String: MCP.Value] = [
                "arr": .array([.int(1), .string("bad"), .int(3)])
            ]
            #expect(throws: ValueExtractionError.self) {
                let _ = try dict.getDoubleArray("arr")
            }
        }

        @Test("getStringArray extracts string array")
        func testGetStringArray() throws {
            let dict: [String: MCP.Value] = [
                "arr": .array([.string("a"), .string("b")])
            ]
            let result = try dict.getStringArray("arr")
            #expect(result == ["a", "b"])
        }
    }

    // MARK: - AnyCodable Path (MCPCompat.swift)

    @Suite("AnyCodable Extraction")
    struct AnyCodableExtractionTests {

        @Test("getString extracts string value")
        func testGetString() throws {
            let args: [String: AnyCodable] = ["key": AnyCodable("hello")]
            let result = try args.getString("key")
            #expect(result == "hello")
        }

        @Test("getString throws on missing key")
        func testGetStringMissing() {
            let args: [String: AnyCodable] = [:]
            #expect(throws: ToolError.self) {
                let _ = try args.getString("missing")
            }
        }

        @Test("getDouble extracts double value")
        func testGetDouble() throws {
            let args: [String: AnyCodable] = ["key": AnyCodable(3.14)]
            let result = try args.getDouble("key")
            #expect(abs(result - 3.14) < 1e-10)
        }

        @Test("getDouble coerces int to double")
        func testGetDoubleFromInt() throws {
            let args: [String: AnyCodable] = ["key": AnyCodable(42)]
            let result = try args.getDouble("key")
            #expect(result == 42.0)
        }

        @Test("getDouble throws on string")
        func testGetDoubleWrongType() {
            let args: [String: AnyCodable] = ["key": AnyCodable("nope")]
            #expect(throws: ToolError.self) {
                let _ = try args.getDouble("key")
            }
        }

        @Test("getInt extracts integer value")
        func testGetInt() throws {
            let args: [String: AnyCodable] = ["key": AnyCodable(7)]
            let result = try args.getInt("key")
            #expect(result == 7)
        }

        @Test("getBool extracts boolean value")
        func testGetBool() throws {
            let args: [String: AnyCodable] = ["key": AnyCodable(true)]
            let result = try args.getBool("key")
            #expect(result == true)
        }

        @Test("getDoubleOptional returns nil for missing key")
        func testGetDoubleOptionalMissing() {
            let args: [String: AnyCodable] = [:]
            #expect(args.getDoubleOptional("missing") == nil)
        }

        @Test("Wire-format round-trip: JSON to MCP.Value to AnyCodable extraction")
        func testWireFormatRoundTrip() throws {
            // This exercises the exact path real MCP requests take
            let args = try decodeArguments("""
                {"rate": 0.05, "periods": 10, "name": "test"}
            """)
            let rate = try args.getDouble("rate")
            let periods = try args.getInt("periods")
            let name = try args.getString("name")
            #expect(abs(rate - 0.05) < 1e-10)
            #expect(periods == 10)
            #expect(name == "test")
        }

        @Test("Wire-format array extraction")
        func testWireFormatArray() throws {
            let args = try decodeArguments("""
                {"values": [1, 2.5, 3]}
            """)
            let values = try args.getDoubleArray("values")
            #expect(values.count == 3)
            #expect(values[0] == 1.0)
            #expect(abs(values[1] - 2.5) < 1e-10)
            #expect(values[2] == 3.0)
        }
    }
}
