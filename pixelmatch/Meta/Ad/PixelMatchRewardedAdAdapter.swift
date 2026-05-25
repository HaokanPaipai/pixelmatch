//
//  PixelMatchRewardedAdAdapter.swift
//  pixelmatch
//
//  HKAdKit RewardedAdAdapting 的宿主实现。海外 = GADRewardedAd，
//  国内 = HKAdvertising 的 EasyAdRewardVideo。
//
//  没装 CocoaPods 时整体 no-op，方便单机测试 / 仅跑 BoardRulesTests。
//

import UIKit
import HKAdKit

#if canImport(GoogleMobileAds)
import GoogleMobileAds

final class PixelMatchRewardedAdAdapter: NSObject, RewardedAdAdapting {
    weak var delegate: RewardedAdAdapterDelegate?

    private var isOverseas: Bool { AdManager.shared.configProvider.region == .overseas }

    // 海外
    private var rewardedAd: GADRewardedAd?
    // 国内
    private var cnRewardVideo: EasyAdRewardVideo?
    private var cnLoaded = false

    var isAdAvailable: Bool {
        isOverseas ? (rewardedAd != nil) : cnLoaded
    }

    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {
        if isOverseas {
            GADMobileAds.sharedInstance().start(completionHandler: nil)
            Task { [weak self] in
                guard let self else { return }
                do {
                    let ad = try await GADRewardedAd.load(withAdUnitID: unitID, request: GADRequest())
                    ad.fullScreenContentDelegate = self
                    self.rewardedAd = ad
                    await MainActor.run { self.delegate?.rewardedDidLoad() }
                } catch {
                    self.rewardedAd = nil
                    await MainActor.run {
                        self.delegate?.rewardedDidFailToLoad(error.localizedDescription)
                    }
                }
            }
        } else {
            guard let json = cnSlotJSON,
                  let topVc = PixelMatchCashierUIProvider.topViewController() else {
                delegate?.rewardedDidFailToLoad("cn rewarded json/vc missing")
                return
            }
            cnLoaded = false
            let video = EasyAdRewardVideo(jsonDic: json, viewController: topVc)
            video.delegate = self
            self.cnRewardVideo = video
            video.loadAd()
        }
    }

    func showAd(from viewController: UIViewController) {
        if isOverseas {
            guard let ad = rewardedAd else {
                delegate?.rewardedDidFailToPresent("rewarded not ready")
                return
            }
            ad.present(fromRootViewController: viewController) { [weak self] in
                self?.delegate?.rewardedDidEarnReward()
            }
        } else {
            cnRewardVideo?.showAd()
        }
    }
}

// MARK: - 海外 GADFullScreenContentDelegate

extension PixelMatchRewardedAdAdapter: GADFullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        rewardedAd = nil
        delegate?.rewardedDidDismiss()
    }
    func ad(_ ad: GADFullScreenPresentingAd,
            didFailToPresentFullScreenContentWithError error: Error) {
        rewardedAd = nil
        delegate?.rewardedDidFailToPresent(error.localizedDescription)
    }
}

// MARK: - 国内 EasyAdRewardVideoDelegate

extension PixelMatchRewardedAdAdapter: EasyAdRewardVideoDelegate {
    func easyAdRewardVideoAdDidPlayFinish() {}
    func easyAdRewardVideoOnAdVideoCached() {
        cnLoaded = true
        delegate?.rewardedDidLoad()
    }
    func easyAdRewardVideoAdDidRewardEffective() {
        delegate?.rewardedDidEarnReward()
    }
    func easyAdDidClose() {
        cnLoaded = false
        delegate?.rewardedDidDismiss()
    }
    func easyAdExposured() {}
    func easyAdClicked() {}
    func easyAdUnifiedViewDidLoad() {}
    func easyAdFailedWithError(_ error: (any Error)!, description: [AnyHashable : Any]!) {
        cnLoaded = false
        delegate?.rewardedDidFailToPresent(error?.localizedDescription ?? "cn rewarded failed")
    }
}

#else

final class PixelMatchRewardedAdAdapter: NSObject, RewardedAdAdapting {
    weak var delegate: RewardedAdAdapterDelegate?
    var isAdAvailable: Bool { false }
    func loadAd(unitID: String, cnSlotJSON: [String: Any]?) {}
    func showAd(from viewController: UIViewController) {}
}

#endif
