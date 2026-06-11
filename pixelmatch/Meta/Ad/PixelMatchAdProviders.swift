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

/// ⚠️「去广告」权益只应屏蔽**侵入式广告**（开屏 / 插屏），绝不该屏蔽**用户主动**触发的
/// 激励视频（+5 步 / +金币 / 补体力 / 免费续关）——那是玩家自愿的价值交换，付费用户同样该用得了。
///
/// 但 HKAdKit 的三个 controller（OpenAdCoordinator / InterstitialController / RewardedController）
/// 都用同一个 `isVip` 做 gate（RewardedController.swift:45 `guard !user.isVip`）。若把 isVip=true
/// 给 noAds 用户，会**连激励视频一起屏蔽**，导致付费玩家点「看广告续关」时静默失败。
///
/// 因此 isVip 恒为 false，侵入式广告改由 `isOpenAdEnabled` / `isInterstitialEnabled` 按
/// `PlayerData.noAds` 单独关闭（见下方 AdConfigProvider）。这样 noAds 用户：开屏/插屏全关、激励仍可用。
final class PixelMatchAdUserProvider: AdUserProvider {
    var isVip: Bool { false }
    var hasAgreedPrivacy: Bool { PlayerData.shared.hasAgreedPrivacy }
}

// MARK: - 运行期配置

final class PixelMatchAdConfigProvider: AdConfigProvider {

    /// HKAdKit v1.2：Google AdMob 单元 ID 经 plist 加载（替代 #if APPSTORE 硬编码）。
    /// 注意：plist 必须加入 Xcode target 的 Copy Bundle Resources，否则返 nil → ID 返 ""，广告不出。
    private static let adConfig: AdConfig? = {
        do {
            return try AdConfigLoader.load(from: "pixelmatch-AdConfig")
        } catch {
            #if DEBUG
            assertionFailure("[PixelMatchAdConfig] 加载 pixelmatch-AdConfig.plist 失败: \(error)。检查是否加入 Copy Bundle Resources。")
            #endif
            return nil
        }
    }()

    private var isAppStoreBuild: Bool {
        #if APPSTORE
        return true
        #else
        return false
        #endif
    }

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

    // 开屏（noAds 用户关闭——侵入式广告随「去广告」权益消失，见 [[PixelMatchAdUserProvider]]）
    var isOpenAdEnabled: Bool      { !PlayerData.shared.noAds }
    var openAdDailyCap: Int        { AdFrequencyConfig.openAdDailyCap }
    var openAdMinInterval: TimeInterval { AdFrequencyConfig.openAdMinInterval }
    var openAdUnitID: String       { Self.adConfig?.openAppUnitID(isAppStore: isAppStoreBuild) ?? "" }

    // 激励（始终开启：用户主动触发的价值交换，noAds 用户同样可用）
    var isRewardedEnabled: Bool    { true }
    var rewardedDailyCap: Int      { AdFrequencyConfig.rewardedDailyCap }
    var rewardedAdUnitID: String   { Self.adConfig?.rewardedUnitID(isAppStore: isAppStoreBuild) ?? "" }

    // 插屏（v1.1 协议字段；noAds 用户关闭）
    var isInterstitialEnabled: Bool { !PlayerData.shared.noAds }
    var interstitialDailyCap: Int   { AdFrequencyConfig.interstitialDailyCap }
    var interstitialMinInterval: TimeInterval { AdFrequencyConfig.interstitialMinInterval }
    var interstitialAdUnitID: String { Self.adConfig?.interstitialUnitID(isAppStore: isAppStoreBuild) ?? "" }

    var frequencySuiteName: String? { AdFrequencyConfig.frequencySuiteName }

    func cnAdSlotJSON(for format: AdFormat) -> [String: Any]? {
        let name: String
        switch format {
        case .openApp:      name = "SplashData"
        case .rewarded:     name = "RewardVideoData"
        case .interstitial: name = "InterstitialData"
        }
        guard let url = Bundle.main.url(forResource: name, withExtension: "json") else {
            #if DEBUG
            assertionFailure("[PixelMatchAdConfig] 找不到 \(name).json。检查是否加入 Copy Bundle Resources。")
            #endif
            return nil
        }
        do {
            let data = try Data(contentsOf: url)
            // 注意：JSONSerialization 严格，不容忍尾逗号等非标准写法，解析失败会抛错而非静默忽略。
            guard let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                #if DEBUG
                assertionFailure("[PixelMatchAdConfig] \(name).json 顶层不是对象。")
                #endif
                return nil
            }
            return obj
        } catch {
            #if DEBUG
            assertionFailure("[PixelMatchAdConfig] 解析 \(name).json 失败: \(error)。多半是 JSON 语法错误（如尾逗号）。")
            #endif
            return nil
        }
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
        switch event {
        case let .loadStart(format, network):
            log(.adLoadStart, format, network)
        case let .loaded(format, network):
            log(.adLoaded, format, network)
        case let .loadFailed(format, network, message):
            log(.adLoadFailed, format, network, extra: ["message": message])
        case let .willPresent(format, network):
            // willPresent 不单独埋点：曝光以 impression 为准，避免双计。
            _ = (format, network)
        case let .impression(format, network):
            log(.adImpression, format, network)
        case let .dismissed(format, network):
            log(.adDismissed, format, network)
        case let .clicked(format, network):
            log(.adClicked, format, network)
        case let .rewardEarned(placement, network):
            AnalyticsManager.shared.track(.adRewardEarned,
                                          properties: ["placement": placement.rawValue,
                                                       "network": network.rawValue])
        }
        #if DEBUG
        print("[Ad] \(event)")
        #endif
    }

    private func log(_ name: AnalyticsEventName, _ format: AdFormat, _ network: AdNetwork,
                     extra: [String: String] = [:]) {
        var props = ["format": Self.formatName(format), "network": network.rawValue]
        props.merge(extra) { _, new in new }
        AnalyticsManager.shared.track(name, properties: props)
    }

    private static func formatName(_ format: AdFormat) -> String {
        switch format {
        case .openApp:      return "open_app"
        case .rewarded:     return "rewarded"
        case .interstitial: return "interstitial"
        }
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
        // 复用启动屏 logo 资源（"LaunchImage" 资源并不存在，此前恒返 nil）。
        UIImage(named: "LaunchLogo")
    }

    func showToast(_ message: String) {
        // 复用 IAP 一侧已实现的 toast，避免重复轮子。
        PixelMatchCashierUIProvider().showToast(message: message)
    }
}
