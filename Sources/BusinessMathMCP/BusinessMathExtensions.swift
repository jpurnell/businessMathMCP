import Foundation
import MCP
import BusinessMath
import Numerics
import SwiftMCPServer

// MARK: - BusinessMath Argument Extraction Extensions

extension Dictionary where Key == String, Value == AnyCodable {
    /// Get Period (BusinessMath-specific)
    public func getPeriod(_ key: String) throws -> Period {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }

        guard let dict = value.value as? [String: AnyCodable] else {
            throw ToolError.invalidArguments("\(key) must be an object")
        }

        guard let yearValue = dict["year"],
              let year = yearValue.value as? Int,
              let typeValue = dict["type"],
              let typeInt = typeValue.value as? Int,
              let periodType = PeriodType(rawValue: typeInt) else {
            throw ToolError.invalidArguments("\(key) must have valid year and type")
        }

        switch periodType {
        case .millisecond, .second, .minute, .hourly:
            throw ToolError.invalidArguments("Sub-daily periods not yet supported in MCP interface")
        case .semiannual:
            // `month` carries the half here, as it does for a quarter: 1-6 is the first
            // half, 7-12 the second.
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) semiannual period must have month")
            }
            let half = month <= 6 ? 1 : 2
            return Period.semiannual(year: year, half: half)
        case .custom:
            // A custom period is an arbitrary date range, which this JSON shape — a year
            // and an optional month/day — cannot express. Saying so beats guessing.
            throw ToolError.invalidArguments("\(key): custom periods need explicit start and end dates, which this interface does not accept")
        case .annual:
            return Period.year(year)
        case .quarterly:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) quarter must have month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) month must have month")
            }
            return Period.month(year: year, month: month)
        case .daily:
            guard let monthValue = dict["month"],
                  let month = monthValue.value as? Int,
                  let dayValue = dict["day"],
                  let day = dayValue.value as? Int else {
                throw ToolError.invalidArguments("\(key) day must have month and day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw ToolError.invalidArguments("\(key) has invalid date components")
            }
            return Period.day(date)
        }
    }

    /// Get TimeSeries (BusinessMath-specific)
    ///
    /// Accepts either:
    /// - A wrapped object: `{"data": [{...}], "metadata": {...}}`
    /// - A flat array of points: `[{"period": {...}, "value": 100}, ...]`
    public func getTimeSeries(_ key: String) throws -> TimeSeries<Double> {
        guard let value = self[key] else {
            throw ToolError.missingRequiredArgument(key)
        }

        // Convert to JSON and decode (use jsonValue to recursively unwrap AnyCodable)
        let jsonData = try JSONSerialization.data(withJSONObject: value.jsonValue)
        let decoder = JSONDecoder()

        // Two shapes are accepted: the wrapped object {"data": [...], "metadata": {...}}
        // and the flat array [{period: {...}, value: 100}, ...]. JSON says which one
        // arrived — an object opens with `{`, an array with `[` — so the shape is decided
        // before decoding rather than by decoding and catching. That matters for error
        // quality: a malformed *wrapped* series used to fall through to the array decode
        // and report "expected an array", hiding the field that was actually wrong.
        let openingToken = jsonData.first { !jsonWhitespace.contains($0) }

        guard openingToken == UInt8(ascii: "[") else {
            return try decoder.decode(TimeSeriesJSON.self, from: jsonData).toTimeSeries()
        }

        let points = try decoder.decode([TimeSeriesJSON.TimeSeriesPointJSON].self, from: jsonData)
        var periods: [Period] = []
        var values: [Double] = []
        for point in points {
            periods.append(try point.period.toPeriod())
            values.append(point.value)
        }
        return TimeSeries(periods: periods, values: values, metadata: TimeSeriesMetadata(name: "Unnamed"))
    }
}
