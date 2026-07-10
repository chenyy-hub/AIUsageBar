import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @State private var dbPath: String = ""
    @State private var refreshInterval: Double = 30
    @State private var budgetAmount: String = ""

    private let dbPathKey = "ai_usage_db_path"

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: "gearshape.fill")
                    .foregroundColor(.accentColor)
                Text("AIUsageBar 设置")
                    .font(.headline)
            }

            Divider()

            // DB Path
            VStack(alignment: .leading, spacing: 6) {
                Text("数据库路径")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    TextField("", text: $dbPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .monospacedDigit()
                    Button("浏览") {
                        selectDBPath()
                    }
                    .controlSize(.small)
                }
                Text("当前: \(service.dbStatus.path)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Refresh
            VStack(alignment: .leading, spacing: 6) {
                Text("刷新间隔: \(Int(refreshInterval)) 秒")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Slider(value: $refreshInterval, in: 10...300, step: 10)
                    .onChange(of: refreshInterval, initial: false) { _, newVal in
                        UserDefaults.standard.set(newVal, forKey: "refresh_interval")
                    }
            }

            // Actions
            HStack {
                Button("重新连接") {
                    reconnectService()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Spacer()

                Button("打开 DB 目录") {
                    let dir = (service.dbStatus.path as NSString).deletingLastPathComponent
                    NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                }
                .controlSize(.small)
            }

            Divider()

            // API Budget
            apiBudgetSection

            Divider()

            // Health Status
            healthStatusSection

            Divider()

            // About
            VStack(alignment: .leading, spacing: 4) {
                Text("AIUsageBar v1.4")
                    .font(.caption)
                Text("基于 ai-cost-monitor 数据库")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .frame(width: 320)
        .onAppear {
            dbPath = UserDefaults.standard.string(forKey: dbPathKey) ?? ""
            refreshInterval = {
                let val = UserDefaults.standard.double(forKey: "refresh_interval")
                return val > 0 ? val : 30
            }()
            budgetAmount = service.initialBalance > 0 ? String(format: "%.2f", service.initialBalance) : ""
        }
    }

    // MARK: - API Budget

    private var apiBudgetSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text("API 预算设置")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            // 概览
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("充值余额")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.formatShort(service.initialBalance))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 2) {
                    Text("累计消费")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.formatShort(service.usageData.totalCost))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .monospacedDigit()
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 2) {
                    Text("当前余额")
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    Text(CostFormatter.formatShort(service.currentBalance))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .monospacedDigit()
                        .foregroundColor(service.currentBalance <= 0 ? .red : .primary)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }

            // 充值输入
            HStack(spacing: 8) {
                TextField("充值金额", text: $budgetAmount)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 100)

                Button("设置余额") {
                    if let amount = Double(budgetAmount), amount > 0 {
                        service.setInitialBalance(amount)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(!canSetBudget)

                Spacer()
            }
        }
    }

    // MARK: - Health Status

    private var healthStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "heart.text.square")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text("系统状态")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
            }

            StatRow(label: "Database", value: service.dbHealth ? "✅" : "❌")
            StatRow(label: "Scanner", value: pipelineHealthLabel, color: pipelineHealthColor)
            StatRow(label: "API Refresh", value: service.apiRefreshHealth ? "✅" : "❌")
            StatRow(label: "Codex", value: service.codexHealth ? "✅" : "❌")
        }
    }

    private var pipelineHealthLabel: String {
        switch service.pipelineHealth {
        case .healthy: return "🟢 Healthy"
        case .warning: return "⚠️ Warning"
        case .error:   return "🔴 Error"
        case .offline: return "⚫ Offline"
        }
    }

    private var pipelineHealthColor: Color {
        switch service.pipelineHealth {
        case .healthy: return .green
        case .warning: return .orange
        case .error:   return .red
        case .offline: return .secondary
        }
    }

    private var canSetBudget: Bool {
        guard let amount = Double(budgetAmount), amount > 0 else { return false }
        return true
    }

    private func reconnectService() {
        Task { @MainActor in
            let path = dbPath.isEmpty ? nil : dbPath
            service.connect(path: path)
        }
    }

    private func selectDBPath() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.database]
        panel.allowsOtherFileTypes = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.message = "选择 ai_usage.db 文件"
        panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory() + "/workspace-agent-digital-employee/runtime/ai_usage")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        dbPath = url.path
        UserDefaults.standard.set(dbPath, forKey: dbPathKey)
        reconnectService()
    }
}
