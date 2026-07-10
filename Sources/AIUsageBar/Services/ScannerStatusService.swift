import Foundation

// MARK: - Pipeline Health

/// 数据管道健康状态
enum PipelineHealth: String, Codable {
    case healthy    // scanner 运行、最近扫描 < 2min
    case warning    // scanner 运行、超过 2min 未扫描
    case error      // scanner 存在但解析失败
    case offline    // daemon 不存在
}

// MARK: - Scanner Status

/// scanner_status.json 解析结构
struct ScannerStatus: Codable {
    var running: Bool
    var pid: Int?
    var lastScanTime: String?
    var lastInsertCount: Int
    var lastError: String?
    var filesScanned: Int
    var projects: Int?

    enum CodingKeys: String, CodingKey {
        case running
        case pid
        case lastScanTime = "last_scan_time"
        case lastInsertCount = "last_insert_count"
        case lastError = "last_error"
        case filesScanned = "files_scanned"
        case projects
    }

    /// 增强的日期解析：支持多种时间格式
    var lastScanDate: Date? {
        guard let ts = lastScanTime, !ts.isEmpty else { return nil }

        // 1. ISO8601 标准格式（含小数秒）：2026-07-10T09:45:05.123Z
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: ts) { return d }

        // 2. ISO8601 无小数秒：2026-07-10T09:45:05Z 或 2026-07-10T09:45:05
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: ts) { return d }
        // 去除尾部 Z 再试
        let strippedZ = ts.hasSuffix("Z") ? String(ts.dropLast()) : ts
        if let d = iso.date(from: strippedZ) { return d }

        // 3. DateFormatter 处理带时区偏移：2026-07-10T09:45:05+08:00
        let fmt = DateFormatter()
        fmt.locale = Locale(identifier: "en_US_POSIX")
        fmt.timeZone = TimeZone(abbreviation: "UTC")
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
        if let d = fmt.date(from: ts) { return d }

        // 4. 无 Z 无时区：2026-07-10T09:45:05
        fmt.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        if let d = fmt.date(from: ts) { return d }

        // 5. 纯日期：2026-07-10
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt.date(from: ts)
    }

    /// 综合健康状态
    var health: PipelineHealth {
        guard running else { return .offline }
        if let err = lastError, !err.isEmpty { return .error }
        if let scanDate = lastScanDate {
            let elapsed = Date().timeIntervalSince(scanDate)
            if elapsed > 120 { return .warning }
        }
        return .healthy
    }

    static let unavailable = ScannerStatus(
        running: false, pid: nil, lastScanTime: nil,
        lastInsertCount: 0, lastError: "未检测到扫描进程",
        filesScanned: 0, projects: nil
    )
}

// MARK: - Scanner Status Service

/// 定时读取 scanner_status.json，不阻塞 UI。
///
/// 职责：
///   - 按需读取 scanner_status.json（由 UsageService.refreshAPI() 驱动）
///   - 发布 @Published scannerStatus
///   - JSON 不存在或解析失败时优雅降级
///
/// v1.4.x 诊断增强：
///   - 详细日志：路径、文件大小、原始 JSON 片段
///   - DecodingError 细分输出（keyNotFound / typeMismatch / valueNotFound / dataCorrupted）
///   - 三级错误文案：「文件不存在」「Scanner状态损坏」「解析失败」
///
final class ScannerStatusService: ObservableObject {

    @Published var scannerStatus: ScannerStatus = .unavailable
    @Published var lastCheck: Date = Date()

    /// 最后一次读取的原始 JSON 文本（前 500 字符，用于调试）
    @Published var lastRawJSON: String = ""

    /// 最后一次诊断摘要
    @Published var lastDiagnostic: ScannerDiagnostic = ScannerDiagnostic()

    private let statusPath: String

    init(statusPath: String = {
        let home = NSHomeDirectory()
        return "\(home)/workspace-agent-digital-employee/runtime/ai_usage/scanner_status.json"
    }()) {
        self.statusPath = statusPath
    }

    // MARK: Check

    /// 立即读取一次状态文件（由 UsageService.refreshAPI() 周期调用）
    func checkNow() {
        let url = URL(fileURLWithPath: statusPath)
        print("[ScannerStatus] === checkNow ===")
        print("[ScannerStatus] path: \(statusPath)")
        print("[ScannerStatus] exists: \(FileManager.default.fileExists(atPath: statusPath))")

        lastDiagnostic = ScannerDiagnostic()
        lastDiagnostic.path = statusPath
        lastDiagnostic.fileExists = FileManager.default.fileExists(atPath: statusPath)

        // ── 文件不存在 ──
        guard FileManager.default.fileExists(atPath: statusPath) else {
            print("[ScannerStatus] RESULT: 文件不存在 → offline")
            lastDiagnostic.status = "文件不存在"
            scannerStatus = ScannerStatus(
                running: false, pid: nil, lastScanTime: nil,
                lastInsertCount: 0, lastError: "文件不存在: Scanner 未启动",
                filesScanned: 0, projects: nil
            )
            lastCheck = Date()
            return
        }

        // ── 读取原始数据 ──
        do {
            let data = try Data(contentsOf: url)
            lastDiagnostic.fileSize = data.count
            print("[ScannerStatus] file size: \(data.count) bytes")

            // 保存前 500 字符原始 JSON
            if let raw = String(data: data, encoding: .utf8) {
                let preview = String(raw.prefix(500))
                lastRawJSON = preview
                lastDiagnostic.rawPreview = preview
                print("[ScannerStatus] raw JSON (first 500):")
                print(preview)
            } else {
                print("[ScannerStatus] WARNING: data is not valid UTF-8")
                lastDiagnostic.rawPreview = "<非 UTF-8 数据>"
            }

            // ── JSON 解码 ──
            let decoder = JSONDecoder()
            let status = try decoder.decode(ScannerStatus.self, from: data)

            print("[ScannerStatus] DECODE OK: running=\(status.running) lastScan=\(status.lastScanTime ?? "nil") insert=\(status.lastInsertCount) files=\(status.filesScanned)")
            print("[ScannerStatus] health=\(status.health.rawValue)")

            lastDiagnostic.status = "解析成功"
            lastDiagnostic.health = status.health.rawValue
            scannerStatus = status

        } catch let error as DecodingError {
            // ── DecodingError 细分 ──
            let detail: String
            switch error {
            case .keyNotFound(let key, let context):
                detail = "缺少字段 '\(key.stringValue)': \(context.debugDescription)"
                print("[ScannerStatus] DecodingError.keyNotFound: key=\(key.stringValue) path=\(context.codingPath.map{$0.stringValue})")
            case .typeMismatch(let type, let context):
                detail = "类型不匹配 期望=\(type) field=\(context.codingPath.map{$0.stringValue})"
                print("[ScannerStatus] DecodingError.typeMismatch: type=\(type) path=\(context.codingPath)")
            case .valueNotFound(let type, let context):
                detail = "非可选字段缺失 类型=\(type) field=\(context.codingPath.map{$0.stringValue})"
                print("[ScannerStatus] DecodingError.valueNotFound: type=\(type) path=\(context.codingPath)")
            case .dataCorrupted(let context):
                detail = "数据损坏: \(context.debugDescription)"
                if let underlying = context.underlyingError {
                    print("[ScannerStatus] DecodingError.dataCorrupted: underlying=\(underlying)")
                }
                print("[ScannerStatus] DecodingError.dataCorrupted: \(context.debugDescription)")
            @unknown default:
                detail = "未知解码错误"
            }

            print("[ScannerStatus] RESULT: decode error → \(detail)")
            lastDiagnostic.status = "JSON损坏"
            lastDiagnostic.errorDetail = detail

            scannerStatus = ScannerStatus(
                running: false, pid: nil, lastScanTime: nil,
                lastInsertCount: 0, lastError: "Scanner状态损坏: \(detail)",
                filesScanned: 0, projects: nil
            )

        } catch {
            // ── 其他错误（权限、IO 等） ──
            print("[ScannerStatus] RESULT: read error → \(error.localizedDescription)")
            print("[ScannerStatus] error domain=\((error as NSError).domain) code=\((error as NSError).code)")

            lastDiagnostic.status = "读取失败"
            lastDiagnostic.errorDetail = "\(error.localizedDescription) (domain=\((error as NSError).domain) code=\((error as NSError).code))"

            scannerStatus = ScannerStatus(
                running: false, pid: nil, lastScanTime: nil,
                lastInsertCount: 0, lastError: "读取失败: \(error.localizedDescription)",
                filesScanned: 0, projects: nil
            )
        }

        lastCheck = Date()
    }
}

// MARK: - Scanner Diagnostic

/// 诊断快照（用于 UI 调试区展示）
struct ScannerDiagnostic {
    var path: String = ""
    var fileExists: Bool = false
    var fileSize: Int = 0
    var status: String = ""
    var health: String = ""
    var errorDetail: String = ""
    var rawPreview: String = ""
}
