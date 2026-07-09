import SwiftUI

// MARK: - Progress Bar

struct ProgressBarView: View {
    let value: Double        // 0.0 – 1.0
    let color: Color
    var height: CGFloat = 6
    var label: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color(nsColor: .separatorColor).opacity(0.3))
                        .frame(height: height)

                    // Fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.7), color],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(geo.size.width * min(value, 1.0), height), height: height)
                        .animation(.easeOut(duration: 0.3), value: value)
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Token Usage Bar

struct TokenUsageRow: View {
    let label: String
    let tokens: Int
    let maxTokens: Int
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(TokenFormatter.format(tokens))
                    .font(.caption)
                    .fontWeight(.medium)
                    .monospacedDigit()
                    .foregroundColor(.primary)
            }
            ProgressBarView(
                value: maxTokens > 0 ? Double(tokens) / Double(maxTokens) : 0,
                color: color,
                height: 5
            )
        }
    }
}

// MARK: - Cost Progress Row (for projects)

struct ProjectCostRow: View {
    let project: ProjectCost
    var maxCost: Double

    var body: some View {
        HStack(spacing: 8) {
            // Project name
            Text(project.name)
                .font(.subheadline)
                .lineLimit(1)
                .frame(width: 120, alignment: .leading)

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(nsColor: .separatorColor).opacity(0.25))
                        .frame(height: 6)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(projectColor(project.name))
                        .frame(width: max(geo.size.width * CGFloat(project.fraction), 6), height: 6)
                        .animation(.easeOut(duration: 0.3), value: project.fraction)
                }
            }
            .frame(height: 6)

            // Cost
            Text(CostFormatter.format(project.totalCost))
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .frame(width: 70, alignment: .trailing)
        }
        .frame(height: 24)
    }

    private func projectColor(_ name: String) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .teal, .indigo]
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Trend Bar

struct TrendBarView: View {
    let summary: DailySummary
    let maxCost: Double
    let isToday: Bool

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            GeometryReader { geo in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 3)
                        .fill(isToday ? Color.accentColor : Color(nsColor: .controlAccentColor).opacity(0.6))
                        .frame(height: maxCost > 0 ? max(geo.size.height * CGFloat(summary.totalCost / maxCost), 3) : 2)
                        .animation(.easeOut(duration: 0.3), value: summary.totalCost)
                }
            }

            // Day label
            let dayLabel = isToday ? "今天" : String(summary.date.suffix(5).dropFirst(3))
            Text(dayLabel)
                .font(.system(size: 9))
                .foregroundColor(isToday ? .primary : .secondary)
                .lineLimit(1)
                .fixedSize()
        }
    }
}
