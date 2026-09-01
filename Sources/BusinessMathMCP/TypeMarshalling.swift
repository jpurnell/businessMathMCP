import Foundation
import BusinessMath
import Numerics
import MCP
import SwiftMCPServer

// MARK: - JSON-Compatible Type Wrappers

/// JSON-compatible representation of a Period
public struct PeriodJSON: Codable, Sendable {
    /// The year.
    public let year: Int
    /// The month.
    public let month: Int?
    /// The day.
    public let day: Int?
    /// The type.
    public let type: Int

    /// Creates the JSON form from a `Period`.
    public init(from period: Period) {
        self.year = period.year
        self.month = period.month
        self.day = period.day
        self.type = period.type.rawValue
    }

    /// Maps string period type names to PeriodType raw values
    private static let typeStringMap: [String: Int] = [
        "millisecond": 0, "second": 1, "minute": 2, "hourly": 3,
        "daily": 4, "monthly": 5, "quarterly": 6, "annual": 7
    ]

    /// Creates the JSON form from a `Decoder`.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.year = try container.decode(Int.self, forKey: .year)
        self.month = try container.decodeIfPresent(Int.self, forKey: .month)
        self.day = try container.decodeIfPresent(Int.self, forKey: .day)

        // Accept type as either Int or String (e.g., 5 or "monthly"). The Int attempt
        // failing is the ordinary path to the String attempt, not an error to discard —
        // `do`/`catch` says that, where `try?` looked like a swallowed failure.
        do {
            self.type = try container.decode(Int.self, forKey: .type)
        } catch {
            let typeStr = try container.decode(String.self, forKey: .type)
            guard let mapped = PeriodJSON.typeStringMap[typeStr.lowercased()] else {
                throw MarshallingError.invalidPeriodType("type must be an Int (0-7) or String (e.g., \"monthly\")")
            }
            self.type = mapped
        }
    }

    private enum CodingKeys: String, CodingKey {
        case year, month, day, type
    }

    /// Converts back to `Period`.
    /// - Throws: If the JSON carries values `Period` does not accept.
    public func toPeriod() throws -> Period {
        guard let periodType = PeriodType(rawValue: type) else {
            throw MarshallingError.invalidPeriodType(String(type))
        }

        switch periodType {
        case .annual:
            return Period.year(year)
        case .quarterly:
            // For quarterly, calculate quarter number from month
            guard let month = month else {
                throw MarshallingError.missingField("month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let month = month else {
                throw MarshallingError.missingField("month")
            }
            return Period.month(year: year, month: month)
        case .millisecond, .second, .minute, .hourly:
            // Sub-daily periods not yet supported in MCP JSON interface
            // TODO: Extend PeriodJSON to include hour, minute, second, millisecond fields
            throw MarshallingError.invalidData("Sub-daily periods not yet supported in MCP interface")
        case .semiannual:
            // `month` carries the half, as it does for a quarter: 1-6 first, 7-12 second.
            guard let month = month else {
                throw MarshallingError.missingField("month")
            }
            return Period.semiannual(year: year, half: month <= 6 ? 1 : 2)
        case .custom:
            // An arbitrary date range; `PeriodJSON` carries a year and optional month/day,
            // which cannot express one.
            throw MarshallingError.invalidData("Custom periods need explicit start and end dates, which PeriodJSON does not carry")
        case .daily:
            // For daily periods, need to construct a Date
            guard let month = month, let day = day else {
                throw MarshallingError.missingField("month or day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw MarshallingError.invalidData("Invalid date components")
            }
            return Period.day(date)
        }
    }
}

/// JSON-compatible representation of a TimeSeries
public struct TimeSeriesJSON: Codable, Sendable {
    /// The data.
    public let data: [TimeSeriesPointJSON]
    /// The metadata.
    public let metadata: TimeSeriesMetadataJSON?

    /// The JSON form of time series point, as carried over MCP.
    public struct TimeSeriesPointJSON: Codable, Sendable {
        /// The period.
        public let period: PeriodJSON
        /// The value.
        public let value: Double
    }

    /// The JSON form of time series metadata, as carried over MCP.
    public struct TimeSeriesMetadataJSON: Codable, Sendable {
        /// The name.
        public let name: String
        /// The description.
        public let description: String?
        /// The unit.
        public let unit: String?
    }

    /// Creates the value.
    public init(from timeSeries: TimeSeries<Double>) {
        // Combine periods and values into data points
        let periods = timeSeries.periods
        let values = timeSeries.valuesArray

        self.data = zip(periods, values).map { period, value in
            TimeSeriesPointJSON(
                period: PeriodJSON(from: period),
                value: value
            )
        }

        self.metadata = TimeSeriesMetadataJSON(
            name: timeSeries.metadata.name,
            description: timeSeries.metadata.description,
            unit: timeSeries.metadata.unit
        )
    }

    /// Converts back to `TimeSeries`.
    /// - Throws: If the JSON carries values `TimeSeries` does not accept.
    public func toTimeSeries() throws -> TimeSeries<Double> {
        var periods: [Period] = []
        var values: [Double] = []

        for point in data {
            let period = try point.period.toPeriod()
            periods.append(period)
            values.append(point.value)
        }

        let metadata: TimeSeriesMetadata
        if let md = self.metadata {
            metadata = TimeSeriesMetadata(
                name: md.name,
                description: md.description,
                unit: md.unit
            )
        } else {
            metadata = TimeSeriesMetadata(name: "Unnamed")
        }

        return TimeSeries(periods: periods, values: values, metadata: metadata)
    }
}

/// JSON-compatible representation of cash flows
public struct CashFlowJSON: Codable, Sendable {
    /// The period.
    public let period: Int
    /// The amount.
    public let amount: Double

    /// Creates the value.
    public init(period: Int, amount: Double) {
        self.period = period
        self.amount = amount
    }
}

/// JSON-compatible representation of an amortization schedule
public struct AmortizationScheduleJSON: Codable, Sendable {
    /// The payments.
    public let payments: [AmortizationPaymentJSON]
    /// The summary.
    public let summary: SummaryJSON

    /// The JSON form of amortization payment, as carried over MCP.
    public struct AmortizationPaymentJSON: Codable, Sendable {
        /// The period.
        public let period: Int
        /// The payment.
        public let payment: Double
        /// The principal.
        public let principal: Double
        /// The interest.
        public let interest: Double
        /// The balance.
        public let balance: Double
    }

    /// The JSON form of summary, as carried over MCP.
    public struct SummaryJSON: Codable, Sendable {
        /// The total payments.
        public let totalPayments: Double
        /// The total principal.
        public let totalPrincipal: Double
        /// The total interest.
        public let totalInterest: Double
    }
}

/// JSON-compatible representation of financial ratios
public struct FinancialRatiosJSON: Codable, Sendable {
    /// The profitability.
    public let profitability: ProfitabilityRatiosJSON?
    /// The efficiency.
    public let efficiency: EfficiencyRatiosJSON?
    /// The liquidity.
    public let liquidity: LiquidityRatiosJSON?
    /// The solvency.
    public let solvency: SolvencyRatiosJSON?

    /// The JSON form of profitability ratios, as carried over MCP.
    public struct ProfitabilityRatiosJSON: Codable, Sendable {
        /// The return on assets.
        public let returnOnAssets: Double?
        /// The return on equity.
        public let returnOnEquity: Double?
        /// The gross margin.
        public let grossMargin: Double?
        /// The operating margin.
        public let operatingMargin: Double?
        /// The net margin.
        public let netMargin: Double?
    }

    /// The JSON form of efficiency ratios, as carried over MCP.
    public struct EfficiencyRatiosJSON: Codable, Sendable {
        /// The asset turnover.
        public let assetTurnover: Double?
        /// The inventory turnover.
        public let inventoryTurnover: Double?
        /// The receivables turnover.
        public let receivablesTurnover: Double?
        /// The days in inventory.
        public let daysInInventory: Double?
        /// The days in receivables.
        public let daysInReceivables: Double?
    }

    /// The JSON form of liquidity ratios, as carried over MCP.
    public struct LiquidityRatiosJSON: Codable, Sendable {
        /// The current ratio.
        public let currentRatio: Double?
        /// The quick ratio.
        public let quickRatio: Double?
        /// The cash ratio.
        public let cashRatio: Double?
    }

    /// The JSON form of solvency ratios, as carried over MCP.
    public struct SolvencyRatiosJSON: Codable, Sendable {
        /// The debt to equity.
        public let debtToEquity: Double?
        /// The debt to assets.
        public let debtToAssets: Double?
        /// The interest coverage.
        public let interestCoverage: Double?
        /// The debt service coverage.
        public let debtServiceCoverage: Double?
    }
}

/// JSON-compatible representation of simulation results
public struct SimulationResultsJSON: Codable, Sendable {
    /// The statistics.
    public let statistics: StatisticsJSON
    /// The percentiles.
    public let percentiles: PercentilesJSON
    /// The trials.
    public let trials: Int

    /// The JSON form of statistics, as carried over MCP.
    public struct StatisticsJSON: Codable, Sendable {
        /// The mean.
        public let mean: Double
        /// The standard deviation.
        public let standardDeviation: Double
        /// The minimum.
        public let minimum: Double
        /// The maximum.
        public let maximum: Double
        /// The confidence interval95 lower.
        public let confidenceInterval95Lower: Double
        /// The confidence interval95 upper.
        public let confidenceInterval95Upper: Double
    }

    /// The JSON form of percentiles, as carried over MCP.
    public struct PercentilesJSON: Codable, Sendable {
        /// The p10.
        public let p10: Double
        /// The p25.
        public let p25: Double
        /// The p50.
        public let p50: Double
        /// The p75.
        public let p75: Double
        /// The p90.
        public let p90: Double
        /// The p95.
        public let p95: Double
        /// The p99.
        public let p99: Double
    }
}

/// JSON-compatible representation of trend analysis results
public struct TrendAnalysisJSON: Codable, Sendable {
    /// The trend type.
    public let trendType: String
    /// The fitted parameters, keyed by coefficient name.
    public let parameters: [String: Double]
    /// The forecast.
    public let forecast: [ForecastPointJSON]
    /// The r squared.
    public let rSquared: Double?

    /// The JSON form of forecast point, as carried over MCP.
    public struct ForecastPointJSON: Codable, Sendable {
        /// The period.
        public let period: PeriodJSON
        /// The value.
        public let value: Double
    }
}

// MARK: - Marshalling Errors

/// A failure converting between an MCP JSON payload and a domain type.
public enum MarshallingError: Error, LocalizedError, Sendable {
    case invalidPeriodType(String)
    case missingField(String)
    case invalidData(String)
    case conversionFailed(String)

    /// A human-readable account of what could not be converted.

    public var errorDescription: String? {
        switch self {
        case .invalidPeriodType(let type):
            return "Invalid period type: \(type)"
        case .missingField(let field):
            return "Missing required field: \(field)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .conversionFailed(let message):
            return "Conversion failed: \(message)"
        }
    }
}

// MARK: - Helper Extensions

extension Array where Element == (Period, Double) {
    /// Convert to JSON-compatible format
    public func toJSON() -> [[String: Any]] {
        return self.map { period, value in
            [
                "period": PeriodJSON(from: period),
                "value": value
            ]
        }
    }
}

extension Dictionary where Key == String, Value == MCP.Value {
    /// Parse a Period from arguments
    public func getPeriod(_ key: String) throws -> Period {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }

        // Try to decode as PeriodJSON
        guard let dict = value.objectValue else {
            throw ValueExtractionError.invalidArguments("\(key) must be an object")
        }

        // Manual parsing of period dictionary
        guard let yearValue = dict["year"],
              let year = yearValue.intValue,
              let typeValue = dict["type"],
              let typeInt = typeValue.intValue,
              let periodType = PeriodType(rawValue: typeInt) else {
            throw ValueExtractionError.invalidArguments("\(key) must have valid year and type")
        }

        switch periodType {
        case .millisecond, .second, .minute, .hourly:
            // Sub-daily periods not yet supported in MCP JSON interface
            throw ValueExtractionError.invalidArguments("Sub-daily periods not yet supported in MCP interface")
        case .semiannual:
            // `month` carries the half, as it does for a quarter: 1-6 first, 7-12 second.
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) semiannual period must have month")
            }
            return Period.semiannual(year: year, half: month <= 6 ? 1 : 2)
        case .custom:
            // An arbitrary date range, which a year plus an optional month/day cannot say.
            throw ValueExtractionError.invalidArguments("\(key): custom periods need explicit start and end dates, which this interface does not accept")
        case .annual:
            return Period.year(year)
        case .quarterly:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) quarter must have month")
            }
            let quarter = (month - 1) / 3 + 1
            return Period.quarter(year: year, quarter: quarter)
        case .monthly:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) month must have month")
            }
            return Period.month(year: year, month: month)
        case .daily:
            guard let monthValue = dict["month"],
                  let month = monthValue.intValue,
                  let dayValue = dict["day"],
                  let day = dayValue.intValue else {
                throw ValueExtractionError.invalidArguments("\(key) day must have month and day")
            }
            var components = DateComponents()
            components.year = year
            components.month = month
            components.day = day
            guard let date = Calendar.current.date(from: components) else {
                throw ValueExtractionError.invalidArguments("\(key) has invalid date components")
            }
            return Period.day(date)
        }
    }

    /// Parse a TimeSeries from arguments
    ///
    /// Accepts either:
    /// - A wrapped object: `{"data": [{...}], "metadata": {...}}`
    /// - A flat array of points: `[{"period": {...}, "value": 100}, ...]`
    public func getTimeSeries(_ key: String) throws -> TimeSeries<Double> {
        guard let value = self[key] else {
            throw ValueExtractionError.missingRequiredArgument(key)
        }

        // Convert Value to JSON data and decode
        let encoder = JSONEncoder()
        let jsonData = try encoder.encode(value)
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

/// The bytes JSON permits between tokens: space, tab, line feed, carriage return.
///
/// Used to find a payload's opening token so its shape can be identified without decoding.
let jsonWhitespace: Set<UInt8> = [0x20, 0x09, 0x0A, 0x0D]

// MARK: - Formatting Helpers

extension Double {
    /// Format as percentage
    @available(*, deprecated, message: "Use .percent() from BusinessMath extension instead")
    public func formatPercentage(decimals: Int = 2) -> String {
        return self.percent(decimals)
    }

    /// Format as decimal
    public func formatDecimal(decimals: Int = 2) -> String {
		return self.number(decimals)
    }
}

// MARK: - Optional array arguments

/// Optional accessors for array arguments.
///
/// SwiftMCPServer provides `getStringOptional`, `getIntOptional`, `getDoubleOptional` and
/// `getBoolOptional` beside their throwing counterparts, but no equivalents for the array
/// getters. Every optional array argument was therefore written
/// `(try args.getDoubleArrayIfPresent(key)) ?? default`, which discards a real "that is not an
/// array of numbers" error as though the argument had simply been omitted — a client
/// sending the wrong shape got the default and no complaint.
///
/// These belong upstream beside their scalar siblings; see this repository's HANDOFF.
extension [String: AnyCodable] {

    /// The array of numbers at `key`, or `nil` when absent.
    ///
    /// - Throws: If the key is present but is not an array of numbers. That is the case
    ///   the `try?` form used to swallow, and it is a caller error worth reporting.
    func getDoubleArrayIfPresent(_ key: String) throws -> [Double]? {
        guard self[key] != nil else { return nil }
        return try getDoubleArray(key)
    }

    /// The array of strings at `key`, or `nil` when absent.
    ///
    /// - Throws: If the key is present but is not an array of strings.
    func getStringArrayIfPresent(_ key: String) throws -> [String]? {
        guard self[key] != nil else { return nil }
        return try getStringArray(key)
    }

    /// The matrix at `key`, or `nil` when absent.
    ///
    /// - Throws: If the key is present but is not a matrix of numbers.
    func getDoubleMatrixIfPresent(_ key: String) throws -> [[Double]]? {
        guard self[key] != nil else { return nil }
        return try getDoubleMatrix(key)
    }
}

// MARK: - Guarded summary statistics

/// Mean and variance with their divisors checked once.
///
/// Both were written inline at a dozen call sites as `reduce(0, +) / Double(count)` and
/// `… / Double(count - 1)`. An empty collection makes the first `0/0`, and a single
/// observation makes the second a division by zero; either produces a `NaN` or an
/// infinity that the tool then formats and reports as a number. Computing them in one
/// place means the guard exists once and reads as part of the definition.
extension Collection where Element == Double {

    /// The arithmetic mean, or `nil` when the collection is empty.
    var meanValue: Double? {
        let observationCount = Double(count)
        guard observationCount > 0 else { return nil }
        return reduce(0, +) / observationCount
    }

    /// The Bessel-corrected sample variance, or `nil` with fewer than two observations.
    var sampleVarianceValue: Double? {
        guard let mean = meanValue else { return nil }
        let degreesOfFreedom = Double(count) - 1
        guard degreesOfFreedom > 0 else { return nil }
        return map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / degreesOfFreedom
    }
}
