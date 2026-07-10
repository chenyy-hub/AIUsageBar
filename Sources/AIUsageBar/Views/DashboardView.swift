import SwiftUI

// MARK: - Main Dashboard (v2.0 — 产品化)

struct DashboardView: View {
    @ObservedObject var service: UsageService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if service.isLoading && service.todaySummary.requestCount == 0 && service.subscriptionSessions == 0 {
                    LoadingView()
                } else if let err = service.errorMessage {
                    ErrorStateView(message: err) { service.reconnect() }
                } else if !service.dbStatus.hasData {
                    EmptyStateView()
                } else {
                    content
                }
            }
            .padding(16)
        }
        .frame(width: 340, height: 560)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        // 1. AI Usage Hero
        aiUsageSection

        // 2. 7 天消耗趋势
        costTrendSection

        // 3. Active Agents
        activeAgentsSection

        // 4. Model Usage
        modelUsageSection

        // 5. Budget
        budgetSection
    }

    // MARK: Section 1 — AI Usage

    private var aiUsageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(L.aiUsage)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                Spacer()
                // Agent status badges
                HStack(spacing: 6) {
                    ForEach(service.agentStatuses.prefix(3)) { agent in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(agent.status == .connected ? Color.green : Color.gray)
                                .frame(width: 5, height: 5)
                            Text(agent.displayName)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            // Hero: 今日消费
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.todayUsage)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.format(service.usageData.todayCost))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // 累计 | 今日 Token | 请求数
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.cumulative)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.formatShort(service.usageData.totalCost))
                        .font(.system(size: 16, weight: .bold, design: .monospaced))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(L.tokens)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(TokenFormatter.format(service.usageData.todayTokens))
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(L.requests)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("\(service.usageData.todayRequests)")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 预计可使用（余额 > 0 时显示）
            if let days = service.estimatedDaysRemaining, service.currentBalance > 0 {
                Divider()
                    .opacity(0.5)

                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.remainingDays)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        HStack(spacing: 2) {
                            Text("\(days)")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .monospacedDigit()
                            Text(L.day)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.10), Color.accentColor.opacity(0.03)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: Section 2 — 7 天消耗趋势

    private var costTrendSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: L.costTrend, icon: "chart.bar.fill")

            if service.costHistory7Days.isEmpty {
                Text(L.noData)
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(Array(service.costHistory7Days.enumerated()), id: \.offset) { index, day in
                        costTrendBar(day: day, index: index, total: service.costHistory7Days.count)
                    }
                }
                .frame(height: 60)
            }
        }
    }

    private func costTrendBar(day: (date: String, cost: Double, tokens: Int), index: Int, total: Int) -> some View {
        let maxCost = service.costHistory7Days.map(\.cost).max() ?? 1
        let isToday = index == total - 1
        let barHeight = maxCost > 0 ? max(CGFloat(day.cost / maxCost) * 44, 4) : 4

        return VStack(spacing: 3) {
            Text(CostFormatter.formatShort(day.cost))
                .font(.system(size: 7))
                .foregroundColor(.secondary)
                .lineLimit(1)

            RoundedRectangle(cornerRadius: 3)
                .fill(isToday ? Color.accentColor : Color.secondary.opacity(0.4))
                .frame(height: barHeight)

            Text(dayDateLabel(day.date, isToday: isToday))
                .font(.system(size: 7))
                .foregroundColor(isToday ? .primary : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Section 3 — Active Agents

    private var activeAgentsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: L.activeAgents, icon: "cpu.fill")

            // Claude Code
            if service.apiTotalStats.totalCost > 0 || service.apiTotalStats.totalRequests > 0 {
                agentCard(
                    icon: "sparkles",
                    title: L.claudeCode,
                    providerColor: .orange,
                    status: service.agentStatuses.first(where: { $0.client == "claude-code" })?.status ?? .noData
                ) {
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(L.cost)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(CostFormatter.format(service.apiTotalStats.totalCost))
                                .font(.title3)
                                .fontWeight(.bold)
                                .monospacedDigit()
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            Text(L.tokens)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            Text(TokenFormatter.format(service.apiTotalStats.totalInput))
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .monospacedDigit()
                        }
                    }

                    if let claudeAgent = service.agentStatuses.first(where: { $0.client == "claude-code" }),
                       let lastActive = claudeAgent.lastSync {
                        Text("Last used \(RelativeTimeFormatter.format(lastActive))")
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Codex
            if service.subscriptionSessions > 0 {
                agentCard(
                    icon: "chevron.left.forwardslash.chevron.right",
                    title: L.codex,
                    providerColor: .blue,
                    status: service.agentStatuses.first(where: { $0.client == "codex" })?.status ?? .noData
                ) {
                    HStack(spacing: 12) {
                        // Session quota
                        VStack(alignment: .leading, spacing: 2) {
                            Text("5h \(L.quotaLabel)")
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Text("\(Int(service.codexQuotaStatus.sessionPercent ?? 0))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                Text(L.used)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            if let remaining = service.codexQuotaStatus.sessionRemainingPercent {
                                Text("\(Int(remaining))% \(L.remaining)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }

                        // Weekly quota
                        VStack(alignment: .leading, spacing: 2) {
                            Text(L.weeklyQuota)
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Text("\(Int(service.codexQuotaStatus.weeklyPercent ?? 0))%")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .monospacedDigit()
                                Text(L.used)
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                            if let reset = service.codexQuotaStatus.sessionResetTime {
                                Text("\(L.reset) \(reset, style: .relative)")
                                    .font(.system(size: 8))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Text("Last sync \(RelativeTimeFormatter.format(service.lastCodexSync))")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: Agent Card Builder

    private func agentCard(
        icon: String,
        title: String,
        providerColor: Color,
        status: AgentConnectionStatus,
        @ViewBuilder content: () -> some View
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                // Status badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor(status))
                        .frame(width: 6, height: 6)
                    Text(statusLabel(status))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(providerColor.opacity(0.08)))
            }
            content()
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }

    private func statusColor(_ status: AgentConnectionStatus) -> Color {
        switch status {
        case .connected:    return .green
        case .syncing:      return .orange
        case .unavailable:  return .red
        case .noData:       return .gray
        }
    }

    private func statusLabel(_ status: AgentConnectionStatus) -> String {
        switch status {
        case .connected:    return "Connected"
        case .syncing:      return "Syncing"
        case .unavailable:  return "Unavailable"
        case .noData:       return "No Data"
        }
    }

    // MARK: Section 4 — Model Usage

    private var modelUsageSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: L.modelUsage, icon: "cpu.fill")

            // API Models
            if !service.apiModels.isEmpty {
                CardView(title: nil) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(service.apiModels.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Circle().fill(modelColor(item.model)).frame(width: 5, height: 5)
                                Text(item.model).font(.subheadline).lineLimit(1)
                                Spacer()
                                Text(CostFormatter.format(item.cost))
                                    .font(.subheadline).fontWeight(.medium).monospacedDigit()
                                Text(TokenFormatter.format(item.tokens))
                                    .font(.caption).foregroundColor(.secondary).monospacedDigit()
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }

            // Subscription Models
            if !service.subscriptionModels.isEmpty {
                CardView(title: nil) {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(service.subscriptionModels.enumerated()), id: \.offset) { _, item in
                            HStack {
                                Circle().fill(Color.orange).frame(width: 5, height: 5)
                                Text(item.model).font(.subheadline).lineLimit(1)
                                Spacer()
                                Text(TokenFormatter.format(Int(item.tokens)))
                                    .font(.subheadline).fontWeight(.medium).monospacedDigit()
                                Text("\(item.sessions) \(L.sessions)")
                                    .font(.caption).foregroundColor(.secondary)
                            }
                            .frame(height: 20)
                        }
                    }
                }
            }
        }
    }

    private func modelColor(_ name: String) -> Color {
        if name.lowercased().contains("pro") { return .purple }
        if name.lowercased().contains("flash") { return .blue }
        return .green
    }

    // MARK: Section 5 — Budget

    private var budgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: L.budget, icon: "creditcard.fill")

            VStack(alignment: .leading, spacing: 10) {
                // Total Budget | Used | Remaining (3-column)
                HStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(L.totalBudget)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(CostFormatter.format(service.initialBalance))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .center, spacing: 2) {
                        Text(L.usedCost)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(CostFormatter.format(service.usageData.totalCost))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(.primary)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(L.remainingBalance)
                            .font(.system(size: 8))
                            .foregroundColor(.secondary)
                        Text(CostFormatter.format(service.currentBalance))
                            .font(.system(size: 16, weight: .bold, design: .monospaced))
                            .foregroundColor(balanceColor)
                            .monospacedDigit()
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }

                // Progress bar
                if service.initialBalance > 0 {
                    let ratio = min(service.usageData.totalCost / service.initialBalance, 1.5)
                    ProgressBarView(
                        value: min(ratio, 1.0),
                        color: ratio > 1 ? .red : (ratio > 0.8 ? .orange : .green),
                        height: 6
                    )
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .windowBackgroundColor))
                    .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
            )
        }
    }

    private var balanceColor: Color {
        let balance = service.currentBalance
        if balance < 0 { return .red }
        if balance < 50 { return .orange }
        return .primary
    }

    // MARK: Helpers

    private func dayDateLabel(_ dateString: String, isToday: Bool) -> String {
        if isToday { return "今天" }
        let parts = dateString.split(separator: "-")
        guard parts.count >= 3 else { return dateString }
        return "\(parts[1])/\(parts[2])"
    }
}
