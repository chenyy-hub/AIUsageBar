import SwiftUI

// MARK: - Provider Manager

struct ProviderManagerView: View {
    @ObservedObject var service: UsageService
    // 使用 WindowManager 替代 .sheet() — 见 service.windowManager
    @State private var providers: [ProviderConfig] = []
    @State private var testingProvider: String?
    @State private var testResult: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if providers.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "key.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("暂无供应商配置")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    ForEach(providers) { config in
                        ProviderCard(
                            config: config,
                            service: service,
                            testingProvider: $testingProvider,
                            testResult: $testResult,
                            onEdit: {
                                service.windowManager?.openProviderEdit(existing: config)
                            },
                            onChanged: { loadProviders() }
                        )
                    }
                }

                Button {
                    service.windowManager?.openProviderEdit()
                } label: {
                    Label("添加供应商", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, 4)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear {
            loadProviders()
        }
        .onChange(of: service.selectedTab, initial: false) { _, _ in
            loadProviders()
        }
    }

    private func loadProviders() {
        providers = service.providerService?.providers ?? []
    }
}

// MARK: - Provider Card

struct ProviderCard: View {
    let config: ProviderConfig
    @ObservedObject var service: UsageService
    @Binding var testingProvider: String?
    @Binding var testResult: String?
    let onEdit: () -> Void
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status dot
                Circle()
                    .fill(config.lastTestStatus == "success" ? Color.green :
                          config.lastTestStatus == "failed" ? Color.red : Color.secondary)
                    .frame(width: 8, height: 8)

                Text(config.displayName.isEmpty ? config.provider : config.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                if config.lastTestStatus == "success" {
                    Text("已连接")
                        .font(.caption2)
                        .foregroundColor(.green)
                }

                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
            }

            Text(config.baseUrl)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(1)

            Text("类型: \(config.providerType)  |  模型: \(config.models.joined(separator: ", "))")
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 8) {
                // API Key indicator
                let hasKey = service.providerService?.hasAPIKey(provider: config.provider) ?? false
                Label(hasKey ? "🔑 已配置" : "⚪ 未配置 Key", systemImage: hasKey ? "checkmark.circle.fill" : "circle")
                    .font(.caption2)
                    .foregroundColor(hasKey ? .green : .secondary)

                Spacer()

                if testingProvider == config.provider {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(height: 16)
                    Text("测试中...")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                } else {
                    Button("测试连接") {
                        testProvider(config)
                    }
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundColor(.accentColor)
                    .disabled(testingProvider != nil)
                }

                if let msg = testResult, testingProvider == nil {
                    Text(msg)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func testProvider(_ config: ProviderConfig) {
        testingProvider = config.provider
        testResult = nil
        Task {
            let result = await service.providerService?.testConnection(config)
            await MainActor.run {
                testingProvider = nil
                if let r = result {
                    testResult = r.success ? "✅ \(Int(r.latencyMs))ms" : "❌ \(r.message)"
                }
                onChanged()
            }
        }
    }
}


// MARK: - Identifiable conformance for ProviderAdapterType

extension ProviderAdapterType: Identifiable {
    public var id: String { rawValue }
}
