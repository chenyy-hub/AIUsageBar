import SwiftUI

// MARK: - Data Health View

struct DataHealthView: View {
    @ObservedObject var service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.accentColor)
                Text("Data Health")
                    .font(.headline)
            }

            // Claude Code
            scannerCard(
                client: "Claude Code",
                icon: "sparkles",
                records: "\(apiRecordsCount()) 条",
                lastData: lastApiDate(),
                status: apiRecordsCount() > 0 ? "🟢 正常" : "⚪ 无数据"
            )

            // Codex
            scannerCard(
                client: "Codex",
                icon: "chevron.left.forwardslash.chevron.right",
                records: "\(quotaRecordsCount()) sessions",
                lastData: lastQuotaDate(),
                status: quotaRecordsCount() > 0 ? "🟢 正常" : "⚪ 无数据"
            )

            // Database info
            CardView(title: "数据库", icon: "cylinder.split.1x2") {
                VStack(alignment: .leading, spacing: 4) {
                    infoRow("路径", service.dbStatus.path)
                    infoRow("记录", "\(service.dbStatus.recordCount)")
                    infoRow("表", "10 张 (4 管理 + 3 扫描 + 2 v5 + 1 内部)")
                    infoRow("模式", "WAL (并发安全)")
                }
            }

            // Warnings
            if let warning = dataWarning() {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(warning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            HStack {
                Button("刷新数据") {
                    service.refresh()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button("运行 Scanner") {
                    runScanner()
                }
                .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Scanner Card

    private func scannerCard(client: String, icon: String, records: String, lastData: String, status: String) -> some View {
        CardView(title: client, icon: icon) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(status)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(records)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Text("最近数据")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(lastData)
                        .font(.caption)
                        .monospacedDigit()
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }

    // MARK: Data Queries

    private func apiRecordsCount() -> Int {
        service.agentUsages.filter { $0.usageType == .apiCost }
            .reduce(0) { $0 + ($1.inputTokens ?? 0) > 0 ? 1 : 0 }
    }

    private func quotaRecordsCount() -> Int {
        service.agentUsages.filter { $0.usageType == .subscriptionQuota }.count
    }

    private func lastApiDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())  // would need a query for actual last date
    }

    private func lastQuotaDate() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: Date())
    }

    private func dataWarning() -> String? {
        if service.agentUsages.isEmpty {
            return "无使用数据 — 请先运行 scanner"
        }
        if service.agentUsages.allSatisfy({ $0.isEstimated }) {
            return "部分数据为估计值 — 建议配置完整 quota 信息"
        }
        return nil
    }

    private func runScanner() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "scripts.monitor_daemon", "scan"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/workspace-agent-digital-employee")
        try? process.run()
        // Give scanner a moment, then refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            service.refresh()
        }
    }
}
