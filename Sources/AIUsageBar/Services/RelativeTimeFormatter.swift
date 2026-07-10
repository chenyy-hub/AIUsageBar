import Foundation

enum RelativeTimeFormatter {
    static func format(_ date: Date, now: Date = Date()) -> String {
        let interval = max(0, Int(now.timeIntervalSince(date)))
        if interval < 60 {
            return "刚刚"
        }
        if interval < 3600 {
            return "\(interval / 60)分钟前"
        }
        return "\(interval / 3600)小时前"
    }
}
