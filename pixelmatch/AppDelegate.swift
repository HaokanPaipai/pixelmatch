import UIKit
import UserNotifications
import GameKit
import HKAdKit

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

        // 广告：先注入 provider/adapter，再触发冷启动开屏编排（先后顺序要紧）。
        PixelMatchAdBootstrap.bootstrap()
        AdManager.shared.startOnColdLaunch()
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
        // 回前台开屏（OpenAdCoordinator 自带冷启动后 10s 静默窗，避免与冷启动重复）。
        AdManager.shared.showOnWarmResume()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                 willPresent notification: UNNotification,
                                 withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
}
