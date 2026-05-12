import Foundation

enum Fmt {
    static func currency(_ v: Double) -> String {
        if v >= 1000 { return String(format: "$%.1fk", v / 1000) }
        if v >= 100  { return String(format: "$%.0f",  v) }
        if v >= 10   { return String(format: "$%.1f",  v) }
        return String(format: "$%.2f", v)
    }

    static func currencyExact(_ v: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = v < 100 ? 2 : 0
        f.minimumFractionDigits = v < 100 ? 2 : 0
        return f.string(from: NSNumber(value: v)) ?? "$0"
    }

    static func tokens(_ v: Int) -> String {
        if v >= 1_000_000 { return String(format: "%.1fM", Double(v) / 1_000_000) }
        if v >= 1_000     { return String(format: "%.0fK", Double(v) / 1_000) }
        return "\(v)"
    }

    static func resetsIn(_ date: Date, now: Date = Date()) -> String {
        let secs = max(0, Int(date.timeIntervalSince(now)))
        if secs <= 0 { return "now" }
        let h = secs / 3600
        let m = (secs % 3600) / 60
        if h >= 24 {
            let d = h / 24
            return "\(d)d \(h % 24)h"
        }
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    /// "May 14" / "Mon 9:00 AM" — short absolute label for reset times.
    static func absoluteShort(_ date: Date, now: Date = Date()) -> String {
        let cal = Calendar.current
        let f = DateFormatter()
        if cal.isDate(date, inSameDayAs: now) {
            f.dateFormat = "h:mm a"
        } else if let days = cal.dateComponents([.day], from: cal.startOfDay(for: now),
                                                to: cal.startOfDay(for: date)).day, days < 7 {
            f.dateFormat = "EEE h:mm a"
        } else {
            f.dateFormat = "MMM d"
        }
        return f.string(from: date)
    }

    static func dayLetter(_ yyyymmdd: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let d = f.date(from: yyyymmdd) else { return "·" }
        let g = DateFormatter()
        g.locale = Locale.current
        g.dateFormat = "EEEEE"
        return g.string(from: d)
    }

    static func shortModel(_ m: String) -> String {
        let lower = m.lowercased()
        if lower.contains("opus")    { return "Opus" }
        if lower.contains("sonnet")  { return "Sonnet" }
        if lower.contains("haiku")   { return "Haiku" }
        if lower.contains("codex")   { return "GPT-Codex" }
        if lower.contains("gpt-5")   { return "GPT-5" }
        if lower.contains("o4")      { return "o4" }
        return String(m.prefix(12))
    }
}
