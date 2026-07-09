import Foundation
import SQLite3

// MARK: - Codex Quota Service

/// Reads Codex subscription quota status when Codex exposes real quota fields.
///
/// Important: this service never derives quota percent from tokens_used. The current
/// Codex state database only contains token/model/session data, so it returns
/// `.unavailable` until real session/weekly quota fields exist.
final class CodexQuotaService {
    private let statePaths: [String]
    private let queue = DispatchQueue(label: "com.a1.ai-usage-bar.codex-quota", qos: .utility)

    init(statePaths: [String]? = nil) {
        if let statePaths {
            self.statePaths = statePaths
        } else {
            let home = NSHomeDirectory()
            self.statePaths = [
                "\(home)/.codex/state_5.sqlite",
                "\(home)/.codex/sqlite/state_5.sqlite",
            ]
        }
    }

    func fetchStatus() -> CodexQuotaStatus {
        queue.sync {
            for path in statePaths where FileManager.default.fileExists(atPath: path) {
                if let status = readQuotaStatus(from: path) {
                    return status
                }
            }
            return .unavailable
        }
    }

    private func readQuotaStatus(from path: String) -> CodexQuotaStatus? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }

        for table in tableNames(db) {
            let columns = Set(columnNames(db, table: table))
            guard columns.contains("session_used_percent"),
                  columns.contains("session_remaining_percent"),
                  columns.contains("session_reset_time"),
                  columns.contains("weekly_used_percent"),
                  columns.contains("weekly_remaining_percent"),
                  columns.contains("weekly_reset_time") else {
                continue
            }

            let sql = """
                SELECT session_used_percent, session_remaining_percent, session_reset_time,
                       weekly_used_percent, weekly_remaining_percent, weekly_reset_time
                FROM \(quoteIdentifier(table))
                ORDER BY rowid DESC
                LIMIT 1
            """
            if let status = queryQuotaRow(db, sql: sql) {
                return status
            }
        }

        return nil
    }

    private func queryQuotaRow(_ db: OpaquePointer, sql: String) -> CodexQuotaStatus? {
        var stmt: OpaquePointer?
        defer { if let stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return nil
        }
        guard sqlite3_step(stmt) == SQLITE_ROW else {
            return nil
        }

        let sessionUsed = sqlite3_column_double(stmt, 0)
        let sessionRemaining = sqlite3_column_double(stmt, 1)
        let sessionReset = stringColumn(stmt, index: 2).flatMap(parseDate)
        let weeklyUsed = sqlite3_column_double(stmt, 3)
        let weeklyRemaining = sqlite3_column_double(stmt, 4)
        let weeklyReset = stringColumn(stmt, index: 5).flatMap(parseDate)

        guard sessionReset != nil, weeklyReset != nil else {
            return nil
        }

        return CodexQuotaStatus(
            sessionUsedPercent: clampPercent(sessionUsed),
            sessionRemainingPercent: clampPercent(sessionRemaining),
            sessionResetTime: sessionReset,
            weeklyUsedPercent: clampPercent(weeklyUsed),
            weeklyRemainingPercent: clampPercent(weeklyRemaining),
            weeklyResetTime: weeklyReset,
            isAvailable: true
        )
    }

    private func tableNames(_ db: OpaquePointer) -> [String] {
        let sql = "SELECT name FROM sqlite_master WHERE type='table'"
        var stmt: OpaquePointer?
        defer { if let stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return []
        }

        var names: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = stringColumn(stmt, index: 0) {
                names.append(name)
            }
        }
        return names
    }

    private func columnNames(_ db: OpaquePointer, table: String) -> [String] {
        let sql = "PRAGMA table_info(\(quoteIdentifier(table)))"
        var stmt: OpaquePointer?
        defer { if let stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return []
        }

        var names: [String] = []
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let name = stringColumn(stmt, index: 1) {
                names.append(name)
            }
        }
        return names
    }

    private func quoteIdentifier(_ value: String) -> String {
        "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private func stringColumn(_ stmt: OpaquePointer, index: Int32) -> String? {
        guard sqlite3_column_type(stmt, index) != SQLITE_NULL,
              let cString = sqlite3_column_text(stmt, index) else {
            return nil
        }
        return String(cString: cString)
    }

    private func clampPercent(_ value: Double) -> Double {
        min(max(value, 0), 100)
    }

    private func parseDate(_ value: String) -> Date? {
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
