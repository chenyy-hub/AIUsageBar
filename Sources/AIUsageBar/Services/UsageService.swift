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
///
/// 双周期刷新：
///   API → 30s (timer)
///   Codex → 120s (codexTimer)
///
@MainActor
final class UsageService: ObservableObject {

    // MARK: Tab
    @Published var selectedTab: AppTab = .dashboard

    // MARK: Published State — API Cost (usage_records / api_usage_records)
    @Published var todayCostText: String = "¥..."
    @Published var todaySummary = DatabaseService.TodaySummary(totalCost: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0, requestCount: 0)
    @Published var models: [ModelBreakdown] = []
    @Published var apiModels: [(model: String, cost: Double, tokens: Int)] = []
    @Published var providerCosts: [(String, Double)] = []
    @Published var trend: [DailySummary] = []
    @Published var apiTotalStats = TotalStats(totalCost: 0, totalInput: 0, totalOutput: 0, totalCacheRead: 0, totalRequests: 0, totalSessions: 0, totalProjects: 0)

    // MARK: Published State — Subscription (quota_usage_records)
    @Published var subscriptionSessions: Int = 0
    @Published var subscriptionTokens: Double = 0
    @Published var subscriptionModels: [(model: String, sessions: Int, tokens: Double)] = []

    // MARK: Published State — Codex Session/Weekly (Task 1)
    @Published var codexQuotaStatus: CodexQuotaStatus = .unavailable

    // MARK: Published State — Agent Provider Status (Task 2)
    @Published var agentStatuses: [AgentProviderStatus] = []

    // MARK: Published State — Common
    @Published var agentUsages: [AgentResource] = []
    @Published var primaryAgentLabel: String = "¥..."
    @Published var secondaryLabel: String = ""
    @Published var hasSubscription: Bool = false
    @Published var hasApiCost: Bool = false
    @Published var dbStatus = DBStatus(recordCount: 0, hasData: false, path: "", lastUpdate: nil)
    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    // MARK: Demo Mode
    @Published var isDemoMode: Bool = false

    // MARK: Data Freshness
    @Published var lastApiSync: Date = Date()
    @Published var lastCodexSync: Date = Date()

    // MARK: Sub-Services
    let db: DatabaseService?
    let profileService: ProfileService?
    let providerService: ProviderService?
    let pricingService: PricingService?
    let budgetService: BudgetService?
    let windowManager: WindowManager?
    let codexUsageScanner: CodexUsageScanner
    let codexQuotaProvider: CodexQuotaProvider

    // MARK: Timers
    private var apiTimer: Timer?          // 30 seconds
    private var codexTimer: Timer?        // 120 seconds
    private var refreshTask: Task<Void, Never>?

    // MARK: Init

    init(demo: Bool = false) {
        let database = DatabaseService(demo: demo)
        self.db = database
        self.isDemoMode = demo
        self.codexUsageScanner = CodexUsageScanner()
        self.codexQuotaProvider = CodexQuotaProvider()

        if let database {
            _ = database.initializeManagementTables()
            self.profileService = ProfileService(db: database)
            self.providerService = ProviderService(db: database)
            self.pricingService = PricingService(db: database)
            self.budgetService = BudgetService(db: database)
            let wm = WindowManager(db: database)
            self.windowManager = wm
            wm.onDataChanged = { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
        } else {
            self.profileService = nil
            self.providerService = nil
            self.pricingService = nil
            self.budgetService = nil
            self.windowManager = nil
            errorMessage = "无法连接数据库"
        }

        refresh()
        startTimers()
    }

    deinit {
        apiTimer?.invalidate()
        codexTimer?.invalidate()
        refreshTask?.cancel()
    }

    // MARK: Connection

    func connect(path: String? = nil) {
        if let path, !path.isEmpty {}
        refresh()
    }

    func reconnect() {
        db?.reconnect()
        refresh()
    }

    // MARK: Timers

    private func startTimers() {
        apiTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshAPI()
            }
        }
        codexTimer = Timer.scheduledTimer(withTimeInterval: 120, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshCodex()
            }
        }
    }

    // MARK: Refresh — API Cost

    func refresh() {
        refreshAPI()
        refreshCodex()
    }

    func refreshAPI() {
        guard let db, db.isConnected else {
            isLoading = false
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            isLoading = true
            errorMessage = nil

            async let modelsData = db.apiModelBreakdown()
            async let trendData = db.dailyTrend(days: 7)
            async let stats = db.apiTotalStats()
            async let status = db.dbStatus()
            async let agentData = db.loadAgentUsages()

            let (m, tr, st, s, ag) = await (modelsData, trendData, stats, status, agentData)

            guard !Task.isCancelled else { return }

            self.todaySummary = DatabaseService.TodaySummary(totalCost: st.totalCost, inputTokens: st.totalInput, outputTokens: 0, cacheTokens: 0, requestCount: st.totalRequests)
            self.todayCostText = CostFormatter.formatShort(st.totalCost)
            self.apiModels = m
            self.models = m.map { ModelBreakdown(model: $0.model, totalCost: $0.cost, inputTokens: $0.tokens, outputTokens: 0, requestCount: 0) }
            self.trend = tr
            self.apiTotalStats = st
            self.dbStatus = s
            self.providerCosts = []
            self.agentUsages = ag

            self.lastApiSync = Date()
            self.updateAgentStatuses()
            self.updatePrimaryLabel()
            self.isLoading = false
        }
    }

    // MARK: Refresh — Codex Subscription

    func refreshCodex() {
        guard let db, db.isConnected else { return }

        Task { @MainActor in
            let scanner = self.codexUsageScanner
            let provider = self.codexQuotaProvider
            let usage = await Task.detached(priority: .utility) {
                scanner.scan()
            }.value
            let quota = await Task.detached(priority: .utility) {
                provider.fetchStatus()
            }.value


            self.lastCodexSync = Date()
            self.subscriptionSessions = usage.sessions
            self.subscriptionTokens = usage.totalTokens
            self.subscriptionModels = usage.models
            self.codexQuotaStatus = quota
            self.updateAgentStatuses()
        }
    }

    // MARK: Update Agent Status (Task 2)

    private func updateAgentStatuses() {
        var statuses: [AgentProviderStatus] = []

        // Claude Code
        let apiCount = apiTotalStats.totalRequests
        statuses.append(AgentProviderStatus(
            client: "claude-code",
            displayName: "Claude Code",
            status: apiCount > 0 ? .connected : .noData,
            lastSync: lastApiSync,
            recordCount: apiCount
        ))

        // Codex
        statuses.append(AgentProviderStatus(
            client: "codex",
            displayName: "Codex",
            status: subscriptionSessions > 0 ? .connected : .noData,
            lastSync: lastCodexSync,
            recordCount: subscriptionSessions
        ))

        self.agentStatuses = statuses
    }

    // MARK: MenuBar Label

    private func updatePrimaryLabel() {
        let subs = agentUsages.filter { $0.usageType == .subscriptionQuota }
        let apis = agentUsages.filter { $0.usageType == .apiCost }

        hasSubscription = !subs.isEmpty
        hasApiCost = !apis.isEmpty

        let subCount = subs.reduce(0) { $0 + ($1.inputTokens ?? 0) }
        let apiCost = apis.reduce(0) { $0 + ($1.cost ?? 0) }

        if hasApiCost {
            primaryAgentLabel = CostFormatter.formatShort(apiCost)
            secondaryLabel = hasSubscription ? "· \(TokenFormatter.format(subCount))" : ""
        } else if hasSubscription {
            primaryAgentLabel = TokenFormatter.format(subCount)
            secondaryLabel = ""
        } else {
            primaryAgentLabel = "¥..."
            secondaryLabel = ""
        }
    }
}
