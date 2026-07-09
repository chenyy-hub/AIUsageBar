import Foundation

// MARK: - 本地化字符串 (zh-CN)

enum L {
    // App
    static let appName = "AIUsageBar"

    // MenuBar
    static let menuBarNormal = "🤖 AI"
    static let menuBarApiCost = "🤖 AI"
    static let menuBarCodexWarning = "⚠️ AI"

    // Dashboard
    static let dashboardTitle = "总览"
    static let apiHeroTitle = "今日 API 消耗"
    static let agentSection = "AI 代理"
    static let modelSection = "模型用量"
    static let systemStatus = "系统状态"

    // Agent names
    static let claudeCode = "Claude Code"
    static let codex = "Codex"
    static let deepseek = "DeepSeek"

    // Status
    static let apiCost = "API 成本"
    static let cost = "成本"
    static let tokens = "Token"
    static let requests = "请求数"
    static let sessions = "会话"
    static let syncTime = "同步时间"

    // Codex subscription
    static let sessionQuota = "会话额度"
    static let weeklyQuota = "周额度"
    static let remaining = "剩余"
    static let used = "已用"
    static let reset = "重置"

    // Model
    static let apiModels = "API 模型"
    static let subscriptionModels = "订阅模型"

    // System
    static let database = "数据库"
    static let healthy = "正常"
    static let noData = "无数据"
    static let refresh = "刷新"
    static let settings = "设置"
    static let quit = "退出"
    static let dataHealth = "数据健康"

    // Timing
    static func ago(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒前" }
        return "\(seconds / 60) 分钟前"
    }

    // Percent
    static let percentFormat = "%d%%"
    static let zeroCost = "¥0"
}
