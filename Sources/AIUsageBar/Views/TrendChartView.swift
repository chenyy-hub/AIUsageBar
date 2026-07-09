import SwiftUI

// MARK: - Daily Trend Chart

struct TrendChartView: View {
    let trend: [DailySummary]

    var body: some View {
        if trend.isEmpty {
            Text("暂无趋势数据")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            let maxCost = trend.map(\.totalCost).max() ?? 1
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(Array(trend.enumerated()), id: \.element.id) { idx, day in
                    TrendBarView(
                        summary: day,
                        maxCost: maxCost,
                        isToday: idx == trend.count - 1
                    )
                }
            }
            .frame(height: 60)
            .padding(.top, 4)

            // Cost labels below bars
            HStack(spacing: 6) {
                ForEach(trend) { day in
                    Text(CostFormatter.formatShort(day.totalCost))
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                }
            }
        }
    }
}

// MARK: - Stats Grid

struct StatsGridView: View {
    let stats: TotalStats

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible()),
            GridItem(.flexible()),
        ], spacing: 12) {
            StatCard(
                label: "总计",
                value: CostFormatter.format(stats.totalCost),
                icon: "dollarsign.circle.fill",
                color: .blue
            )
            StatCard(
                label: "请求",
                value: "\(stats.totalRequests)",
                icon: "arrow.triangle.branch",
                color: .green
            )
            StatCard(
                label: "Session",
                value: "\(stats.totalSessions)",
                icon: "rectangle.stack.fill",
                color: .orange
            )
            StatCard(
                label: "项目",
                value: "\(stats.totalProjects)",
                icon: "folder.fill",
                color: .purple
            )
            StatCard(
                label: "输入",
                value: TokenFormatter.format(stats.totalInput),
                icon: "arrow.down.doc.fill",
                color: .indigo
            )
            StatCard(
                label: "输出",
                value: TokenFormatter.format(stats.totalOutput),
                icon: "arrow.up.doc.fill",
                color: .teal
            )
        }
    }
}

struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
            Text(value)
                .font(.callout)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }
}
