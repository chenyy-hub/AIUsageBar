import Foundation

// MARK: - Active Agent Service

/// 活跃 Agent 检测服务
///
/// 通过检查各 Agent 的本地文件最近修改时间和数据库记录，
/// 判断当前正在使用的 AI Agent。
///
/// 数据来源：
///   - Codex:     ~/.codex/state_5.sqlite 文件修改时间
///   - Claude:    ~/.claude/projects/**/*.jsonl 文件修改时间
///   - DeepSeek:  api_usage_records 最近记录（通过 DatabaseService）
///
final class ActiveAgentService {
    private let home: String
    private let detectionWindow: TimeInterval

    /// 时间窗口内只要有活动就认为 Agent 活跃（默认 5 分钟）
    init(detectionWindow: TimeInterval = 300) {
        self.home = NSHomeDirectory()
        self.detectionWindow = detectionWindow
    }

    /// 检测当前活跃 Agent
    /// - Parameter costSummary: 今日 API 成本统计（用于 Claude/DeepSeek 活跃推断）
    /// - Returns: 检测结果（活跃 Agent、详情字符串、最后活跃时间）
    func detect(costSummary: DatabaseService.CostSummary? = nil, codexPercent: Double? = nil) -> ActiveAgentInfo {
        let codexRecent = checkCodexRecentActivity()
        let claudeRecent = checkClaudeRecentActivity()
        let cost = costSummary?.todayCost ?? 0
        let now = Date()

        // 构建候选列表
        var candidates: [(agent: ActiveAgent, score: Int, detail: String, lastActive: Date?)] = []

        // Codex: 文件最近修改且额度数据可用
        if codexRecent, let pct = codexPercent, pct >= 0 {
            candidates.append((.codex, 3, "\(Int(pct))%", now))
        }

        // Claude Code: JSONL 文件最近修改或有今日 API 成本
        if claudeRecent || cost > 0 {
            let detail = cost > 0
                ? CostFormatter.formatShort(cost)
                : "今日 \(CostFormatter.formatShort(cost))"
            candidates.append((.claudeCode, 2, detail, now))
        }

        // DeepSeek: 有今日成本且高于阈值
        if cost > 0.01 {
            let detail = CostFormatter.formatShort(cost)
            candidates.append((.deepseek, 1, detail, now))
        }

        // 选出最高优先级的活跃 Agent
        if let winner = candidates.max(by: { $0.score < $1.score }) {
            return ActiveAgentInfo(
                agent: winner.agent,
                detail: winner.detail,
                lastActive: winner.lastActive
            )
        }

        return ActiveAgentInfo(agent: .none, detail: "", lastActive: nil)
    }

    // MARK: - Codex Activity

    /// 检查 Codex state_5.sqlite 文件是否在窗口期内有修改
    private func checkCodexRecentActivity() -> Bool {
        latestCodexActivityDate() != nil
    }

    /// 获取最新 Codex state 文件的修改时间
    func latestCodexActivityDate() -> Date? {
        let paths = [
            "\(home)/.codex/state_5.sqlite",
            "\(home)/.codex/sqlite/state_5.sqlite",
        ]
        var latest: Date?
        for path in paths {
            guard let attrs = try? FileManager.default.attributesOfItem(atPath: path),
                  let mtime = attrs[.modificationDate] as? Date else {
                continue
            }
            if mtime > (latest ?? .distantPast) {
                latest = mtime
            }
        }
        return latest
    }

    // MARK: - Claude Code Activity

    /// 检查 ~/.claude/projects/ 下 JSONL 文件是否在窗口期内有修改
    private func checkClaudeRecentActivity() -> Bool {
        latestClaudeActivityDate() != nil
    }

    /// 获取最新 Claude JSONL 文件的修改时间（所有 projects 子目录）
    /// 用于 Dashboard「Last used」时间更新
    func latestClaudeActivityDate() -> Date? {
        let claudeDir = "\(home)/.claude/projects"
        guard FileManager.default.fileExists(atPath: claudeDir) else { return nil }

        let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: claudeDir),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        )

        guard let enumerator else { return nil }

        var latest: Date?
        for case let file as URL in enumerator {
            guard file.pathExtension == "jsonl" else { continue }
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mtime = attrs.contentModificationDate else {
                continue
            }
            if mtime > (latest ?? .distantPast) {
                latest = mtime
            }
        }
        return latest
    }
}
