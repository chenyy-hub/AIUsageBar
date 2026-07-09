import SwiftUI

// MARK: - AIUsageBar App

/// macOS Menu Bar app — AI Agent Resource Monitor v5.2
///
/// 菜单栏动态标签策略：
///   - 纯订阅: 显示 AI 🤖 + token 用量
///   - 纯 API:  显示 ¥cost
///   - 混合:    显示 AI 🤖 + 短 cost
@main
struct AIUsageBarApp: App {
    @StateObject private var service = UsageService()

    var body: some Scene {
        MenuBarExtra {
            MenuBarContentView(service: service)
        } label: {
            HStack(spacing: 4) {
                if service.hasSubscription {
                    Image(systemName: "cpu")
                        .font(.system(size: 10))
                    Text(service.primaryAgentLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                    if !service.secondaryLabel.isEmpty {
                        Text(service.secondaryLabel)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                } else if service.hasApiCost {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12))
                    Text(service.primaryAgentLabel)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                } else {
                    Image(systemName: "chart.pie.fill")
                        .font(.system(size: 12))
                    Text("¥...")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
