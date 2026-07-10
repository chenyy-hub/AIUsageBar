import SwiftUI

struct MenuBarContentView: View {
    @ObservedObject var viewModel: MenuBarViewModel
    @ObservedObject var service: UsageService
    @State private var showSettings = false
    @State private var showDataHealth = false

    var body: some View {
        VStack(spacing: 0) {
            providerStatusSection
            Divider()

            Picker("", selection: $service.selectedTab) {
                ForEach(AppTab.allCases) { tab in
                    Text(tab.title).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            tabContent

            Divider()
            bottomBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var providerStatusSection: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.caption)
                    .foregroundColor(providerColor)
                Text(viewModel.providerName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .padding(.bottom, 6)

            if let sectionTitle = viewModel.sectionTitle {
                Text(sectionTitle)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 14)
                    .padding(.bottom, 2)
            }

            ForEach(viewModel.detailRows) { row in
                StatRow(label: row.label, value: row.value, color: color(for: row.color))
            }
            .padding(.horizontal, 14)

            scannerSection
                .padding(.top, viewModel.detailRows.isEmpty ? 0 : 6)
        }
        .padding(.bottom, 6)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var scannerSection: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                Circle()
                    .fill(service.scannerStatus.running ? Color.green : Color.red)
                    .frame(width: 5, height: 5)
                Text(service.scannerStatus.running ? "Scanner: Running" : "Scanner: Offline")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundColor(service.scannerStatus.running ? .primary : .red)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text("Last Sync")
                    .font(.system(size: 7))
                    .foregroundColor(.secondary)
                Text(scannerStatusText)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(scannerError ? .red : .secondary)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    private var scannerStatusText: String {
        if let error = service.scannerStatus.lastError, !error.isEmpty, !service.scannerStatus.running {
            return "Error"
        }
        if let date = service.scannerStatus.lastScanDate {
            return RelativeTimeFormatter.format(date)
        }
        return "N/A"
    }

    private var scannerError: Bool {
        guard let error = service.scannerStatus.lastError else { return false }
        return !error.isEmpty && !service.scannerStatus.running
    }

    @ViewBuilder
    private var tabContent: some View {
        switch service.selectedTab {
        case .dashboard: DashboardView(service: service)
        case .profiles: ProfileManagerView(service: service)
        case .providers: ProviderManagerView(service: service)
        case .pricing: PricingManagerView(service: service)
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 0) {
            Button { showDataHealth.toggle() } label: {
                Label(L.dataHealth, systemImage: "heart.text.square").font(.caption)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showDataHealth) { DataHealthView(service: service) }

            Spacer()
            HStack(spacing: 4) {
                Circle().fill(service.dbStatus.hasData ? Color.green : Color.red).frame(width: 5, height: 5)
                Text("DB").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()

            Button { showSettings.toggle() } label: {
                Label(L.settings, systemImage: "gearshape").font(.caption)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) { SettingsView(service: service) }

            Spacer()
            Button { NSApplication.shared.terminate(nil) } label: {
                Label(L.quit, systemImage: "xmark.circle").font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var providerColor: Color { color(for: viewModel.statusColor) }

    private func color(for status: MenuBarStatusColor) -> Color {
        switch status {
        case .primary: return .primary
        case .warning: return .orange
        case .critical, .unavailable: return .red
        }
    }
}
