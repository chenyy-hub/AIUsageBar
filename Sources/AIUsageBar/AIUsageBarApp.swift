import SwiftUI

// MARK: - AIUsageBar App

/// macOS Menu Bar — AI Agent Usage Observability Dashboard v1.1
///
/// 菜单栏智能状态：
///   - API 有消耗 → 显示 "🤖 ¥xxx"
///   - 正常             → 显示 "AI ✓"
///
@main
struct AIUsageBarApp: App {
    @StateObject private var service: UsageService

    init() {
        let isDemo = CommandLine.arguments.contains("--demo")
        _service = StateObject(wrappedValue: UsageService(demo: isDemo))
    }

    private var menuLabel: some View {
        let apiCost = service.apiTotalStats.totalCost
        let hasUsage = service.apiTotalStats.totalRequests > 0

        if hasUsage && apiCost > 0 {
            // API 有消耗
            return AnyView(HStack(spacing: 4) {
                Text("🤖")
                    .font(.system(size: 11))
                Text(service.todayCostText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
            })
        } else {
            // 正常状态
            return AnyView(HStack(spacing: 4) {
                Text("AI")
                    .font(.system(size: 11, weight: .medium))
                Text("✓")
                    .font(.system(size: 11))
                    .foregroundColor(.green)
            })
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(service: service)
        } label: {
            menuLabel
        }
        .menuBarExtraStyle(.window)
    }
}
