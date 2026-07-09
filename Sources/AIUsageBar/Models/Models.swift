import Foundation

// MARK: - Usage Record (from SQLite usage_records)

struct UsageRecord: Decodable {
    let id: Int
    let timestamp: String
    let project: String
    let sessionId: String
    let eventUuid: String
    let model: String
    let provider: String
    let inputTokens: Int
    let outputTokens: Int
    let cacheReadTokens: Int
    let cacheCreationTokens: Int
    let inputCost: Double
    let outputCost: Double
    let totalCost: Double
}

// MARK: - Aggregated Usage Data

struct DailySummary: Identifiable {
    let id = UUID()
    let date: String
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let requestCount: Int
}

struct ProjectCost: Identifiable {
    let id = UUID()
    let name: String
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let cacheTokens: Int
    let sessionCount: Int
    let requestCount: Int
    var fraction: Double = 0

    var totalTokens: Int { inputTokens + outputTokens + cacheTokens }
}

struct ModelBreakdown: Identifiable {
    let id = UUID()
    let model: String
    let totalCost: Double
    let inputTokens: Int
    let outputTokens: Int
    let requestCount: Int
}

struct TotalStats {
    let totalCost: Double
    let totalInput: Int
    let totalOutput: Int
    let totalCacheRead: Int
    let totalRequests: Int
    let totalSessions: Int
    let totalProjects: Int
}

struct CodexQuotaStatus {
    let sessionUsed: Double?
    let sessionLimit: Double?
    let sessionPercent: Double?
    let sessionResetTime: Date?
    let weeklyUsed: Double?
    let weeklyLimit: Double?
    let weeklyPercent: Double?
    let weeklyResetTime: Date?
    let status: String

    var isAvailable: Bool { status == "available" }

    var sessionRemainingPercent: Double? {
        sessionPercent.map { max(0, 100 - $0) }
    }

    var weeklyRemainingPercent: Double? {
        weeklyPercent.map { max(0, 100 - $0) }
    }

    static let unavailable = CodexQuotaStatus(
        sessionUsed: nil,
        sessionLimit: nil,
        sessionPercent: nil,
        sessionResetTime: nil,
        weeklyUsed: nil,
        weeklyLimit: nil,
        weeklyPercent: nil,
        weeklyResetTime: nil,
        status: "unavailable"
    )
}

struct CodexUsageSnapshot {
    let sessions: Int
    let totalTokens: Double
    let models: [(model: String, sessions: Int, tokens: Double)]
}




struct DBStatus {
    let recordCount: Int
    let hasData: Bool
    let path: String
    let lastUpdate: Date?
}

// MARK: - Management Models

/// Model Profile — 模型配置预设
struct ModelProfile: Identifiable, Codable {
    let id: Int
    var name: String
    var provider: String
    var model: String
    var baseUrl: String
    var client: String
    var envConfigJSON: String           // JSON with {{keychain:name}} placeholders
    var isActive: Bool
    var createdAt: String

    /// 解析 env_config 为字典
    var envConfig: [String: [String: String]] {
        (try? JSONSerialization.jsonObject(with: Data(envConfigJSON.utf8)) as? [String: [String: String]]) ?? [:]
    }

    /// 默认初始化
    static func empty() -> ModelProfile {
        ModelProfile(id: 0, name: "", provider: "", model: "", baseUrl: "",
                     client: "claude-code", envConfigJSON: "{}", isActive: false, createdAt: "")
    }
}

/// Provider Config — API 供应商配置
struct ProviderConfig: Identifiable, Codable {
    let id: Int
    var provider: String                  // key name: "deepseek"
    var providerType: String              // "deepseek" | "openai-compatible" | "anthropic" | "openrouter"
    var displayName: String
    var baseUrl: String
    var modelsJSON: String                // JSON array
    var keychainService: String           // Keychain service name
    var isActive: Bool
    var lastTestStatus: String            // "success" | "failed" | ""
    var lastTestTime: String
    var createdAt: String

    var models: [String] {
        (try? JSONSerialization.jsonObject(with: Data(modelsJSON.utf8)) as? [String]) ?? []
    }

    /// Keychain 账户名
    var keychainAccount: String { "api_key" }

    static func empty(provider: String = "") -> ProviderConfig {
        ProviderConfig(id: 0, provider: provider, providerType: "openai-compatible",
                       displayName: "", baseUrl: "", modelsJSON: "[]",
                       keychainService: "", isActive: true,
                       lastTestStatus: "", lastTestTime: "", createdAt: "")
    }
}

/// Model Pricing — 模型定价
struct ModelPricing: Identifiable, Codable {
    let id: Int
    var provider: String
    var model: String
    var currency: String
    var inputCacheHitPrice: Double         // /1M tokens
    var inputCacheMissPrice: Double
    var outputPrice: Double
    var isCustom: Bool                     // 不被模板覆盖
    var updatedAt: String

    static func empty(provider: String = "", model: String = "") -> ModelPricing {
        ModelPricing(id: 0, provider: provider, model: model, currency: "CNY",
                     inputCacheHitPrice: 0, inputCacheMissPrice: 0, outputPrice: 0,
                     isCustom: false, updatedAt: "")
    }
}

/// Budget — 预算配置
struct Budget: Identifiable, Codable {
    let id: Int
    var name: String
    var provider: String                   // "" = 全局
    var initialBalance: Double
    var currency: String
    var periodType: String                 // "total" | "daily" | "weekly" | "monthly"
    var startDate: String
    var isActive: Bool
    var createdAt: String

    static func empty() -> Budget {
        Budget(id: 0, name: "", provider: "", initialBalance: 0,
               currency: "CNY", periodType: "total",
               startDate: "", isActive: true, createdAt: "")
    }
}

// MARK: - V5 Agent Resource Models

/// 使用类型
enum UsageType: String, Codable {
    case apiCost = "api_cost"
    case subscriptionQuota = "subscription_quota"
    case localUsage = "local_usage"
}

/// Agent 使用资源（统一展示模型）
struct AgentResource: Identifiable {
    let id = UUID()
    let client: String
    let provider: String
    let usageType: UsageType
    let cost: Double?
    let inputTokens: Int?
    let outputTokens: Int?
    let quotaUsed: Double?
    let quotaLimit: Double?
    let resetTime: Date?
    let isEstimated: Bool

    var displayName: String {
        switch client {
        case "claude-code": return "Claude Code"
        case "codex":       return "Codex"
        case "openclaw":    return "OpenClaw"
        default:            return client
        }
    }

    var iconName: String {
        switch client {
        case "claude-code": return "sparkles"
        case "codex":       return "chevron.left.forwardslash.chevron.right"
        default:            return "gearshape"
        }
    }

    var typeLabel: String {
        switch usageType {
        case .apiCost:           return "API"
        case .subscriptionQuota: return "Subscription"
        case .localUsage:        return "Local"
        }
    }

    var typeIcon: String {
        switch usageType {
        case .apiCost:           return "network"
        case .subscriptionQuota: return "creditcard.fill"
        case .localUsage:        return "desktopcomputer"
        }
    }
}

// MARK: - Agent Provider Status (v1.1.1)

enum AgentConnectionStatus: String, Codable {
    case connected
    case syncing
    case unavailable
    case noData
}

struct AgentProviderStatus: Identifiable {
    let id = UUID()
    let client: String
    let displayName: String
    let status: AgentConnectionStatus
    let lastSync: Date?
    let recordCount: Int

    var iconName: String {
        switch client {
        case "claude-code": return "sparkles"
        case "codex":       return "chevron.left.forwardslash.chevron.right"
        default:            return "gearshape"
        }
    }

    var statusIcon: String {
        switch status {
        case .connected:    return "circle.fill"
        case .syncing:      return "arrow.triangle.2.circlepath"
        case .unavailable:  return "exclamationmark.triangle.fill"
        case .noData:       return "circle.dashed"
        }
    }

    var statusColor: String {
        switch status {
        case .connected:    return "green"
        case .syncing:      return "orange"
        case .unavailable:  return "red"
        case .noData:       return "gray"
        }
    }
}

// MARK: - Provider Adapter

/// Provider 适配器类型
enum ProviderAdapterType: String, CaseIterable, Codable {
    case deepseek
    case openaiCompatible = "openai-compatible"
    case anthropic
    case openrouter

    var displayName: String {
        switch self {
        case .deepseek:          return "DeepSeek"
        case .openaiCompatible:  return "OpenAI Compatible"
        case .anthropic:         return "Anthropic"
        case .openrouter:        return "OpenRouter"
        }
    }
}

/// 连接测试结果
struct ConnectionTestResult {
    let success: Bool
    let latencyMs: Double
    let model: String
    let message: String
}

// MARK: - Formatters

enum CostFormatter {
    static func format(_ cost: Double) -> String {
        if cost >= 10000 { return String(format: "¥%.1fK", cost / 1000) }
        if cost >= 1     { return String(format: "¥%.2f", cost) }
        if cost >= 0.01  { return String(format: "¥%.4f", cost) }
        return String(format: "¥%.6f", cost)
    }

    static func formatShort(_ cost: Double) -> String {
        if cost >= 10000 { return String(format: "¥%.1fK", cost / 1000) }
        if cost >= 1     { return String(format: "¥%.2f", cost) }
        return String(format: "¥%.2f", cost)
    }
}

enum TokenFormatter {
    static func format(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000     { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }
}
