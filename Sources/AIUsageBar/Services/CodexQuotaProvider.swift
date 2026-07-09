import Foundation

// MARK: - Codex Quota Provider

/// Fetches real Codex quota from Codex app-server rate-limit APIs.
///
/// This provider never estimates quota from token usage. If Codex auth, app-server,
/// or rate-limit data is unavailable, it returns `.unavailable`.
final class CodexQuotaProvider: @unchecked Sendable {
    private let executablePath: String
    private let timeout: TimeInterval

    init(executablePath: String = "/opt/homebrew/bin/codex", timeout: TimeInterval = 4) {
        self.executablePath = executablePath
        self.timeout = timeout
    }

    func fetchStatus() -> CodexQuotaStatus {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            return .unavailable
        }
        return fetchViaAppServer() ?? .unavailable
    }

    private func fetchViaAppServer() -> CodexQuotaStatus? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = ["app-server"]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var result: CodexQuotaStatus?
        var buffer = Data()

        output.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }

            lock.lock()
            buffer.append(data)
            while let newline = buffer.firstIndex(of: 10) {
                let line = buffer.prefix(upTo: newline)
                buffer.removeSubrange(buffer.startIndex...newline)
                if let status = self.parseRateLimitResponse(line) {
                    result = status
                    semaphore.signal()
                }
            }
            lock.unlock()
        }

        do {
            try process.run()
        } catch {
            output.fileHandleForReading.readabilityHandler = nil
            return nil
        }

        let messages = [
            #"{"method":"initialize","id":1,"params":{"clientInfo":{"name":"AIUsageBar","title":"AIUsageBar","version":"1.1.3"}}}"#,
            #"{"method":"initialized","params":{}}"#,
            #"{"method":"account/rateLimits/read","id":2}"#,
        ]
        for message in messages {
            if let data = "\(message)\n".data(using: .utf8) {
                input.fileHandleForWriting.write(data)
            }
        }

        _ = semaphore.wait(timeout: .now() + timeout)
        output.fileHandleForReading.readabilityHandler = nil
        process.terminate()

        lock.lock()
        let finalResult = result
        lock.unlock()
        return finalResult
    }

    private func parseRateLimitResponse(_ data: Data.SubSequence) -> CodexQuotaStatus? {
        guard let object = try? JSONSerialization.jsonObject(with: Data(data)) as? [String: Any],
              object["id"] as? Int == 2,
              let result = object["result"] as? [String: Any] else {
            return nil
        }

        var windows: [(usedPercent: Double, durationMins: Double, resetTime: Date)] = []
        if let rateLimitsById = result["rateLimitsByLimitId"] as? [String: Any] {
            for (_, value) in rateLimitsById {
                if let dict = value as? [String: Any] {
                    windows.append(contentsOf: parseWindows(dict))
                }
            }
        } else if let rateLimits = result["rateLimits"] as? [String: Any],
                  !rateLimits.isEmpty {
            windows.append(contentsOf: parseWindows(rateLimits))
        }

        guard !windows.isEmpty else {
            return nil
        }

        windows.sort { $0.durationMins < $1.durationMins }
        let session = windows.first
        let weekly = windows.last

        return CodexQuotaStatus(
            sessionUsed: nil,
            sessionLimit: nil,
            sessionPercent: session?.usedPercent,
            sessionResetTime: session?.resetTime,
            weeklyUsed: nil,
            weeklyLimit: nil,
            weeklyPercent: weekly?.usedPercent,
            weeklyResetTime: weekly?.resetTime,
            status: "available"
        )
    }

    private func parseWindows(_ dict: [String: Any]) -> [(usedPercent: Double, durationMins: Double, resetTime: Date)] {
        ["primary", "secondary"].compactMap { key in
            guard let window = dict[key] as? [String: Any],
                  let usedPercent = number(window["usedPercent"]),
                  let duration = number(window["windowDurationMins"]),
                  let resetsAt = number(window["resetsAt"]) else {
                return nil
            }
            return (
                usedPercent: min(max(usedPercent, 0), 100),
                durationMins: duration,
                resetTime: Date(timeIntervalSince1970: resetsAt)
            )
        }
    }

    private func number(_ value: Any?) -> Double? {
        switch value {
        case let value as Double:
            return value
        case let value as Int:
            return Double(value)
        case let value as NSNumber:
            return value.doubleValue
        default:
            return nil
        }
    }
}
