//
//  PixelMatchOpenAdAdapter.swift
//  pixelmatch
//
//  HKAdKit OpenAdAdapting 的宿主实现。海外 = GADAppOpenAd，国内 = HKAdSplash。
//  PixelMatch 直接照搬 goodlook 同名 adapter，仅去掉 goodlook 特有的依赖
//  （改读 PixelMatchAdConfigProvider.region 经 HKAdKit 提供的 AdRegion 推断）。
//
//  ⚠️ 没装 CocoaPods（GoogleMobileAds + HKAdvertising）时，本文件整体编译为 no-op，
//  保证 PixelMatch 仍可独立构建跑 BoardRulesTests。pod install 后自动启用真实链路。
//

import UIKit
import HKAdKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds
#if canImport(UserMessagingPlatform)
import UserMessagingPlatform
#endif

final class PixelMatchOpenAdAdapter: NSObject, OpenAdAdapting {
    weak var delegate: OpenAdAdapterDelegate?

    private var isOverseas: Bool { AdManager.shared.configProvider.region == .overseas }

    // 海外
    private var appOpenAd: GADAppOpenAd?
    private var loadTime: Date?
    private var isLoading = false
    private let timeoutInterval: TimeInterval = 4 * 3600

    // 国内
    private var hkAdSplash: HKAdSplash?

    var isAdAvailable: Bool {
        guard isOverseas else { return false } // HKAdSplash 为 load+show 一体，无缓存语义
        guard appOpenAd != nil, let t = loadTime else { return false }
        return Date().timeIntervalSince(t) < timeoutInterval
    }

    func prepareConsent(completion: @escaping (Bool) -> Void) {
        guard isOverseas else { completion(true); return } // 国内合规走《用户协议》同意，不走 UMP
        #if canImport(UserMessagingPlatform)
        // 海外 GDPR：经 UMP 拉取同意信息，必要时弹同意表单。任何环节失败都「fail open」
        // （仍允许请求广告，由 AdMob 兜底走非个性化广告），避免合规流程把广告全堵死。
        DispatchQueue.main.async {
            let params = RequestParameters()
            params.isTaggedForUnderAgeOfConsent = false
            ConsentInformation.shared.requestConsentInfoUpdate(with: params) { error in
                if error != nil {
                    completion(true); return
                }
                let present = {
                    let topVc = PixelMatchCashierUIProvider.topViewController()
                    ConsentForm.loadAndPresentIfRequired(from: topVc) { _ in
                        completion(ConsentInformation.shared.canRequestAds)
                    }
                }
                if Thread.isMainThread { present() } else { DispatchQueue.main.async(execute: present) }
            }
        }
        #else
        // 未链接 GoogleUserMessagingPlatform：直接放行（非 EEA 构建或纯单机测试）。
        completion(true)
        #endif
    }

    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {
        if isOverseas {
            guard !isLoading, !isAdAvailable else { return }
            isLoading = true
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let ad = try await GADAppOpenAd.load(withAdUnitID: unitID, request: GADRequest())
                    ad.fullScreenContentDelegate = self
                    self.appOpenAd = ad
                    self.loadTime = Date()
                    self.isLoading = false
                    await MainActor.run { self.delegate?.openAdDidLoad() }
                } catch {
                    self.appOpenAd = nil
                    self.loadTime = nil
                    self.isLoading = false
                    await MainActor.run {
                        self.delegate?.openAdDidFailToLoad(error.localizedDescription)
                    }
                }
            }
        } else {
            guard let json = cnSlotJSON else {
                delegate?.openAdDidFailToLoad("cn splash json missing")
                return
            }
            let splash = HKAdSplash(jsonDic: json, viewController: nil)
            splash.delegate = self
            splash.showLogoRequire = true
            if let logo = UIImage(named: "launch_logo") { splash.logoImage = logo }
            splash.timeout = 5
            self.hkAdSplash = splash
        }
    }

    func showAd(placeholder: UIImage?) {
        if isOverseas {
            guard let ad = appOpenAd else { return }
            // 显式传当前顶层 VC（SpriteKit 容器层级下传 nil 可能取不到正确 root）。
            ad.present(fromRootViewController: PixelMatchCashierUIProvider.topViewController())
        } else {
            if let placeholder { hkAdSplash?.backgroundImage = placeholder }
            hkAdSplash?.loadAndShowAd()
        }
    }
}

// MARK: - 海外 GADFullScreenContentDelegate

extension PixelMatchOpenAdAdapter: GADFullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.openAdWillPresent()
    }
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        appOpenAd = nil; loadTime = nil
        delegate?.openAdDidDismiss()
    }
    func ad(_ ad: GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        appOpenAd = nil; loadTime = nil
        delegate?.openAdDidFailToPresent(error.localizedDescription)
    }
}

// MARK: - 国内 EasyAdSplashDelegate（经 bridging header 暴露的 ObjC protocol）

extension PixelMatchOpenAdAdapter: EasyAdSplashDelegate {
    func easyAdUnifiedViewDidLoad() {}
    func easyAdExposured() {
        // CN：曝光成功 ≈ 已上屏。映射为 willPresent 触发频次记账。
        delegate?.openAdWillPresent()
    }
    func easyAdFailedWithError(_ error: (any Error)!, description: [AnyHashable : Any]!) {
        delegate?.openAdDidFailToPresent(error?.localizedDescription ?? "cn splash failed")
    }
    func easyAdSupplierWillLoad(_ supplierId: String!) {}
    func easyAdClicked() {}
    func easyAdDidClose() { delegate?.openAdDidDismiss() }
    func easyAdSplashOnAdCountdownToZero() {}
    func easyAdSplashOnAdSkipClicked() {}
    func easyAdSuccessSortTag(_ sortTag: String!) {}
}

#else

// 无广告 SDK（未 pod install）：no-op stub，保证 HKAdKit setup 即使没注入也安全。
final class PixelMatchOpenAdAdapter: NSObject, OpenAdAdapting {
    weak var delegate: OpenAdAdapterDelegate?
    var isAdAvailable: Bool { false }
    func prepareConsent(completion: @escaping (Bool) -> Void) { completion(false) }
    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {}
    func showAd(placeholder: UIImage?) {}
}

#endif
