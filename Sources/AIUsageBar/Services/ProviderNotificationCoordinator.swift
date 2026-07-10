import Foundation

/// Persists provider-specific notification progress so the five-second
/// MenuBar refresh never emits duplicate alerts.
@MainActor
final class ProviderNotificationCoordinator {
    private let notificationService: NotificationService
    private let defaults: UserDefaults

    private let claudeDayKey = "providerAlerts.claude.day"
    private let claudeLevelKey = "providerAlerts.claude.level"
    private let codexWindowKey = "providerAlerts.codex.window"
    private let codexLevelKey = "providerAlerts.codex.level"

    init(notificationService: NotificationService, defaults: UserDefaults = .standard) {
        self.notificationService = notificationService
        self.defaults = defaults
    }

    func evaluate(claudeTodayCost: Double, claudeBudget: Double, codexQuota: CodexQuotaStatus, now: Date = Date()) {
        evaluateClaude(todayCost: claudeTodayCost, budget: claudeBudget, now: now)
        evaluateCodex(quota: codexQuota, now: now)
    }

    private func evaluateClaude(todayCost: Double, budget: Double, now: Date) {
        guard budget > 0 else { return }

        let day = Self.dayFormatter.string(from: now)
        if defaults.string(forKey: claudeDayKey) != day {
            defaults.set(day, forKey: claudeDayKey)
            defaults.set(0, forKey: claudeLevelKey)
        }

        let percent = todayCost / budget * 100
        let level: Int
        switch percent {
        case 100...: level = 3
        case 90...: level = 2
        case 80...: level = 1
        default: level = 0
        }

        let previousLevel = defaults.integer(forKey: claudeLevelKey)
        guard level > previousLevel else { return }
        defaults.set(level, forKey: claudeLevelKey)

        let type: NotificationService.NotificationType
        let threshold: Int
        switch level {
        case 1: type = .claudeUsageWarning; threshold = 80
        case 2: type = .claudeUsageCritical; threshold = 90
        default: type = .claudeUsageLimit; threshold = 100
        }
        notificationService.send(
            type: type,
            body: "Claude today usage reached \(threshold)% of the configured budget.",
            playSound: level >= 2
        )
    }

    private func evaluateCodex(quota: CodexQuotaStatus, now: Date) {
        guard let resetTime = quota.sessionResetTime, quota.isAvailable else { return }

        // Round to a minute: the provider may report sub-second reset changes.
        let windowID = String(Int(resetTime.timeIntervalSince1970 / 60))
        if defaults.string(forKey: codexWindowKey) != windowID {
            defaults.set(windowID, forKey: codexWindowKey)
            defaults.set(0, forKey: codexLevelKey)
        }

        let remaining = max(0, resetTime.timeIntervalSince(now))
        let level: Int
        if remaining <= 10 * 60 {
            level = 2
        } else if remaining <= 30 * 60 {
            level = 1
        } else {
            level = 0
        }

        let previousLevel = defaults.integer(forKey: codexLevelKey)
        guard level > previousLevel else { return }
        defaults.set(level, forKey: codexLevelKey)

        let type: NotificationService.NotificationType = level == 2
            ? .codexQuota10Minutes
            : .codexQuota30Minutes
        let minutes = Int(ceil(remaining / 60))
        notificationService.send(
            type: type,
            body: "Codex 5-hour window resets in \(minutes) minutes.",
            playSound: level == 2
        )
    }

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
