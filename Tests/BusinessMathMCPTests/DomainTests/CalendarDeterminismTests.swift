import Testing
import Foundation
import MCP
import BusinessMath
@testable import BusinessMathMCP
@testable import SwiftMCPServer

/// A calendar date a caller names — `{"year": 2024, "month": 3, "day": 15}` — is that day
/// wherever the server runs, and a bond that matures "in ten years" matures at the same instant
/// whichever machine prices it. BusinessMath reads every `Date` it is given with a Gregorian
/// calendar in UTC, so a date built with the machine's own calendar is a different day east of
/// UTC and an hour off across a daylight-saving change. These tests pin the instants, which do
/// not depend on the zone the suite runs in.
@Suite("Calendar dates do not move with the machine")
struct CalendarDeterminismTests {

    /// The instant in ISO 8601, in UTC, so a failure reads as a date rather than a number.
    private func utc(_ date: Date?) -> String {
        guard let date else { return "nil" }
        return date.formatted(.iso8601)
    }

    /// What a throwing expression says to the caller, or "did not throw".
    private func message(_ body: () throws -> Void) -> String {
        do {
            try body()
            return "did not throw"
        } catch {
            return error.localizedDescription
        }
    }

    // MARK: - The calendar itself

    @Test("The package calendar is Gregorian in UTC")
    func calendarIsGregorianUTC() {
        #expect(gregorianUTC.identifier == .gregorian)
        #expect(gregorianUTC.timeZone.identifier == "GMT")
        #expect(gregorianUTC.timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: 1_720_000_000)) == 0)
    }

    // MARK: - A named day

    @Test("A named day is midnight UTC of that day")
    func namedDayIsMidnightUTC() {
        #expect(utc(utcDay(year: 2024, month: 3, day: 15)) == "2024-03-15T00:00:00Z")
        #expect(utc(utcDay(year: 2024, month: 2, day: 29)) == "2024-02-29T00:00:00Z")
        #expect(utc(utcDay(year: 2023, month: 12, day: 31)) == "2023-12-31T00:00:00Z")
    }

    @Test("A day that is not on the calendar is refused rather than rolled forward",
          arguments: [(2024, 2, 30), (2023, 2, 29), (2024, 13, 1), (2024, 0, 10), (2024, 4, 31),
                      (2024, 6, 0), (2024, 6, -1)])
    func daysNotOnTheCalendar(year: Int, month: Int, day: Int) {
        #expect(utc(utcDay(year: year, month: month, day: day)) == "nil")
    }

    @Test("A daily period decoded from JSON starts at midnight UTC of the named day")
    func periodJSONDay() throws {
        let data = Data(#"{"year": 2024, "month": 3, "day": 15, "type": "daily"}"#.utf8)
        let period = try JSONDecoder().decode(PeriodJSON.self, from: data).toPeriod()
        #expect(utc(period.startDate) == "2024-03-15T00:00:00Z")
        #expect(period.label == "2024-03-15")
    }

    @Test("A daily period read from MCP values starts at midnight UTC of the named day")
    func valuePeriodDay() throws {
        let arguments: [String: MCP.Value] = [
            "period": .object(["year": .int(2024), "month": .int(3), "day": .int(15), "type": .int(4)])
        ]
        let period = try arguments.getPeriod("period")
        #expect(utc(period.startDate) == "2024-03-15T00:00:00Z")
        #expect(period.label == "2024-03-15")
    }

    @Test("A daily period read from tool arguments starts at midnight UTC of the named day")
    func anyCodablePeriodDay() throws {
        let arguments: [String: AnyCodable] = [
            "period": AnyCodable(MCP.Value.object(
                ["year": .int(2024), "month": .int(3), "day": .int(15), "type": .int(4)]))
        ]
        let period = try arguments.getPeriod("period")
        #expect(utc(period.startDate) == "2024-03-15T00:00:00Z")
        #expect(period.label == "2024-03-15")
    }

    @Test("The first of a month stays in that month")
    func firstOfMonthStaysInMonth() throws {
        let data = Data(#"{"year": 2025, "month": 1, "day": 1, "type": "daily"}"#.utf8)
        let period = try JSONDecoder().decode(PeriodJSON.self, from: data).toPeriod()
        #expect(utc(period.startDate) == "2025-01-01T00:00:00Z")
        #expect(period.label == "2025-01-01")
    }

    @Test("30 February is refused by every route a daily period arrives by")
    func thirtiethOfFebruary() {
        let json = message {
            let data = Data(#"{"year": 2024, "month": 2, "day": 30, "type": "daily"}"#.utf8)
            _ = try JSONDecoder().decode(PeriodJSON.self, from: data).toPeriod()
        }
        #expect(json == "Invalid data: Invalid date components")

        let value = message {
            let arguments: [String: MCP.Value] = [
                "period": .object(["year": .int(2024), "month": .int(2), "day": .int(30), "type": .int(4)])
            ]
            _ = try arguments.getPeriod("period")
        }
        #expect(value == "Invalid arguments: period has invalid date components")

        let anyCodable = message {
            let arguments: [String: AnyCodable] = [
                "period": AnyCodable(MCP.Value.object(
                ["year": .int(2024), "month": .int(2), "day": .int(30), "type": .int(4)]))
            ]
            _ = try arguments.getPeriod("period")
        }
        #expect(anyCodable == "Invalid arguments: period has invalid date components")
    }

    // MARK: - A number of years from an instant

    @Test("Adding years keeps the UTC date and time of day")
    func addingYearsKeepsUTCWallTime() {
        // 2024-10-04T14:30:00Z
        let start = Date(timeIntervalSince1970: 1_728_052_200)
        #expect(utc(start) == "2024-10-04T14:30:00Z")
        #expect(utc(dateByAdding(years: 10, to: start)) == "2034-10-04T14:30:00Z")
        #expect(utc(dateByAdding(years: 0, to: start)) == "2024-10-04T14:30:00Z")
    }

    @Test("Adding years across a daylight-saving change does not move the instant by an hour")
    func addingYearsAcrossDaylightSaving() {
        // 2026-03-09T12:00:00Z. New York is on daylight time that day in 2026 and on standard
        // time on the same date in 2027, so a New York calendar answers 13:00Z.
        let start = Date(timeIntervalSince1970: 1_773_057_600)
        #expect(utc(start) == "2026-03-09T12:00:00Z")
        #expect(utc(dateByAdding(years: 1, to: start)) == "2027-03-09T12:00:00Z")
    }

    @Test("Adding a year to 28 February UTC stays on 28 February UTC")
    func addingYearsNearLeapDay() {
        // 2024-02-28T16:00:00Z is already 29 February in Tokyo, where a local calendar lands on
        // 28 February Tokyo time — the 27th in UTC.
        let start = Date(timeIntervalSince1970: 1_709_136_000)
        #expect(utc(start) == "2024-02-28T16:00:00Z")
        #expect(utc(dateByAdding(years: 1, to: start)) == "2025-02-28T16:00:00Z")
    }

    @Test("Adding a year to 29 February lands on 28 February")
    func addingYearsFromLeapDay() {
        // 2024-02-29T09:00:00Z
        let start = Date(timeIntervalSince1970: 1_709_197_200)
        #expect(utc(start) == "2024-02-29T09:00:00Z")
        #expect(utc(dateByAdding(years: 1, to: start)) == "2025-02-28T09:00:00Z")
        #expect(utc(dateByAdding(years: 4, to: start)) == "2028-02-29T09:00:00Z")
    }
}
