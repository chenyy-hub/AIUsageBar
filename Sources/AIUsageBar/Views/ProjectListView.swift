import SwiftUI

// MARK: - Project List

struct ProjectListView: View {
    let projects: [ProjectCost]

    var body: some View {
        if projects.isEmpty {
            Text("暂无项目数据")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            let maxCost = projects.first?.totalCost ?? 1
            VStack(spacing: 6) {
                ForEach(projects) { project in
                    ProjectCostRow(project: project, maxCost: maxCost)
                }
            }
        }
    }
}

// MARK: - Model Breakdown

struct ModelListView: View {
    let models: [ModelBreakdown]

    var body: some View {
        if models.isEmpty {
            Text("暂无模型数据")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.vertical, 8)
        } else {
            let colors: [Color] = [.blue, .green, .orange]
            VStack(spacing: 6) {
                ForEach(Array(models.enumerated()), id: \.element.id) { idx, model in
                    HStack {
                        Circle()
                            .fill(colors[idx % colors.count])
                            .frame(width: 8, height: 8)
                        Text(model.model)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text(CostFormatter.format(model.totalCost))
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .monospacedDigit()
                        Text("(\(TokenFormatter.format(model.inputTokens + model.outputTokens)))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospacedDigit()
                    }
                    .frame(height: 22)
                }
            }
        }
    }
}
