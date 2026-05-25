//
//  PixelMatchAdProviders.swift
//  pixelmatch
//
//  HKAdKit 的 5 个宿主 Provider 实现。PixelMatch 把"账号体系/云控/品牌资源"
//  这些 SDK 不该认的东西用本文件包一层喂给 HKAdKit。
//
//  设计对齐 goodlook/AdProviders/GoodlookAdProviders.swift；差异点：
//  · isVip 直接读 `PlayerData.noAds`（PixelMatch 没账号，noAds IAP 即"免广告权益"）
//  · 配置无云控，常量集中在 EconomyConfig.swift 的 AdConfig
//  · 奖励按 placement 分发到 PlayerData / LivesManager（VIP 时长在 goodlook 端，PixelMatch 不需要）
//

import UIKit
import HKAdKit

// MARK: - 用户态

final class PixelMatchAdUserProvider: AdUserProvider {
    var isVip: Bool { PlayerData.shared.noAds }
    var hasAgreedPrivacy: Bool { PlayerData.shared.hasAgreedPrivacy }
}

// MARK: - 运行期配置

final class PixelMatchAdConfigProvider: AdConfigProvider {

    // 地区策略：纯 iOS 端轻量判定（locale + 时区双保险，调试可经 UserDefaults 覆盖）。
    var region: AdRegion {
        if let override = UserDefaults.standard.string(forKey: "ad_region_override") {
            return override.lowercased() == "cn" ? .china : .overseas
        }
        // 兼容 iOS 15：Locale.region 是 iOS 16+，这里用旧 API regionCode。
        let isCN = (Locale.current.regionCode == "CN")
            || TimeZone.current.identifier == "Asia/Shanghai"
        return isCN ? .china : .overseas
    }

    // 开屏
    var isOpenAdEnabled: Bool      { true }
    var openAdDailyCap: Int        { AdConfig.openAdDailyCap }
    var openAdMinInterval: TimeInterval { AdConfig.openAdMinInterval }
    var openAdUnitID: String       { AdConfig.googleOpenAdUnitID }

    // 激励
    var isRewardedEnabled: Bool    { true }
    var rewardedDailyCap: Int      { AdConfig.rewardedDailyCap }
    var rewardedAdUnitID: String   { AdConfig.googleRewardedAdUnitID }

    // 插屏（v1.1 协议字段）
    var isInterstitialEnabled: Bool { true }
    var interstitialDailyCap: Int   { AdConfig.interstitialDailyCap }
    var interstitialMinInterval: TimeInterval { AdConfig.interstitialMinInterval }
    var interstitialAdUnitID: String { AdConfig.googleInterstitialAdUnitID }

    var frequencySuiteName: String? { AdConfig.frequencySuiteName }

    func cnAdSlotJSON(for format: AdFormat) -> [String: Any]? {
        let name: String
        switch format {
        case .openApp:      name = "SplashData"
        case .rewarded:     name = "RewardVideoData"
        case .interstitial: name = "InterstitialData"
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let obj  = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }
}

// MARK: - 奖励兑现（核心业务接线）

/// 激励 placement 对照表（与挂载点字符串保持一致）：
/// · "continueLevel" → 失败页"看广告免费重试"。SDK 只通知"看完了"，由调用方自行跳关而非这里发；
///   本 provider 不发任何东西（reward = 0）。
/// · "extraMoves"    → 步数耗尽 +5 步。同上：由 GameScene 调用方处理，本 provider 不发。
/// · "refillLife"    → 体力为 0 时 +1 生命。本 provider 直接给生命补一格。
/// · "bonusCoins"    → 通用兜底：直接给 50 金币。
/// 之所以"continueLevel/extraMoves"在 provider 不发奖，是因为它们的副作用要绑定到具体 Scene 状态（跳到哪关、加哪局的步数），由 Scene 监听 completion 回调更精准。
final class PixelMatchAdRewardProvider: AdRewardProvider {
    func grantReward(_ result: AdRewardResult) {
        switch result.placement.rawValue {
        case "refillLife":
            LivesManager.shared.refillOne()
        case "bonusCoins":
            PlayerData.shared.addCoins(50)
        case "continueLevel", "extraMoves":
            // 由调用方在 showRewardedAd 的 completion 里处理（更精准的场景副作用）
            break
        default:
            // 未知 placement 默认给 50 金币兜底，避免用户看完广告无感。
            PlayerData.shared.addCoins(50)
        }
        // "看完广告"埋点已由 HKAdKit 经 AdAnalyticsProvider.rewardEarned 触发，这里不再重复。
    }
}

// MARK: - 埋点

final class PixelMatchAdAnalyticsProvider: AdAnalyticsProvider {
    func track(_ event: AdEvent) {
        // PixelMatch 本地分析无广告事件类型，先打 log；接 Firebase/AppsFlyer 后映射到具体事件。
        // TODO: 接入远端分析后映射为 ad_load_start / ad_loaded / ad_impression / ad_reward_earned 等。
        print("[Ad] \(event)")
    }
}

// MARK: - UI / 资源

final class PixelMatchAdUIProvider: AdUIProvider {

    /// 海外开屏 load 期间的占位 view：与 LoadingScene 视觉风格对齐的暗色背景 + 居中 logo 占位。
    func makeLaunchPlaceholderView() -> UIView {
        let v = UIView(frame: UIScreen.main.bounds)
        v.backgroundColor = UIColor(red: 11/255.0, green: 17/255.0, blue: 32/255.0, alpha: 1)
        // logo 占位：白色描边方块（替代品；待用户提供 logo 后改成 UIImageView）。
        let logo = UIView(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        logo.center = v.center
        logo.layer.borderColor = UIColor.white.withAlphaComponent(0.7).cgColor
        logo.layer.borderWidth = 3
        logo.layer.cornerRadius = 12
        v.addSubview(logo)
        return v
    }

    func cnSplashPlaceholderImage() -> UIImage? {
        UIImage(named: "LaunchImage")
    }

    func showToast(_ message: String) {
        // 复用 IAP 一侧已实现的 toast，避免重复轮子。
        PixelMatchCashierUIProvider().showToast(message: message)
    }
}
