import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
    @ObservedObject var service: UsageService
    @State private var dbPath: String = ""
    @State private var refreshInterval: Double = 30

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
                    .onChange(of: refreshInterval) { newVal in
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

            // About
            VStack(alignment: .leading, spacing: 4) {
                Text("AIUsageBar v1.0")
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
        }
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
