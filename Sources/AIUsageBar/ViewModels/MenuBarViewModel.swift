import Foundation
import Combine

enum MenuBarStatusColor {
    case primary
    case warning
    case critical
    case unavailable
}

struct MenuBarDetailRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let color: MenuBarStatusColor
}

struct MenuBarDisplayState {
    let displayTitle: String
    let providerName: String
    let sectionTitle: String?
    let detailRows: [MenuBarDetailRow]
    let color: MenuBarStatusColor

    static let idle = MenuBarDisplayState(
        displayTitle: "AIUsageBar",
        providerName: "AIUsageBar",
        sectionTitle: nil,
        detailRows: [],
        color: .primary
    )
}

/// Converts provider state into stable MenuBar strings and colors. This type
/// intentionally has no repository, database, or Codex provider dependency.
@MainActor
final class MenuBarViewModel: ObservableObject {
    @Published private(set) var displayState: MenuBarDisplayState = .idle

    var displayTitle: String { displayState.displayTitle }
    var providerName: String { displayState.providerName }
    var sectionTitle: String? { displayState.sectionTitle }
    var detailRows: [MenuBarDetailRow] { displayState.detailRows }
    var statusColor: MenuBarStatusColor { displayState.color }

    private var cancellable: AnyCancellable?

    init(providerStatusService: AIProviderStatusService) {
        update(from: providerStatusService.snapshot)
        cancellable = providerStatusService.$snapshot.sink { [weak self] snapshot in
            guard let self else { return }
            self.update(from: snapshot)
        }
    }

    private func update(from snapshot: AIProviderSnapshot) {
        switch snapshot.currentProvider {
        case .claude:
            let cost = formatCost(snapshot.claudeUsage.todayCost)
            displayState = MenuBarDisplayState(
                displayTitle: "✨ Claude \(cost)",
                providerName: "Claude",
                sectionTitle: nil,
                detailRows: [
                    MenuBarDetailRow(label: "Today Cost", value: cost, color: .primary),
                    MenuBarDetailRow(label: "Tokens", value: TokenFormatter.format(snapshot.claudeUsage.todayTokens), color: .primary),
                    MenuBarDetailRow(label: "Last Activity", value: formatActivity(snapshot.claudeUsage.lastActivity), color: .primary)
                ],
                color: .primary
            )

        case .codex:
            let remaining = formatRemaining(until: snapshot.codexQuota.sessionResetTime)
            let used = snapshot.codexQuota.sessionPercent.map { "\(Int($0))%" } ?? "N/A"
            let quotaColor = color(for: snapshot.codexQuota)
            displayState = MenuBarDisplayState(
                displayTitle: "🤖 Codex \(remaining)",
                providerName: "Codex",
                sectionTitle: "5 Hour Window",
                detailRows: [
                    MenuBarDetailRow(label: "Remaining", value: remaining, color: quotaColor),
                    MenuBarDetailRow(label: "Used", value: used, color: quotaColor),
                    MenuBarDetailRow(label: "Reset", value: formatReset(snapshot.codexQuota.sessionResetTime), color: .primary),
                    MenuBarDetailRow(label: "Last Activity", value: formatActivity(snapshot.codexLastActivity), color: .primary)
                ],
                color: quotaColor
            )

        case .none:
            displayState = .idle
        }
    }

    private func formatCost(_ value: Double) -> String {
        CostFormatter.formatShort(value).replacingOccurrences(of: "¥", with: "$")
    }

    private func formatRemaining(until resetTime: Date?, now: Date = Date()) -> String {
        guard let resetTime else { return "N/A" }
        let seconds = max(0, resetTime.timeIntervalSince(now))
        if seconds < 60 { return "Now" }
        let totalMinutes = Int(seconds / 60)
        return "\(totalMinutes / 60)h\(totalMinutes % 60)m"
    }

    private func formatReset(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "HH:mm" : "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func formatActivity(_ date: Date?) -> String {
        guard let date else { return "N/A" }
        return RelativeTimeFormatter.format(date)
    }

    private func color(for quota: CodexQuotaStatus) -> MenuBarStatusColor {
        guard let percent = quota.sessionPercent else { return .unavailable }
        if percent >= 95 { return .critical }
        if percent >= 80 { return .warning }
        return .primary
    }
}
