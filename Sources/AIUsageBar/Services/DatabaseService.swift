import Foundation
import SQLite3

// MARK: - Database Service

/// Thread-safe SQLite access for ai_usage.db
///
/// 两层连接设计：
///   db      — READONLY，用于 usage_records 查询（已有，不修改）
///   mgmtDb  — READWRITE，用于 management 表（model_profiles / provider_configs / budgets / pricing）
///
final class DatabaseService {
    private let dbPath: String
    private let queue: DispatchQueue

    /// Resolve demo database path (Bundle.app → Resources/demo/)
    static var demoDBPath: String {
        if let resourcePath = Bundle.main.resourcePath {
            let candidate = "\(resourcePath)/demo/demo_usage.db"
            if FileManager.default.fileExists(atPath: candidate) {
                return candidate
            }
        }
        // Fallback for development (swift build)
        let cwd = FileManager.default.currentDirectoryPath
        return "\(cwd)/Resources/demo/demo_usage.db"
    }

    // MARK: Connections
    private var db: OpaquePointer?       // READONLY — usage_records
    private var mgmtDb: OpaquePointer?   // READWRITE — management tables

    // MARK: Init

    init?(path: String? = nil, demo: Bool = false) {
        self.queue = DispatchQueue(label: "com.a1.ai-usage-bar.db", qos: .utility)

        if demo {
            self.dbPath = DatabaseService.demoDBPath
        } else if let path, !path.isEmpty {
            self.dbPath = URL(fileURLWithPath: path).resolvingSymlinksInPath().path
        } else {
            let home = NSHomeDirectory()
            let p = "\(home)/workspace-agent-digital-employee/runtime/ai_usage/ai_usage.db"
            self.dbPath = URL(fileURLWithPath: p).resolvingSymlinksInPath().path
        }

        guard openReadonly() else { return nil }
        _ = openReadwrite()
    }

    deinit {
        sqlite3_close(db)
        sqlite3_close(mgmtDb)
    }

    var isConnected: Bool { db != nil }
    var databasePath: String { dbPath }

    // ------------------------------------------------------------------
    // MARK: Connection Management
    // ------------------------------------------------------------------

    private func openReadonly() -> Bool {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(dbPath, &handle, SQLITE_OPEN_READONLY, nil)
        guard rc == SQLITE_OK, let handle else {
            NSLog("[AIUsageBar] Failed to open readonly: rc=\(rc)")
            return false
        }
        db = handle
        return true
    }

    private func openReadwrite() -> Bool {
        var handle: OpaquePointer?
        let rc = sqlite3_open_v2(dbPath, &handle, SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE, nil)
        guard rc == SQLITE_OK, let handle else {
            NSLog("[AIUsageBar] Failed to open readwrite: rc=\(rc)")
            return false
        }
        // Enable WAL for concurrent access
        sqlite3_exec(handle, "PRAGMA journal_mode=WAL", nil, nil, nil)
        sqlite3_exec(handle, "PRAGMA synchronous=NORMAL", nil, nil, nil)
        mgmtDb = handle
        return true
    }

    func reconnect() {
        sqlite3_close(db); db = nil
        sqlite3_close(mgmtDb); mgmtDb = nil
        _ = openReadonly()
        _ = openReadwrite()
    }

    // ------------------------------------------------------------------
    // MARK: Internal Query Helpers
    // ------------------------------------------------------------------

    /// SELECT on the readonly connection
    private func query(_ sql: String, args: [Any] = []) -> [[String: Any]] {
        queue.sync { executeQuery(db, sql, args: args) }
    }

    /// SELECT on the management (readwrite) connection
    private func mgmtQuery(_ sql: String, args: [Any] = []) -> [[String: Any]] {
        queue.sync { executeQuery(mgmtDb, sql, args: args) }
    }

    /// INSERT / UPDATE / DELETE on the management connection
    @discardableResult
    private func mgmtUpdate(_ sql: String, args: [Any] = []) -> Int {
        queue.sync { executeUpdate(mgmtDb, sql, args: args) }
    }

    /// Last inserted row ID
    private func lastInsertId() -> Int {
        guard let mgmtDb else { return 0 }
        return Int(sqlite3_last_insert_rowid(mgmtDb))
    }

    // ------------------------------------------------------------------
    // MARK: Core SQLite Primitives
    // ------------------------------------------------------------------

    private func executeQuery(_ db: OpaquePointer?, _ sql: String, args: [Any]) -> [[String: Any]] {
        guard let db else { return [] }
        var stmt: OpaquePointer?
        defer { if let s = stmt { sqlite3_finalize(s) } }

        var rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            return []
        }

        bindArgs(stmt, args: args)

        var results: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)
        while true {
            rc = sqlite3_step(stmt)
            if rc == SQLITE_DONE { break }
            guard rc == SQLITE_ROW else { return results }

            var row: [String: Any] = [:]
            for i in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, i))
                switch sqlite3_column_type(stmt, i) {
                case SQLITE_INTEGER: row[name] = Int(sqlite3_column_int64(stmt, i))
                case SQLITE_FLOAT:   row[name] = sqlite3_column_double(stmt, i)
                case SQLITE_TEXT:    if let c = sqlite3_column_text(stmt, i) { row[name] = String(cString: c) }
                case SQLITE_NULL:    row[name] = NSNull()
                default:             if let c = sqlite3_column_text(stmt, i) { row[name] = String(cString: c) }
                }
            }
            results.append(row)
        }
        return results
    }

    @discardableResult
    private func executeUpdate(_ db: OpaquePointer?, _ sql: String, args: [Any]) -> Int {
        guard let db else { return 0 }
        var stmt: OpaquePointer?
        defer { if let s = stmt { sqlite3_finalize(s) } }

        let rc = sqlite3_prepare_v2(db, sql, -1, &stmt, nil)
        guard rc == SQLITE_OK, let stmt else {
            let err = sqlite3_errmsg(db).map { String(cString: $0) } ?? "?"
            NSLog("[AIUsageBar] Update error: \(err)")
            return 0
        }

        bindArgs(stmt, args: args)
        let stepRc = sqlite3_step(stmt)
        return stepRc == SQLITE_DONE ? Int(sqlite3_changes(db)) : 0
    }

    private func bindArgs(_ stmt: OpaquePointer, args: [Any]) {
        for (idx, arg) in args.enumerated() {
            let col = Int32(idx + 1)
            switch arg {
            case let v as String:
                sqlite3_bind_text(stmt, col, v, -1, unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self))
            case let v as Int:
                sqlite3_bind_int64(stmt, col, Int64(v))
            case let v as Double:
                sqlite3_bind_double(stmt, col, v)
            case let v as Bool:
                sqlite3_bind_int(stmt, col, v ? 1 : 0)
            default:
                break
            }
        }
    }

    // ------------------------------------------------------------------
    // MARK: - Management Table Setup
    // ------------------------------------------------------------------

    /// V5 migration: api_usage_records + quota_usage_records + budget_transactions
    static let v5SchemaSQL = """
    CREATE TABLE IF NOT EXISTS api_usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL,
        project TEXT NOT NULL DEFAULT 'unknown',
        session_id TEXT NOT NULL,
        event_uuid TEXT NOT NULL DEFAULT '',
        client TEXT NOT NULL DEFAULT 'claude-code',
        provider TEXT NOT NULL DEFAULT 'deepseek',
        model TEXT NOT NULL DEFAULT 'unknown',
        input_tokens INTEGER DEFAULT 0,
        output_tokens INTEGER DEFAULT 0,
        cache_read_tokens INTEGER DEFAULT 0,
        cache_creation_tokens INTEGER DEFAULT 0,
        input_cost REAL DEFAULT 0,
        output_cost REAL DEFAULT 0,
        cache_cost REAL DEFAULT 0,
        total_cost REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS quota_usage_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        timestamp TEXT NOT NULL DEFAULT '',
        client TEXT NOT NULL,
        provider TEXT NOT NULL,
        plan TEXT NOT NULL DEFAULT '',
        session_id TEXT NOT NULL DEFAULT '',
        project TEXT NOT NULL DEFAULT '',
        model TEXT NOT NULL DEFAULT '',
        quota_used REAL DEFAULT 0,
        quota_limit REAL DEFAULT 0,
        quota_percent REAL DEFAULT 0,
        weekly_used REAL DEFAULT 0,
        weekly_limit REAL DEFAULT 0,
        weekly_percent REAL DEFAULT 0,
        reset_time TEXT DEFAULT '',
        is_estimated INTEGER DEFAULT 0,
        tokens_used REAL DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );
    CREATE TABLE IF NOT EXISTS budget_transactions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        type TEXT NOT NULL,
        amount REAL NOT NULL,
        timestamp TEXT DEFAULT CURRENT_TIMESTAMP,
        note TEXT DEFAULT ''
    );
    """

    /// SQL definitions for all management tables
    static let managementSchemaSQL = """
    CREATE TABLE IF NOT EXISTS model_profiles (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        name       TEXT NOT NULL UNIQUE,
        provider   TEXT NOT NULL,
        model      TEXT NOT NULL,
        base_url   TEXT DEFAULT '',
        client     TEXT DEFAULT 'claude-code',
        env_config TEXT DEFAULT '{}',
        is_active  INTEGER DEFAULT 0,
        created_at TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS provider_configs (
        id                INTEGER PRIMARY KEY AUTOINCREMENT,
        provider          TEXT NOT NULL UNIQUE,
        provider_type     TEXT NOT NULL DEFAULT 'openai-compatible',
        display_name      TEXT DEFAULT '',
        base_url          TEXT DEFAULT '',
        models            TEXT DEFAULT '[]',
        keychain_service  TEXT DEFAULT '',
        is_active         INTEGER DEFAULT 1,
        last_test_status  TEXT DEFAULT '',
        last_test_time    TEXT DEFAULT '',
        created_at        TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS model_pricing (
        id                    INTEGER PRIMARY KEY AUTOINCREMENT,
        provider              TEXT NOT NULL,
        model                 TEXT NOT NULL,
        currency              TEXT DEFAULT 'CNY',
        input_cache_hit_price REAL DEFAULT 0,
        input_cache_miss_price REAL DEFAULT 0,
        output_price          REAL DEFAULT 0,
        is_custom             INTEGER DEFAULT 0,
        updated_at            TEXT DEFAULT CURRENT_TIMESTAMP,
        UNIQUE(provider, model)
    );

    CREATE TABLE IF NOT EXISTS budgets (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        name            TEXT DEFAULT '',
        provider        TEXT NOT NULL DEFAULT '',
        initial_balance REAL NOT NULL,
        currency        TEXT DEFAULT 'CNY',
        period_type     TEXT DEFAULT 'total',
        start_date      TEXT DEFAULT CURRENT_DATE,
        is_active       INTEGER DEFAULT 1,
        created_at      TEXT DEFAULT CURRENT_TIMESTAMP
    );

    CREATE TABLE IF NOT EXISTS api_budget_config (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        initial_balance REAL NOT NULL DEFAULT 0,
        warning_balance REAL NOT NULL DEFAULT 50,
        created_at      TEXT DEFAULT CURRENT_TIMESTAMP
    );
    """

    /// Create management tables if they don't exist. Returns true on success.
    func initializeManagementTables() -> Bool {
        guard mgmtDb != nil else { return false }
        for stmt in (Self.v5SchemaSQL + Self.managementSchemaSQL).components(separatedBy: ";") {
            let trimmed = stmt.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                let rc = sqlite3_exec(mgmtDb, trimmed + ";", nil, nil, nil)
                if rc != SQLITE_OK {
                    let err = sqlite3_errmsg(mgmtDb).map { String(cString: $0) } ?? "?"
                    NSLog("[AIUsageBar] Schema exec error: \(err)")
                }
            }
        }
        return true
    }

    // ================================================================
    // MARK: - Model Profiles CRUD
    // ================================================================

    func loadProfiles() -> [ModelProfile] {
        let rows = mgmtQuery("SELECT * FROM model_profiles ORDER BY is_active DESC, name ASC")
        return rows.map { rowToProfile($0) }
    }

    func getProfile(id: Int) -> ModelProfile? {
        let rows = mgmtQuery("SELECT * FROM model_profiles WHERE id = ?", args: [id])
        return rows.first.map { rowToProfile($0) }
    }

    func getActiveProfile() -> ModelProfile? {
        let rows = mgmtQuery("SELECT * FROM model_profiles WHERE is_active = 1 LIMIT 1")
        return rows.first.map { rowToProfile($0) }
    }

    func saveProfile(_ p: ModelProfile) -> Int {
        if p.id > 0 {
            mgmtUpdate("""
                UPDATE model_profiles SET name=?, provider=?, model=?, base_url=?,
                    client=?, env_config=?, is_active=?
                WHERE id=?
            """, args: [p.name, p.provider, p.model, p.baseUrl, p.client, p.envConfigJSON, p.isActive ? 1 : 0, p.id])
            return p.id
        } else {
            mgmtUpdate("""
                INSERT INTO model_profiles (name, provider, model, base_url, client, env_config, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, args: [p.name, p.provider, p.model, p.baseUrl, p.client, p.envConfigJSON, p.isActive ? 1 : 0])
            return lastInsertId()
        }
    }

    func deleteProfile(id: Int) {
        mgmtUpdate("DELETE FROM model_profiles WHERE id = ?", args: [id])
    }

    func setActiveProfile(id: Int) {
        mgmtUpdate("UPDATE model_profiles SET is_active = 0")
        mgmtUpdate("UPDATE model_profiles SET is_active = 1 WHERE id = ?", args: [id])
    }

    private func rowToProfile(_ r: [String: Any]) -> ModelProfile {
        ModelProfile(
            id: r["id"] as? Int ?? 0,
            name: r["name"] as? String ?? "",
            provider: r["provider"] as? String ?? "",
            model: r["model"] as? String ?? "",
            baseUrl: r["base_url"] as? String ?? "",
            client: r["client"] as? String ?? "claude-code",
            envConfigJSON: r["env_config"] as? String ?? "{}",
            isActive: (r["is_active"] as? Int ?? 0) != 0,
            createdAt: r["created_at"] as? String ?? ""
        )
    }

    // ================================================================
    // MARK: - Provider Configs CRUD
    // ================================================================

    func loadProviders() -> [ProviderConfig] {
        let rows = mgmtQuery("SELECT * FROM provider_configs ORDER BY provider ASC")
        return rows.map { rowToProvider($0) }
    }

    func getProvider(name: String) -> ProviderConfig? {
        let rows = mgmtQuery("SELECT * FROM provider_configs WHERE provider = ?", args: [name])
        return rows.first.map { rowToProvider($0) }
    }

    func saveProvider(_ p: ProviderConfig) -> Int {
        if let existing = getProvider(name: p.provider), existing.id > 0 {
            mgmtUpdate("""
                UPDATE provider_configs SET provider_type=?, display_name=?, base_url=?,
                    models=?, keychain_service=?, is_active=?
                WHERE provider=?
            """, args: [p.providerType, p.displayName, p.baseUrl, p.modelsJSON, p.keychainService, p.isActive ? 1 : 0, p.provider])
            return existing.id
        } else {
            mgmtUpdate("""
                INSERT INTO provider_configs (provider, provider_type, display_name, base_url, models, keychain_service, is_active)
                VALUES (?, ?, ?, ?, ?, ?, ?)
            """, args: [p.provider, p.providerType, p.displayName, p.baseUrl, p.modelsJSON, p.keychainService, p.isActive ? 1 : 0])
            return lastInsertId()
        }
    }

    func updateProviderTestStatus(provider: String, status: String) {
        mgmtUpdate("UPDATE provider_configs SET last_test_status=?, last_test_time=datetime('now') WHERE provider=?",
                    args: [status, provider])
    }

    func deleteProvider(name: String) {
        mgmtUpdate("DELETE FROM provider_configs WHERE provider = ?", args: [name])
    }

    private func rowToProvider(_ r: [String: Any]) -> ProviderConfig {
        ProviderConfig(
            id: r["id"] as? Int ?? 0,
            provider: r["provider"] as? String ?? "",
            providerType: r["provider_type"] as? String ?? "openai-compatible",
            displayName: r["display_name"] as? String ?? "",
            baseUrl: r["base_url"] as? String ?? "",
            modelsJSON: r["models"] as? String ?? "[]",
            keychainService: r["keychain_service"] as? String ?? "",
            isActive: (r["is_active"] as? Int ?? 0) != 0,
            lastTestStatus: r["last_test_status"] as? String ?? "",
            lastTestTime: r["last_test_time"] as? String ?? "",
            createdAt: r["created_at"] as? String ?? ""
        )
    }

    // ================================================================
    // MARK: - Model Pricing CRUD
    // ================================================================

    func loadPricing() -> [ModelPricing] {
        let rows = mgmtQuery("SELECT * FROM model_pricing ORDER BY provider, model")
        return rows.map { rowToPricing($0) }
    }

    func getPricing(provider: String, model: String) -> ModelPricing? {
        let rows = mgmtQuery("SELECT * FROM model_pricing WHERE provider = ? AND model = ?", args: [provider, model])
        return rows.first.map { rowToPricing($0) }
    }

    func savePricing(_ p: ModelPricing) {
        mgmtUpdate("""
            INSERT INTO model_pricing (provider, model, currency, input_cache_hit_price, input_cache_miss_price, output_price, is_custom)
            VALUES (?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(provider, model) DO UPDATE SET
                currency=?,
                input_cache_hit_price=?,
                input_cache_miss_price=?,
                output_price=?,
                is_custom=?,
                updated_at=datetime('now')
        """, args: [
            p.provider, p.model, p.currency,
            p.inputCacheHitPrice, p.inputCacheMissPrice, p.outputPrice,
            p.isCustom ? 1 : 0,
            p.currency,
            p.inputCacheHitPrice, p.inputCacheMissPrice, p.outputPrice,
            p.isCustom ? 1 : 0,
        ])
    }

    func deletePricing(provider: String, model: String) {
        mgmtUpdate("DELETE FROM model_pricing WHERE provider = ? AND model = ?", args: [provider, model])
    }

    func importPricingFromJSON(_ items: [[String: Any]]) {
        for item in items {
            let prov = item["provider"] as? String ?? ""
            let mod = item["model"] as? String ?? ""
            if prov.isEmpty || mod.isEmpty { continue }
            let existingIsCustom = getPricing(provider: prov, model: mod)?.isCustom ?? false
            if existingIsCustom { continue } // 不覆盖用户自定义
            mgmtUpdate("""
                INSERT INTO model_pricing (provider, model, currency, input_cache_hit_price, input_cache_miss_price, output_price, is_custom)
                VALUES (?, ?, ?, ?, ?, ?, 0)
                ON CONFLICT(provider, model) DO NOTHING
            """, args: [
                prov, mod,
                item["currency"] as? String ?? "CNY",
                item["input_cache_hit_price"] as? Double ?? 0,
                item["input_cache_miss_price"] as? Double ?? 0,
                item["output_price"] as? Double ?? 0,
            ])
        }
    }

    private func rowToPricing(_ r: [String: Any]) -> ModelPricing {
        ModelPricing(
            id: r["id"] as? Int ?? 0,
            provider: r["provider"] as? String ?? "",
            model: r["model"] as? String ?? "",
            currency: r["currency"] as? String ?? "CNY",
            inputCacheHitPrice: r["input_cache_hit_price"] as? Double ?? 0,
            inputCacheMissPrice: r["input_cache_miss_price"] as? Double ?? 0,
            outputPrice: r["output_price"] as? Double ?? 0,
            isCustom: (r["is_custom"] as? Int ?? 0) != 0,
            updatedAt: r["updated_at"] as? String ?? ""
        )
    }

    // ================================================================
    // MARK: - API Cost History (v3.0 — 7 天趋势，时区安全)
    // ================================================================

    /// 最近 N 天的 API 每日成本（从 api_usage_records）
    func apiDailyCostHistory(days: Int = 7) -> [(date: String, cost: Double, tokens: Int)] {
        var results: [(String, Double, Int)] = []
        let localDates = Self.lastNLocalDates(days)

        for date in localDates {
            let range = Self.localDayRange(date)
            let sql = """
                SELECT COALESCE(SUM(total_cost), 0) AS cost,
                       COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
                FROM api_usage_records
                WHERE timestamp >= ? AND timestamp < ?
            """
            let rows = query(sql, args: [range.startTimestamp, range.endTimestamp])
            if let row = rows.first {
                let ds = dateToDateString(date)
                results.append((
                    ds,
                    row["cost"] as? Double ?? 0,
                    row["tokens"] as? Int ?? 0
                ))
            }
        }
        return results
    }

    // MARK: Swift 本地时区范围查询 (v3.3)

    /// 今日 API 统计（Swift 当前时区生成日期边界，数据库 timestamp 保持原格式）
    func apiTodayStatsSQL() -> (cost: Double, inputTokens: Int, outputTokens: Int, requests: Int) {
        let range = Self.localDayRange(Date())
        let rows = query("""
            SELECT
                COALESCE(SUM(total_cost), 0) AS cost,
                COALESCE(SUM(input_tokens), 0) AS input_tokens,
                COALESCE(SUM(output_tokens), 0) AS output_tokens,
                COUNT(*) AS requests
            FROM api_usage_records
            WHERE timestamp >= ? AND timestamp < ?
        """, args: [range.startTimestamp, range.endTimestamp])
        guard let row = rows.first else {
            return (0, 0, 0, 0)
        }
        return (
            cost: row["cost"] as? Double ?? 0,
            inputTokens: row["input_tokens"] as? Int ?? 0,
            outputTokens: row["output_tokens"] as? Int ?? 0,
            requests: row["requests"] as? Int ?? 0
        )
    }

    /// 最近 N 天 API 每日成本（Swift 当前时区逐日范围查询）
    func apiDailyCostHistorySQL(days: Int = 7) -> [(date: String, cost: Double, tokens: Int)] {
        Self.lastNLocalDates(days).map { date in
            let range = Self.localDayRange(date)
            let rows = query("""
                SELECT
                    COALESCE(SUM(total_cost), 0) AS cost,
                    COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
                FROM api_usage_records
                WHERE timestamp >= ? AND timestamp < ?
            """, args: [range.startTimestamp, range.endTimestamp])
            let row = rows.first ?? [:]
            return (
                dateToDateString(date),
                row["cost"] as? Double ?? 0,
                row["tokens"] as? Int ?? 0
            )
        }
    }

    /// 各 Agent 最后活跃时间（从 api_usage_records）
    func apiLatestActivityByClient() -> [(client: String, lastActive: String, provider: String)] {
        let rows = query("""
            SELECT
                client,
                MAX(timestamp) AS last_active,
                provider
            FROM api_usage_records
            GROUP BY client
        """)
        return rows.map {
            (
                $0["client"] as? String ?? "",
                $0["last_active"] as? String ?? "",
                $0["provider"] as? String ?? ""
            )
        }
    }

    // ================================================================
    // ================================================================
    // MARK: - V5 Agent Usage Queries
    // ================================================================

    // MARK: Cost Summary (v1.6.0 — 时间语义分层)

    struct CostSummary {
        let todayCost: Double
        let monthCost: Double
        let totalCost: Double
        let todayRequests: Int
    }

    /// 分层成本统计：今日 / 本月 / 累计（v3.0 — 本地时区 → UTC 查询）
    func apiCostSummary() -> CostSummary {
        let todayRange = Self.localDayRange(Date())
        let monthRange = Self.localMonthRange(Date())

        let rows = query("""
            SELECT
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN total_cost ELSE 0 END), 0) AS today_cost,
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN total_cost ELSE 0 END), 0) AS month_cost,
                COALESCE(SUM(total_cost), 0) AS total_cost,
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN 1 ELSE 0 END), 0) AS today_requests
            FROM api_usage_records
        """, args: [
            todayRange.startTimestamp, todayRange.endTimestamp,
            monthRange.startTimestamp, monthRange.endTimestamp,
            todayRange.startTimestamp, todayRange.endTimestamp,
        ])

        guard let row = rows.first else {
            return CostSummary(todayCost: 0, monthCost: 0, totalCost: 0, todayRequests: 0)
        }
        return CostSummary(
            todayCost: row["today_cost"] as? Double ?? 0,
            monthCost: row["month_cost"] as? Double ?? 0,
            totalCost: row["total_cost"] as? Double ?? 0,
            todayRequests: row["today_requests"] as? Int ?? 0
        )
    }
    /// 时区安全的成本统计：截至当前时刻（非全天/整月）
    ///
    /// - today:  本地 00:00 ~ 当前时刻
    /// - month:  本月 1 日 00:00 ~ 当前时刻
    /// - total:  全部
    func apiCostSummaryToNow(now: Date = Date()) -> (todayCost: Double, todayTokens: Int, todayRequests: Int, monthCost: Double, totalCost: Double) {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: now)
        guard let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: now)) else {
            return (0, 0, 0, 0, 0)
        }

        let startToday = Self.databaseTimestampString(startOfDay)
        let startMonth = Self.databaseTimestampString(startOfMonth)
        let nowTimestamp = Self.databaseTimestampString(now)

        let rows = query("""
            SELECT
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN total_cost ELSE 0 END), 0) AS today_cost,
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN total_cost ELSE 0 END), 0) AS month_cost,
                COALESCE(SUM(total_cost), 0) AS total_cost,
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN 1 ELSE 0 END), 0) AS today_requests,
                COALESCE(SUM(CASE WHEN timestamp >= ? AND timestamp < ? THEN input_tokens + output_tokens ELSE 0 END), 0) AS today_tokens
            FROM api_usage_records
        """, args: [
            startToday, nowTimestamp,
            startMonth, nowTimestamp,
            startToday, nowTimestamp,
            startToday, nowTimestamp,
        ])

        guard let row = rows.first else {
            return (0, 0, 0, 0, 0)
        }
        return (
            todayCost: row["today_cost"] as? Double ?? 0,
            todayTokens: row["today_tokens"] as? Int ?? 0,
            todayRequests: row["today_requests"] as? Int ?? 0,
            monthCost: row["month_cost"] as? Double ?? 0,
            totalCost: row["total_cost"] as? Double ?? 0
        )
    }

    /// 本周 API 成本（周一 00:00 至当前时刻）
    func apiWeekCostToNow(now: Date = Date()) -> Double {
        let cal = Calendar.current
        guard let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)) else {
            return 0
        }
        let rows = query("""
            SELECT COALESCE(SUM(total_cost), 0) AS cost
            FROM api_usage_records
            WHERE timestamp >= ? AND timestamp < ?
        """, args: [Self.databaseTimestampString(weekStart), Self.databaseTimestampString(now)])
        return (rows.first?["cost"] as? Double) ?? 0
    }


    /// API-only today summary (v3.0 — 时区安全 UTC 范围查询)
    func apiTodaySummary() -> TodaySummary {
        let range = Self.localDayRange(Date())
        let rows = query("""
            SELECT COALESCE(SUM(total_cost), 0) AS total_cost,
                   COUNT(*) AS request_count,
                   COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
            FROM api_usage_records
            WHERE timestamp >= ? AND timestamp < ?
        """, args: [range.startTimestamp, range.endTimestamp])
        guard let row = rows.first else {
            return TodaySummary(totalCost: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0, requestCount: 0)
        }
        return TodaySummary(
            totalCost: row["total_cost"] as? Double ?? 0,
            inputTokens: (row["tokens"] as? Int ?? 0) / 2,
            outputTokens: (row["tokens"] as? Int ?? 0) / 2,
            cacheTokens: 0,
            requestCount: row["request_count"] as? Int ?? 0
        )
    }

    /// API total stats (from api_usage_records)
    func apiTotalStats() -> TotalStats {
        let rows = query("""
            SELECT COALESCE(SUM(total_cost), 0) AS total_cost,
                   COALESCE(SUM(input_tokens + output_tokens), 0) AS total_tokens,
                   COUNT(*) AS total_requests
            FROM api_usage_records
        """)
        guard let row = rows.first else {
            return TotalStats(totalCost: 0, totalInput: 0, totalOutput: 0, totalCacheRead: 0, totalRequests: 0, totalSessions: 0, totalProjects: 0)
        }
        return TotalStats(
            totalCost: row["total_cost"] as? Double ?? 0,
            totalInput: row["total_tokens"] as? Int ?? 0,
            totalOutput: 0,
            totalCacheRead: 0,
            totalRequests: row["total_requests"] as? Int ?? 0,
            totalSessions: 0,
            totalProjects: 0
        )
    }

    /// Subscription stats (from quota_usage_records)
    func subscriptionStats() -> (sessions: Int, totalTokens: Double, providers: [String]) {
        let rows = query("""
            SELECT COUNT(*) AS sessions,
                   COALESCE(SUM(CASE WHEN tokens_used > 0 THEN tokens_used ELSE quota_used END), 0) AS total_tokens,
                   GROUP_CONCAT(DISTINCT provider) AS providers
            FROM quota_usage_records
        """)
        guard let row = rows.first else { return (0, 0, []) }
        let provs = (row["providers"] as? String ?? "").split(separator: ",").map(String.init)
        return (
            row["sessions"] as? Int ?? 0,
            row["total_tokens"] as? Double ?? 0,
            provs
        )
    }

    /// API model breakdown (from api_usage_records, cost only)
    func apiModelBreakdown() -> [(model: String, cost: Double, tokens: Int)] {
        let rows = query("""
            SELECT model,
                   COALESCE(SUM(total_cost), 0) AS total_cost,
                   COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
            FROM api_usage_records
            GROUP BY model
            ORDER BY total_cost DESC
        """)
        return rows.map {
            ($0["model"] as? String ?? "unknown",
             $0["total_cost"] as? Double ?? 0,
             $0["tokens"] as? Int ?? 0)
        }
    }

    /// Subscription model breakdown (from quota_usage_records, tokens only, no cost)
    func subscriptionModelBreakdown() -> [(model: String, sessions: Int, tokens: Double)] {
        let rows = query("""
            SELECT model,
                   COUNT(*) AS sessions,
                   COALESCE(SUM(CASE WHEN tokens_used > 0 THEN tokens_used ELSE quota_used END), 0) AS total_tokens
            FROM quota_usage_records
            GROUP BY model
            ORDER BY total_tokens DESC
        """)
        return rows.map {
            ($0["model"] as? String ?? "unknown",
             $0["sessions"] as? Int ?? 0,
             $0["total_tokens"] as? Double ?? 0)
        }
    }

    /// API usage by client (from api_usage_records)
    func apiUsageByClient() -> [(client: String, provider: String, cost: Double, tokens: Int)] {
        let rows = query("""
            SELECT client, provider,
                   COALESCE(SUM(total_cost), 0) AS cost,
                   COALESCE(SUM(input_tokens + output_tokens), 0) AS tokens
            FROM api_usage_records
            GROUP BY client, provider
            ORDER BY cost DESC
        """)
        return rows.map {
            ($0["client"] as? String ?? "unknown",
             $0["provider"] as? String ?? "unknown",
             $0["cost"] as? Double ?? 0,
             $0["tokens"] as? Int ?? 0)
        }
    }

    /// Quota usage (per client)
    func quotaUsageByClient() -> [(client: String, provider: String, sessions: Int, totalTokens: Double, estimated: Bool)] {
        let rows = query("""
            SELECT client, provider,
                   COUNT(*) AS sessions,
                   COALESCE(SUM(CASE WHEN tokens_used > 0 THEN tokens_used ELSE quota_used END), 0) AS total_tokens,
                   MAX(is_estimated) AS estimated
            FROM quota_usage_records
            GROUP BY client, provider
            ORDER BY total_tokens DESC
        """)
        return rows.map {
            ($0["client"] as? String ?? "unknown",
             $0["provider"] as? String ?? "unknown",
             $0["sessions"] as? Int ?? 0,
             $0["total_tokens"] as? Double ?? 0,
             ($0["estimated"] as? Int ?? 0) != 0)
        }
    }

    /// All agent usage unified (for AgentUsageView)
    func loadAgentUsages() -> [AgentResource] {
        var agents: [AgentResource] = []

        // 1. API clients (from api_usage_records)
        for row in apiUsageByClient() {
            agents.append(AgentResource(
                client: row.client,
                provider: row.provider,
                usageType: .apiCost,
                cost: row.cost,
                inputTokens: row.tokens,
                outputTokens: 0,
                quotaUsed: nil,
                quotaLimit: nil,
                resetTime: nil,
                isEstimated: false
            ))
        }

        // 2. Subscription clients (from quota_usage_records)
        for row in quotaUsageByClient() {
            agents.append(AgentResource(
                client: row.client,
                provider: row.provider,
                usageType: .subscriptionQuota,
                cost: nil,
                inputTokens: Int(row.totalTokens),
                outputTokens: 0,
                quotaUsed: nil,
                quotaLimit: nil,
                resetTime: nil,
                isEstimated: row.estimated
            ))
        }

        return agents
    }

    // MARK: - Existing Reading Queries (unchanged)
    // ================================================================

    func recordCount() -> Int {
        let rows = query("SELECT COUNT(*) AS cnt FROM usage_records")
        return (rows.first?["cnt"] as? Int) ?? 0
    }

    struct TodaySummary {
        let totalCost: Double
        let inputTokens: Int
        let outputTokens: Int
        let cacheTokens: Int
        let requestCount: Int
    }

    func todaySummary() -> TodaySummary {
        let range = Self.localDayRange(Date())
        let sql = """
            SELECT COALESCE(SUM(total_cost), 0) AS total_cost,
                   COALESCE(SUM(input_tokens), 0) AS input_tokens,
                   COALESCE(SUM(output_tokens), 0) AS output_tokens,
                   COALESCE(SUM(cache_read_tokens + cache_creation_tokens), 0) AS cache_tokens,
                   COUNT(*) AS request_count
            FROM usage_records
            WHERE timestamp >= ? AND timestamp < ?
        """
        let rows = query(sql, args: [range.startTimestamp, range.endTimestamp])
        guard let row = rows.first else {
            return TodaySummary(totalCost: 0, inputTokens: 0, outputTokens: 0, cacheTokens: 0, requestCount: 0)
        }
        return TodaySummary(
            totalCost: row["total_cost"] as? Double ?? 0,
            inputTokens: row["input_tokens"] as? Int ?? 0,
            outputTokens: row["output_tokens"] as? Int ?? 0,
            cacheTokens: row["cache_tokens"] as? Int ?? 0,
            requestCount: row["request_count"] as? Int ?? 0
        )
    }

    func projectBreakdown() -> [ProjectCost] {
        let rows = query("""
            SELECT project, SUM(total_cost) AS total_cost,
                   SUM(input_tokens) AS input_tokens,
                   SUM(output_tokens) AS output_tokens,
                   SUM(cache_read_tokens + cache_creation_tokens) AS cache_tokens,
                   COUNT(DISTINCT session_id) AS session_count,
                   COUNT(*) AS request_count
            FROM usage_records GROUP BY project ORDER BY total_cost DESC
        """)
        let total = rows.reduce(0.0) { $0 + ($1["total_cost"] as? Double ?? 0) }
        return rows.map {
            let cost = $0["total_cost"] as? Double ?? 0
            return ProjectCost(
                name: $0["project"] as? String ?? "unknown",
                totalCost: cost,
                inputTokens: $0["input_tokens"] as? Int ?? 0,
                outputTokens: $0["output_tokens"] as? Int ?? 0,
                cacheTokens: $0["cache_tokens"] as? Int ?? 0,
                sessionCount: $0["session_count"] as? Int ?? 0,
                requestCount: $0["request_count"] as? Int ?? 0,
                fraction: total > 0 ? cost / total : 0
            )
        }
    }

    // MARK: Provider Breakdown (from model → provider mapping)

    func providerBreakdown() -> [(String, Double)] {
        let rows = query("""
            SELECT model, SUM(total_cost) AS total_cost
            FROM usage_records GROUP BY model ORDER BY total_cost DESC
        """)
        var provMap: [String: Double] = [:]
        for r in rows {
            let model = r["model"] as? String ?? ""
            let cost = r["total_cost"] as? Double ?? 0
            let prov: String
            if model.contains("deepseek") { prov = "deepseek" }
            else if model.contains("gpt") || model.contains("o1") || model.contains("o3") { prov = "openai" }
            else if model.contains("claude") || model.contains("anthropic") { prov = "anthropic" }
            else { prov = "other" }
            provMap[prov, default: 0] += cost
        }
        return provMap.sorted { $0.value > $1.value }.map { ($0.key, $0.value) }
    }

    func modelBreakdown() -> [ModelBreakdown] {
        let rows = query("""
            SELECT model, SUM(total_cost) AS total_cost,
                   SUM(input_tokens) AS input_tokens,
                   SUM(output_tokens) AS output_tokens,
                   COUNT(*) AS request_count
            FROM usage_records GROUP BY model ORDER BY total_cost DESC
        """)
        return rows.map {
            ModelBreakdown(
                model: $0["model"] as? String ?? "unknown",
                totalCost: $0["total_cost"] as? Double ?? 0,
                inputTokens: $0["input_tokens"] as? Int ?? 0,
                outputTokens: $0["output_tokens"] as? Int ?? 0,
                requestCount: $0["request_count"] as? Int ?? 0
            )
        }
    }

    func dailyTrend(days: Int = 7) -> [DailySummary] {
        var results: [DailySummary] = []
        let localDates = Self.lastNLocalDates(days)
        for date in localDates {
            let range = Self.localDayRange(date)
            let sql = """
                SELECT COALESCE(SUM(total_cost), 0) AS total_cost,
                       COALESCE(SUM(input_tokens), 0) AS input_tokens,
                       COALESCE(SUM(output_tokens), 0) AS output_tokens,
                       COALESCE(SUM(cache_read_tokens + cache_creation_tokens), 0) AS cache_tokens,
                       COUNT(*) AS request_count
                FROM usage_records
                WHERE timestamp >= ? AND timestamp < ?
            """
            let rows = query(sql, args: [range.startTimestamp, range.endTimestamp])
            if let row = rows.first {
                let ds = dateToDateString(date)
                results.append(DailySummary(
                    date: ds,
                    totalCost: row["total_cost"] as? Double ?? 0,
                    inputTokens: row["input_tokens"] as? Int ?? 0,
                    outputTokens: row["output_tokens"] as? Int ?? 0,
                    cacheTokens: row["cache_tokens"] as? Int ?? 0,
                    requestCount: row["request_count"] as? Int ?? 0
                ))
            }
        }
        return results
    }

    func totalStats() -> TotalStats {
        let rows = query("""
            SELECT COALESCE(SUM(total_cost), 0) AS total_cost,
                   COALESCE(SUM(input_tokens), 0) AS total_input,
                   COALESCE(SUM(output_tokens), 0) AS total_output,
                   COALESCE(SUM(cache_read_tokens + cache_creation_tokens), 0) AS total_cache,
                   COUNT(*) AS total_requests,
                   COUNT(DISTINCT session_id) AS total_sessions,
                   COUNT(DISTINCT project) AS total_projects
            FROM usage_records
        """)
        guard let row = rows.first else {
            return TotalStats(totalCost: 0, totalInput: 0, totalOutput: 0, totalCacheRead: 0, totalRequests: 0, totalSessions: 0, totalProjects: 0)
        }
        return TotalStats(
            totalCost: row["total_cost"] as? Double ?? 0,
            totalInput: row["total_input"] as? Int ?? 0,
            totalOutput: row["total_output"] as? Int ?? 0,
            totalCacheRead: row["total_cache"] as? Int ?? 0,
            totalRequests: row["total_requests"] as? Int ?? 0,
            totalSessions: row["total_sessions"] as? Int ?? 0,
            totalProjects: row["total_projects"] as? Int ?? 0
        )
    }

    func dbStatus() -> DBStatus {
        let cnt = recordCount()
        return DBStatus(recordCount: cnt, hasData: cnt > 0, path: dbPath, lastUpdate: nil)
    }

    // MARK: Cost Range (v3.0 — 时区安全)

    /// 本地日期范围映射为 UTC 时间戳字符串
    struct CostRange {
        let startTimestamp: String   // e.g. "2026-07-09T16:00:00Z"
        let endTimestamp: String     // e.g. "2026-07-10T16:00:00Z"
    }

    /// 本地本月 → 数据库 timestamp 范围
    static func localMonthRange(_ date: Date) -> CostRange {
        var cal = Calendar.current
        cal.timeZone = .current
        let startOfMonth = cal.date(from: cal.dateComponents([.year, .month], from: date))!
        let endOfMonth = cal.date(byAdding: .month, value: 1, to: startOfMonth)!
        return CostRange(
            startTimestamp: databaseTimestampString(startOfMonth),
            endTimestamp: databaseTimestampString(endOfMonth)
        )
    }

    /// 本地某天 → 数据库 timestamp 范围
    static func localDayRange(_ date: Date) -> CostRange {
        var cal = Calendar.current
        cal.timeZone = .current
        let startOfDay = cal.startOfDay(for: date)
        let endOfDay = cal.date(byAdding: .day, value: 1, to: startOfDay)!
        return CostRange(
            startTimestamp: databaseTimestampString(startOfDay),
            endTimestamp: databaseTimestampString(endOfDay)
        )
    }

    /// 最近 N 天的本地日期集合
    static func lastNLocalDates(_ days: Int) -> [Date] {
        let cal = Calendar.current
        let today = Date()
        var dates: [Date] = []
        for offset in (0..<days).reversed() {
            if let date = cal.date(byAdding: .day, value: -offset, to: today) {
                dates.append(date)
            }
        }
        return dates
    }

    static let utcDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(abbreviation: "UTC")!
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
        return f
    }()

    static func databaseTimestampString(_ date: Date) -> String {
        utcDateFormatter.string(from: date)
    }

    // MARK: Helpers (legacy — kept for non-date queries)

    private func todayDateString() -> String { dateToDateString(Date()) }

    private func monthDateString() -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM"
        return fmt.string(from: Date())
    }

    private func dateToDateString(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.string(from: date)
    }

    private func parseDate(_ value: String) -> Date? {
        guard !value.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: value) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        for pattern in ["yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd"] {
            formatter.dateFormat = pattern
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }
}
