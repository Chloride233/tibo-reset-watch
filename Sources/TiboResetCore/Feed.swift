import Foundation

public struct FeedSnapshot: Decodable, Sendable {
    public let stale: Bool
    public let fetchedAt: String?
    public let newestPostAt: String?
    public let sourceScope: String?
    public let profile: FeedProfile?
    public let tweets: [FeedPost]

    public init(
        stale: Bool,
        fetchedAt: String? = nil,
        newestPostAt: String? = nil,
        sourceScope: String? = nil,
        profile: FeedProfile? = nil,
        tweets: [FeedPost]
    ) {
        self.stale = stale
        self.fetchedAt = fetchedAt
        self.newestPostAt = newestPostAt
        self.sourceScope = sourceScope
        self.profile = profile
        self.tweets = tweets
    }

    public var isExpectedTiboTimeline: Bool {
        profile?.handle.caseInsensitiveCompare(FeedClient.expectedHandle) == .orderedSame &&
            sourceScope?.caseInsensitiveCompare("timeline") == .orderedSame
    }

    enum CodingKeys: String, CodingKey {
        case stale
        case fetchedAt = "fetched_at"
        case newestPostAt = "newest_post_at"
        case sourceScope = "source_scope"
        case profile
        case tweets
    }
}

public struct FeedProfile: Decodable, Sendable {
    public let handle: String

    public init(handle: String) {
        self.handle = handle
    }
}

public struct FeedPost: Decodable, Sendable, Equatable {
    public let id: String
    public let url: URL
    public let text: String
    public let at: String?
    public let kind: String?
    public let resetVerificationStatus: String?

    public init(
        id: String,
        url: URL,
        text: String,
        at: String? = nil,
        kind: String?,
        resetVerificationStatus: String?
    ) {
        self.id = id
        self.url = url
        self.text = text
        self.at = at
        self.kind = kind
        self.resetVerificationStatus = resetVerificationStatus
    }

    public func isAuthored(by expectedHandle: String) -> Bool {
        guard let host = url.host?.lowercased(),
              ["x.com", "www.x.com", "twitter.com", "www.twitter.com"].contains(host) else {
            return false
        }

        let path = url.path.split(separator: "/").map(String.init)
        guard path.count >= 3 else { return false }

        return path[0].caseInsensitiveCompare(expectedHandle) == .orderedSame &&
            path[1].caseInsensitiveCompare("status") == .orderedSame &&
            path[2] == id
    }

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case text
        case at
        case kind
        case resetVerificationStatus = "reset_verification_status"
    }
}

public enum FeedClient {
    public static let expectedHandle = "thsottiaux"
    public static let fallbackEndpoint = URL(string: "https://codex-reset.com/api/feed")!
    public static let endpointDefaultsKey = "feedEndpoint"

    public static var endpoint: URL {
        guard let value = UserDefaults.standard.string(forKey: endpointDefaultsKey),
              let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            return fallbackEndpoint
        }
        return url
    }

    public static func fetch() async throws -> FeedSnapshot {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("TiboResetWatch/0.3", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.unexpectedResponse((response as? HTTPURLResponse)?.statusCode)
        }

        let snapshot = try JSONDecoder().decode(FeedSnapshot.self, from: data)
        guard snapshot.isExpectedTiboTimeline else {
            throw FeedError.unexpectedTimeline
        }
        return snapshot
    }
}

enum FeedError: LocalizedError {
    case unexpectedResponse(Int?)
    case unexpectedTimeline

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse(let statusCode):
            if let statusCode {
                return "The reset feed returned HTTP \(statusCode)."
            }
            return "The reset feed did not return a successful response."
        case .unexpectedTimeline:
            return "The reset feed did not identify itself as @thsottiaux's timeline."
        }
    }
}
