import Foundation

// Deprecated:
// replaced by MenuBarViewModel
// MARK: - MenuBar Status Service (legacy compatibility)

/// 菜单栏状态服务
///
/// 根据最近活跃 Agent 自动切换两行 MenuBar 标签：
///   ✨ Claude
///   今日 ¥0.24          — Claude Code 活跃
///   ⌘ Codex
///   5h 80%              — Codex 活跃（session percent）
///   AI ✓                — 无活跃 Agent
///
@available(*, deprecated, message: "Use MenuBarViewModel instead.")
@MainActor
final class MenuBarStatusService {
    private weak var usageService: UsageService?

    init(usageService: UsageService) {
        self.usageService = usageService
    }

    /// 计算当前菜单栏标签（两行格式）
    func computeLabel() -> String {
        guard let service = usageService else {
            print("[MenuBar] usageService=nil")
            return "AI !"
        }

        let activeInfo = service.activeAgentInfo

        switch activeInfo.agent {
        case .claudeCode:
            let cost = service.usageData.todayCost
            return "✨ Claude\n今日 \(CostFormatter.formatShort(cost))"

        case .deepseek:
            let cost = service.usageData.todayCost
            return "🤖 DeepSeek\n今日 \(CostFormatter.formatShort(cost))"

        case .codex:
            if service.codexQuotaStatus.isAvailable {
                let pct = Int(service.codexQuotaStatus.sessionPercent ?? 0)
                return "⌘ Codex\n5h \(pct)%"
            }
            return "⌘ Codex\nNo quota"

        case .none:
            break
        }

        // 降级：今日有 API 成本
        let todayCost = service.usageData.todayCost
        if todayCost > 0 {
            return "AI \(CostFormatter.formatShort(todayCost))"
        }

        // 正常状态
        if service.dbStatus.hasData {
            return L.menuBarNormal
        }

        return "AI !"
    }

    /// 获取快速状态（Dropdown 顶部显示）
    func quickStatusContent() -> [(label: String, value: String)] {
        guard let service = usageService else { return [] }

        var items: [(String, String)] = []

        // 活跃 Agent
        let agentName = service.activeAgentInfo.agent.displayName
        items.append(("活跃 Agent", agentName))

        // 今日成本
        items.append(("今日成本", CostFormatter.formatShort(service.costSummary.todayCost)))

        // Codex 额度
        let codexPct = service.codexQuotaStatus.sessionPercent ?? service.codexQuotaStatus.weeklyPercent ?? -1
        items.append(("Codex 额度", codexPct >= 0 ? "\(Int(codexPct))%" : "N/A"))

        // 最后活跃：来自 UsageRepository 汇总后的统一时间源
        if let lastActive = service.latestActivityDate ?? service.activeAgentInfo.lastActive {
            items.append(("最后活跃", RelativeTimeFormatter.format(lastActive)))
        }

        return items
    }
}
