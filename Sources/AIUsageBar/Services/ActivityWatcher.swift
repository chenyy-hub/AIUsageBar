import Foundation

// MARK: - Activity Watcher (v3.2)

/// 文件活动监控器
///
/// 监听 `~/.claude/projects/**/*.jsonl` 文件的 mtime 变化。
/// 每 5 秒检查一次，仅记录最新修改时间（不扫描文件内容）。
/// 当检测到新活动时，通过回调通知调用方。
///
final class ActivityWatcher {
    /// 活动回调：通知外部有新的活动时间
    var onActivityDetected: ((Date) -> Void)?

    private let fileManager = FileManager.default
    private let claudeDir: String
    private let home: String

    /// 上次已知的最新文件修改时间
    private var lastKnownMtime: Date?
    /// 轮询定时器
    private var timer: Timer?

    init() {
        self.home = NSHomeDirectory()
        self.claudeDir = "\(home)/.claude/projects"
    }

    // MARK: - Public

    /// 启动监听（必须从主线程调用）
    func start() {
        // 首次记录最新 mtime（不触发回调）
        lastKnownMtime = scanLatestMtime()
        print("[ActivityWatcher] start — initial mtime: \(lastKnownMtime?.description ?? "nil")")

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            self?.check()
        }
    }

    /// 停止监听
    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// 获取当前最新活动时间（可被外部读取）
    var latestActivityDate: Date? {
        lastKnownMtime
    }

    // MARK: - Private

    /// 每次定时器触发：检查是否有更新的 mtime
    private func check() {
        guard let latest = scanLatestMtime() else { return }

        if let last = lastKnownMtime {
            if latest > last {
                // 发现新活动
                lastKnownMtime = latest
                print("[ActivityWatcher] new activity detected: \(latest)")
                DispatchQueue.main.async { [weak self] in
                    self?.onActivityDetected?(latest)
                }
            }
            // else: 无变化，什么都不做
        } else {
            // 首次或重置
            lastKnownMtime = latest
        }
    }

    /// 扫描所有 JSONL 文件的最新 mtime（轻量：仅比较 mtime，不读内容）
    private func scanLatestMtime() -> Date? {
        guard fileManager.fileExists(atPath: claudeDir) else { return nil }

        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: claudeDir),
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var latest: Date?
        for case let file as URL in enumerator {
            guard file.pathExtension == "jsonl" else { continue }
            guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                  let mtime = attrs.contentModificationDate else {
                continue
            }
            if mtime > (latest ?? .distantPast) {
                latest = mtime
            }
        }
        return latest
    }
}
