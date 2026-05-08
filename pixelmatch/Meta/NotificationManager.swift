import UserNotifications
import UIKit

final class NotificationManager {
    static let shared = NotificationManager()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    func requestPermission() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func scheduleLivesFullNotification(inSeconds seconds: TimeInterval) {
        cancelNotifications(withIdentifier: "lives_full")
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "❤️ Lives Full!"
        content.body  = "Your hearts are full — jump back in and beat that level!"
        content.sound = .default
        content.badge = 1

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(identifier: "lives_full", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleDailyRewardNotification() {
        cancelNotifications(withIdentifier: "daily_reward")

        let content = UNMutableNotificationContent()
        content.title = "🎁 Daily Reward Ready!"
        content.body  = "Open PixelMatch and claim your free coins and diamonds!"
        content.sound = .default
        content.badge = 1

        var components = DateComponents()
        components.hour   = 9
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: "daily_reward", content: content, trigger: trigger)
        center.add(request)
    }

    func scheduleReturnReminderNotification() {
        cancelNotifications(withIdentifier: "return_reminder")

        let content = UNMutableNotificationContent()
        content.title = "🎮 Still Matching?"
        content.body  = "New levels await! Your pixel gems miss you."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400 * 2, repeats: false)
        let request = UNNotificationRequest(identifier: "return_reminder", content: content, trigger: trigger)
        center.add(request)
    }

    func cancelNotifications(withIdentifier id: String) {
        center.removePendingNotificationRequests(withIdentifiers: [id])
    }

    func clearBadge() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0)
        } else {
            UIApplication.shared.applicationIconBadgeNumber = 0
        }
    }
}
