import Foundation
import Combine

// MARK: - App Tab

enum AppTab: String, CaseIterable, Identifiable {
    case dashboard
    case profiles
    case providers
    case pricing

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dashboard: return "总览"
        case .profiles:  return "模型"
        case .providers: return "供应商"
        case .pricing:   return "定价"
        }
    }
}

// MARK: - Usage Service

/// Observable object managing periodic data refresh + sub-services.
///
/// v1.4.x 刷新周期：
///   MenuBar → 5s (menuBarTimer)        — UsageRepository → lightweight usage
///   Dashboard/API → 10s (apiTimer)     — UsageRepository → usageData
///   Codex → 60s (codexTimer)           — quota / subscription
///   CodexQuotaMonitor → 60s            — 窗口刷新检测 + alert
///   ActivityWatcher → 5s              — JSONL mtime 轮询
///
@MainActor
final class UsageService: ObservableObject {

    // MARK: Tab
    @Published var selectedTab: AppTab = .dashboard

    // MARK: Published State — API Cost (分层)
    @Published var costSummary = DatabaseService.CostSummary(todayCost: 0, monthCost: 0, totalCost: 0, todayRequests: 0)
    @Published var todayCostText: String = "¥..."
    @Published var todaySummary = DatabaseService.TodaySummary(totalCost: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0, requestCount: 0)
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

    // MARK: Published State — Active Agent (v2.0)
    @Published var activeAgentInfo = ActiveAgentInfo(agent: .none, detail: "", lastActive: nil)
    @Published var latestActivityDate: Date? = nil

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

    // MARK: Pipeline Health (v1.4.x 多路独立健康)
    @Published var scannerStatus: ScannerStatus = .unavailable
    @Published var pipelineHealth: PipelineHealth = .offline
    @Published var lastScannerCheck: Date = Date()
    @Published var scannerDiagnostic: ScannerDiagnostic = ScannerDiagnostic()

    /// Database 健康（由 refreshAPI 更新）
    @Published var dbHealth: Bool = false

    /// API Refresh 健康（最近刷新是否正常）
    @Published var apiRefreshHealth: Bool = false

    /// Codex 健康（quota 是否可用）
    @Published var codexHealth: Bool = false

    // MARK: Data Freshness
    @Published var lastApiSync: Date = Date()
    @Published var lastCodexSync: Date = Date()

    // MARK: Sub-Services
    let db: DatabaseService?
    let usageRepository: UsageRepository?
    let profileService: ProfileService?
    let providerService: ProviderService?
    let pricingService: PricingService?
    let windowManager: WindowManager?
    let codexUsageScanner: CodexUsageScanner
    let codexQuotaProvider: CodexQuotaProvider

    // MARK: v2.0 New Services
    let activeAgentService: ActiveAgentService
    let notificationService: NotificationService
    let codexQuotaMonitor: CodexQuotaMonitor

    // MARK: v3.0 New Services
    let costSummaryService: CostSummaryService
    let activityWatcher: ActivityWatcher

    // MARK: v3.1 Scanner Health
    let scannerStatusService: ScannerStatusService

    // MARK: Published State — Budget Forecast (v3.0 → v1.3.2 simplified)
    @Published var usageData = UsageData(
        todayCost: 0, todayTokens: 0, todayRequests: 0,
        monthCost: 0, totalCost: 0, dailyAverage: 0
    )
    @Published var costHistory7Days: [(date: String, cost: Double, tokens: Int)] = []
    @Published var costSummaryDebugText: String = ""

    // MARK: API Budget (UserDefaults-backed, @Published for UI refresh)

    /// UserDefaults key for initial balance
    private let initialBalanceKey = "apiBudget.initialBalance"

    /// 充值余额（用户手动设置，@Published 确保 UI 即时刷新）
    @Published var initialBalance: Double {
        didSet {
            UserDefaults.standard.set(initialBalance, forKey: initialBalanceKey)
        }
    }

    /// 剩余余额 = 充值余额 - 累计消费（允许负数）
    var currentBalance: Double {
        initialBalance - usageData.totalCost
    }

    /// 预计可用天数
    var estimatedDaysRemaining: Int? {
        let avg = usageData.dailyAverage
        guard avg > 0, currentBalance > 0 else { return nil }
        return Int(currentBalance / avg)
    }

    // MARK: Timers
    private var menuBarTimer: Timer?      // 5 seconds
    private var apiTimer: Timer?          // 10 seconds
    private var codexTimer: Timer?        // 60 seconds (v1.4)
    private var refreshTask: Task<Void, Never>?

    // MARK: Init

    init(demo: Bool = false) {
        print("[Startup] UsageService init start (demo=\(demo))")
        let database = DatabaseService(demo: demo)
        self.db = database
        self.usageRepository = database.map { UsageRepository(db: $0) }
        self.isDemoMode = demo
        // Load persisted initial balance from UserDefaults
        self.initialBalance = UserDefaults.standard.double(forKey: "apiBudget.initialBalance")
        self.codexUsageScanner = CodexUsageScanner()
        self.codexQuotaProvider = CodexQuotaProvider()

        // v2.0 Services
        self.activeAgentService = ActiveAgentService()
        self.notificationService = NotificationService()
        self.codexQuotaMonitor = CodexQuotaMonitor(
            provider: codexQuotaProvider,
            notificationService: notificationService
        )

        // v3.0 Services
        self.costSummaryService = CostSummaryService(db: database)
        self.activityWatcher = ActivityWatcher()

        // v3.1 Scanner Health
        let scannerSvc = ScannerStatusService()
        self.scannerStatusService = scannerSvc
        self.scannerStatus = scannerSvc.scannerStatus
        self.lastScannerCheck = scannerSvc.lastCheck

        if let database {
            _ = database.initializeManagementTables()
            self.profileService = ProfileService(db: database)
            self.providerService = ProviderService(db: database)
            self.pricingService = PricingService(db: database)
            let wm = WindowManager(db: database)
            self.windowManager = wm
            wm.onDataChanged = { [weak self] in
                Task { @MainActor in self?.refresh() }
            }
        } else {
            self.profileService = nil
            self.providerService = nil
            self.pricingService = nil
            self.windowManager = nil
            errorMessage = "无法连接数据库"
        }

        // 请求通知权限
        notificationService.requestAuthorization()

        // ActivityWatcher：检测到 JSONL 变化时，更新 agent 状态
        activityWatcher.onActivityDetected = { [weak self] (date: Date) in
            Task { @MainActor in
                guard let self else { return }
                print("[ActivityWatcher] detected \(date) → updating agent status")
                self.lastApiSync = Date()
                self.latestActivityDate = self.maxDate(self.latestActivityDate, date)
                self.refreshMenuBar()
                self.updateAgentStatuses()
                self.updateActiveAgent()
                self.updatePrimaryLabel()
            }
        }

        // ScannerStatusService 由 refreshAPI() 周期驱动（10s）
        // 不再使用自驱动 timer 或 async stream

        refresh()
        startTimers()
    }

    deinit {
        menuBarTimer?.invalidate()
        apiTimer?.invalidate()
        codexTimer?.invalidate()
        refreshTask?.cancel()
        codexQuotaMonitor.stop()
        activityWatcher.stop()
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
        // MenuBar → 5s lightweight refresh from UsageRepository
        menuBarTimer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshMenuBar()
            }
        }
        // Dashboard/API cost → 10s full refresh
        apiTimer = Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshAPI()
            }
        }
        // Codex quota → 60s
        codexTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.refreshCodex()
            }
        }
        // Scanner Status → 由 refreshAPI() 10s 周期驱动
        // CodexQuotaMonitor → 60s（内置）
        codexQuotaMonitor.start()
        // ActivityWatcher → 5s（JSONL mtime）
        activityWatcher.start()
    }

    // MARK: Refresh — API Cost

    func refresh() {
        refreshAPI()
        refreshCodex()
    }

    func refreshMenuBar() {
        guard let usageRepository, db?.isConnected == true else { return }
        let snapshot = usageRepository.loadMenuBarSnapshot()
        let today = snapshot.todayStats
        self.todaySummary = DatabaseService.TodaySummary(
            totalCost: today.cost,
            inputTokens: today.inputTokens,
            outputTokens: today.outputTokens,
            cacheTokens: 0,
            requestCount: today.requests
        )
        self.todayCostText = CostFormatter.formatShort(today.cost)
        self.costSummary = DatabaseService.CostSummary(
            todayCost: today.cost,
            monthCost: usageData.monthCost,
            totalCost: snapshot.totalStats.totalCost,
            todayRequests: today.requests
        )
        self.apiTotalStats = snapshot.totalStats
        self.dbStatus = snapshot.dbStatus
        self.usageData = UsageData(
            todayCost: today.cost,
            todayTokens: today.inputTokens + today.outputTokens,
            todayRequests: today.requests,
            monthCost: usageData.monthCost,
            totalCost: snapshot.totalStats.totalCost,
            dailyAverage: usageData.dailyAverage
        )
        self.latestActivityDate = latestActivityDate(
            from: snapshot.latestActivityByClient,
            dbLastUpdate: snapshot.dbStatus.lastUpdate
        )
        self.updateAgentStatuses()
        self.updateActiveAgent()
        self.updatePrimaryLabel()
    }

    func refreshAPI() {
        guard let db, db.isConnected, let usageRepository else {
            isLoading = false
            return
        }

        refreshTask?.cancel()
        refreshTask = Task { @MainActor in
            print("[CostSummary] refreshAPI start")
            isLoading = true
            errorMessage = nil

            let snapshot = usageRepository.loadDashboardSnapshot()
            let m = snapshot.apiModels
            let tr = snapshot.trend
            let st = snapshot.totalStats
            let s = snapshot.dbStatus
            let ag = snapshot.agentUsages

            guard !Task.isCancelled else {
                print("[CostSummary] refreshAPI cancelled")
                return
            }

            // 今日统计使用 UsageRepository 统一入口
            let today = snapshot.todayStats
            print("[CostSummary] today cost=\(today.cost) tokens=\(today.inputTokens+today.outputTokens) reqs=\(today.requests)")

            let cs = DatabaseService.CostSummary(
                todayCost: today.cost,
                monthCost: 0,
                totalCost: st.totalCost,
                todayRequests: today.requests
            )

            self.costSummary = cs
            self.todaySummary = DatabaseService.TodaySummary(
                totalCost: today.cost,
                inputTokens: today.inputTokens,
                outputTokens: today.outputTokens,
                cacheTokens: 0,
                requestCount: today.requests
            )
            self.todayCostText = CostFormatter.formatShort(today.cost)
            self.apiModels = m
            self.trend = tr
            self.apiTotalStats = st
            self.dbStatus = s
            self.providerCosts = []
            self.agentUsages = ag

            self.lastApiSync = Date()
            self.updateAgentStatuses()
            self.updatePrimaryLabel()
            self.updateActiveAgent()
            self.usageData = snapshot.usageData
            self.costHistory7Days = snapshot.costHistory7Days
            self.costSummaryDebugText = snapshot.costSummaryDebugText
            self.latestActivityDate = latestActivityDate(
                from: snapshot.latestActivityByClient,
                dbLastUpdate: snapshot.dbStatus.lastUpdate
            )
            self.updateScannerStatus()
            self.updateHealthIndicators()
            self.isLoading = false

            // API 成本警告
            if today.cost > 100 {
                self.notificationService.send(
                    type: .apiCostWarning,
                    body: "今日 API 消耗已达 \(CostFormatter.format(today.cost))",
                    playSound: false
                )
            }
            print("[CostSummary] refreshAPI done")
        }
    }

    // MARK: Refresh — Codex Subscription

    func refreshCodex() {
        guard let db, db.isConnected else { return }

        Task { @MainActor in
            let scanner = self.codexUsageScanner
            let usage = await Task.detached(priority: .utility) {
                scanner.scan()
            }.value
            // 使用 codexQuotaMonitor 的最新状态而不是每次都请求
            let quota = self.codexQuotaMonitor.quotaStatus

            self.lastCodexSync = Date()
            self.subscriptionSessions = usage.sessions
            self.subscriptionTokens = usage.totalTokens
            self.subscriptionModels = usage.models

            // 仅在 codexQuotaMonitor 状态不可用时 fallback 到手动请求
            if quota.status == "unavailable" {
                let provider = self.codexQuotaProvider
                let freshQuota = await Task.detached(priority: .utility) {
                    provider.fetchStatus()
                }.value
                self.codexQuotaStatus = freshQuota
            } else {
                self.codexQuotaStatus = quota
            }

            self.updateAgentStatuses()
            self.updateActiveAgent()
        }
    }

    // MARK: Update Agent Status (v3.1.2 — 优先 JSONL 文件时间)

    /// 从 ISO8601 字符串解析 Date，支持多种格式（微秒/毫秒/无小数）
    private func parseISO8601Date(_ str: String) -> Date? {
        // 方法1: ISO8601DateFormatter（新系统，支持 withFractionalSeconds）
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }

        // 方法2: DateFormatter 6位微秒
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(abbreviation: "UTC")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
        if let d = fmt.date(from: str) { return d }

        // 方法3: DateFormatter 3位毫秒
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        if let d = fmt.date(from: str) { return d }

        // 方法4: 截断到19位 + Z
        let trimmed = String(str.prefix(19)) + "Z"
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return fmt.date(from: trimmed)
    }

    private func latestActivityDate(
        from activities: [(client: String, lastActive: String, provider: String)],
        dbLastUpdate: Date?
    ) -> Date? {
        var latest = dbLastUpdate
        latest = maxDate(latest, activeAgentService.latestClaudeActivityDate())
        for activity in activities {
            latest = maxDate(latest, parseISO8601Date(activity.lastActive))
        }
        return latest
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (l?, r?): return max(l, r)
        case let (l?, nil): return l
        case let (nil, r?): return r
        case (nil, nil): return nil
        }
    }

    private func updateAgentStatuses() {
        var statuses: [AgentProviderStatus] = []

        // 从数据库查询各 Agent 最后活跃时间
        var lastActiveMap: [String: Date] = [:]
        if let usageRepository {
            for activity in usageRepository.latestActivityByClient() {
                if let date = parseISO8601Date(activity.lastActive) {
                    lastActiveMap[activity.client] = date
                    print("[Database] \(activity.client) last_active: \(date)")
                } else {
                    print("[Database] FAILED to parse: '\(activity.lastActive)'")
                }
            }
        }
        print("[ClaudeScanner] DB last_active: \(lastActiveMap["claude-code"]?.description ?? "nil")")

        // Claude Code: 优先使用 JSONL 文件修改时间（实时），
        // 其次使用数据库记录（来自 Python backend）
        let apiCount = apiTotalStats.totalRequests
        let dbClaudeActive = lastActiveMap["claude-code"]
        let jsonlActive = activeAgentService.latestClaudeActivityDate()
        let claudeLastActive: Date?
        if let j = jsonlActive, let d = dbClaudeActive {
            claudeLastActive = max(j, d)  // 取较新的
        } else {
            claudeLastActive = jsonlActive ?? dbClaudeActive
        }
        print("[ClaudeScanner] JSONL latest: \(jsonlActive?.description ?? "nil") → chosen: \(claudeLastActive?.description ?? "nil")")

        statuses.append(AgentProviderStatus(
            client: "claude-code",
            displayName: "Claude Code",
            status: apiCount > 0 ? .connected : .noData,
            lastSync: claudeLastActive ?? lastApiSync,
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

    // MARK: Active Agent Detection (v3.1.2)

    private func updateActiveAgent() {
        let codexPct = codexQuotaStatus.sessionPercent ?? codexQuotaStatus.weeklyPercent

        // 从数据库查询最近的活跃 Agent
        var latestClient: String?
        var latestTime: Date?

        if let usageRepository {
            for activity in usageRepository.latestActivityByClient() {
                if let date = parseISO8601Date(activity.lastActive),
                   date > (latestTime ?? .distantPast) {
                    latestTime = date
                    latestClient = activity.client
                }
            }
        }

        let info: ActiveAgentInfo
        if let client = latestClient {
            switch client {
            case "claude-code":
                let cost = costSummary.todayCost
                let detail = CostFormatter.formatShort(cost)
                info = ActiveAgentInfo(agent: .claudeCode, detail: detail, lastActive: latestTime)
            case "deepseek":
                let cost = costSummary.todayCost
                let detail = CostFormatter.formatShort(cost)
                info = ActiveAgentInfo(agent: .deepseek, detail: detail, lastActive: latestTime)
            default:
                let fallback = activeAgentService.detect(costSummary: costSummary, codexPercent: codexPct)
                info = fallback
            }
        } else if let pct = codexPct, pct >= 0, subscriptionSessions > 0 {
            info = ActiveAgentInfo(agent: .codex, detail: "\(Int(pct))%", lastActive: lastCodexSync)
        } else {
            let fallback = activeAgentService.detect(costSummary: costSummary, codexPercent: codexPct)
            info = fallback
        }
        self.activeAgentInfo = info
    }

    // MARK: Scanner Status (v1.4.x — 由 refreshAPI 驱动)

    private func updateScannerStatus() {
        scannerStatusService.checkNow()
        self.scannerStatus = scannerStatusService.scannerStatus
        self.lastScannerCheck = scannerStatusService.lastCheck
        self.pipelineHealth = scannerStatusService.scannerStatus.health
        self.scannerDiagnostic = scannerStatusService.lastDiagnostic
    }

    // MARK: Health Indicators (v1.4.x)

    private func updateHealthIndicators() {
        // Database
        self.dbHealth = dbStatus.hasData

        // API Refresh
        let elapsed = Date().timeIntervalSince(lastApiSync)
        self.apiRefreshHealth = elapsed < 60

        // Codex
        self.codexHealth = codexQuotaStatus.isAvailable
    }

    // MARK: Usage Data (v1.3.2)

    private func updateUsageData(todayStats: (cost: Double, inputTokens: Int, outputTokens: Int, requests: Int)? = nil) {
        guard let usageRepository else { return }
        let snapshot = usageRepository.loadUsageData(todayStats: todayStats)
        self.usageData = snapshot.usageData
        self.costHistory7Days = snapshot.costHistory7Days
        self.costSummaryDebugText = snapshot.costSummaryDebugText
    }

    // MARK: Budget

    func setInitialBalance(_ amount: Double) {
        guard amount >= 0 else { return }
        initialBalance = amount
        UserDefaults.standard.set(amount, forKey: initialBalanceKey)
        UserDefaults.standard.synchronize()
        updateUsageData()
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
