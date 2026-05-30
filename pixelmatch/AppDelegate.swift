import UIKit
import UserNotifications
import GameKit
import HKAdKit
import AppTrackingTransparency

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

        // 启动顺序按 HKIAPKit/INTEGRATION.md Step 5：IAP 先 → ATT 授权 → Ad 初始化 → 冷启动编排。
        IAPManager.shared.start()
        requestTrackingThenStartAds()
        return true
    }

    /// 先请求 ATT 授权再初始化广告：AdMob 据 IDFA 授权状态决定个性化程度，
    /// 也满足苹果「使用 IDFA 须经 ATT 同意」的审核要求。iOS 15+ 下若 App 尚未 active，
    /// 系统会自动把弹窗推迟到 active 后展示；回调一定会触发，故广告初始化挂在回调里不会丢。
    private func requestTrackingThenStartAds() {
        let startAds = {
            PixelMatchAdBootstrap.bootstrap()
            AdManager.shared.startOnColdLaunch()
        }
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { _ in
                DispatchQueue.main.async(execute: startAds)
            }
        } else {
            startAds()
        }
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
