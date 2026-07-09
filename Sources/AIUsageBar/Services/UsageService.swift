import Foundation
import Combine

// MARK: - App Tab

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case profiles
    case providers
    case pricing
    case budgets

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "看板"
        case .profiles:  return "模型"
        case .providers: return "供应商"
        case .pricing:   return "定价"
        case .budgets:   return "预算"
        }
    }
}

// MARK: - Usage Service

/// Observable object managing periodic data refresh + sub-services.
@MainActor
final class UsageService: ObservableObject {

    // MARK: Tab
    @Published var selectedTab: AppTab = .dashboard

    // MARK: Published State (usage dashboard)
    @Published var todayCostText: String = "¥..."
    @Published var todaySummary = DatabaseService.TodaySummary(totalCost: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0, requestCount: 0)
    @Published var projects: [ProjectCost] = []
    @Published var models: [ModelBreakdown] = []
    @Published var providerCosts: [(String, Double)] = []
    @Published var agentUsages: [AgentResource] = []
    @Published var primaryAgentLabel: String = "¥..."
    @Published var secondaryLabel: String = ""
    @Published var hasSubscription: Bool = false
    @Published var subscriptionPercent: Double = 0
    @Published var hasApiCost: Bool = false
    @Published var lastScanTimes: [String: String] = [:]
    @Published var trend: [DailySummary] = []
    @Published var totalStats = TotalStats(totalCost: 0, totalInput: 0, totalOutput: 0, totalCacheRead: 0, totalRequests: 0, totalSessions: 0, totalProjects: 0)
    @Published var dbStatus = DBStatus(recordCount: 0, hasData: false, path: "", lastUpdate: nil)
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    // MARK: Sub-Services
    let db: DatabaseService?
    let profileService: ProfileService?
    let providerService: ProviderService?
    let pricingService: PricingService?
    let budgetService: BudgetService?

    // MARK: Privates
    private var timer: Timer?
    private var refreshTask: Task<Void, Never>?

    // MARK: Init

    init() {
        let database = DatabaseService()
        self.db = database

        if let database {
            _ = database.initializeManagementTables()
            self.profileService = ProfileService(db: database)
            self.providerService = ProviderService(db: database)
            self.pricingService = PricingService(db: database)
            self.budgetService = BudgetService(db: database)
        } else {
            self.profileService = nil
            self.providerService = nil
            self.pricingService = nil
            self.budgetService = nil
            errorMessage = "无法连接数据库"
        }

        refresh()
        startAutoRefresh()
    }

    deinit {
        timer?.invalidate()
        refreshTask?.cancel()
    }

    // MARK: Connection

    /// Connect with optional custom path (for Settings)
    func connect(path: String? = nil) {
        // Note: in v4, reconnect is used for settings path changes
        // The db is already initialized in init()
        if let path, !path.isEmpty {
            // Custom path - currently not supported for re-initialization
            // In a full implementation, would recreate db with new path
        }
        refresh()
    }

    func reconnect() {
        db?.reconnect()
        refresh()
    }

    // MARK: Auto Refresh

    private func startAutoRefresh() {
        timer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    // MARK: Refresh

    func refresh() {
        guard let db, db.isConnected else {
            isLoading = false
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            async let today = db.todaySummary()
            async let projectsData = db.projectBreakdown()
            async let modelsData = db.modelBreakdown()
            async let trendData = db.dailyTrend(days: 7)
            async let stats = db.totalStats()
            async let status = db.dbStatus()
            async let provData = db.providerBreakdown()
            async let agentData = db.loadAgentUsages()

            let (t, p, m, tr, st, s, pv, ag) = await (today, projectsData, modelsData, trendData, stats, status, provData, agentData)

            guard !Task.isCancelled else { return }

            self.todaySummary = t
            self.todayCostText = CostFormatter.formatShort(t.totalCost)
            self.projects = p
            self.models = m
            self.trend = tr
            self.totalStats = st
            self.dbStatus = s
            self.providerCosts = pv
            self.agentUsages = ag

            // 更新菜单栏标签
            self.updatePrimaryLabel()

            self.isLoading = false
        }
    }

    // MARK: MenuBar Label

    /// 更新菜单栏动态标签
    ///   订阅优先 → quota 百分比
    ///   API → cost
    ///   混合 → quota% + cost
    private func updatePrimaryLabel() {
        let subs = agentUsages.filter { $0.usageType == .subscriptionQuota }
        let apis = agentUsages.filter { $0.usageType == .apiCost }

        hasSubscription = !subs.isEmpty
        hasApiCost = !apis.isEmpty

        let subCount = subs.reduce(0) { $0 + Int(($1.quotaUsed ?? 0)) }
        let apiCost = apis.reduce(0) { $0 + ($1.cost ?? 0) }

        if hasSubscription && hasApiCost {
            // 混合模式: "97% · ¥12.5"
            primaryAgentLabel = "\(TokenFormatter.format(subCount))"
            secondaryLabel = CostFormatter.formatShort(apiCost)
            subscriptionPercent = 100
        } else if hasSubscription {
            primaryAgentLabel = TokenFormatter.format(subCount)
            secondaryLabel = "🤖"
            subscriptionPercent = 100
        } else if hasApiCost {
            primaryAgentLabel = CostFormatter.formatShort(apiCost)
            secondaryLabel = ""
            subscriptionPercent = 0
        } else {
            primaryAgentLabel = "¥..."
            secondaryLabel = ""
            subscriptionPercent = 0
        }
    }
}
