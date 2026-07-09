import Foundation

// MARK: - Edit Session Manager

final class EditSessionManager: @unchecked Sendable {
    private let lock = NSLock()
    private var depth = 0

    var isEditing: Bool {
        lock.lock()
        defer { lock.unlock() }
        return depth > 0
    }

    func beginEditing() {
        lock.lock()
        depth += 1
        lock.unlock()
    }

    func endEditing() {
        lock.lock()
        depth = max(0, depth - 1)
        lock.unlock()
    }
}
