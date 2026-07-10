import SwiftUI

// MARK: - Data Health View (v2.0 — + Developer Mode)

struct DataHealthView: View {
    @ObservedObject var service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "heart.text.square.fill")
                    .foregroundColor(.accentColor)
                Text(L.dataHealth)
                    .font(.headline)
            }

            // Agent Statuses
            if !service.agentStatuses.isEmpty {
                ForEach(service.agentStatuses) { agent in
                    scannerStatusCard(agent: agent)
                }
            }

            // Database info
            CardView(title: L.database, icon: "cylinder.split.1x2") {
                VStack(alignment: .leading, spacing: 4) {
                    infoRow(L.database, service.dbStatus.path)
                    infoRow(L.records, "\(service.dbStatus.recordCount)")
                    infoRow(L.mode, "WAL（并发安全）")
                    infoRow(L.tables, "10 张表")
                    infoRow(L.status, service.dbStatus.hasData ? "🟢 \(L.healthy)" : "⚪ \(L.noData)")
                }
            }

            // MARK: Developer Mode (v2.0 — 从主面板移入)

            CardView(title: L.developerMode, icon: "hammer.fill") {
                VStack(alignment: .leading, spacing: 8) {
                    // Scanner Health
                    scannerPipelineSection

                    Divider().opacity(0.3)

                    // Diagnostic info
                    scannerDiagnosticSection

                    Divider().opacity(0.3)

                    // Debug — Today Range
                    debugSection
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
                Button(L.refresh) { service.refresh() }
                    .buttonStyle(.borderedProminent).controlSize(.small)
                Spacer()
                Button(L.runScanner) { runScanner() }
                    .controlSize(.small)
            }
        }
        .padding(16)
        .frame(width: 340)
    }

    // MARK: Scanner Pipeline Section

    private var scannerPipelineSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(pipelineColor)
                    .frame(width: 8, height: 8)
                Text("Data Pipeline: \(pipelineLabel)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(pipelineColor)
                Spacer()
            }

            // Stats grid
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Last Scan")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(scannerLastScanText)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .center, spacing: 2) {
                    Text("Last Insert")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("\(service.scannerStatus.lastInsertCount) records")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("Files")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text("\(service.scannerStatus.filesScanned)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(.primary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // Error
            if let error = service.scannerStatus.lastError, !error.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                        .foregroundColor(.red)
                    Text(error)
                        .font(.caption2)
                        .foregroundColor(.red)
                        .lineLimit(1)
                }
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("None")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var pipelineLabel: String {
        switch service.pipelineHealth {
        case .healthy: return "Healthy"
        case .warning: return "Warning"
        case .error:   return "Error"
        case .offline: return "Offline"
        }
    }

    private var pipelineColor: Color {
        switch service.pipelineHealth {
        case .healthy: return .green
        case .warning: return .orange
        case .error:   return .red
        case .offline: return .secondary
        }
    }

    private var scannerLastScanText: String {
        if let d = service.scannerStatus.lastScanDate {
            return RelativeTimeFormatter.format(d)
        }
        return "N/A"
    }

    // MARK: Scanner Diagnostic Section

    private var scannerDiagnosticSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Data Pipeline:")
                .font(.system(size: 7, weight: .semibold, design: .monospaced))
                .foregroundColor(.secondary)
            Text("Path: \(service.scannerDiagnostic.path)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.secondary)
                .lineLimit(1)
            Text("File: \(service.scannerDiagnostic.fileExists ? "✅" : "❌" )  Size: \(service.scannerDiagnostic.fileSize) bytes")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.secondary)
            Text("Status: \(service.scannerDiagnostic.status)")
                .font(.system(size: 7, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: Debug — Today Range

    private var debugSection: some View {
        let lines = service.costSummaryDebugText.components(separatedBy: "\n")
        return VStack(alignment: .leading, spacing: 2) {
            if lines.indices.contains(0) {
                Text(verbatim: lines[0])
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if lines.indices.contains(1) {
                Text(verbatim: lines[1])
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if lines.indices.contains(2) {
                Text(verbatim: lines[2])
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
            if lines.indices.contains(3) {
                Text(verbatim: lines[3])
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: Scanner Status Card (Agent)

    private func scannerStatusCard(agent: AgentProviderStatus) -> some View {
        CardView(title: agent.displayName, icon: agent.iconName) {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Circle()
                        .fill(statusColor(agent.status))
                        .frame(width: 8, height: 8)
                    Text(statusLabel(agent.status))
                        .font(.subheadline).fontWeight(.medium)
                    Spacer()
                    Text("\(agent.recordCount) \(L.records)")
                        .font(.caption).foregroundColor(.secondary)
                }
                if let lastSync = agent.lastSync {
                    HStack {
                        Image(systemName: "clock")
                            .font(.system(size: 8)).foregroundColor(.secondary)
                        Text("\(L.lastSync): \(RelativeTimeFormatter.format(lastSync))")
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
            return "无数据 — 请先运行扫描"
        }
        if service.agentUsages.allSatisfy({ $0.isEstimated }) {
            return "部分数据为估算值"
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

    private func statusLabel(_ status: AgentConnectionStatus) -> String {
        switch status {
        case .connected:    return "已连接"
        case .syncing:      return "同步中"
        case .unavailable:  return "不可用"
        case .noData:       return "无数据"
        }
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
