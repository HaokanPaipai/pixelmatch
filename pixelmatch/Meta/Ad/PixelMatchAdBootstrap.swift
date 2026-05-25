//
//  PixelMatchAdBootstrap.swift
//  pixelmatch
//
//  组装 5 个 Provider + 3 个网络 Adapter 并经 AdManager.setup(...) 注入 HKAdKit。
//  由 AppDelegate.didFinishLaunching 在 IAPManager.start() 之后调用。幂等。
//

import UIKit
import HKAdKit

@MainActor
enum PixelMatchAdBootstrap {

    private static var didBootstrap = false

    /// 启动注入。可重复调用（HKAdKit 自身 setup 也是幂等的）。
    static func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

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
