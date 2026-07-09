import SwiftUI

// MARK: - AIUsageBar App (v1.5.0)

/// macOS Menu Bar — 菜单栏智能状态
///
///   🤖 AI          — 正常状态
///   ⚠ AI 95%      — Codex 额度 ≥ 90%
///   🤖 AI ¥12.5   — API 有消耗
///
@main
struct AIUsageBarApp: App {
    @StateObject private var service: UsageService
    private let statusService: MenuBarStatusService

    init() {
        let isDemo = CommandLine.arguments.contains("--demo")
        let svc = UsageService(demo: isDemo)
        _service = StateObject(wrappedValue: svc)
        statusService = MenuBarStatusService(usageService: svc)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(service: service)
        } label: {
            let status = statusService.computeStatus()
            Text(status.fullText)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundColor(status.state == .offline ? .red : .primary)
        }
        .menuBarExtraStyle(.window)
    }
}
