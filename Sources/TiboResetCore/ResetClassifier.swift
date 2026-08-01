import Foundation

public enum ResetAlertLevel: String, Sendable, Equatable {
    case upcoming
    case confirmed

    public var notificationTitle: String {
        switch self {
        case .upcoming:
            return "Tibo：可能有 Codex reset"
        case .confirmed:
            return "Tibo：Codex reset 已确认"
        }
    }

    public var menuLabel: String {
        switch self {
        case .upcoming:
            return "可能 reset 信号"
        case .confirmed:
            return "确认 reset"
        }
    }
}

public struct ResetAlert: Sendable, Equatable {
    public let post: FeedPost
    public let level: ResetAlertLevel

    public init(post: FeedPost, level: ResetAlertLevel) {
        self.post = post
        self.level = level
    }

    public var persistentKey: String {
        "\(post.id)|\(level.rawValue)"
    }
}

public enum ResetClassifier {
    public static func classify(_ post: FeedPost) -> ResetAlert? {
        let text = post.text.lowercased()

        if containsAny(text, in: noResetPhrases) {
            return nil
        }

        if post.resetVerificationStatus == "confirmed" || containsAny(text, in: confirmedPhrases) {
            return ResetAlert(post: post, level: .confirmed)
        }

        guard text.contains("reset"),
              containsAny(text, in: quotaContextPhrases),
              containsAny(text, in: futurePhrases) else {
            return nil
        }

        return ResetAlert(post: post, level: .upcoming)
    }

    private static func containsAny(_ text: String, in phrases: [String]) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private static let confirmedPhrases = [
        "i've reset usage limits",
        "i have reset usage limits",
        "we've reset usage limits",
        "we have reset usage limits",
        "usage limits have been reset",
        "usage limit has been reset",
        "usage limits reset for all",
        "reset usage limits for all",
        "reset the usage limits for all",
        "limits have been reset",
    ]

    private static let quotaContextPhrases = [
        "usage limit",
        "usage limits",
        "limit reset",
        "quota",
        "codex",
        "chatgpt work",
        "banked reset",
    ]

    private static let futurePhrases = [
        "will reset",
        "going to reset",
        "about to reset",
        "in a few hours",
        "next hour",
        "later today",
        "tomorrow",
        "feeling like a limit reset",
        "time for a reset",
        "more manual resets",
    ]

    private static let noResetPhrases = [
        "no reset",
        "not a reset",
        "isn't a reset",
        "is not a reset",
        "not about to announce a reset",
    ]
}
