import UIKit

// Stub AdManager — replace with Google AdMob or AppLovin MAX SDK
// when ready for production monetization.

@MainActor
final class AdManager {
    static let shared = AdManager()
    private init() {}

    private var isRewardedAdReady = false
    private var isInterstitialReady = false
    private var rewardCompletion: ((Bool) -> Void)?

    // Called once at app launch
    func initialize() {
        // TODO: AdMob: GADMobileAds.sharedInstance().start(completionHandler: nil)
        // Simulate ad readiness after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.isRewardedAdReady = true
            self.isInterstitialReady = true
        }
    }

    // Show rewarded ad (e.g., for free booster or extra moves)
    func showRewardedAd(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        guard !PlayerData.shared.noAds else {
            completion(false)
            return
        }

        guard isRewardedAdReady else {
            completion(false)
            return
        }

        rewardCompletion = completion

        // TODO: Replace with real rewarded ad presentation:
        // let ad = GADRewardedAd(adUnitID: "ca-app-pub-XXXXX")
        // ad.present(fromRootViewController: vc, userDidEarnRewardHandler: { ... })

        // Stub: simulate watching a 5-second ad
        let alert = UIAlertController(title: "Watch Ad",
                                       message: "Simulating ad view (5 seconds)...",
                                       preferredStyle: .alert)
        vc.present(alert, animated: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            alert.dismiss(animated: true) {
                self.isRewardedAdReady = false
                self.rewardCompletion?(true)
                self.rewardCompletion = nil
                // Reload for next time
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.isRewardedAdReady = true
                }
            }
        }
    }

    // Show interstitial after level failure (non-intrusive)
    func showInterstitialIfReady(from vc: UIViewController) {
        guard !PlayerData.shared.noAds, isInterstitialReady else { return }

        // Only show 1 in 3 attempts to avoid being annoying
        guard Int.random(in: 0..<3) == 0 else { return }

        // TODO: Replace with real interstitial:
        // GADInterstitialAd.load(with: "ca-app-pub-XXXXX", ...) { ad in ad.present(from: vc) }

        isInterstitialReady = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.isInterstitialReady = true
        }
    }

    var canShowRewardedAd: Bool {
        !PlayerData.shared.noAds && isRewardedAdReady
    }
}
