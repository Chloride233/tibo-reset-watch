import Darwin
import Foundation
import TiboResetCore

@main
struct TiboResetNotifierChecks {
    static func main() {
        var failures: [String] = []

        expect(
            ResetClassifier.classify(makePost(
                text: "The usage limits have been reset for all paid users of Codex and ChatGPT Work."
            ))?.level == .confirmed,
            "explicit usage reset is confirmed",
            failures: &failures
        )

        expect(
            ResetClassifier.classify(makePost(
                text: "A deliberately vague post.",
                verificationStatus: "confirmed"
            ))?.level == .confirmed,
            "feed confirmation marker is respected",
            failures: &failures
        )

        expect(
            ResetClassifier.classify(makePost(
                text: "I'm feeling like a limit reset. Hold on tight and see you in a few hours."
            ))?.level == .upcoming,
            "future limit reset is marked upcoming",
            failures: &failures
        )

        expect(
            ResetClassifier.classify(makePost(
                text: "Thinking I am about to announce a reset. But no."
            )) == nil,
            "explicit no-reset post is ignored",
            failures: &failures
        )

        expect(
            ResetClassifier.classify(makePost(
                text: "The day we develop really good models. There will be signs. Resets. These kinds of things."
            )) == nil,
            "unrelated reset mention is ignored",
            failures: &failures
        )

        expect(
            makePost(text: "A normal Tibo post.").isAuthored(by: FeedClient.expectedHandle),
            "canonical Tibo status URL passes author validation",
            failures: &failures
        )

        let otherAuthorPost = FeedPost(
            id: "456",
            url: URL(string: "https://x.com/OpenAI/status/456")!,
            text: "Usage limits have been reset.",
            kind: "signal",
            resetVerificationStatus: "confirmed"
        )
        expect(
            !otherAuthorPost.isAuthored(by: FeedClient.expectedHandle),
            "another account is rejected even when its text mentions a reset",
            failures: &failures
        )

        let mismatchedStatusPost = FeedPost(
            id: "789",
            url: URL(string: "https://x.com/thsottiaux/status/456")!,
            text: "A mismatched status URL.",
            kind: "other",
            resetVerificationStatus: nil
        )
        expect(
            !mismatchedStatusPost.isAuthored(by: FeedClient.expectedHandle),
            "status URL must match the feed post id",
            failures: &failures
        )

        expect(
            PollingPolicy.retryInterval(afterConsecutiveFailures: 1) == 60,
            "first failed check retries in one minute",
            failures: &failures
        )

        expect(
            PollingPolicy.retryInterval(afterConsecutiveFailures: 2) == 120,
            "second failed check backs off to two minutes",
            failures: &failures
        )

        expect(
            PollingPolicy.retryInterval(afterConsecutiveFailures: 4) == 480,
            "retries grow exponentially",
            failures: &failures
        )

        expect(
            PollingPolicy.retryInterval(afterConsecutiveFailures: 8) == 900,
            "retry interval is capped at fifteen minutes",
            failures: &failures
        )

        do {
            let data = Data("""
            {
              "stale": false,
              "source_scope": "timeline",
              "profile": {
                "handle": "thsottiaux"
              },
              "tweets": [
                {
                  "id": "123",
                  "url": "https://x.com/thsottiaux/status/123",
                  "text": "Usage limits have been reset for all Codex users.",
                  "at": "2026-08-01T02:05:31.000Z",
                  "kind": "signal",
                  "reset_verification_status": "confirmed"
                }
              ]
            }
            """.utf8)
            let snapshot = try JSONDecoder().decode(FeedSnapshot.self, from: data)

            expect(!snapshot.stale, "feed stale flag decodes", failures: &failures)
            expect(snapshot.isExpectedTiboTimeline, "feed identifies Tibo's timeline", failures: &failures)
            expect(snapshot.tweets.count == 1, "feed post count decodes", failures: &failures)
            expect(
                snapshot.tweets[0].at == "2026-08-01T02:05:31.000Z",
                "feed post timestamp decodes",
                failures: &failures
            )
            expect(
                ResetClassifier.classify(snapshot.tweets[0])?.level == .confirmed,
                "decoded feed post is classified",
                failures: &failures
            )
        } catch {
            failures.append("public feed shape decodes: \(error.localizedDescription)")
        }

        guard failures.isEmpty else {
            failures.forEach { print("FAIL: \($0)") }
            exit(1)
        }

        print("PASS: 17 notifier checks")
    }

    private static func expect(
        _ condition: Bool,
        _ description: String,
        failures: inout [String]
    ) {
        if !condition {
            failures.append(description)
        }
    }

    private static func makePost(
        text: String,
        verificationStatus: String? = nil
    ) -> FeedPost {
        let id = UUID().uuidString
        return FeedPost(
            id: id,
            url: URL(string: "https://x.com/thsottiaux/status/" + id)!,
            text: text,
            kind: "signal",
            resetVerificationStatus: verificationStatus
        )
    }
}
