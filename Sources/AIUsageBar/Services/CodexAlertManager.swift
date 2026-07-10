import Foundation

// MARK: - Codex Quota State

enum CodexQuotaState: String, Codable {
    case normal
    case warning
    case critical
    case limitReached
    case reset
}

// MARK: - Codex Alert Event

enum CodexAlertEvent: Equatable {
    case none
    case warning(percent: Int)
    case critical(percent: Int)
    case limitReached(percent: Int)
    case reset(percent: Int)
}

// MARK: - Codex Alert Manager

/// State-change driven Codex quota notifications.
final class CodexAlertManager {
    private let warningThreshold: Double = 80
    private let criticalThreshold: Double = 95
    private let limitReachedThreshold: Double = 100
    private let dropResetThreshold: Double = 50

    private let stateKey = "lastCodexQuotaState"
    private let alertTimeKey = "lastCodexAlertTime"
    private let percentKey = "lastCodexQuotaPercent"

    private var lastCodexQuotaState: CodexQuotaState {
        get {
            guard let raw = UserDefaults.standard.string(forKey: stateKey),
                  let state = CodexQuotaState(rawValue: raw) else { return .normal }
            return state
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: stateKey)
        }
    }

    private var lastCodexAlertTime: Date? {
        get { UserDefaults.standard.object(forKey: alertTimeKey) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: alertTimeKey) }
    }

    private var lastCodexQuotaPercent: Double? {
        get {
            let value = UserDefaults.standard.double(forKey: percentKey)
            return UserDefaults.standard.object(forKey: percentKey) == nil ? nil : value
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue, forKey: percentKey)
            } else {
                UserDefaults.standard.removeObject(forKey: percentKey)
            }
        }
    }

    func evaluate(status: CodexQuotaStatus) -> CodexAlertEvent {
        guard let percent = status.sessionPercent, percent >= 0 else {
            return .none
        }

        let previousState = lastCodexQuotaState
        let previousPercent = lastCodexQuotaPercent
        let currentState = state(for: percent)
        let recovered = previousState.isAlerting && currentState == .normal
        let droppedAfterAlert = previousState.isAlerting
            && currentState.rawOrder < previousState.rawOrder
            && ((previousPercent ?? percent) - percent) >= dropResetThreshold

        lastCodexQuotaPercent = percent

        if recovered || droppedAfterAlert {
            lastCodexQuotaState = .reset
            lastCodexAlertTime = Date()
            return .reset(percent: Int(percent))
        }

        if previousState == currentState {
            return .none
        }

        lastCodexQuotaState = currentState

        switch currentState {
        case .normal:
            return .none
        case .warning:
            lastCodexAlertTime = Date()
            return .warning(percent: Int(percent))
        case .critical:
            lastCodexAlertTime = Date()
            return .critical(percent: Int(percent))
        case .limitReached:
            lastCodexAlertTime = Date()
            return .limitReached(percent: Int(percent))
        case .reset:
            return .none
        }
    }

    func forceReset() {
        lastCodexQuotaState = .normal
        lastCodexAlertTime = nil
        lastCodexQuotaPercent = nil
        UserDefaults.standard.removeObject(forKey: stateKey)
        UserDefaults.standard.removeObject(forKey: alertTimeKey)
        UserDefaults.standard.removeObject(forKey: percentKey)
    }

    private func state(for percent: Double) -> CodexQuotaState {
        if percent >= limitReachedThreshold { return .limitReached }
        if percent >= criticalThreshold { return .critical }
        if percent >= warningThreshold { return .warning }
        return .normal
    }
}

private extension CodexQuotaState {
    var isAlerting: Bool {
        self == .warning || self == .critical || self == .limitReached
    }

    var rawOrder: Int {
        switch self {
        case .normal: return 0
        case .warning: return 1
        case .critical: return 2
        case .limitReached: return 3
        case .reset: return -1
        }
    }
}
