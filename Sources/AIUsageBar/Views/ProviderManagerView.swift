import SwiftUI

// MARK: - Provider Manager

struct ProviderManagerView: View {
    @ObservedObject var service: UsageService
    @State private var showAddSheet = false
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
                            onChanged: { loadProviders() }
                        )
                    }
                }

                Button {
                    showAddSheet = true
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
        .onAppear { loadProviders() }
        .onChange(of: service.selectedTab) { _ in loadProviders() }
        .sheet(isPresented: $showAddSheet) {
            ProviderEditSheet(service: service, onSave: { loadProviders() })
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
    @State private var showEditSheet = false
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
                    showEditSheet = true
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
        .sheet(isPresented: $showEditSheet) {
            ProviderEditSheet(service: service, existing: config, onSave: onChanged)
        }
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

// MARK: - Add / Edit Provider Sheet

struct ProviderEditSheet: View {
    @ObservedObject var service: UsageService
    var existing: ProviderConfig? = nil
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var provider = ""
    @State private var providerType = "openai-compatible"
    @State private var displayName = ""
    @State private var baseUrl = ""
    @State private var modelsText = ""
    @State private var apiKey = ""

    private let typeOptions = ProviderAdapterType.allCases

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "key.fill").foregroundColor(.accentColor)
                Text(existing != nil ? "编辑供应商" : "添加供应商").font(.headline)
            }

            Group {
                TextField("Provider 名称 (如 deepseek)", text: $provider)
                    .textFieldStyle(.roundedBorder)
                    .disabled(existing != nil)

                Picker("类型", selection: $providerType) {
                    ForEach(typeOptions) { opt in
                        Text(opt.displayName).tag(opt.rawValue)
                    }
                }

                TextField("显示名称 (可选)", text: $displayName)
                    .textFieldStyle(.roundedBorder)

                TextField("Base URL", text: $baseUrl)
                    .textFieldStyle(.roundedBorder)

                TextField("模型列表 (逗号分隔)", text: $modelsText)
                    .textFieldStyle(.roundedBorder)

                SecureField("API Key (存储在 Keychain)", text: $apiKey)
                    .textFieldStyle(.roundedBorder)
            }
            .font(.subheadline)

            HStack {
                Button("取消") { dismiss() }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                Spacer()
                Button("保存") {
                    guard !provider.isEmpty else { return }
                    let models = modelsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    let modelsJSON = (try? JSONSerialization.data(withJSONObject: models)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"

                    let config = ProviderConfig(
                        id: existing?.id ?? 0,
                        provider: provider,
                        providerType: providerType,
                        displayName: displayName,
                        baseUrl: baseUrl,
                        modelsJSON: modelsJSON,
                        keychainService: existing?.keychainService ?? "",
                        isActive: true,
                        lastTestStatus: "",
                        lastTestTime: "",
                        createdAt: existing?.createdAt ?? ""
                    )
                    service.providerService?.saveProvider(config)

                    if !apiKey.isEmpty {
                        service.providerService?.saveAPIKey(provider: provider, key: apiKey)
                    }

                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(provider.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
        .onAppear {
            if let e = existing {
                provider = e.provider
                providerType = e.providerType
                displayName = e.displayName
                baseUrl = e.baseUrl
                modelsText = e.models.joined(separator: ", ")
                apiKey = service.providerService?.readAPIKey(provider: e.provider) ?? ""
            }
        }
    }
}

// MARK: - Identifiable conformance for ProviderAdapterType

extension ProviderAdapterType: Identifiable {
    public var id: String { rawValue }
}
