import Testing
import Foundation
import MCP
@testable import BusinessMathMCP
@testable import SwiftMCPServer
@testable import BusinessMath

/// Tests for PeriodJSON and TimeSeriesJSON marshalling in TypeMarshalling.swift.
@Suite("Type Marshalling Tests")
struct TypeMarshallingTests {

    // MARK: - PeriodJSON

    @Suite("PeriodJSON Marshalling")
    struct PeriodJSONTests {

        @Test("Annual period round-trips correctly")
        func testAnnualRoundTrip() throws {
            let period = Period.year(2024)
            let json = PeriodJSON(from: period)
            let decoded = try json.toPeriod()
            #expect(decoded.year == 2024)
        }

        @Test("Monthly period round-trips correctly")
        func testMonthlyRoundTrip() throws {
            let period = Period.month(year: 2024, month: 6)
            let json = PeriodJSON(from: period)
            let decoded = try json.toPeriod()
            #expect(decoded.year == 2024)
            #expect(decoded.month == 6)
        }

        @Test("Quarterly period round-trips correctly")
        func testQuarterlyRoundTrip() throws {
            let period = Period.quarter(year: 2024, quarter: 2)
            let json = PeriodJSON(from: period)
            let decoded = try json.toPeriod()
            #expect(decoded.year == 2024)
        }

        @Test("String type 'annual' decodes to type 7")
        func testStringTypeAnnual() throws {
            let data = #"{"year": 2024, "type": "annual"}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(periodJSON.type == 7)
        }

        @Test("String type 'monthly' decodes to type 5")
        func testStringTypeMonthly() throws {
            let data = #"{"year": 2024, "month": 6, "type": "monthly"}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(periodJSON.type == 5)
        }

        @Test("String type 'quarterly' decodes to type 6")
        func testStringTypeQuarterly() throws {
            let data = #"{"year": 2024, "month": 3, "type": "quarterly"}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(periodJSON.type == 6)
        }

        @Test("String type 'daily' decodes to type 4")
        func testStringTypeDaily() throws {
            let data = #"{"year": 2024, "month": 3, "day": 15, "type": "daily"}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(periodJSON.type == 4)
        }

        @Test("Integer type decodes correctly")
        func testIntegerType() throws {
            let data = #"{"year": 2024, "month": 6, "type": 5}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(periodJSON.type == 5)
            let period = try periodJSON.toPeriod()
            #expect(period.month == 6)
        }

        @Test("Invalid string type throws MarshallingError")
        func testInvalidStringType() {
            let data = #"{"year": 2024, "type": "invalid"}"#.data(using: .utf8)!
            #expect(throws: (any Error).self) {
                let _ = try JSONDecoder().decode(PeriodJSON.self, from: data)
            }
        }

        @Test("Invalid integer type throws on toPeriod()")
        func testInvalidIntegerType() throws {
            let data = #"{"year": 2024, "type": 99}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(throws: MarshallingError.self) {
                let _ = try periodJSON.toPeriod()
            }
        }

        @Test("Sub-daily period types throw descriptive error")
        func testSubDailyThrows() throws {
            // type 0 = millisecond
            let data = #"{"year": 2024, "type": 0}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(throws: MarshallingError.self) {
                let _ = try periodJSON.toPeriod()
            }
        }

        @Test("Monthly period without month field throws")
        func testMonthlyMissingMonth() throws {
            let data = #"{"year": 2024, "type": 5}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(throws: MarshallingError.self) {
                let _ = try periodJSON.toPeriod()
            }
        }

        @Test("Daily period without day field throws")
        func testDailyMissingDay() throws {
            let data = #"{"year": 2024, "month": 3, "type": 4}"#.data(using: .utf8)!
            let periodJSON = try JSONDecoder().decode(PeriodJSON.self, from: data)
            #expect(throws: MarshallingError.self) {
                let _ = try periodJSON.toPeriod()
            }
        }
    }

    // MARK: - TimeSeriesJSON

    @Suite("TimeSeriesJSON Marshalling")
    struct TimeSeriesJSONTests {

        @Test("Wrapped format decodes correctly")
        func testWrappedFormat() throws {
            let json = """
            {
                "data": [
                    {"period": {"year": 2023, "type": 7}, "value": 100.0},
                    {"period": {"year": 2024, "type": 7}, "value": 110.0}
                ],
                "metadata": {"name": "Revenue", "unit": "USD"}
            }
            """
            let data = json.data(using: .utf8)!
            let tsJSON = try JSONDecoder().decode(TimeSeriesJSON.self, from: data)
            let ts = try tsJSON.toTimeSeries()
            #expect(ts.count == 2)
            #expect(ts.metadata.name == "Revenue")
        }

        @Test("Flat array format decodes via getTimeSeries MCP.Value path")
        func testFlatFormatMCPValue() throws {
            let json = """
            [
                {"period": {"year": 2023, "type": 7}, "value": 100.0},
                {"period": {"year": 2024, "type": 7}, "value": 110.0}
            ]
            """
            let data = json.data(using: .utf8)!
            let points = try JSONDecoder().decode([TimeSeriesJSON.TimeSeriesPointJSON].self, from: data)
            #expect(points.count == 2)
            #expect(points[0].value == 100.0)
        }

        @Test("TimeSeries round-trips through JSON")
        func testRoundTrip() throws {
            let periods = [Period.year(2023), Period.year(2024)]
            let values = [100.0, 110.0]
            let metadata = TimeSeriesMetadata(name: "Test")
            let ts = TimeSeries(periods: periods, values: values, metadata: metadata)

            let tsJSON = TimeSeriesJSON(from: ts)
            let decoded = try tsJSON.toTimeSeries()

            #expect(decoded.count == 2)
            #expect(decoded.metadata.name == "Test")
        }

        @Test("Missing metadata defaults to 'Unnamed'")
        func testMissingMetadata() throws {
            let json = """
            {
                "data": [
                    {"period": {"year": 2024, "type": 7}, "value": 50.0}
                ]
            }
            """
            let data = json.data(using: .utf8)!
            let tsJSON = try JSONDecoder().decode(TimeSeriesJSON.self, from: data)
            let ts = try tsJSON.toTimeSeries()
            #expect(ts.metadata.name == "Unnamed")
        }
    }
}
