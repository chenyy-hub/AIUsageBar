import SwiftUI

// MARK: - Main Dashboard

struct DashboardView: View {
    @ObservedObject var service: UsageService

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if service.isLoading && service.todaySummary.requestCount == 0 {
                    LoadingView()
                } else if let err = service.errorMessage {
                    ErrorStateView(message: err) {
                        service.reconnect()
                    }
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
        // AI Agent Usage (v5 new)
        if !service.agentUsages.isEmpty {
            AgentUsageView(usages: service.agentUsages)
        }

        // Today's Cost Hero
        todayHero

        // Token Usage
        CardView(title: "Token 使用量", icon: "chart.bar.fill") {
            tokenUsageSection
        }

        // Projects
        CardView(title: "项目成本", icon: "folder.fill") {
            ProjectListView(projects: service.projects)
        }

        // Models
        CardView(title: "模型分布", icon: "cpu.fill") {
            ModelListView(models: service.models)
        }

        // Trend
        CardView(title: "近7天趋势", icon: "chart.line.uptrend.xyaxis") {
            TrendChartView(trend: service.trend)
        }

        // Stats Grid
        CardView(title: "全局统计", icon: "sum") {
            StatsGridView(stats: service.totalStats)
        }

        // Provider Cards (追加，不破坏已有布局)
        if !service.providerCosts.isEmpty {
            ProviderCardRow(costs: service.providerCosts)
        }

        // DB info
        HStack {
            Circle()
                .fill(service.dbStatus.hasData ? Color.green : Color.red)
                .frame(width: 6, height: 6)
            Text(service.dbStatus.hasData ? "\(service.dbStatus.recordCount) 条记录" : "无数据")
                .font(.caption2)
                .foregroundColor(.secondary)
            Spacer()
            Button("刷新") { service.refresh() }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundColor(.accentColor)
        }
        .padding(.horizontal, 4)
    }

    // MARK: Today Hero

    private var todayHero: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("今日 AI 成本")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(CostFormatter.format(service.todaySummary.totalCost))
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
                    .monospacedDigit()
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                StatValue(label: "请求", value: "\(service.todaySummary.requestCount)")
                StatValue(label: "输入", value: TokenFormatter.format(service.todaySummary.inputTokens))
                StatValue(label: "输出", value: TokenFormatter.format(service.todaySummary.outputTokens))
            }
        }
        .padding(16)
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

    // MARK: Token Usage

    private var tokenUsageSection: some View {
        let maxTokens = max(service.todaySummary.inputTokens,
                            service.todaySummary.outputTokens,
                            service.todaySummary.cacheTokens, 1)
        return VStack(spacing: 8) {
            TokenUsageRow(
                label: "输入",
                tokens: service.todaySummary.inputTokens,
                maxTokens: maxTokens,
                color: .blue
            )
            TokenUsageRow(
                label: "输出",
                tokens: service.todaySummary.outputTokens,
                maxTokens: maxTokens,
                color: .green
            )
            TokenUsageRow(
                label: "缓存",
                tokens: service.todaySummary.cacheTokens,
                maxTokens: maxTokens,
                color: .orange
            )
        }
    }
}

// MARK: - Stat Value

// MARK: - Provider Card Row

struct ProviderCardRow: View {
    let costs: [(String, Double)]

    var body: some View {
        let total = costs.map(\.1).reduce(0, +)
        VStack(alignment: .leading, spacing: 8) {
            SectionHeaderView(title: "供应商", icon: "building.2.fill")
            HStack(spacing: 6) {
                ForEach(costs.prefix(4), id: \.0) { item in
                    let fraction = total > 0 ? item.1 / total : 0
                    let color = providerColor(item.0)
                    VStack(spacing: 2) {
                        Circle()
                            .fill(color)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text(item.0.prefix(1).uppercased())
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                            )
                        Text(item.0)
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                        Text(CostFormatter.formatShort(item.1))
                            .font(.caption)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        ProgressBarView(
                            value: fraction,
                            color: color,
                            height: 3
                        )
                        .frame(width: 50)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(nsColor: .windowBackgroundColor))
                    )
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
        )
    }

    private func providerColor(_ name: String) -> Color {
        switch name {
        case "deepseek":  return .blue
        case "openai":    return .green
        case "anthropic": return .orange
        default:          return .purple
        }
    }
}

// MARK: - Stat Value

struct StatValue: View {
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
        }
    }
}
