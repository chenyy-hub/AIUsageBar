import SwiftUI

// MARK: - AIUsageBar App (v1.4 — 动态 Agent 状态)

/// macOS MenuBar — AI Agent Status Bar
///
///   根据 lastAgent 自动切换单行显示：
///   ✨ Claude ¥x.xx     — Claude Code 活跃（今日 API cost）
///   ⌘ Codex xx%         — Codex 活跃（5h 窗口百分比）
///   🤖 DeepSeek ¥x.xx   — DeepSeek 活跃
///   AI ✓                — 正常状态，无活跃 Agent
///
@main
struct AIUsageBarApp: App {
    @StateObject private var service: UsageService
    @StateObject private var providerStatusService: AIProviderStatusService
    @StateObject private var menuBarViewModel: MenuBarViewModel

    init() {
        let isDemo = CommandLine.arguments.contains("--demo")
        let svc = UsageService(demo: isDemo)
        let notificationCoordinator = ProviderNotificationCoordinator(
            notificationService: svc.notificationService
        )
        let providerStatus = AIProviderStatusService(
            usageRepository: svc.usageRepository,
            codexQuotaMonitor: svc.codexQuotaMonitor,
            activityService: svc.activeAgentService,
            notificationCoordinator: notificationCoordinator,
            claudeBudgetProvider: { svc.initialBalance }
        )
        _service = StateObject(wrappedValue: svc)
        _providerStatusService = StateObject(wrappedValue: providerStatus)
        _menuBarViewModel = StateObject(wrappedValue: MenuBarViewModel(providerStatusService: providerStatus))
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(viewModel: menuBarViewModel, service: service)
        } label: {
            Text(menuBarViewModel.displayTitle)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundColor(menuBarColor)
            .opacity(service.codexQuotaMonitor.didResetQuota ? 0.3 : 1.0)
            .animation(.easeInOut(duration: 0.2).repeatCount(3), value: service.codexQuotaMonitor.didResetQuota)
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarColor: Color {
        switch menuBarViewModel.statusColor {
        case .primary: return .primary
        case .warning: return .orange
        case .critical, .unavailable: return .red
        }
    }
}
