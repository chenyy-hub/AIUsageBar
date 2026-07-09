import Foundation
import AppKit

// MARK: - Profile Service

/// Model Profile 业务逻辑
///
/// 职责：
///   - Profile CRUD（委托 DatabaseService 数据层）
///   - Profile export（clipboard / .env 文件）
///   - env_config 中 {{keychain:name}} 占位符解析为真实 API Key
///
/// 安全：API Key 永远不写入 SQLite 或 export 的 JSON 文件（.env 文件除外，export 时解析后替换）
///
final class ProfileService {
    private let db: DatabaseService

    init(db: DatabaseService) {
        self.db = db
    }

    // MARK: - CRUD

    var profiles: [ModelProfile] { db.loadProfiles() }

    func getProfile(id: Int) -> ModelProfile? { db.getProfile(id: id) }

    func getActiveProfile() -> ModelProfile? { db.getActiveProfile() }

    @discardableResult
    func saveProfile(_ profile: ModelProfile) -> Int { db.saveProfile(profile) }

    func deleteProfile(id: Int) { db.deleteProfile(id: id) }

    func activateProfile(id: Int) { db.setActiveProfile(id: id) }

    // MARK: - Export: Resolve Keychain References

    /// 将 env_config 中的 {{keychain:name}} 占位符替换为实际 API Key。
    /// 返回完整解析后的配置字典（Key 已注入，可安全用于 export）。
    func resolveEnvConfig(_ profile: ModelProfile, providerService: ProviderService) -> [String: [String: String]] {
        let raw = profile.envConfig
        var resolved: [String: [String: String]] = [:]

        for (client, envVars) in raw {
            var resolvedVars: [String: String] = [:]
            for (key, value) in envVars {
                if let ref = parseKeychainReference(value) {
                    // 从 Keychain 读取
                    let apiKey = providerService.readAPIKey(provider: ref.provider) ?? ""
                    resolvedVars[key] = apiKey
                } else {
                    resolvedVars[key] = value
                }
            }
            resolved[client] = resolvedVars
        }
        return resolved
    }

    /// 将 env_config 文本导出为 .env 格式（包含实际 Key 值）
    func exportAsEnvFileContent(_ profile: ModelProfile, providerService: ProviderService) -> String {
        let resolved = resolveEnvConfig(profile, providerService: providerService)
        var lines: [String] = [
            "# AIUsageBar Profile: \(profile.name)",
            "# Provider: \(profile.provider) | Model: \(profile.model)",
            "# Exported at \(ISO8601DateFormatter().string(from: Date()))",
            "",
        ]

        // 按 client 分组输出
        for (client, envVars) in resolved.sorted(by: { $0.key < $1.key }) {
            lines.append("# --- \(client) ---")
            for (key, value) in envVars.sorted(by: { $0.key < $1.key }) {
                // 对值中的特殊字符做 shell 安全转义
                let safeValue = value.contains(" ") ? "\"\(value)\"" : value
                lines.append("\(key)=\(safeValue)")
            }
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }

    /// 复制 env 内容到剪贴板
    func copyToClipboard(_ profile: ModelProfile, providerService: ProviderService) {
        let content = exportAsEnvFileContent(profile, providerService: providerService)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(content, forType: .string)
    }

    /// 导出 .env 文件到指定目录（默认桌面）
    func exportEnvFile(_ profile: ModelProfile, providerService: ProviderService, to directory: URL? = nil) -> URL? {
        let content = exportAsEnvFileContent(profile, providerService: providerService)

        let dir = directory ?? FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
        let fileName = "ai-\(profile.name.lowercased().replacingOccurrences(of: " ", with: "-")).env"
        let fileURL = dir.appendingPathComponent(fileName)

        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            NSLog("[ProfileService] Failed to write env file: \(error)")
            return nil
        }
    }

    // MARK: - Preview (不解析 Key)

    /// 预览 env_config（占位符保持 {{keychain:name}} 不变，不泄露 Key）
    func previewEnvConfig(_ profile: ModelProfile) -> String {
        let raw = profile.envConfig
        var lines: [String] = [
            "# Profile Preview: \(profile.name)",
            "# API Key 引用将按 {{keychain:provider}} 形式显示，不泄露实际值",
            "",
        ]
        for (client, envVars) in raw.sorted(by: { $0.key < $1.key }) {
            lines.append("# --- \(client) ---")
            for (key, value) in envVars.sorted(by: { $0.key < $1.key }) {
                if parseKeychainReference(value) != nil {
                    lines.append("\(key)=<keychain:\(value)>")
                } else {
                    lines.append("\(key)=\(value)")
                }
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// 解析 {{keychain:provider_name}} 格式
    private struct KeychainRef {
        let provider: String
    }

    private func parseKeychainReference(_ value: String) -> KeychainRef? {
        let pattern = #"\{\{keychain:(\w+)\}\}"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: value, range: NSRange(value.startIndex..., in: value)),
              let range = Range(match.range(at: 1), in: value)
        else { return nil }
        return KeychainRef(provider: String(value[range]))
    }
}
