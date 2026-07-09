import Foundation
import Security

// MARK: - Provider Service

/// Provider 配置 + Keychain API Key 管理 + Test Connection 调度
///
/// 安全原则：
///   - API Key 只通过 macOS Keychain 存储（SecItemAdd / SecItemCopyMatching）
///   - SQLite 只存 keychain_service 名称，不存 Key 本身
///   - env_config 仅以 {{keychain:name}} 占位符引用
///
final class ProviderService {
    private let db: DatabaseService

    /// Keychain service 前缀
    private static let keychainServicePrefix = "com.a1.ai-usage-bar.provider"

    init(db: DatabaseService) {
        self.db = db
    }

    // MARK: - CRUD

    var providers: [ProviderConfig] { db.loadProviders() }

    func getProvider(name: String) -> ProviderConfig? { db.getProvider(name: name) }

    @discardableResult
    func saveProvider(_ config: ProviderConfig) -> Int {
        var c = config
        if c.keychainService.isEmpty {
            c.keychainService = "\(Self.keychainServicePrefix).\(c.provider)"
        }
        return db.saveProvider(c)
    }

    func deleteProvider(name: String) {
        deleteAPIKey(provider: name)
        db.deleteProvider(name: name)
    }

    func updateTestStatus(provider: String, status: String) {
        db.updateProviderTestStatus(provider: provider, status: status)
    }

    // MARK: - Keychain API Key 管理

    /// 保存 API Key 到 Keychain
    func saveAPIKey(provider: String, key: String) {
        let service = "\(Self.keychainServicePrefix).\(provider)"
        let account = "api_key"
        guard let keyData = key.data(using: .utf8) else { return }

        // 先删除已有条目
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        // 新增
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: keyData,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        if status != errSecSuccess {
            NSLog("[ProviderService] Keychain save error: \(status)")
        }
    }

    /// 从 Keychain 读取 API Key
    func readAPIKey(provider: String) -> String? {
        let service = "\(Self.keychainServicePrefix).\(provider)"
        let account = "api_key"

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let data = result as? Data else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    /// 删除 Keychain 中的 API Key
    func deleteAPIKey(provider: String) {
        let service = "\(Self.keychainServicePrefix).\(provider)"
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "api_key",
        ]
        SecItemDelete(query as CFDictionary)
    }

    /// 检查 Keychain 中是否存在 API Key
    func hasAPIKey(provider: String) -> Bool {
        readAPIKey(provider: provider) != nil
    }

    // MARK: - Test Connection

    /// 测试指定 provider 的连接
    func testConnection(_ config: ProviderConfig) async -> ConnectionTestResult {
        guard let apiKey = readAPIKey(provider: config.provider), !apiKey.isEmpty else {
            updateTestStatus(provider: config.provider, status: "failed")
            return ConnectionTestResult(success: false, latencyMs: 0, model: config.provider,
                                        message: "API Key 未配置")
        }

        guard let adapter = ProviderAdapterFactory.adapter(for: config.providerType) else {
            updateTestStatus(provider: config.provider, status: "failed")
            return ConnectionTestResult(success: false, latencyMs: 0, model: config.provider,
                                        message: "不支持的 Provider 类型: \(config.providerType)")
        }

        let model = config.models.first ?? "unknown"
        let result = await adapter.testConnection(
            apiKey: apiKey,
            baseURL: config.baseUrl,
            model: model
        )

        updateTestStatus(provider: config.provider, status: result.success ? "success" : "failed")
        return result
    }

    func testConnection(provider: String) async -> ConnectionTestResult? {
        guard let config = getProvider(name: provider) else { return nil }
        return await testConnection(config)
    }
}
