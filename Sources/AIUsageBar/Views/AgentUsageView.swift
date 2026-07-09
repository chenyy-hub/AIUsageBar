import SwiftUI

// MARK: - Agent Usage View (v1.0)

/// 展示所有 AI Agent 的使用资源。
///
/// 严格区分 API Cost 和 Subscription Quota：
///   - API:         成本 + Token 总量
///   - Subscription: Token 用量 + Session 数（无金额）
///
struct AgentUsageView: View {
    let usages: [AgentResource]

    var body: some View {
        if usages.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 8) {
                SectionHeaderView(title: "AI Agent", icon: "cpu.fill")

                ForEach(sortedUsages) { agent in
                    AgentCard(agent: agent)
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
            )
        }
    }

    private var sortedUsages: [AgentResource] {
        usages.sorted { a, b in
            let aVal = a.cost ?? a.quotaUsed ?? 0
            let bVal = b.cost ?? b.quotaUsed ?? 0
            return aVal > bVal
        }
    }
}

// MARK: - Agent Card

struct AgentCard: View {
    let agent: AgentResource

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
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
        }
    }

    // MARK: Subscription Content

    private var subscriptionContent: some View {
        HStack(alignment: .center) {
            if let used = agent.quotaUsed {
                VStack(alignment: .leading, spacing: 1) {
                    Text("用量")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(TokenFormatter.format(Int(used)))
                        .font(.title3)
                        .fontWeight(.bold)
                        .monospacedDigit()
                }
            }

            Spacer()

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
