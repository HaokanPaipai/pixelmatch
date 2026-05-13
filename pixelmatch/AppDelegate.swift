import UIKit
import UserNotifications
import GameKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let rootViewController = GameViewController()
        let appWindow = UIWindow(frame: UIScreen.main.bounds)
        appWindow.rootViewController = rootViewController
        appWindow.makeKeyAndVisible()
        window = appWindow

        UNUserNotificationCenter.current().delegate = self
        NotificationManager.shared.requestPermission()
        NotificationManager.shared.scheduleDailyRewardNotification()
        NotificationManager.shared.scheduleReturnReminderNotification()

        GameCenterManager.shared.rootViewController = rootViewController
        GameCenterManager.shared.authenticate()
        AnalyticsManager.shared.track(.appLaunch)
        return true
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let secs = LivesManager.shared.secondsUntilNextLife
        if secs > 0 {
            let livesNeeded = GameConstants.maxLives - LivesManager.shared.currentLives
            let totalSecs = secs + (livesNeeded - 1) * GameConstants.lifeRefillMinutes * 60
            NotificationManager.shared.scheduleLivesFullNotification(inSeconds: TimeInterval(totalSecs))
        }
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        NotificationManager.shared.clearBadge()
        NotificationManager.shared.cancelNotifications(withIdentifier: "lives_full")
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
}
