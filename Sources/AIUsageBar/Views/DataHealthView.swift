import SwiftUI

// MARK: - Data Health View (v1.1.1)

struct DataHealthView: View {
    @ObservedObject var service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.accentColor)
                Text("Data Health")
                    .font(.headline)
            }

            // Agent Statuses
            if !service.agentStatuses.isEmpty {
                ForEach(service.agentStatuses) { agent in
                    scannerStatusCard(agent: agent)
                }
            }

            // Database info
            CardView(title: "Database", icon: "cylinder.split.1x2") {
                VStack(alignment: .leading, spacing: 4) {
                    infoRow("Path", service.dbStatus.path)
                    infoRow("Records", "\(service.dbStatus.recordCount)")
                    infoRow("Mode", "WAL (concurrent safe)")
                    infoRow("Tables", "10 tables")
                    infoRow("Status", service.dbStatus.hasData ? "🟢 Healthy" : "⚪ Empty")
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
                Button("Refresh") { service.refresh() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Spacer()
                Button("Run Scanner") { runScanner() }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Scanner Status Card

    private func scannerStatusCard(agent: AgentProviderStatus) -> some View {
        CardView(title: agent.displayName, icon: agent.iconName) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusColor(agent.status))
                        .frame(width: 8, height: 8)
                    Text(agent.status.rawValue.capitalized)
                        .font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text("\(agent.recordCount) records")
                        .font(.caption).foregroundColor(.secondary)
                }
                if let lastSync = agent.lastSync {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 8)).foregroundColor(.secondary)
                        Text("Last sync: \(timeAgo(lastSync))")
                            .font(.caption).foregroundColor(.secondary)
                        Spacer()
                    }
                }
            }
        }
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundColor(.secondary)
            Spacer()
            Text(value).font(.caption).foregroundColor(.primary)
                .lineLimit(1).truncationMode(.middle)
        }
    }

    private func dataWarning() -> String? {
        if service.agentStatuses.allSatisfy({ $0.status == .noData }) {
            return "No data — please run scanner first"
        }
        if service.agentUsages.allSatisfy({ $0.isEstimated }) {
            return "Some data is estimated"
        }
        return nil
    }

    private func statusColor(_ status: AgentConnectionStatus) -> Color {
        switch status {
        case .connected: return .green
        case .syncing: return .orange
        case .unavailable: return .red
        case .noData: return .gray
        }
    }

    private func timeAgo(_ date: Date) -> String {
        let interval = Int(-date.timeIntervalSinceNow)
        if interval < 60 { return "\(interval)s ago" }
        return "\(interval / 60)min ago"
    }

    private func runScanner() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-m", "scripts.monitor_daemon", "scan"]
        process.currentDirectoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/workspace-agent-digital-employee")
        try? process.run()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { service.refresh() }
    }
}
