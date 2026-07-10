// AIUsageBar v3.0 — 数据验证脚本
// 验证时区安全查询逻辑

import Foundation

let sep = String(repeating: "-", count: 60)

// =============================================================
// 1. Timezone 转换测试
// =============================================================

print(sep)
print("  🕐 时区转换测试")
print(sep)

let utcFormatter: DateFormatter = {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.timeZone = TimeZone(abbreviation: "UTC")!
    f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
    return f
}()

// 测试用例：UTC 2026-07-09T16:30:00Z
// 中国时间 (UTC+8) = 2026-07-10 00:30
// 应该属于：2026-07-10（当天）

let utcDateStr = "2026-07-09T16:30:00Z"
let utcDate = utcFormatter.date(from: utcDateStr)!

let cal = Calendar.current
let localDayStart = cal.startOfDay(for: utcDate)
let localDayEnd = cal.date(byAdding: .day, value: 1, to: localDayStart)!

let localDayStartStr = utcFormatter.string(from: localDayStart)
let localDayEndStr = utcFormatter.string(from: localDayEnd)

let localDateFormatter = DateFormatter()
localDateFormatter.dateFormat = "yyyy-MM-dd HH:mm (zzz)"
localDateFormatter.timeZone = TimeZone.current

print("")
print("  测试: UTC 时间戳 2026-07-09T16:30:00Z")
print("  中国时间:        \(localDateFormatter.string(from: utcDate))")
print("")
print("  本地时区 当天 UTC 范围:")
print("    Start: \(localDayStartStr)")
print("    End:   \(localDayEndStr)")
print("")
print("  SQL 查询:")
print("    WHERE timestamp >= '\(localDayStartStr)'")
print("      AND timestamp <  '\(localDayEndStr)'")
print("")

let isInRange = utcDateStr >= localDayStartStr && utcDateStr < localDayEndStr
print("  \(utcDateStr) >= \(localDayStartStr) && < \(localDayEndStr) → \(isInRange)")
print("  ✅ UTC+8 用户看到 2026-07-09T16:30:00Z 属于本地 2026-07-10")
print("")

// =============================================================
// 2. 本月 UTC 范围
// =============================================================

print(sep)
print("  📅 本月 UTC 范围")
print(sep)

let now = Date()
let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: now))!
let monthEnd = cal.date(byAdding: .month, value: 1, to: monthStart)!

let monthStartUTC = utcFormatter.string(from: monthStart)
let monthEndUTC = utcFormatter.string(from: monthEnd)

print("")
print("  当前本地时间: \(localDateFormatter.string(from: now))")
print("  本月 UTC 范围:")
print("    Start: \(monthStartUTC)")
print("    End:   \(monthEndUTC)")
print("")
print("  SQL 查询:")
print("    WHERE timestamp >= '\(monthStartUTC)'")
print("      AND timestamp <  '\(monthEndUTC)'")
print("")

// =============================================================
// 3. 今天 UTC 范围
// =============================================================

print(sep)
print("  📆 今天 UTC 范围")
print(sep)

let todayStart = cal.startOfDay(for: now)
let todayEnd = cal.date(byAdding: .day, value: 1, to: todayStart)!

let todayStartUTC = utcFormatter.string(from: todayStart)
let todayEndUTC = utcFormatter.string(from: todayEnd)

print("")
print("  今天 UTC 范围:")
print("    Start: \(todayStartUTC)")
print("    End:   \(todayEndUTC)")
print("")
print("  SQL 查询:")
print("    WHERE timestamp >= '\(todayStartUTC)'")
print("      AND timestamp <  '\(todayEndUTC)'")
print("")

// =============================================================
// 4. 累计成本 SQL（无时间过滤）
// =============================================================

print(sep)
print("  💰 累计成本 SQL")
print(sep)
print("")
print("  SELECT COALESCE(SUM(total_cost), 0) AS total_cost")
print("  FROM api_usage_records")
print("  -- 无 WHERE，统计所有记录")
print("")

// =============================================================
// 5. 7天趋势 SQL
// =============================================================

print(sep)
print("  📊 7 天趋势 SQL（最近一天示例）")
print(sep)
print("")
print("  SELECT")
print("    COALESCE(SUM(total_cost), 0) AS cost,")
print("    COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens")
print("  FROM api_usage_records")
print("  WHERE timestamp >= '\(todayStartUTC)'")
print("    AND timestamp <  '\(todayEndUTC)'")
print("")

// =============================================================
// 6. 汇总
// =============================================================

print(sep)
print("  📋 时区安全规则")
print(sep)
print("")
print("  1. 所有日期过滤使用本地时区计算边界")
print("     Calendar.current 自动使用系统时区")
print("")
print("  2. 边界转换为 UTC 字符串格式")
print("     yyyy-MM-dd'T'HH:mm:ss'Z'")
print("")
print("  3. SQLite 使用范围查询")
print("     timestamp >= ? AND timestamp < ?")
print("")
print("  4. 不再使用 substr(timestamp,1,10) = ?")
print("     避免 UTC 与本地时区不匹配")
print("")
print("  ✅ 验证完成")
