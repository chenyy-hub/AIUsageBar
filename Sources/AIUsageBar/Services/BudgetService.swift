import Foundation

// MARK: - Budget Service

/// 预算业务逻辑
///
/// 职责：
///   - Budget CRUD（委托 DatabaseService）
///   - 实时余额计算（SUM usage_records.total_cost）
///   - 日均消耗 + 消耗预测（runway）
///   - 多 Provider 预算拆解
///
/// 计算规则：
///   period_type = "total"    → 从 start_date 开始累计，永远不归零
///   period_type = "daily"    → 只算今天
///   period_type = "weekly"   → 只算本周
///   period_type = "monthly"  → 只算本月
///
final class BudgetService {
    private let db: DatabaseService

    init(db: DatabaseService) {
        self.db = db
    }

    // MARK: - CRUD

    var budgets: [Budget] { db.loadBudgets() }

    func getBudget(id: Int) -> Budget? { db.getBudget(id: id) }

    @discardableResult
    func saveBudget(_ budget: Budget) -> Int { db.saveBudget(budget) }

    func deleteBudget(id: Int) { db.deleteBudget(id: id) }

    // MARK: - Balance Calculation

    /// 余额计算结果
    struct BalanceResult {
        let spent: Double
        let remaining: Double
        let daysActive: Int
        let dailyAverage: Double
        let runwayDays: Double?
        let currency: String
        let periodStart: String

        /// 预测耗尽日期
        var runwayDate: Date? {
            guard let runwayDays, runwayDays.isFinite, runwayDays > 0 else { return nil }
            return Calendar.current.date(byAdding: .day, value: Int(runwayDays), to: Date())
        }

        /// 消耗百分比
        var spentPercent: Double {
            guard remaining + spent > 0 else { return 0 }
            return spent / (spent + remaining) * 100
        }
    }

    /// 计算指定 budget 的余额
    func calculateBalance(_ budget: Budget) -> BalanceResult {
        let (sinceDate, daysActive) = periodInfo(budget: budget)
        let spent = db.querySpent(provider: budget.provider, sinceDate: sinceDate)
        let remaining = max(0, budget.initialBalance - spent)

        let avg = daysActive > 0 ? spent / Double(daysActive) : 0
        let runway: Double? = avg > 0 ? remaining / avg : nil

        return BalanceResult(
            spent: spent,
            remaining: remaining,
            daysActive: daysActive,
            dailyAverage: avg,
            runwayDays: runway,
            currency: budget.currency,
            periodStart: sinceDate
        )
    }

    /// 批量计算所有 active budget 的余额
    func calculateAllBalances() -> [BalanceResult] {
        budgets.filter(\.isActive).map { calculateBalance($0) }
    }

    // MARK: - Daily Spending Trend

    /// 最近 N 天的每日花费
    func dailySpending(provider: String, days: Int = 30) -> [(String, Double)] {
        db.queryDailySpending(provider: provider, days: days)
    }

    // MARK: - Period Helpers

    /// 根据 period_type 计算起始日期和活跃天数
    private func periodInfo(budget: Budget) -> (sinceDate: String, daysActive: Int) {
        let calendar = Calendar.current
        let today = Date()

        switch budget.periodType {
        case "daily":
            let ds = dateString(today)
            return (ds, 1)

        case "weekly":
            guard let weekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: today)) else {
                return (dateString(today), 1)
            }
            let ds = dateString(weekStart)
            let days = calendar.dateComponents([.day], from: weekStart, to: today).day ?? 1
            return (ds, max(1, days + 1))

        case "monthly":
            let comps = calendar.dateComponents([.year, .month], from: today)
            guard let monthStart = calendar.date(from: comps) else {
                return (dateString(today), 1)
            }
            let ds = dateString(monthStart)
            let days = calendar.dateComponents([.day], from: monthStart, to: today).day ?? 1
            return (ds, max(1, days + 1))

        default: // "total"
            // 如果没有 start_date，使用最早记录日期
            let start = budget.startDate.isEmpty ? "2026-01-01" : budget.startDate
            let days = daysBetween(start, dateString(today))
            return (start, max(1, days))
        }
    }

    // MARK: - Helpers

    private func dateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func daysBetween(_ from: String, _ to: String) -> Int {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        guard let d1 = fmt.date(from: from), let d2 = fmt.date(from: to) else { return 1 }
        return max(1, Calendar.current.dateComponents([.day], from: d1, to: d2).day ?? 1)
    }
}
