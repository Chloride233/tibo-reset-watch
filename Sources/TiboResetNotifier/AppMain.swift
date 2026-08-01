import AppKit
import Foundation
import TiboResetCore
import UserNotifications

@main
@MainActor
struct TiboResetNotifierMain {
    static func main() {
        let app = NSApplication.shared
        let appDelegate = NotifierAppDelegate()
        app.setActivationPolicy(.accessory)
        app.delegate = appDelegate
        withExtendedLifetime(appDelegate) {
            app.run()
        }
    }
}

@MainActor
final class NotifierAppDelegate: NSObject, NSApplicationDelegate {
    private let pollInterval: TimeInterval = 120
    private let seenAlerts = SeenAlertStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusLine = NSMenuItem(title: "正在启动…", action: nil, keyEquivalent: "")
    private let latestPostItem = NSMenuItem(title: "暂时没有 reset 信号", action: nil, keyEquivalent: "")

    private var timer: Timer?
    private var latestPostURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBar()
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { _, _ in }
        poll()

        timer = Timer.scheduledTimer(
            timeInterval: pollInterval,
            target: self,
            selector: #selector(pollTimerFired),
            userInfo: nil,
            repeats: true
        )
    }

    func applicationWillTerminate(_ notification: Notification) {
        timer?.invalidate()
    }

    private func configureMenuBar() {
        guard let button = statusItem.button else { return }

        button.image = NSImage(
            systemSymbolName: "bell.badge",
            accessibilityDescription: "Tibo reset notifier"
        )
        button.image?.isTemplate = true
        button.toolTip = "Tibo Reset Notifier — 正在启动"

        statusLine.isEnabled = false
        latestPostItem.target = self
        latestPostItem.action = #selector(openLatestPost)
        latestPostItem.isEnabled = false

        let refreshItem = NSMenuItem(
            title: "立即检查",
            action: #selector(checkNow),
            keyEquivalent: "r"
        )
        refreshItem.target = self

        let testItem = NSMenuItem(
            title: "发送测试通知",
            action: #selector(sendTestNotification),
            keyEquivalent: "t"
        )
        testItem.target = self

        let quitItem = NSMenuItem(
            title: "退出 Tibo Reset Notifier",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        menu.addItem(statusLine)
        menu.addItem(latestPostItem)
        menu.addItem(.separator())
        menu.addItem(refreshItem)
        menu.addItem(testItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func poll() {
        setStatus("正在检查 @thsottiaux 的公开 feed…")

        Task { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try await FeedClient.fetch()
                consume(snapshot)
            } catch {
                setStatus("检查失败：\(error.localizedDescription)")
            }
        }
    }

    private func consume(_ snapshot: FeedSnapshot) {
        guard !snapshot.stale else {
            setStatus("Feed 标记为过期，稍后会重试")
            return
        }

        let alerts = snapshot.tweets.compactMap(ResetClassifier.classify)
        updateLatestPost(using: alerts.first)

        guard seenAlerts.hasPrimed else {
            seenAlerts.prime(with: alerts)
            setStatus("已开始监听；现有 \(alerts.count) 条信号不会补发")
            return
        }

        var delivered = 0
        for alert in alerts where seenAlerts.shouldDeliver(alert) {
            seenAlerts.record(alert)
            deliver(alert)
            delivered += 1
        }

        if delivered > 0 {
            setStatus("已推送 \(delivered) 条新 reset 信号")
        } else {
            setStatus("监听中 · 上次检查 \(timeString())")
        }
    }

    private func updateLatestPost(using alert: ResetAlert?) {
        guard let alert else { return }

        latestPostURL = alert.post.url
        latestPostItem.title = "打开最新：\(alert.level.menuLabel)"
        latestPostItem.isEnabled = true
    }

    private func deliver(_ alert: ResetAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.level.notificationTitle
        content.body = notificationBody(for: alert.post.text)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tibo-reset-\(alert.persistentKey)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request) { error in
            if let error {
                NSLog("Unable to deliver Tibo reset notification: \(error.localizedDescription)")
            }
        }
    }

    private func notificationBody(for text: String) -> String {
        let oneLine = text
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
        let limit = 240

        guard oneLine.count > limit else { return oneLine }
        return "\(oneLine.prefix(limit - 1))…"
    }

    private func setStatus(_ text: String) {
        statusLine.title = text
        statusItem.button?.toolTip = "Tibo Reset Notifier — \(text)"
    }

    private func timeString() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: Date())
    }

    @objc private func pollTimerFired() {
        poll()
    }

    @objc private func checkNow(_ sender: Any?) {
        poll()
    }

    @objc private func openLatestPost(_ sender: Any?) {
        guard let latestPostURL else { return }
        NSWorkspace.shared.open(latestPostURL)
    }

    @objc private func sendTestNotification(_ sender: Any?) {
        let content = UNMutableNotificationContent()
        content.title = "Tibo Reset Notifier 测试"
        content.body = "如果你看到了这条系统通知，弹窗权限工作正常。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tibo-reset-test-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        notificationCenter.add(request)
    }
}
