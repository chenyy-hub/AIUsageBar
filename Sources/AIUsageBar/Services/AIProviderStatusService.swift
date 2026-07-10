import Foundation

enum AIProvider: Equatable {
    case claude
    case codex
    case none
}

struct ClaudeProviderUsage {
    let todayCost: Double
    let todayTokens: Int
    let lastActivity: Date?
}

struct AIProviderSnapshot {
    let currentProvider: AIProvider
    let claudeUsage: ClaudeProviderUsage
    let codexQuota: CodexQuotaStatus
    let codexLastActivity: Date?
    let latestActivity: Date?

    static let unavailable = AIProviderSnapshot(
        currentProvider: .none,
        claudeUsage: ClaudeProviderUsage(todayCost: 0, todayTokens: 0, lastActivity: nil),
        codexQuota: .unavailable,
        codexLastActivity: nil,
        latestActivity: nil
    )
}

/// Provider-facing state for the MenuBar. It reads the existing repository
/// snapshot and Codex monitor output, but owns neither collection pipeline.
@MainActor
final class AIProviderStatusService: ObservableObject {
    @Published private(set) var snapshot: AIProviderSnapshot = .unavailable

    private let usageRepository: UsageRepository?
    private let codexQuotaMonitor: CodexQuotaMonitor
    private let activityService: ActiveAgentService
    private let notificationCoordinator: ProviderNotificationCoordinator
    private let claudeBudgetProvider: () -> Double
    private var timer: Timer?

    init(
        usageRepository: UsageRepository?,
        codexQuotaMonitor: CodexQuotaMonitor,
        activityService: ActiveAgentService,
        notificationCoordinator: ProviderNotificationCoordinator,
        claudeBudgetProvider: @escaping () -> Double
    ) {
        self.usageRepository = usageRepository
        self.codexQuotaMonitor = codexQuotaMonitor
        self.activityService = activityService
        self.notificationCoordinator = notificationCoordinator
        self.claudeBudgetProvider = claudeBudgetProvider
        start()
    }

    deinit {
        timer?.invalidate()
    }

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        guard let usageRepository else {
            snapshot = .unavailable
            return
        }

        let repositorySnapshot = usageRepository.loadMenuBarSnapshot()
        let activities = repositorySnapshot.latestActivityByClient
        let claudeDatabaseActivity = latestActivity(in: activities, clients: ["claude-code", "deepseek"])
        let claudeActivity = maxDate(activityService.latestClaudeActivityDate(), claudeDatabaseActivity)
        let codexDatabaseActivity = latestActivity(in: activities, clients: ["codex"])
        let codexActivity = maxDate(activityService.latestCodexActivityDate(), codexDatabaseActivity)
        let latest = maxDate(claudeActivity, codexActivity)

        let provider: AIProvider
        switch (claudeActivity, codexActivity) {
        case let (claude?, codex?): provider = claude >= codex ? .claude : .codex
        case (.some, nil): provider = .claude
        case (nil, .some): provider = .codex
        case (nil, nil): provider = .none
        }

        let today = repositorySnapshot.todayStats
        let value = AIProviderSnapshot(
            currentProvider: provider,
            claudeUsage: ClaudeProviderUsage(
                todayCost: today.cost,
                todayTokens: today.inputTokens + today.outputTokens,
                lastActivity: claudeActivity
            ),
            codexQuota: codexQuotaMonitor.quotaStatus,
            codexLastActivity: codexActivity,
            latestActivity: latest
        )
        snapshot = value
        notificationCoordinator.evaluate(
            claudeTodayCost: value.claudeUsage.todayCost,
            claudeBudget: claudeBudgetProvider(),
            codexQuota: value.codexQuota
        )
    }

    private func latestActivity(
        in activities: [(client: String, lastActive: String, provider: String)],
        clients: Set<String>
    ) -> Date? {
        activities
            .filter { clients.contains($0.client) }
            .compactMap { parseISO8601Date($0.lastActive) }
            .max()
    }

    private func parseISO8601Date(_ value: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }

    private func maxDate(_ lhs: Date?, _ rhs: Date?) -> Date? {
        switch (lhs, rhs) {
        case let (left?, right?): return max(left, right)
        case let (left?, nil): return left
        case let (nil, right?): return right
        case (nil, nil): return nil
        }
    }
}
