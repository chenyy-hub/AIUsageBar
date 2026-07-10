import Foundation
import Combine

// MARK: - Codex Quota Monitor (v2.0 — Alert State Machine + Cooldown)

/// Codex 额度监控器
///
/// 每 60 秒读取 Codex rateLimits，通过 `CodexAlertManager` 状态机检测：
///   - Normal   (< 80%)                → 不触发任何告警
///   - Warning  (80%-89%)              → 首次进入触发 ⚠️ 提醒（30min 冷却）
///   - Critical (>= 95%)              → 首次进入触发提醒
///   - LimitReached (100%)             → 首次进入触发提醒
///   - Reset（额度恢复）               → 首次恢复触发提醒
///
/// 告警行为：
///   - `didResetQuota = true`          → MenuBar 闪烁 3 次
///   - macOS 本地通知（可选声音）
///
final class CodexQuotaMonitor: ObservableObject {

    // MARK: Published State

    /// 最近一次检测到的额度状态
    @Published var quotaStatus: CodexQuotaStatus = .unavailable

    /// 告警/重置闪烁标志（1 秒后自动清空）
    /// MenuBarExtra label 通过 `.opacity()` + `.repeatCount(3)` 实现 3 次闪烁
    @Published var didResetQuota: Bool = false {
        didSet {
            if didResetQuota {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                    self?.didResetQuota = false
                }
            }
        }
    }

    // MARK: Internal State

    private let provider: CodexQuotaProvider
    private let notificationService: NotificationService
    private let alertManager: CodexAlertManager
    private var timer: Timer?

    // MARK: Init

    init(provider: CodexQuotaProvider = CodexQuotaProvider(),
         notificationService: NotificationService = NotificationService()) {
        self.provider = provider
        self.notificationService = notificationService
        self.alertManager = CodexAlertManager()
    }

    // MARK: Start / Stop

    /// 开始监控（每 60 秒检查一次）
    func start() {
        check() // 立即执行首次检测
        timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    /// 停止监控
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: Check

    /// 强制立即检测
    func check() {
        let status = provider.fetchStatus()

        // 将状态交给 AlertManager 状态机评估
        let event = alertManager.evaluate(status: status)

        switch event {
        case .warning(let percent):
            // Codex quota warning — 首次进入 >= 80%
            didResetQuota = true  // MenuBar 闪烁 3 次
            notificationService.send(
                type: .quotaWarning,
                body: "Codex 5h quota warning\nUsage: \(percent)%",
                playSound: true
            )

        case .critical(let percent):
            // Codex quota critical — 首次进入 >= 95%
            didResetQuota = true
            notificationService.send(
                type: .quotaWarning,
                body: "Codex quota critical\nUsage: \(percent)%",
                playSound: true
            )

        case .limitReached(let percent):
            // Codex quota limit reached — 首次进入 100%
            didResetQuota = true
            notificationService.send(
                type: .quotaWarning,
                body: "Codex quota limit reached\nUsage: \(percent)%",
                playSound: true
            )

        case .reset(let percent):
            // 额度恢复 — 状态变化提醒一次
            notificationService.send(
                type: .quotaReset,
                body: "Codex quota refreshed (\(percent)%)",
                playSound: false
            )

        case .none:
            break
        }

        // 更新发布状态
        DispatchQueue.main.async { [weak self] in
            self?.quotaStatus = status
        }
    }
}
