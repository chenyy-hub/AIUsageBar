import Foundation

// MARK: - 本地化字符串 (zh-CN)

enum L {
    // App
    static let appName = "AIUsageBar"

    // MenuBar
    static let menuBarNormal = "AI ✓"
    static let menuBarCodex = "◉ Codex"
    static let menuBarClaude = "✨ Claude"
    static let menuBarDeepSeek = "🤖 DeepSeek"

    // Dashboard
    static let dashboardTitle = "总览"
    static let apiHeroTitle = "今日消耗"
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
    static let todayCost = "今日消费"
    static let monthCost = "本月消费"
    static let tokens = "Token"
    static let requests = "请求数"
    static let sessions = "会话"
    static let syncTime = "同步"
    static let activeAgent = "活跃 Agent"
    static let codexQuota = "Codex 额度"
    static let lastSync = "最近同步"

    // Codex subscription
    static let sessionQuota = "会话额度"
    static let weeklyQuota = "周额度"
    static let remaining = "剩余"
    static let used = "已用"
    static let reset = "重置"

    // Model
    static let apiModels = "API 模型"
    static let subscriptionModels = "订阅模型"

    // Notification
    static let quotaResetTitle = "Codex 额度已刷新"
    static let quotaWarningTitle = "Codex 额度不足"
    static let apiCostWarningTitle = "API 消耗提醒"

    // System
    static let database = "数据库"
    static let healthy = "正常"
    static let noData = "无数据"
    static let refresh = "刷新"
    static let settings = "设置"
    static let quit = "退出"
    static let dataHealth = "数据健康"
    static let mode = "模式"
    static let tables = "表"
    static let status = "状态"
    static let warning = "警告"
    static let scanner = "扫描器"
    static let records = "记录"
    static let runScanner = "运行扫描"

    // API Budget (v3.0)
    static let apiBudget = "API 预算"
    static let balance = "余额"
    static let remainingDays = "预计可用"
    static let dailyAvg = "日均"
    static let day = "天"
    static let costTrend = "消耗趋势"
    static let budgetSetup = "预算设置"
    static let recharge = "充值金额"
    static let warningThreshold = "警告阈值"
    static let todayUsage = "今日使用"

    // v2.0 — Productized Labels
    static let aiUsage = "AI Usage"
    static let cumulative = "累计"
    static let activeAgents = "Active Agents"
    static let modelUsage = "Model Usage"
    static let budget = "Budget"
    static let totalBudget = "Total Budget"
    static let usedCost = "Used"
    static let remainingBalance = "Remaining"
    static let developerMode = "Developer Mode"
    static let statusLabel = "状态"
    static let modelLabel = "模型"
    static let quotaLabel = "Quota"

    // Timing
    static func ago(_ seconds: Int) -> String {
        if seconds < 60 { return "\(seconds) 秒前" }
        return "\(seconds / 60) 分钟前"
    }

    // Percent
    static let percentFormat = "%d%%"
    static let zeroCost = "¥0"
}
