import Foundation
import SQLite3

// MARK: - Codex Usage Scanner

final class CodexUsageScanner: @unchecked Sendable {
    private let statePaths: [String]
    private let queue = DispatchQueue(label: "com.a1.ai-usage-bar.codex-usage", qos: .utility)

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

    func scan() -> CodexUsageSnapshot {
        queue.sync {
            for path in statePaths where FileManager.default.fileExists(atPath: path) {
                if let snapshot = scan(path: path) {
                    return snapshot
                }
            }
            return CodexUsageSnapshot(sessions: 0, totalTokens: 0, models: [])
        }
    }

    private func scan(path: String) -> CodexUsageSnapshot? {
        var db: OpaquePointer?
        guard sqlite3_open_v2(path, &db, SQLITE_OPEN_READONLY, nil) == SQLITE_OK, let db else {
            return nil
        }
        defer { sqlite3_close(db) }

        guard tableExists(db, table: "threads") else {
            return nil
        }

        let total = queryOne(db, sql: """
            SELECT COUNT(*) AS sessions,
                   COALESCE(SUM(tokens_used), 0) AS total_tokens
            FROM threads
            WHERE tokens_used > 0
        """)

        let modelRows = queryRows(db, sql: """
            SELECT COALESCE(NULLIF(model, ''), 'unknown') AS model,
                   COUNT(*) AS sessions,
                   COALESCE(SUM(tokens_used), 0) AS total_tokens
            FROM threads
            WHERE tokens_used > 0
            GROUP BY COALESCE(NULLIF(model, ''), 'unknown')
            ORDER BY total_tokens DESC
        """)

        let models = modelRows.map {
            (
                model: $0["model"] as? String ?? "unknown",
                sessions: $0["sessions"] as? Int ?? 0,
                tokens: $0["total_tokens"] as? Double ?? 0
            )
        }

        return CodexUsageSnapshot(
            sessions: total["sessions"] as? Int ?? 0,
            totalTokens: total["total_tokens"] as? Double ?? 0,
            models: models
        )
    }

    private func tableExists(_ db: OpaquePointer, table: String) -> Bool {
        var stmt: OpaquePointer?
        defer { if let stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, "SELECT 1 FROM sqlite_master WHERE type='table' AND name=? LIMIT 1", -1, &stmt, nil) == SQLITE_OK else {
            return false
        }
        sqlite3_bind_text(stmt, 1, table, -1, unsafeBitCast(OpaquePointer(bitPattern: -1), to: sqlite3_destructor_type.self))
        return sqlite3_step(stmt) == SQLITE_ROW
    }

    private func queryOne(_ db: OpaquePointer, sql: String) -> [String: Any] {
        queryRows(db, sql: sql).first ?? [:]
    }

    private func queryRows(_ db: OpaquePointer, sql: String) -> [[String: Any]] {
        var stmt: OpaquePointer?
        defer { if let stmt { sqlite3_finalize(stmt) } }
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            return []
        }

        var rows: [[String: Any]] = []
        let colCount = sqlite3_column_count(stmt)
        while sqlite3_step(stmt) == SQLITE_ROW {
            var row: [String: Any] = [:]
            for idx in 0..<colCount {
                let name = String(cString: sqlite3_column_name(stmt, idx))
                switch sqlite3_column_type(stmt, idx) {
                case SQLITE_INTEGER:
                    row[name] = Int(sqlite3_column_int64(stmt, idx))
                case SQLITE_FLOAT:
                    row[name] = sqlite3_column_double(stmt, idx)
                case SQLITE_TEXT:
                    if let text = sqlite3_column_text(stmt, idx) {
                        row[name] = String(cString: text)
                    }
                default:
                    break
                }
            }
            rows.append(row)
        }
        return rows
    }
}
