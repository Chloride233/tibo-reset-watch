import TiboResetCore

enum AlertMode: String, CaseIterable {
    case confirmedOnly
    case possibleAndConfirmed

    var title: String {
        switch self {
        case .confirmedOnly:
            return "仅确认 reset"
        case .possibleAndConfirmed:
            return "可能 + 确认 reset"
        }
    }

    func accepts(_ alert: ResetAlert) -> Bool {
        switch self {
        case .confirmedOnly:
            return alert.level == .confirmed
        case .possibleAndConfirmed:
            return true
        }
    }
}
