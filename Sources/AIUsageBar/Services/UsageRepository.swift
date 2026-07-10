import Foundation

// MARK: - Usage Repository

/// Single read entry point for usage data shown by Dashboard and MenuBar.
final class UsageRepository {
    private let db: DatabaseService

    init(db: DatabaseService) {
        self.db = db
    }

    func loadDashboardSnapshot() -> UsageDashboardSnapshot {
        let today = db.apiTodayStatsSQL()
        let totalStats = db.apiTotalStats()
        let usage = loadUsageData(todayStats: today)

        return UsageDashboardSnapshot(
            todayStats: today,
            apiModels: db.apiModelBreakdown(),
            trend: db.dailyTrend(days: 7),
            totalStats: totalStats,
            dbStatus: db.dbStatus(),
            agentUsages: db.loadAgentUsages(),
            usageData: usage.usageData,
            costHistory7Days: usage.costHistory7Days,
            costSummaryDebugText: usage.costSummaryDebugText,
            latestActivityByClient: db.apiLatestActivityByClient()
        )
    }

    func loadMenuBarSnapshot() -> UsageMenuBarSnapshot {
        let today = db.apiTodayStatsSQL()
        return UsageMenuBarSnapshot(
            todayStats: today,
            totalStats: db.apiTotalStats(),
            dbStatus: db.dbStatus(),
            latestActivityByClient: db.apiLatestActivityByClient()
        )
    }

    func loadUsageData(
        todayStats: (cost: Double, inputTokens: Int, outputTokens: Int, requests: Int)? = nil
    ) -> UsageDataSnapshot {
        let today = todayStats ?? db.apiTodayStatsSQL()
        let todayTokenTotal = today.inputTokens + today.outputTokens
        let nowStats = db.apiCostSummaryToNow()
        let total = db.apiTotalStats()
        let history = db.apiDailyCostHistorySQL(days: 7)
        let total7DayCost = history.reduce(0) { $0 + $1.cost }
        let dailyAvg = history.isEmpty ? 0 : total7DayCost / Double(history.count)

        return UsageDataSnapshot(
            usageData: UsageData(
                todayCost: today.cost,
                todayTokens: todayTokenTotal,
                todayRequests: today.requests,
                monthCost: nowStats.monthCost,
                totalCost: total.totalCost,
                dailyAverage: dailyAvg
            ),
            costHistory7Days: history,
            costSummaryDebugText: CostSummaryService.formatDebugText(
                todayCost: today.cost,
                todayTokens: todayTokenTotal,
                todayRequests: today.requests
            )
        )
    }

    func latestActivityByClient() -> [(client: String, lastActive: String, provider: String)] {
        db.apiLatestActivityByClient()
    }
}

struct UsageDashboardSnapshot {
    let todayStats: (cost: Double, inputTokens: Int, outputTokens: Int, requests: Int)
    let apiModels: [(model: String, cost: Double, tokens: Int)]
    let trend: [DailySummary]
    let totalStats: TotalStats
    let dbStatus: DBStatus
    let agentUsages: [AgentResource]
    let usageData: UsageData
    let costHistory7Days: [(date: String, cost: Double, tokens: Int)]
    let costSummaryDebugText: String
    let latestActivityByClient: [(client: String, lastActive: String, provider: String)]
}

struct UsageMenuBarSnapshot {
    let todayStats: (cost: Double, inputTokens: Int, outputTokens: Int, requests: Int)
    let totalStats: TotalStats
    let dbStatus: DBStatus
    let latestActivityByClient: [(client: String, lastActive: String, provider: String)]
}

struct UsageDataSnapshot {
    let usageData: UsageData
    let costHistory7Days: [(date: String, cost: Double, tokens: Int)]
    let costSummaryDebugText: String
}
