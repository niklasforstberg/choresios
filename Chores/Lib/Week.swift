import Foundation

/// Weeks run Monday–Sunday and are numbered by ISO 8601, like the paper sheet.
/// Dates are local calendar days as YYYY-MM-DD strings, as the API takes them.
enum Week {
    static let calendar: Calendar = {
        var c = Calendar(identifier: .iso8601)
        c.timeZone = .current
        return c
    }()

    static func iso(_ date: Date) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year!, c.month!, c.day!)
    }

    static func parse(_ s: String) -> Date {
        let parts = s.split(separator: "-").compactMap { Int($0) }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))!
    }

    static func addDays(_ date: Date, _ days: Int) -> Date {
        calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: date))!
    }

    static func monday(of date: Date) -> Date {
        let weekday = calendar.component(.weekday, from: date) // 1 is Sunday
        return addDays(date, -((weekday + 5) % 7))
    }

    static func number(_ date: Date) -> Int {
        calendar.component(.weekOfYear, from: date)
    }

    static func today() -> String { iso(Date()) }

    static let weekdayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.setLocalizedDateFormatFromTemplate("EEE")
        return f
    }()

    static let rangeFormatter: DateIntervalFormatter = {
        let f = DateIntervalFormatter()
        f.locale = L10n.locale
        f.dateTemplate = "dMMM"
        return f
    }()

    static let longFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = L10n.locale
        f.dateStyle = .long
        return f
    }()

    static func weekday(_ date: Date) -> String {
        weekdayFormatter.string(from: date).replacingOccurrences(of: ".", with: "").capitalized
    }
}
