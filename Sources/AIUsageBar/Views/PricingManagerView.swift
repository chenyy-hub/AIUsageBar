import SwiftUI

// MARK: - Pricing Manager

struct PricingManagerView: View {
    @ObservedObject var service: UsageService
    @State private var pricing: [ModelPricing] = []
    @State private var importMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if pricing.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "dollarsign.circle").font(.title2).foregroundColor(.secondary)
                        Text("暂无定价数据").font(.subheadline).foregroundColor(.secondary)
                        Button("从 pricing.yaml 导入") {
                            guard let svc = service.pricingService else { return }
                            let count = svc.importFromYaml()
                            importMessage = "已导入 \(count) 条"
                            loadPricing()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importMessage = nil }
                        }
                        .buttonStyle(.borderedProminent).controlSize(.small).padding(.top, 4)
                    }.frame(maxWidth: .infinity).padding(30)
                } else {
                    let grouped = Dictionary(grouping: pricing) { $0.provider }
                    ForEach(grouped.keys.sorted(), id: \.self) { provider in
                        ProviderPricingCard(provider: provider, items: grouped[provider] ?? [], service: service, onChanged: { loadPricing() })
                    }

                    HStack(spacing: 12) {
                        Button("📥 导入 pricing.yaml") {
                            guard let svc = service.pricingService else { return }
                            importMessage = "已导入 \(svc.importFromYaml()) 条"
                            loadPricing()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importMessage = nil }
                        }.buttonStyle(.borderedProminent).controlSize(.small)
                        Button("📤 同步到 pricing.yaml") {
                            importMessage = (service.pricingService?.syncToYaml() == true) ? "✅ 已同步" : "❌ 同步失败"
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { importMessage = nil }
                        }.controlSize(.small)
                    }.padding(.top, 4)

                    if let msg = importMessage { Text(msg).font(.caption).foregroundColor(.secondary) }
                }

                Button(action: { service.windowManager?.openPricingEdit() }) {
                    Label("添加定价", systemImage: "plus.circle").font(.subheadline)
                }
                .buttonStyle(.plain).foregroundColor(.accentColor).padding(.top, 2)
            }
            .padding(12)
        }
        .frame(width: 340, height: 520)
        .onAppear { loadPricing() }
    }

    private func loadPricing() { pricing = service.pricingService?.allPricing ?? [] }
}

// MARK: - Provider Pricing Card

struct ProviderPricingCard: View {
    let provider: String
    let items: [ModelPricing]
    @ObservedObject var service: UsageService
    let onChanged: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "building.2.fill").font(.caption).foregroundColor(.accentColor)
                Text(provider).font(.subheadline).fontWeight(.semibold)
                Spacer()
                Text("CNY / 1M tokens").font(.caption2).foregroundColor(.secondary)
            }
            HStack {
                Text("模型").frame(width: 80, alignment: .leading)
                Text("Cache命中").frame(width: 60, alignment: .trailing)
                Text("Cache未中").frame(width: 60, alignment: .trailing)
                Text("输出").frame(width: 50, alignment: .trailing)
                Spacer()
                Text("Edit")
            }
            .font(.system(size: 9)).foregroundColor(.secondary)

            ForEach(items) { item in
                HStack {
                    Text(item.model).font(.caption).fontWeight(.medium).frame(width: 80, alignment: .leading).lineLimit(1)
                    Text(String(format: "%.2f", item.inputCacheHitPrice)).font(.system(size: 9)).frame(width: 60, alignment: .trailing).monospacedDigit()
                    Text(String(format: "%.2f", item.inputCacheMissPrice)).font(.system(size: 9)).frame(width: 60, alignment: .trailing).monospacedDigit()
                    Text(String(format: "%.2f", item.outputPrice)).font(.system(size: 9)).frame(width: 50, alignment: .trailing).monospacedDigit()
                    Spacer()
                    Button("Edit") { service.windowManager?.openPricingEdit(existing: item) }
                        .buttonStyle(.plain).font(.system(size: 9)).foregroundColor(.accentColor)
                }.frame(height: 24)
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(nsColor: .windowBackgroundColor)))
    }
}
