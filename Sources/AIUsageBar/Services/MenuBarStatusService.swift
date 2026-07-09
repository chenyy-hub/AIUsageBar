import Foundation

// MARK: - MenuBar State

/// 菜单栏显示状态枚举（优先级从高到低）
enum MenuBarState: String, Codable, CaseIterable {
    case codexWarning   // Codex quota >= 75%
    case apiCost        // API cost > 0 today
    case normal         // AI ✓
    case syncing        // 正在同步
    case offline        // 无数据
}

// MARK: - MenuBar Status

/// 菜单栏当前状态
struct MenuBarStatus {
    let state: MenuBarState
    let icon: String
    let text: String
    let priority: Int

    var fullText: String {
        switch state {
        case .codexWarning: return "\(icon) AI \(text)"
        case .apiCost:      return "AI \(text)"
        case .normal:       return "AI \(text)"
        case .syncing:      return "AI \(text)"
        case .offline:      return "AI \(text)"
        }
    }
}

// MARK: - MenuBar Status Service

/// 负责根据 UsageService、DatabaseService、CodexQuotaProvider 计算菜单栏状态。
///
/// 状态优先级：
///   1. Codex quota >= 90% → 🔥 AI 95%
///   2. Codex quota >= 75% → ⚠ AI 80%
///   3. API cost > 0       → AI ¥12.5
///   4. 有数据              → AI ✓
///   5. 无数据              → AI !
///
@MainActor
final class MenuBarStatusService {
    private weak var usageService: UsageService?

    init(usageService: UsageService) {
        self.usageService = usageService
    }

    /// 计算当前菜单栏状态（基于现有 timer 数据，不额外查询 DB）
    func computeStatus() -> MenuBarStatus {
        guard let service = usageService else {
            return MenuBarStatus(state: .offline, icon: "!", text: "!", priority: 0)
        }

        let dbOk = service.dbStatus.hasData
        let todayCost = service.apiTotalStats.totalCost
        let codexPct = service.codexQuotaStatus.sessionPercent ?? service.codexQuotaStatus.weeklyPercent ?? -1

        // 1. Codex quota warning (最高优先级)
        if codexPct >= 90 {
            return MenuBarStatus(
                state: .codexWarning,
                icon: "🔥",
                text: "\(Int(codexPct))%",
                priority: 5
            )
        }

        if codexPct >= 75 {
            return MenuBarStatus(
                state: .codexWarning,
                icon: "⚠",
                text: "\(Int(codexPct))%",
                priority: 4
            )
        }

        // 2. API cost
        if todayCost > 0 {
            return MenuBarStatus(
                state: .apiCost,
                icon: "",
                text: CostFormatter.formatShort(todayCost),
                priority: 3
            )
        }

        // 3. Normal (有数据)
        if dbOk {
            return MenuBarStatus(
                state: .normal,
                icon: "",
                text: "✓",
                priority: 2
            )
        }

        // 4. Offline
        return MenuBarStatus(
            state: .offline,
            icon: "",
            text: "!",
            priority: 0
        )
    }

    /// 获取快速状态（Dropdown 顶部显示）
    func quickStatusContent() -> [(label: String, value: String)] {
        guard let service = usageService else { return [] }

        var items: [(String, String)] = []

        // API Cost
        let cost = CostFormatter.format(service.apiTotalStats.totalCost)
        items.append(("API Cost", cost))

        items.append(("Requests", "\(service.apiTotalStats.totalRequests)"))

        // Codex
        let codexPct = service.codexQuotaStatus.sessionPercent ?? service.codexQuotaStatus.weeklyPercent ?? -1
        items.append(("Codex", codexPct >= 0 ? "\(Int(codexPct))%" : "N/A"))

        // Last Sync
        let apiAgo = timeAgo(service.lastApiSync)
        items.append(("Last Sync", apiAgo))

        return items
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Int(-date.timeIntervalSinceNow)
        if interval < 60 { return "\(interval)s ago" }
        return "\(interval / 60)min ago"
    }
}
