import Foundation

// MARK: - Pricing Service

/// 模型定价业务逻辑
///
/// 数据流：
///   pricing.yaml (初始化模板)
///       │ Python Process 导入
///       ▼
///   model_pricing SQLite 表（运行时真实来源）
///       │ AIUsageBar 编辑 → 保存
///       ▼
///   model_pricing ←→ pricing.yaml 双向同步
///
/// 安全：pricing.yaml 仅存价格，不含 API Key。
///
final class PricingService {
    private let db: DatabaseService

    /// pricing.yaml 路径（相对于 workspace root）
    private var pricingYamlPath: String {
        let home = NSHomeDirectory()
        return "\(home)/workspace-agent-digital-employee/skills/ai-cost-monitor/config/pricing.yaml"
    }

    init(db: DatabaseService) {
        self.db = db
    }

    // MARK: - CRUD

    var allPricing: [ModelPricing] { db.loadPricing() }

    func getPricing(provider: String, model: String) -> ModelPricing? {
        db.getPricing(provider: provider, model: model)
    }

    func savePricing(_ pricing: ModelPricing) {
        db.savePricing(pricing)
    }

    func deletePricing(provider: String, model: String) {
        db.deletePricing(provider: provider, model: model)
    }

    // MARK: - Import from pricing.yaml

    /// 从 pricing.yaml 导入定价数据到 model_pricing 表
    /// 返回导入的条目数（不覆盖 is_custom=1 的行）
    func importFromYaml() -> Int {
        guard let items = parseYamlViaPython(pricingYamlPath) else {
            NSLog("[PricingService] Failed to parse pricing.yaml")
            return 0
        }
        db.importPricingFromJSON(items)
        return items.count
    }

    /// 用 Python3 解析 pricing.yaml。
    /// 兼容新旧两种格式：
    ///   新格式: provider → models → model_name → prices
    ///   旧格式: model_name → {input_price, output_price, cache_read_price, cache_creation_price, provider}
    private func parseYamlViaPython(_ path: String) -> [[String: Any]]? {
        let script = """
        import yaml, json, sys
        try:
            with open(sys.argv[1]) as f:
                data = yaml.safe_load(f)
            if not data:
                print('[]')
                sys.exit(0)
            result = []
            for key, config in data.items():
                if not isinstance(config, dict):
                    continue

                # New format: provider -> {models: {model_name: {prices}}, currency: CNY}
                models = config.get('models')
                if isinstance(models, dict):
                    currency = config.get('currency', 'CNY')
                    for model_name, prices in models.items():
                        if not isinstance(prices, dict):
                            continue
                        result.append({
                            "provider": key,
                            "model": model_name,
                            "currency": prices.get('currency', currency),
                            "input_cache_hit_price": prices.get('input_cache_hit_price',
                                            prices.get('cache_read_price', 0)),
                            "input_cache_miss_price": prices.get('input_cache_miss_price',
                                            prices.get('input_price', 0) - prices.get('cache_read_price', 0)),
                            "output_price": prices.get('output_price', 0),
                        })
                else:
                    # Old format: model_name -> {input_price, output_price, cache_read_price, provider}
                    provider = config.get('provider', 'unknown')
                    inp = config.get('input_price', 0)
                    out = config.get('output_price', 0)
                    cache = config.get('cache_read_price', 0)
                    result.append({
                        "provider": provider,
                        "model": key,
                        "currency": config.get('currency', 'CNY'),
                        "input_cache_hit_price": cache / 2 if cache > 0 else 0,
                        "input_cache_miss_price": inp - (cache / 2) if cache > 0 else inp,
                        "output_price": out,
                    })
            print(json.dumps(result))
        except Exception as e:
            print(json.dumps({"error": str(e)}))
        """

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", script, path]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8) else { return nil }

            if let items = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [[String: Any]] {
                return items
            }
            if let error = try? JSONSerialization.jsonObject(with: Data(output.utf8)) as? [String: String],
               let errMsg = error["error"] {
                NSLog("[PricingService] YAML parse error: \(errMsg)")
            }
            return nil
        } catch {
            NSLog("[PricingService] Python process error: \(error)")
            return nil
        }
    }

    // MARK: - Sync to pricing.yaml

    /// 将 model_pricing 表同步回 pricing.yaml
    /// 用于用户编辑定价后更新配置
    func syncToYaml() -> Bool {
        let items = allPricing
        guard !items.isEmpty else { return false }

        let script = """
        import yaml, json, sys
        try:
            # Write in old flat format for Python backend compatibility
            data = json.loads(sys.argv[1])
            output = {}
            for item in data:
                model = item['model']
                hit = item['input_cache_hit_price']
                miss = item['input_cache_miss_price']
                inp = hit + miss
                output[model] = {
                    'provider': item['provider'],
                    'input_price': inp,
                    'output_price': item['output_price'],
                    'cache_read_price': hit,
                    'cache_creation_price': 0,
                    'currency': item.get('currency', 'CNY'),
                }
            with open(sys.argv[2], 'w') as f:
                yaml.dump(output, f, default_flow_style=False, allow_unicode=True)
            print('OK')
        except Exception as e:
            print(json.dumps({"error": str(e)}))
        """

        guard let jsonData = try? JSONSerialization.data(withJSONObject: items.map {
            [
                "provider": $0.provider,
                "model": $0.model,
                "input_cache_hit_price": $0.inputCacheHitPrice,
                "input_cache_miss_price": $0.inputCacheMissPrice,
                "output_price": $0.outputPrice,
                "currency": $0.currency,
            ] as [String: Any]
        }), let jsonStr = String(data: jsonData, encoding: .utf8) else {
            return false
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = ["-c", script, jsonStr, pricingYamlPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.trimmingCharacters(in: .whitespacesAndNewlines) == "OK"
        } catch {
            NSLog("[PricingService] Sync error: \(error)")
            return false
        }
    }
}
