import Foundation

public struct FeedSnapshot: Decodable, Sendable {
    public let stale: Bool
    public let tweets: [FeedPost]

    public init(stale: Bool, tweets: [FeedPost]) {
        self.stale = stale
        self.tweets = tweets
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
        let (data, response) = try await URLSession.shared.data(from: endpoint)

        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw FeedError.unexpectedResponse
        }

        return try JSONDecoder().decode(FeedSnapshot.self, from: data)
    }
}

enum FeedError: LocalizedError {
    case unexpectedResponse

    var errorDescription: String? {
        switch self {
        case .unexpectedResponse:
            return "The reset feed did not return a successful response."
        }
    }
}
