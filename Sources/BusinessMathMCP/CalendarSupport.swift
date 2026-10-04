import Foundation

/// The Gregorian calendar in UTC: the one calendar this server does date arithmetic with.
///
/// ## Why not `Calendar.current`
///
/// `Calendar.current` takes its calendar system, locale and time zone from the machine. This
/// server is developed in one zone and deployed in another, and a tool call must mean the same
/// thing on both. It did not: `{"year": 2024, "month": 3, "day": 15}` built with the machine's
/// calendar is local midnight, which east of UTC is still 14 March in UTC — and UTC is how
/// BusinessMath reads every `Date` it is handed (`Period.day`, the bond coupon walk and the
/// amortization schedule all use its own Gregorian-UTC calendar). The caller named the 15th and
/// the library saw the 14th.
///
/// The same holds for "N years from now". A machine calendar keeps the *local* time of day, so
/// when daylight saving is in force on one date and not the other the result is an hour off in
/// UTC, and a coupon walk that steps in UTC months from the issue date no longer lands on the
/// maturity date.
///
/// ## Why it is defined here
///
/// `SwiftDeterminism` vends `Calendar.gregorianUTC` and BusinessMath aliases it, but
/// BusinessMath's alias is internal and `SwiftDeterminism` is not a dependency this package
/// declares. (`Calendar.gregorianUTC` does resolve here today, because BusinessMath re-exports
/// a few unrelated `SwiftDeterminism` types; that is a side effect of someone else's import
/// list, not an API to build on.) This is the single definition for this module; every site
/// that needs a calendar uses it, so adopting the vended one later is a change to this line.
/// `Calendar(identifier: .gregorian)` alone is not enough — it fixes the calendar system and
/// still inherits the machine's time zone.
let gregorianUTC: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// The instant a named calendar day begins: midnight UTC of `year`-`month`-`day`.
///
/// `Calendar.date(from:)` is lenient — it turns 30 February into 1 March and month 13 into the
/// following January — so the result is read back and compared with what was asked for. A day
/// that is not on the calendar gives `nil` rather than a neighbouring day the caller did not
/// name.
///
/// - Parameters:
///   - year: The Gregorian year.
///   - month: The month, 1 through 12.
///   - day: The day of the month, starting at 1.
/// - Returns: Midnight UTC at the start of that day, or `nil` if there is no such day.
func utcDay(year: Int, month: Int, day: Int) -> Date? {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    guard let date = gregorianUTC.date(from: components) else {
        return nil
    }
    let resolved = gregorianUTC.dateComponents([.era, .year, .month, .day], from: date)
    guard resolved.era == 1, resolved.year == year, resolved.month == month, resolved.day == day else {
        return nil
    }
    return date
}

/// The instant a whole number of calendar years after `start`, reckoned in UTC.
///
/// The UTC date and time of day are kept, so the answer is the same on every machine and lines
/// up with BusinessMath's schedules, which step from the same instant with the same calendar.
/// From 29 February the result is 28 February when the target year has no leap day.
///
/// - Parameters:
///   - years: The number of years to add.
///   - start: The instant to count from.
/// - Returns: The later instant, or `nil` if it cannot be represented.
func dateByAdding(years: Int, to start: Date) -> Date? {
    gregorianUTC.date(byAdding: .year, value: years, to: start)
}
