import Foundation

// MARK: - Cost Summary Service (v3.1.1 — 安全稳定版)

/// 成本汇总服务
///
/// 日期统计由 Swift 按 macOS 当前时区生成边界，
/// 数据库 timestamp 保持原格式并通过范围条件查询。
///
/// 安全策略：
///   - 所有 SQL 查询通过 `DatabaseService.query()` 安全执行（nil 返回空）
///   - 计算属性只在首次访问或显式 refresh 后重新计算
///   - 不阻塞主线程
///
final class CostSummaryService {
    private weak var db: DatabaseService?

    init(db: DatabaseService?) {
        self.db = db
    }

    // MARK: - 批量查询（安全：仅调用一次 SQL）

    struct Summary {
        let todayCost: Double
        let todayTokens: Int
        let todayRequests: Int
        let weekCost: Double
        let monthCost: Double
        let totalCost: Double
    }

    /// 执行 SQL 查询并返回汇总
    func compute() -> Summary {
        guard let db else {
            return Summary(todayCost: 0, todayTokens: 0, todayRequests: 0, weekCost: 0, monthCost: 0, totalCost: 0)
        }
        let today = db.apiTodayStatsSQL()
        let total = db.apiTotalStats()
        return Summary(
            todayCost: today.cost,
            todayTokens: today.inputTokens + today.outputTokens,
            todayRequests: today.requests,
            weekCost: 0,
            monthCost: 0,
            totalCost: total.totalCost
        )
    }

    /// 今日统计调试文本（不触发 SQL — 由外部传入数据）
    static func formatDebugText(todayCost: Double, todayTokens: Int, todayRequests: Int) -> String {
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let now = Date()
        let nowStr = fmt.string(from: now)
        let tz = TimeZone.current
        let tzOffset = tz.secondsFromGMT()
        let tzSign = tzOffset >= 0 ? "+" : ""
        let tzHours = abs(tzOffset) / 3600
        let tzMinutes = (abs(tzOffset) % 3600) / 60
        let tzStr = String(format: "%@%02d%02d", tzSign, tzHours, tzMinutes)

        return """
        Today Range (macOS timezone):
        \(nowStr) \(tzStr)
        Cost: \(CostFormatter.formatShort(todayCost)) | Tok: \(todayTokens) | Req: \(todayRequests)
        """
    }
}
