import SwiftUI

// MARK: - Agent Usage View (v5.2 Optimized)

/// 展示所有 AI Agent 的使用资源。
///
/// 双模式展示：
///   - API Cost:   成本 + Token 总量 + Provider 标识
///   - Subscription: Quota 占比 + Session 数 + Reset time
///
/// 按成本/用量自动排序（最高优先）。
///
struct AgentUsageView: View {
    let usages: [AgentResource]

    var body: some View {
        if usages.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "AI Agent 使用", icon: "cpu.fill")

                // 按 cost 排序（API 优先），quota 在后
                ForEach(sortedUsages) { agent in
                    AgentCard(agent: agent)
                }

                // Agent 排行（迷你条状图）
                agentRankingBar
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
            )
        }
    }

    /// 排序：混合情况 API 在前，按 cost/用量降序
    private var sortedUsages: [AgentResource] {
        usages.sorted { a, b in
            let aVal = a.cost ?? a.quotaUsed ?? 0
            let bVal = b.cost ?? b.quotaUsed ?? 0
            return aVal > bVal
        }
    }

    /// Agent 排行迷你条
    private var agentRankingBar: some View {
        let total = sortedUsages.reduce(0.0) { $0 + max(($1.cost ?? 0), ($1.quotaUsed ?? 0)) }
        guard total > 0 else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 3) {
                ForEach(sortedUsages.prefix(3)) { agent in
                    let val = max(agent.cost ?? 0, agent.quotaUsed ?? 0)
                    let fraction = val / total
                    HStack(spacing: 6) {
                        Image(systemName: agent.iconName)
                            .font(.system(size: 8))
                            .foregroundColor(.accentColor)
                            .frame(width: 14)
                        Text(agent.displayName)
                            .font(.system(size: 9))
                            .frame(width: 70, alignment: .leading)
                            .lineLimit(1)
                        ProgressBarView(value: fraction, color: agentColor(agent), height: 4)
                        Text(agent.typeLabel)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                            .frame(width: 60)
                    }
                }
            }
            .padding(.top, 4)
        )
    }

    private func agentColor(_ agent: AgentResource) -> Color {
        agent.usageType == .apiCost ? .blue : .orange
    }
}

// MARK: - Agent Card (v5.2)

struct AgentCard: View {
    let agent: AgentResource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: icon + name + type badge + provider
            HStack {
                Image(systemName: agent.iconName)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(agent.displayName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                providerBadge(name: agent.provider)
                typeBadge
            }

            // Content by type
            switch agent.usageType {
            case .apiCost:
                apiCostContent
            case .subscriptionQuota:
                subscriptionContent
            case .localUsage:
                localUsageContent
            }

            // Warning
            if agent.isEstimated {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                    Text("估计值 — SQLite 数据不完整")
                        .font(.system(size: 8))
                        .foregroundColor(.orange)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    // MARK: Badges

    private var typeBadge: some View {
        HStack(spacing: 3) {
            Image(systemName: agent.typeIcon)
                .font(.system(size: 7))
            Text(agent.typeLabel)
                .font(.system(size: 8, weight: .medium))
        }
        .foregroundColor(agent.usageType == .apiCost ? .blue : .orange)
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill((agent.usageType == .apiCost ? Color.blue : Color.orange).opacity(0.1))
        )
    }

    @ViewBuilder
    private func providerBadge(name: String) -> some View {
        HStack(spacing: 3) {
            Circle()
                .fill(providerColor(name))
                .frame(width: 6, height: 6)
            Text(name)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(providerColor(name))
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 2)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(providerColor(name).opacity(0.08))
        )
    }

    // MARK: API Cost Content

    private var apiCostContent: some View {
        HStack(alignment: .center) {
            // Cost (large)
            if let cost = agent.cost {
                VStack(alignment: .leading, spacing: 1) {
                    Text("成本")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.format(cost))
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            Spacer()

            // Tokens
            if let tokens = agent.inputTokens, tokens > 0 {
                VStack(alignment: .trailing, spacing: 1) {
                    Text("Token")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(TokenFormatter.format(tokens))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .monospacedDigit()
                }
            }

            // Session count (derived)
            if let tokens = agent.inputTokens, tokens > 100_000 {
                let estSessions = tokens / 200_000
                VStack(alignment: .trailing, spacing: 1) {
                    Text("会话")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("~\(estSessions)")
                        .font(.caption)
                        .monospacedDigit()
                }
                .padding(.leading, 8)
            }
        }
    }

    // MARK: Subscription Content

    private var subscriptionContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Token line
            if let used = agent.quotaUsed {
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("已用 Token")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(TokenFormatter.format(Int(used)))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                    }

                    Spacer()

                    if let limit = agent.quotaLimit, limit > 0 {
                        let pct = min(used / max(limit, 1), 1.0)
                        VStack(alignment: .trailing, spacing: 1) {
                            Text("配额")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text("\(Int(pct * 100))%")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(pct > 0.85 ? .red : pct > 0.6 ? .orange : .green)
                        }
                    }
                }

                // Progress bar
                if let limit = agent.quotaLimit, limit > 0 {
                    let pct = min(used / max(limit, 1), 1.0)
                    ProgressBarView(
                        value: pct,
                        color: pct > 0.85 ? .red : pct > 0.6 ? .orange : .green,
                        height: 5
                    )
                }
            }

            // Reset + sessions
            HStack(spacing: 12) {
                if let reset = agent.resetTime {
                    Text("🔄 \(reset, style: .relative)")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                if let used = agent.quotaUsed {
                    let estSessions = max(1, Int(used) / 500_000)
                    Text("~\(estSessions) 次会话")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: Local Content

    private var localUsageContent: some View {
        Text("本地运行 — 无云端消耗")
            .font(.caption)
            .foregroundColor(.secondary)
    }

    // MARK: Colors

    private func providerColor(_ name: String) -> Color {
        switch name.lowercased() {
        case "deepseek":  return .blue
        case "openai":    return .green
        case "anthropic": return .orange
        case "gemini":    return .purple
        default:          return .gray
        }
    }
}
