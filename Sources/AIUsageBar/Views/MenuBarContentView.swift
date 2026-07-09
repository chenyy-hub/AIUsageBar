import SwiftUI

// MARK: - Menu Bar Content

struct MenuBarContentView: View {
    @ObservedObject var service: UsageService
    @State private var showSettings = false
    @State private var showDataHealth = false

    var body: some View {
        VStack(spacing: 0) {
            // Quick Status Bar (TASK 4)
            quickStatusBar

            Divider()

            // Tab bar
            Picker("", selection: $service.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            // Tab content
            tabContent

            // Bottom toolbar
            Divider()
            bottomBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Quick Status Bar

    private var quickStatusBar: some View {
        HStack(spacing: 12) {
            // Brand
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.accentColor)
                    .frame(width: 6, height: 6)
                Text("AIUsageBar")
                    .font(.system(size: 9, weight: .semibold))
            }

            Spacer()

            // API 成本
            VStack(alignment: .trailing, spacing: 0) {
                Text(L.cost)
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                Text(CostFormatter.formatShort(service.apiTotalStats.totalCost))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
            }
            .frame(width: 60)

            // Codex 额度
            VStack(alignment: .trailing, spacing: 0) {
                Text("Codex")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                Text({
                    let pct = service.codexQuotaStatus.sessionPercent ?? service.codexQuotaStatus.weeklyPercent ?? -1
                    return pct >= 0 ? "\(Int(pct))%" : "N/A"
                }())
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundColor({
                        let pct = service.codexQuotaStatus.sessionPercent ?? service.codexQuotaStatus.weeklyPercent ?? -1
                        return pct >= 80 ? .red : .primary
                    }())
            }
            .frame(width: 50)

            // 同步时间
            VStack(alignment: .trailing, spacing: 0) {
                Text(L.syncTime)
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                Text(L.ago(Int(-service.lastApiSync.timeIntervalSinceNow)))
                    .font(.system(size: 9, design: .monospaced))
            }
            .frame(width: 55)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch service.selectedTab {
        case .dashboard:
            DashboardView(service: service)
        case .profiles:
            ProfileManagerView(service: service)
        case .providers:
            ProviderManagerView(service: service)
        case .pricing:
            PricingManagerView(service: service)
        case .budgets:
            BudgetManagerView(service: service)
        }
    }

    // MARK: Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button {
                showDataHealth.toggle()
            } label: {
                Label("数据", systemImage: "heart.text.square")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDataHealth) {
                DataHealthView(service: service)
            }

            Spacer()

            HStack(spacing: 4) {
                Circle()
                    .fill(service.dbStatus.hasData ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
                Text("DB")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                showSettings.toggle()
            } label: {
                Label("设置", systemImage: "gearshape")
                    .font(.caption)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) {
                SettingsView(service: service)
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "xmark.circle")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    // MARK: Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Int(-date.timeIntervalSinceNow)
        if interval < 60 { return "\(interval)s ago" }
        return "\(interval / 60)min ago"
    }
}
