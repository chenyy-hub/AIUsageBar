import SwiftUI

// MARK: - Menu Bar Content

struct MenuBarContentView: View {
    @ObservedObject var service: UsageService
    @State private var showSettings = false
    @State private var showDataHealth = false

    var body: some View {
        VStack(spacing: 0) {
            // Tab bar
            Picker("", selection: $service.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            // Tab content
            tabContent

            // Bottom toolbar
            Divider()
            bottomBar
        }
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
}
