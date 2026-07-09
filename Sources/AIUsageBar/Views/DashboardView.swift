import SwiftUI

// MARK: - Main Dashboard (v1.1)

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
        .frame(width: 340, height: 520)
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        // Data Freshness
        freshnessBar

        // API Cost Overview
        apiCostCard

        // Codex Subscription Card
        if service.subscriptionSessions > 0 || !service.subscriptionModels.isEmpty {
            codexCard
        }

        // Agent Usage
        if !service.agentUsages.isEmpty {
            AgentUsageView(usages: service.agentUsages)
        }

        // Model Usage
        modelUsageCard

        // DB Info
        dbInfoBar
    }

    // MARK: Data Freshness (Phase 6)

    private var freshnessBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            Text("API \(timeAgo(service.lastApiSync))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text("·")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text("Codex \(timeAgo(service.lastCodexSync))")
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(.horizontal, 2)
    }

    // MARK: API Cost Overview (Phase 2)

    private var apiCostCard: some View {
        VStack(spacing: 12) {
            // Hero
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("API Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CostFormatter.format(service.apiTotalStats.totalCost))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    StatValue(label: "Requests", value: "\(service.apiTotalStats.totalRequests)")
                    StatValue(label: "Tokens", value: TokenFormatter.format(service.apiTotalStats.totalInput))
                }
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: Agent Status (Task 2)

    private var agentStatusCard: some View {
        CardView(title: "Agent Status", icon: "antenna.radiowaves.left.and.right") {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(service.agentStatuses) { agent in
                    HStack {
                        Image(systemName: agent.iconName)
                            .font(.caption).foregroundColor(.accentColor)
                        Text(agent.displayName)
                            .font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Text(agent.status.rawValue)
                            .font(.caption).foregroundColor(.secondary)
                        Circle()
                            .fill(statusColor(agent.status))
                            .frame(width: 6, height: 6)
                    }
                    .frame(height: 22)
                }
            }
        }
    }

    private func statusColor(_ status: AgentConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .syncing: return .orange
        case .unavailable: return .red
        case .noData: return .gray
        }
    }

    // MARK: Model Usage (Phase 3)

    private var modelUsageCard: some View {
        CardView(title: "Model Usage", icon: "cpu.fill") {
            VStack(alignment: .leading, spacing: 8) {
                // API Models
                if !service.apiModels.isEmpty {
                    Text("API Models")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)

                    ForEach(Array(service.apiModels.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Circle().fill(Color.blue).frame(width: 5, height: 5)
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

                // Subscription Models
                if !service.subscriptionModels.isEmpty {
                    Divider()
                    Text("Subscription Models")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.orange)

                    ForEach(Array(service.subscriptionModels.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Circle().fill(Color.orange).frame(width: 5, height: 5)
                            Text(item.model).font(.subheadline).lineLimit(1)
                            Spacer()
                            Text(TokenFormatter.format(Int(item.tokens)))
                                .font(.subheadline).fontWeight(.medium).monospacedDigit()
                            Text("\(item.sessions) sessions")
                                .font(.caption).foregroundColor(.secondary)
                        }
                        .frame(height: 20)
                    }
                }
            }
        }
    }

    // MARK: Codex Card (v1.1.1 — Session/Weekly)

    private var codexCard: some View {
        CardView(title: "Codex Plus", icon: "chevron.left.forwardslash.chevron.right") {
            VStack(alignment: .leading, spacing: 10) {
                let quota = service.codexQuotaStatus
                if quota.isAvailable,
                   let sessionUsed = quota.sessionUsedPercent,
                   let sessionRemaining = quota.sessionRemainingPercent,
                   let sessionReset = quota.sessionResetTime,
                   let weeklyUsed = quota.weeklyUsedPercent,
                   let weeklyRemaining = quota.weeklyRemainingPercent,
                   let weeklyReset = quota.weeklyResetTime {
                    quotaWindow(
                        title: "Session",
                        usedPercent: sessionUsed,
                        remainingPercent: sessionRemaining,
                        resetTime: sessionReset
                    )

                    quotaWindow(
                        title: "Weekly",
                        usedPercent: weeklyUsed,
                        remainingPercent: weeklyRemaining,
                        resetTime: weeklyReset
                    )
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Session")
                            .font(.caption)
                            .fontWeight(.semibold)
                        unavailableQuotaRow()

                        Text("Weekly")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.top, 4)
                        unavailableQuotaRow()
                    }
                }

                Divider()

                Text("Usage Trend")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                Text("No quota trend data")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                // Models
                if !service.subscriptionModels.isEmpty {
                    Divider()
                    Text("Models")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    ForEach(Array(service.subscriptionModels.enumerated()), id: \.offset) { _, item in
                        HStack {
                            Circle().fill(Color.orange.opacity(0.5)).frame(width: 5, height: 5)
                            Text(item.model).font(.caption)
                            Spacer()
                            Text(TokenFormatter.format(Int(item.tokens)))
                                .font(.caption).monospacedDigit()
                        }
                    }
                }

                // Last sync
                Divider()
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 8)).foregroundColor(.secondary)
                    Text("Synced \(timeAgo(service.lastCodexSync))")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                    Spacer()
                    Text(service.codexQuotaStatus.isAvailable ? "Quota data" : "No quota data")
                        .font(.system(size: 9)).foregroundColor(.secondary)
                }
            }
        }
    }

    private func quotaWindow(title: String, usedPercent: Double, remainingPercent: Double, resetTime: Date) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).fontWeight(.semibold)
                Spacer()
                Text("\(Int(remainingPercent.rounded()))% remaining")
                    .font(.caption)
                    .foregroundColor(remainingPercent < 20 ? .red : .secondary)
            }
            ProgressBarView(
                value: usedPercent / 100,
                color: remainingPercent < 20 ? .red : remainingPercent < 50 ? .orange : .green,
                height: 6
            )
            HStack {
                Text("\(Int(usedPercent.rounded()))% used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("Reset \(resetTime, style: .relative)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func unavailableQuotaRow() -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ProgressBarView(value: 0, color: .gray, height: 6)
            HStack {
                Text("Unavailable")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Spacer()
                Text("No quota data")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: DB Info

    private var dbInfoBar: some View {
        HStack {
            Circle()
                .fill(service.dbStatus.hasData ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text("\(service.dbStatus.recordCount) records")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Button("Refresh") { service.refresh() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Int(-date.timeIntervalSinceNow)
        if interval < 60 { return "\(interval)s ago" }
        let minutes = interval / 60
        return "\(minutes)min ago"
    }

}

// MARK: - Provider Card Row

struct ProviderCardRow: View {
    let costs: [(String, Double)]

    var body: some View {
        let total = costs.map(\.1).reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "Provider", icon: "building.2.fill")
            HStack(spacing: 6) {
                ForEach(costs.prefix(4), id: \.0) { item in
                    let fraction = total > 0 ? item.1 / total : 0
                    let color = providerColor(item.0)
                    VStack(spacing: 2) {
                        Circle().fill(color).frame(width: 16, height: 16)
                            .overlay(Text(item.0.prefix(1).uppercased()).font(.system(size: 8, weight: .bold)).foregroundColor(.white))
                        Text(item.0).font(.system(size: 9)).foregroundColor(.secondary).lineLimit(1)
                        Text(CostFormatter.formatShort(item.1)).font(.caption).fontWeight(.medium).monospacedDigit()
                        ProgressBarView(value: fraction, color: color, height: 3).frame(width: 50)
                    }
                    .frame(maxWidth: .infinity).padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color(nsColor: .windowBackgroundColor)))
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color(nsColor: .windowBackgroundColor)).shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1))
    }

}

// MARK: - Shared Components

struct StatValue: View {
    let label: String
    let value: String
    var body: some View {
        HStack(spacing: 4) {
            Text(label).font(.caption2).foregroundColor(.secondary)
            Text(value).font(.caption).fontWeight(.medium).monospacedDigit()
        }
    }
}

// MARK: - Shared Helpers

fileprivate func providerColor(_ name: String) -> Color {
    switch name {
    case "deepseek":  return .blue
    case "openai":    return .green
    case "anthropic": return .orange
    default:          return .purple
    }
}

// StatItem is shared from BudgetManagerView
