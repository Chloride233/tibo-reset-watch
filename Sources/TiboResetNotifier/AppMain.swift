import AppKit
import Foundation
import TiboResetCore
@preconcurrency import UserNotifications

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
final class NotifierAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private let welcomeKey = "hasShownWelcome"
    private let notificationCategoryIdentifier = "TIBO_RESET_ALERT"
    private let openPostActionIdentifier = "OPEN_TIBO_POST"
    private let seenAlerts = SeenAlertStore()
    private let notificationCenter = UNUserNotificationCenter.current()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let menu = NSMenu()
    private let statusLine = NSMenuItem(title: "正在启动…", action: nil, keyEquivalent: "")
    private let sourceLine = NSMenuItem(title: "数据源：正在连接…", action: nil, keyEquivalent: "")
    private let latestPostItem = NSMenuItem(title: "正在获取 Tibo 最新动态…", action: nil, keyEquivalent: "")
    private let alertModeItem = NSMenuItem(title: "提醒条件", action: nil, keyEquivalent: "")

    private var timer: Timer?
    private var latestPostURL: URL?
    private var isPolling = false
    private var consecutiveFailures = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureMenuBar()
        configureNotificationActions()
        notificationCenter.delegate = self
        showWelcomeIfNeeded()
        requestNotificationAuthorization()
        poll()
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
        button.toolTip = "Tibo Reset Watch — 正在启动"

        statusLine.isEnabled = false
        sourceLine.isEnabled = false
        latestPostItem.target = self
        latestPostItem.action = #selector(openLatestPost)
        latestPostItem.isEnabled = false

        let alertModeMenu = NSMenu()
        for mode in AlertMode.allCases {
            let item = NSMenuItem(
                title: mode.title,
                action: #selector(setAlertMode(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = mode.rawValue
            alertModeMenu.addItem(item)
        }
        alertModeItem.submenu = alertModeMenu
        updateAlertModeMenu()

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
            title: "退出 Tibo Reset Watch",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        menu.addItem(statusLine)
        menu.addItem(sourceLine)
        menu.addItem(latestPostItem)
        menu.addItem(.separator())
        menu.addItem(alertModeItem)
        menu.addItem(refreshItem)
        menu.addItem(testItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        statusItem.menu = menu
    }

    private func configureNotificationActions() {
        let openPostAction = UNNotificationAction(
            identifier: openPostActionIdentifier,
            title: "打开原帖",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: notificationCategoryIdentifier,
            actions: [openPostAction],
            intentIdentifiers: [],
            options: []
        )
        notificationCenter.setNotificationCategories([category])
    }

    private func requestNotificationAuthorization() {
        notificationCenter.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor in
                guard let self else { return }

                if let error {
                    self.setStatus("通知权限请求失败", symbolName: "bell.slash")
                    NSLog("Unable to request notification authorization: \(error.localizedDescription)")
                } else if !granted {
                    self.setStatus("系统通知未开启", symbolName: "bell.slash")
                }
            }
        }
    }

    private func showWelcomeIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: welcomeKey) else { return }

        UserDefaults.standard.set(true, forKey: welcomeKey)

        let alert = NSAlert()
        alert.messageText = "Tibo Reset Watch 已启动"
        alert.informativeText = "它正在菜单栏运行。请在屏幕右上角寻找铃铛图标；首次运行请允许系统通知。"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "知道了")
        alert.runModal()
    }

    private func poll() {
        guard !isPolling else {
            setStatus("正在检查，请稍候", symbolName: "arrow.triangle.2.circlepath")
            return
        }

        timer?.invalidate()
        timer = nil
        isPolling = true
        setStatus("正在检查 @thsottiaux 的公开 feed…", symbolName: "arrow.triangle.2.circlepath")

        Task { [weak self] in
            guard let self else { return }

            do {
                let snapshot = try await FeedClient.fetch()
                handle(snapshot)
            } catch {
                handleFailure(error.localizedDescription)
            }
        }
    }

    private func handle(_ snapshot: FeedSnapshot) {
        isPolling = false

        guard !snapshot.stale else {
            handleFailure("Feed 标记为过期", sourceStatus: "标记为过期")
            return
        }

        let tiboPosts = snapshot.tweets.filter {
            $0.isAuthored(by: FeedClient.expectedHandle)
        }
        guard snapshot.tweets.isEmpty || !tiboPosts.isEmpty else {
            handleFailure("Feed 中没有通过作者校验的帖子", sourceStatus: "作者校验失败")
            return
        }

        consecutiveFailures = 0
        setSourceStatus(sourceStatusText(for: tiboPosts.first))
        consume(tiboPosts)
        scheduleNextPoll(after: PollingPolicy.normalInterval)
    }

    private func handleFailure(_ description: String, sourceStatus: String = "连接失败") {
        isPolling = false
        consecutiveFailures += 1

        let retryInterval = PollingPolicy.retryInterval(
            afterConsecutiveFailures: consecutiveFailures
        )
        setSourceStatus(sourceStatus + " · 第 " + String(consecutiveFailures) + " 次")
        setStatus(
            "检查失败；" + retryDescription(for: retryInterval) + "后重试",
            symbolName: "exclamationmark.triangle"
        )
        NSLog("Tibo reset feed check failed: \(description)")
        scheduleNextPoll(after: retryInterval)
    }

    private func consume(_ tiboPosts: [FeedPost]) {
        updateLatestPost(using: tiboPosts.first)
        let alerts = tiboPosts.compactMap(ResetClassifier.classify)

        guard seenAlerts.hasPrimed else {
            seenAlerts.prime(with: alerts)
            setStatus("已开始监听；现有 " + String(alerts.count) + " 条信号不会补发")
            return
        }

        var delivered = 0
        var suppressed = 0
        for alert in alerts where seenAlerts.shouldDeliver(alert) {
            seenAlerts.record(alert)

            if seenAlerts.alertMode.accepts(alert) {
                deliver(alert)
                delivered += 1
            } else {
                suppressed += 1
            }
        }

        if delivered > 0 {
            setStatus("已推送 " + String(delivered) + " 条新 reset 信号")
        } else if suppressed > 0 {
            setStatus(
                "发现 " + String(suppressed) + " 条可能信号（当前仅提醒确认）",
                symbolName: "bell.slash"
            )
        } else {
            setStatus("监听中 · 上次检查 " + timeString())
        }
    }

    private func updateLatestPost(using post: FeedPost?) {
        guard let post else {
            latestPostURL = nil
            latestPostItem.title = "未获取到 Tibo 动态"
            latestPostItem.toolTip = nil
            latestPostItem.isEnabled = false
            return
        }

        latestPostURL = post.url
        latestPostItem.title = "打开最新动态：" + compactText(post.text, limit: 48)
        latestPostItem.toolTip = post.text
        latestPostItem.isEnabled = true
    }

    private func deliver(_ alert: ResetAlert) {
        let content = UNMutableNotificationContent()
        content.title = alert.level.notificationTitle
        content.body = notificationBody(for: alert.post.text)
        content.sound = .default
        content.categoryIdentifier = notificationCategoryIdentifier
        content.userInfo = ["url": alert.post.url.absoluteString]

        let request = UNNotificationRequest(
            identifier: "tibo-reset-" + alert.persistentKey,
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
        compactText(text, limit: 240)
    }

    private func compactText(_ text: String, limit: Int) -> String {
        let oneLine = text
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")

        guard oneLine.count > limit else { return oneLine }
        return "\(oneLine.prefix(limit - 1))…"
    }

    private func sourceStatusText(for post: FeedPost?) -> String {
        guard let time = formattedPostTime(post?.at) else {
            return post == nil ? "正常 · 暂无 Tibo 动态" : "正常 · Tibo 时间线"
        }
        return "正常 · Tibo 最新 " + time
    }

    private func formattedPostTime(_ value: String?) -> String? {
        guard let value else { return nil }

        let fractionalParser = ISO8601DateFormatter()
        fractionalParser.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = fractionalParser.date(from: value) ?? ISO8601DateFormatter().date(from: value)
        guard let date else { return nil }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = Calendar.current.isDateInToday(date) ? "今天 HH:mm" : "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    private func scheduleNextPoll(after interval: TimeInterval) {
        timer?.invalidate()
        timer = Timer.scheduledTimer(
            timeInterval: interval,
            target: self,
            selector: #selector(pollTimerFired),
            userInfo: nil,
            repeats: false
        )
    }

    private func setSourceStatus(_ text: String) {
        sourceLine.title = "数据源：" + text
    }

    private func setStatus(_ text: String, symbolName: String = "bell.badge") {
        statusLine.title = text
        statusItem.button?.image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "Tibo reset notifier"
        )
        statusItem.button?.image?.isTemplate = true
        statusItem.button?.toolTip = "Tibo Reset Watch — " + text
    }

    private func updateAlertModeMenu() {
        let activeMode = seenAlerts.alertMode
        for item in alertModeItem.submenu?.items ?? [] {
            guard let rawValue = item.representedObject as? String,
                  let mode = AlertMode(rawValue: rawValue) else {
                continue
            }
            item.state = mode == activeMode ? .on : .off
        }
    }

    private func retryDescription(for interval: TimeInterval) -> String {
        let minutes = Int(interval / 60)
        return String(minutes) + " 分钟"
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

    @objc private func setAlertMode(_ sender: NSMenuItem) {
        guard let rawValue = sender.representedObject as? String,
              let mode = AlertMode(rawValue: rawValue) else {
            return
        }

        seenAlerts.alertMode = mode
        updateAlertModeMenu()
        setStatus("提醒条件已切换为 " + mode.title)
    }

    @objc private func openLatestPost(_ sender: Any?) {
        guard let latestPostURL else { return }
        NSWorkspace.shared.open(latestPostURL)
    }

    @objc private func sendTestNotification(_ sender: Any?) {
        let content = UNMutableNotificationContent()
        content.title = "Tibo Reset Watch 测试"
        content.body = "如果你看到了这条系统通知，弹窗权限工作正常。"
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "tibo-reset-test-" + UUID().uuidString,
            content: content,
            trigger: nil
        )
        notificationCenter.add(request)
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }

        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier ||
                response.actionIdentifier == "OPEN_TIBO_POST",
              let urlString = response.notification.request.content.userInfo["url"] as? String,
              let url = URL(string: urlString) else {
            return
        }

        Task { @MainActor in
            NSWorkspace.shared.open(url)
        }
    }
}
