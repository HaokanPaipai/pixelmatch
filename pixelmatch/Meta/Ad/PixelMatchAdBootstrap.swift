//
//  PixelMatchAdBootstrap.swift
//  pixelmatch
//
//  组装 5 个 Provider + 3 个网络 Adapter 并经 AdManager.setup(...) 注入 HKAdKit。
//  由 AppDelegate.didFinishLaunching 在 IAPManager.start() 之后调用。幂等。
//

import UIKit
import HKAdKit
import GoogleMobileAds

@MainActor
enum PixelMatchAdBootstrap {

    private static var didBootstrap = false

    /// 启动注入。可重复调用（HKAdKit 自身 setup 也是幂等的）。
    static func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        // 崩溃上报统一走 Firebase Crashlytics：禁用 GMA 自带的信号处理器，
        // 否则它会抢注 SIGABRT/SIGSEGV 等 handler，截走崩溃报告（启动日志会警告）。
        // 必须在任何 GADMobileAds.start 之前调用。
        GADMobileAds.sharedInstance().disableSDKCrashReporting()

        AdManager.shared.setup(
            user: PixelMatchAdUserProvider(),
            config: PixelMatchAdConfigProvider(),
            reward: PixelMatchAdRewardProvider(),
            analytics: PixelMatchAdAnalyticsProvider(),
            ui: PixelMatchAdUIProvider(),
            openAdAdapter: PixelMatchOpenAdAdapter(),
            rewardedAdAdapter: PixelMatchRewardedAdAdapter(),
            interstitialAdAdapter: PixelMatchInterstitialAdapter()
        )
    }
}
