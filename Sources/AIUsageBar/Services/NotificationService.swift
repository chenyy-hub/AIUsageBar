import Foundation
import UserNotifications

// MARK: - Notification Service (v1.1 — 安全初始化)

/// 通知服务
///
/// 安全策略：
///   - UNUserNotificationCenter.current() 在非 .app bundle 环境中会崩溃
///     （bundleProxyForCurrentProcess is nil）
///   - 使用 optional + lazy 初始化，仅在有效 bundle 下才创建
///
final class NotificationService {

    /// 通知类型
    enum NotificationType: String {
        case quotaReset    = "quota_reset"
        case quotaWarning  = "quota_warning"
        case apiCostWarning = "api_cost_warning"
        case claudeUsageWarning = "claude_usage_warning"
        case claudeUsageCritical = "claude_usage_critical"
        case claudeUsageLimit = "claude_usage_limit"
        case codexQuota30Minutes = "codex_quota_30_minutes"
        case codexQuota10Minutes = "codex_quota_10_minutes"

        var localizedTitle: String {
            switch self {
            case .quotaReset:     return "Codex 额度已刷新"
            case .quotaWarning:   return "Codex 额度不足"
            case .apiCostWarning: return "API 消耗提醒"
            case .claudeUsageWarning: return "Claude 用量提醒"
            case .claudeUsageCritical: return "Claude 用量告急"
            case .claudeUsageLimit: return "Claude 用量已达上限"
            case .codexQuota30Minutes: return "Codex 窗口即将重置"
            case .codexQuota10Minutes: return "Codex 窗口即将重置"
            }
        }
    }

    private var isAuthorized = false
    /// 可能为 nil：在非 .app bundle 下运行时为 nil
    private let notifCenter: UNUserNotificationCenter? = {
        // UNUserNotificationCenter.current() 内部要求 bundleProxyForCurrentProcess
        // 不为 nil。直接运行二进制时 mainBundle.bundleURL 不是 .app 路径，会 crash。
        guard Bundle.main.bundleURL.pathExtension == "app" else {
            print("[Startup] NotificationService: running outside .app bundle → notifications disabled")
            return nil
        }
        return UNUserNotificationCenter.current()
    }()

    deinit {
        print("[Startup] NotificationService deinit")
    }

    private var isAvailable: Bool {
        guard notifCenter != nil else { return false }
        return true
    }

    /// 请求通知权限（启动时调用一次）
    func requestAuthorization() {
        guard let center = notifCenter else { return }
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            self?.isAuthorized = granted
        }
    }

    /// 发送本地通知
    /// - Parameters:
    ///   - type: 通知类型
    ///   - body: 通知正文
    ///   - playSound: 是否播放提示音
    func send(type: NotificationType, body: String, playSound: Bool = false) {
        guard let center = notifCenter else { return }
        guard isAuthorized else {
            // 还未授权时尝试请求
            center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
                if granted {
                    self.sendNow(center: center, type: type, body: body, playSound: playSound)
                }
            }
            return
        }
        sendNow(center: center, type: type, body: body, playSound: playSound)
    }

    private func sendNow(center: UNUserNotificationCenter, type: NotificationType, body: String, playSound: Bool) {
        let content = UNMutableNotificationContent()
        content.title = type.localizedTitle
        content.body = body
        if playSound {
            content.sound = .default
        }

        let request = UNNotificationRequest(
            identifier: "\(type.rawValue)_\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil  // 立即发送
        )

        center.add(request) { error in
            if let error {
                NSLog("[AIUsageBar] Notification error: \(error.localizedDescription)")
            }
        }
    }
}
