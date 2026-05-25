//
//  PixelMatchInterstitialAdapter.swift
//  pixelmatch
//
//  HKAdKit InterstitialAdAdapting 的宿主实现（v1.1 新增）。
//  海外 = GADInterstitialAd，国内 = HKAdvertising 的 EasyAdInterstitial。
//
//  与 Rewarded adapter 形状完全对称，只是没有"奖励"回调。
//

import UIKit
import HKAdKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class PixelMatchInterstitialAdapter: NSObject, InterstitialAdAdapting {
    weak var delegate: InterstitialAdAdapterDelegate?

    private var isOverseas: Bool { AdManager.shared.configProvider.region == .overseas }

    // 海外
    private var interstitial: GADInterstitialAd?
    // 国内
    private var cnInterstitial: EasyAdInterstitial?
    private var cnLoaded = false

    var isAdAvailable: Bool {
        isOverseas ? (interstitial != nil) : cnLoaded
    }

    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {
        if isOverseas {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let ad = try await GADInterstitialAd.load(withAdUnitID: unitID,
                                                              request: GADRequest())
                    ad.fullScreenContentDelegate = self
                    self.interstitial = ad
                    await MainActor.run { self.delegate?.interstitialDidLoad() }
                } catch {
                    self.interstitial = nil
                    await MainActor.run {
                        self.delegate?.interstitialDidFailToLoad(error.localizedDescription)
                    }
                }
            }
        } else {
            guard let json = cnSlotJSON,
                  let topVc = PixelMatchCashierUIProvider.topViewController() else {
                delegate?.interstitialDidFailToLoad("cn interstitial json/vc missing")
                return
            }
            cnLoaded = false
            let ad = EasyAdInterstitial(jsonDic: json, viewController: topVc)
            ad.delegate = self
            self.cnInterstitial = ad
            ad.loadAd()
        }
    }

    func showAd(from viewController: UIViewController) {
        if isOverseas {
            guard let ad = interstitial else {
                delegate?.interstitialDidFailToPresent("interstitial not ready")
                return
            }
            ad.present(fromRootViewController: viewController)
        } else {
            cnInterstitial?.showAd()
        }
    }
}

// MARK: - 海外 GADFullScreenContentDelegate

extension PixelMatchInterstitialAdapter: GADFullScreenContentDelegate {
    func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        delegate?.interstitialWillPresent()
    }
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        interstitial = nil
        delegate?.interstitialDidDismiss()
    }
    func ad(_ ad: GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        interstitial = nil
        delegate?.interstitialDidFailToPresent(error.localizedDescription)
    }
}

// MARK: - 国内 EasyAdInterstitialDelegate

extension PixelMatchInterstitialAdapter: EasyAdInterstitialDelegate {
    func easyAdInterstitialOnAdLoadSuccess() {
        cnLoaded = true
        delegate?.interstitialDidLoad()
    }
    func easyAdExposured() { delegate?.interstitialWillPresent() }
    func easyAdDidClose() {
        cnLoaded = false
        delegate?.interstitialDidDismiss()
    }
    func easyAdClicked() {}
    func easyAdUnifiedViewDidLoad() {}
    func easyAdFailedWithError(_ error: (any Error)!, description: [AnyHashable : Any]!) {
        cnLoaded = false
        delegate?.interstitialDidFailToPresent(error?.localizedDescription ?? "cn interstitial failed")
    }
    func easyAdSupplierWillLoad(_ supplierId: String!) {}
}

#else

final class PixelMatchInterstitialAdapter: NSObject, InterstitialAdAdapting {
    weak var delegate: InterstitialAdAdapterDelegate?
    var isAdAvailable: Bool { false }
    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {}
    func showAd(from viewController: UIViewController) {}
}

#endif
