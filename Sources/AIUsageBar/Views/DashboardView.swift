import SwiftUI

// MARK: - Main Dashboard (v1.5.0)

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
        // 1. AI Status Hero
        aiHeroCard

        // 2. Agent Cards
        agentCardsSection

        // 3. Model Cards
        modelCardsSection

        // 4. System Status
        systemStatusBar
    }

    // MARK: AI Hero Card

    private var aiHeroCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.apiHeroTitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(CostFormatter.format(service.apiTotalStats.totalCost))
                        .font(.system(size: 34, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                        .monospacedDigit()
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    statChip(label: L.requests, value: "\(service.apiTotalStats.totalRequests)")
                    statChip(label: L.tokens, value: TokenFormatter.format(service.apiTotalStats.totalInput))
                }
            }

            // Agent status badges
            HStack(spacing: 8) {
                ForEach(service.agentStatuses.prefix(3)) { agent in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(agent.status == .connected ? Color.green : Color.gray)
                            .frame(width: 6, height: 6)
                        Text(agent.displayName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                }
            }

            // Sync time
            HStack(spacing: 12) {
                Label(L.syncTime, systemImage: "clock")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(L.ago(Int(-service.lastApiSync.timeIntervalSinceNow)))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.12), Color.accentColor.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }

    // MARK: Agent Cards

    private var agentCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: L.agentSection, icon: "cpu.fill")

            // Claude Code
            if service.apiTotalStats.totalCost > 0 || service.apiTotalStats.totalRequests > 0 {
                AgentMiniCard(icon: "sparkles", title: L.claudeCode, provider: L.deepseek) {
                    apiAgentContent
                }
            }

            // Codex (no cost)
            if service.subscriptionSessions > 0 {
                AgentMiniCard(icon: "chevron.left.forwardslash.chevron.right", title: L.codex, provider: "OpenAI") {
                    codexAgentContent
                }
            }
        }
    }

    private var apiAgentContent: some View {
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
    }

    private var codexAgentContent: some View {
        HStack(spacing: 12) {
            // Session quota
            VStack(alignment: .leading, spacing: 2) {
                Text(L.sessionQuota)
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
                Text("\(Int(100 - (service.codexQuotaStatus.sessionPercent ?? 0)))% \(L.remaining)")
                    .font(.system(size: 8))
                    .foregroundColor(.secondary)
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
    }

    // MARK: Model Cards

    private var modelCardsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeaderView(title: L.modelSection, icon: "cpu.fill")

            // API Models
            if !service.apiModels.isEmpty {
                CardView(title: L.apiModels, icon: "network") {
                    VStack(alignment: .leading, spacing: 6) {
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
                }
            }

            // Subscription Models
            if !service.subscriptionModels.isEmpty {
                CardView(title: L.subscriptionModels, icon: "creditcard.fill") {
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

    // MARK: System Status

    private var systemStatusBar: some View {
        HStack {
            Circle()
                .fill(service.dbStatus.hasData ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(service.dbStatus.hasData ? L.healthy : L.noData)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text("· \(L.ago(Int(-service.lastApiSync.timeIntervalSinceNow)))")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Button(L.refresh) { service.refresh() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Helpers

    private func statChip(label: String, value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 8))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Agent Mini Card

struct AgentMiniCard<Content: View>: View {
    let icon: String
    let title: String
    let provider: String
    let content: Content

    init(icon: String, title: String, provider: String, @ViewBuilder content: () -> Content) {
        self.icon = icon
        self.title = title
        self.provider = provider
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                HStack(spacing: 3) {
                    Circle().fill(Color.blue).frame(width: 5, height: 5)
                    Text(provider)
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(RoundedRectangle(cornerRadius: 4).fill(Color.blue.opacity(0.08)))
            }
            content
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.04), radius: 2, x: 0, y: 1)
        )
    }
}
