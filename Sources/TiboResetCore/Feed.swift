import Foundation

public struct FeedSnapshot: Decodable, Sendable {
    public let stale: Bool
    public let fetchedAt: String?
    public let newestPostAt: String?
    public let tweets: [FeedPost]

    public init(
        stale: Bool,
        fetchedAt: String? = nil,
        newestPostAt: String? = nil,
        tweets: [FeedPost]
    ) {
        self.stale = stale
        self.fetchedAt = fetchedAt
        self.newestPostAt = newestPostAt
        self.tweets = tweets
    }

    enum CodingKeys: String, CodingKey {
        case stale
        case fetchedAt = "fetched_at"
        case newestPostAt = "newest_post_at"
        case tweets
    }
}

public struct FeedPost: Decodable, Sendable, Equatable {
    public let id: String
    public let url: URL
    public let text: String
    public let kind: String?
    public let resetVerificationStatus: String?

    public init(
        id: String,
        url: URL,
        text: String,
        kind: String?,
        resetVerificationStatus: String?
    ) {
        self.id = id
        self.url = url
        self.text = text
        self.kind = kind
        self.resetVerificationStatus = resetVerificationStatus
    }

    enum CodingKeys: String, CodingKey {
        case id
        case url
        case text
        case kind
        case resetVerificationStatus = "reset_verification_status"
    }
}

public enum FeedClient {
    public static let endpoint = URL(string: "https://codex-reset.com/api/feed")!

    public static func fetch() async throws -> FeedSnapshot {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 20
        request.setValue("TiboResetWatch/0.2", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.unexpectedResponse((response as? HTTPURLResponse)?.statusCode)
        }

        return try JSONDecoder().decode(FeedSnapshot.self, from: data)
    }
}

enum FeedError: LocalizedError {
    case unexpectedResponse(Int?)

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse(let statusCode):
            if let statusCode {
                return "The reset feed returned HTTP \(statusCode)."
            }
            return "The reset feed did not return a successful response."
        }
    }
}
