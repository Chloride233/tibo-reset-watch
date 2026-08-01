import Foundation
import TiboResetCore

@MainActor
final class SeenAlertStore {
    private enum Key {
        static let hasPrimed = "hasPrimed"
        static let alertKeys = "alertKeys"
        static let alertMode = "alertMode"
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var hasPrimed: Bool {
        defaults.bool(forKey: Key.hasPrimed)
    }

    var alertMode: AlertMode {
        get {
            AlertMode(rawValue: defaults.string(forKey: Key.alertMode) ?? "") ?? .possibleAndConfirmed
        }
        set {
            defaults.set(newValue.rawValue, forKey: Key.alertMode)
        }
    }

    func prime(with alerts: [ResetAlert]) {
        var keys = alertKeys
        keys.formUnion(alerts.map(\.persistentKey))
        save(keys)
        defaults.set(true, forKey: Key.hasPrimed)
    }

    func shouldDeliver(_ alert: ResetAlert) -> Bool {
        !alertKeys.contains(alert.persistentKey)
    }

    func record(_ alert: ResetAlert) {
        var keys = alertKeys
        keys.insert(alert.persistentKey)
        save(keys)
    }

    private var alertKeys: Set<String> {
        Set(defaults.stringArray(forKey: Key.alertKeys) ?? [])
    }

    private func save(_ keys: Set<String>) {
        defaults.set(Array(keys.sorted().suffix(200)), forKey: Key.alertKeys)
    }
}
