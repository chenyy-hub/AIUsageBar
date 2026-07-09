import SwiftUI

// MARK: - Pricing Manager

struct PricingManagerView: View {
    @ObservedObject var service: UsageService
    @State private var pricing: [ModelPricing] = []
    @State private var showAddSheet = false
    @State private var importMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if pricing.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        Text("暂无定价数据")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Button("从 pricing.yaml 导入") {
                            importFromYaml()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .padding(.top, 4)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(30)
                } else {
                    // Group by provider
                    let grouped = Dictionary(grouping: pricing) { $0.provider }
                    ForEach(grouped.keys.sorted(), id: \.self) { provider in
                        ProviderPricingCard(
                            provider: provider,
                            items: grouped[provider] ?? [],
                            pricing: $pricing,
                            service: service
                        )
                    }

                    // Import / Sync buttons
                    HStack(spacing: 12) {
                        Button("📥 导入 pricing.yaml") {
                            importFromYaml()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                        Button("📤 同步到 pricing.yaml") {
                            syncToYaml()
                        }
                        .controlSize(.small)
                    }
                    .padding(.top, 4)

                    if let msg = importMessage {
                        Text(msg)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Button {
                    showAddSheet = true
                } label: {
                    Label("添加定价", systemImage: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .foregroundColor(.accentColor)
                .padding(.top, 2)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear { loadPricing() }
        .onChange(of: service.selectedTab) { _ in loadPricing() }
        .sheet(isPresented: $showAddSheet) {
            PricingEditSheet(service: service, onSave: { loadPricing() })
        }
    }

    private func loadPricing() {
        pricing = service.pricingService?.allPricing ?? []
    }

    private func importFromYaml() {
        guard let svc = service.pricingService else { return }
        let count = svc.importFromYaml()
        importMessage = "已导入 \(count) 条定价（不覆盖自定义）"
        loadPricing()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importMessage = nil }
    }

    private func syncToYaml() {
        guard let svc = service.pricingService else { return }
        if svc.syncToYaml() {
            importMessage = "✅ 已同步到 pricing.yaml"
        } else {
            importMessage = "❌ 同步失败"
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importMessage = nil }
    }
}

// MARK: - Provider Pricing Card

struct ProviderPricingCard: View {
    let provider: String
    let items: [ModelPricing]
    @Binding var pricing: [ModelPricing]
    @ObservedObject var service: UsageService

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            HStack {
                Image(systemName: "building.2.fill")
                    .font(.caption)
                    .foregroundColor(.accentColor)
                Text(provider)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Spacer()
                Text("CNY / 1M tokens")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            // Column headers
            HStack {
                Text("模型").frame(width: 80, alignment: .leading)
                Text("Cache命中").frame(width: 60, alignment: .trailing)
                Text("Cache未中").frame(width: 60, alignment: .trailing)
                Text("输出").frame(width: 50, alignment: .trailing)
            }
            .font(.system(size: 9))
            .foregroundColor(.secondary)

            // Rows
            ForEach(items) { item in
                PricingRow(item: item, onSave: { updated in
                    service.pricingService?.savePricing(updated)
                    loadPricing()
                })
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(nsColor: .windowBackgroundColor))
        )
    }

    private func loadPricing() {
        pricing = service.pricingService?.allPricing ?? []
    }
}

// MARK: - Pricing Row (Editable)

struct PricingRow: View {
    let item: ModelPricing
    let onSave: (ModelPricing) -> Void
    @State private var hitPrice: String = ""
    @State private var missPrice: String = ""
    @State private var outputPrice: String = ""
    @State private var edited = false

    var body: some View {
        HStack {
            Text(item.model)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)
                .lineLimit(1)

            TextField("", text: $hitPrice)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 9))
                .frame(width: 60)
                .monospacedDigit()
                .onChange(of: hitPrice) { _ in edited = true }

            TextField("", text: $missPrice)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 9))
                .frame(width: 60)
                .monospacedDigit()
                .onChange(of: missPrice) { _ in edited = true }

            TextField("", text: $outputPrice)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 9))
                .frame(width: 50)
                .monospacedDigit()
                .onChange(of: outputPrice) { _ in edited = true }

            if edited {
                Button("保存") {
                    var updated = item
                    updated.inputCacheHitPrice = Double(hitPrice) ?? item.inputCacheHitPrice
                    updated.inputCacheMissPrice = Double(missPrice) ?? item.inputCacheMissPrice
                    updated.outputPrice = Double(outputPrice) ?? item.outputPrice
                    updated.isCustom = true
                    onSave(updated)
                    edited = false
                }
                .buttonStyle(.plain)
                .font(.system(size: 9))
                .foregroundColor(.accentColor)
            }
        }
        .frame(height: 24)
        .onAppear {
            hitPrice = String(format: "%.2f", item.inputCacheHitPrice)
            missPrice = String(format: "%.2f", item.inputCacheMissPrice)
            outputPrice = String(format: "%.2f", item.outputPrice)
        }
    }
}

// MARK: - Add Pricing Sheet

struct PricingEditSheet: View {
    @ObservedObject var service: UsageService
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var provider = ""
    @State private var model = ""
    @State private var hitPrice: Double = 0.80
    @State private var missPrice: Double = 4.00
    @State private var outputPrice: Double = 6.00

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "dollarsign.circle.fill").foregroundColor(.accentColor)
                Text("添加定价").font(.headline)
            }

            Group {
                TextField("Provider (如 deepseek)", text: $provider)
                    .textFieldStyle(.roundedBorder)
                TextField("模型 (如 deepseek-v4-pro)", text: $model)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    Text("Cache 命中单价").frame(width: 100, alignment: .leading)
                    TextField("0.80", value: $hitPrice, format: .number).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Cache 未中单价").frame(width: 100, alignment: .leading)
                    TextField("4.00", value: $missPrice, format: .number).textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("输出单价").frame(width: 100, alignment: .leading)
                    TextField("6.00", value: $outputPrice, format: .number).textFieldStyle(.roundedBorder)
                }
            }
            .font(.subheadline)

            HStack {
                Button("取消") { dismiss() }.buttonStyle(.plain).foregroundColor(.secondary)
                Spacer()
                Button("保存") {
                    guard !provider.isEmpty, !model.isEmpty else { return }
                    let p = ModelPricing(
                        id: 0, provider: provider, model: model, currency: "CNY",
                        inputCacheHitPrice: hitPrice,
                        inputCacheMissPrice: missPrice,
                        outputPrice: outputPrice,
                        isCustom: true, updatedAt: ""
                    )
                    service.pricingService?.savePricing(p)
                    onSave()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(provider.isEmpty || model.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 300)
    }
}
