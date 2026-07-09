import Foundation

// MARK: - Edit Drafts (独立于 @ObservedObject)

struct ProfileEditDraft {
    var name: String = ""
    var provider: String = "deepseek"
    var model: String = ""
    var baseUrl: String = ""
    var client: String = "claude-code"
    var envConfigJSON: String = "{}"
    var isActive: Bool = false

    init() {}

    init(from existing: any EditableProfile) {
        name = existing.name
        provider = existing.provider
        model = existing.model
        baseUrl = existing.baseUrl
        client = existing.client
        envConfigJSON = existing.envConfigJSON
        isActive = existing.isActive
    }

    func toModelProfile(id: Int = 0) -> ModelProfile {
        ModelProfile(id: id, name: name, provider: provider, model: model,
                     baseUrl: baseUrl, client: client, envConfigJSON: envConfigJSON,
                     isActive: isActive, createdAt: "")
    }
}

struct ProviderEditDraft {
    var provider: String = ""
    var providerType: String = "openai-compatible"
    var displayName: String = ""
    var baseUrl: String = ""
    var modelsJSON: String = "[]"
    var apiKey: String = ""

    init() {}

    init(from existing: any EditableProvider) {
        provider = existing.provider
        providerType = existing.providerType
        displayName = existing.displayName
        baseUrl = existing.baseUrl
        modelsJSON = existing.modelsJSON
        apiKey = ProviderService.readAPIKey(provider: existing.provider) ?? ""
    }

    func toProviderConfig(id: Int = 0) -> ProviderConfig {
        ProviderConfig(id: id, provider: provider, providerType: providerType,
                       displayName: displayName, baseUrl: baseUrl, modelsJSON: modelsJSON,
                       keychainService: "", isActive: true,
                       lastTestStatus: "", lastTestTime: "", createdAt: "")
    }
}

struct PricingEditDraft {
    var provider: String = ""
    var model: String = ""
    var currency: String = "CNY"
    var inputCacheHitPrice: Double = 0
    var inputCacheMissPrice: Double = 0
    var outputPrice: Double = 0
    var isCustom: Bool = true

    init() {}

    init(from existing: any EditablePricing) {
        provider = existing.provider
        model = existing.model
        currency = existing.currency
        inputCacheHitPrice = existing.inputCacheHitPrice
        inputCacheMissPrice = existing.inputCacheMissPrice
        outputPrice = existing.outputPrice
        isCustom = existing.isCustom
    }

    func toModelPricing(id: Int = 0) -> ModelPricing {
        ModelPricing(id: id, provider: provider, model: model, currency: currency,
                     inputCacheHitPrice: inputCacheHitPrice,
                     inputCacheMissPrice: inputCacheMissPrice,
                     outputPrice: outputPrice, isCustom: isCustom, updatedAt: "")
    }
}

struct BudgetEditDraft {
    var name: String = ""
    var provider: String = ""
    var initialBalance: Double = 1000
    var currency: String = "CNY"
    var periodType: String = "total"
    var startDate: String = ""
    var isActive: Bool = true

    init() {}

    init(from existing: any EditableBudget) {
        name = existing.name
        provider = existing.provider
        initialBalance = existing.initialBalance
        currency = existing.currency
        periodType = existing.periodType
        isActive = existing.isActive
        startDate = ""
    }

    func toBudget(id: Int = 0) -> Budget {
        Budget(id: id, name: name, provider: provider, initialBalance: initialBalance,
               currency: currency, periodType: periodType, startDate: startDate,
               isActive: isActive, createdAt: "")
    }
}
