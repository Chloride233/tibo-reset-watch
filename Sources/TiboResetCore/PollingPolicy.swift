import Foundation

public enum PollingPolicy {
    public static let normalInterval: TimeInterval = 120

    public static func retryInterval(afterConsecutiveFailures failureCount: Int) -> TimeInterval {
        let exponent = min(max(failureCount - 1, 0), 4)
        let seconds = 60 * Double(1 << exponent)
        return min(seconds, 15 * 60)
    }
}
