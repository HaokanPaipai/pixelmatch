import Foundation

struct EconomyConfig {
    static let shared = EconomyConfig()

    let startingCoins = 500
    let startingDiamonds = 10

    let baseWinCoinsPerStar = 15
    let remainingMoveCoinBonus = 5
    let winStreakBonusStep = 10
    let winStreakBonusEvery = 3
    let maxWinStreakBonus = 50

    let outOfMovesContinueDiamonds = 10
    let lifeRefillDiamonds = 15

    let dailyBaseCoins = 50
    let dailyStreakCoinStep = 25
    let dailyStreakCap = 7
    let dailyMidStreakDiamonds = 2
    let dailyFullStreakDiamonds = 5

    let questRewardCoins = 120
    let questRewardDiamonds = 1
    let questDailyCount = 3

    let chestStarInterval = 12
    let chestCoins = 180
    let chestDiamonds = 3
    let chestHammer = 1
    let chestShuffle = 1

    let boosterCosts: [BoosterType: Int] = [
        .hammer: 50,
        .shuffle: 30,
        .extraMoves: 80,
        .colorBomb: 100
    ]

    func boosterCost(_ type: BoosterType) -> Int {
        boosterCosts[type] ?? 0
    }

    func winCoins(stars: Int, remainingMoves: Int, winStreak: Int) -> Int {
        let streakTier = min(winStreak / winStreakBonusEvery,
                             maxWinStreakBonus / max(1, winStreakBonusStep))
        return (stars + 1) * baseWinCoinsPerStar
            + remainingMoves * remainingMoveCoinBonus
            + streakTier * winStreakBonusStep
    }

    func dailyReward(for streak: Int) -> (coins: Int, diamonds: Int) {
        let cappedStreak = min(max(streak, 1), dailyStreakCap)
        let coins = dailyBaseCoins + cappedStreak * dailyStreakCoinStep
        let diamonds = cappedStreak == dailyStreakCap
            ? dailyFullStreakDiamonds
            : (cappedStreak >= 5 ? dailyMidStreakDiamonds : 0)
        return (coins, diamonds)
    }
}

// MARK: - 广告配置（由 PixelMatchAdConfigProvider 读取）

/// 广告位与频次常量。PixelMatch 暂未接云控，集中在此调参；上线前云控接入后改 provider 即可。
/// TODO: 接入云控（cloud-control key 命名参照 goodlook 的 i18n_show_* 系列）。
enum AdConfig {

    // MARK: 频次
    static let openAdDailyCap        = 10
    static let openAdMinInterval     : TimeInterval = 300   // 5min
    static let rewardedDailyCap      = 10
    static let interstitialDailyCap  = 20
    /// 关卡间触发，60s 内最多一次（避免连失/连胜疯狂插）
    static let interstitialMinInterval: TimeInterval = 60

    /// 频次存储用的 UserDefaults suite 名（多 App 隔离）。
    static let frequencySuiteName    = "com.goodloook.pixelmatch.ads"

    // MARK: Google 广告位 ID
    // Debug 走官方测试 unit id（必须用，否则审核会标违规）；Release 用 PixelMatch 自己 AdMob 账号正式 id。
    // AdMob App ID（GADApplicationIdentifier，对应 Info.plist）：ca-app-pub-8471055942691930~1210114236

    #if DEBUG
    static let googleOpenAdUnitID        = "ca-app-pub-3940256099942544/5575463023"
    static let googleRewardedAdUnitID    = "ca-app-pub-3940256099942544/1712485313"
    static let googleInterstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let googleOpenAdUnitID        = "ca-app-pub-8471055942691930/8126190610"
    static let googleRewardedAdUnitID    = "ca-app-pub-8471055942691930/1560782268"
    static let googleInterstitialAdUnitID = "ca-app-pub-8471055942691930/5338729802"
    // 备注：暂未接入"插页式激励广告 (Rewarded Interstitial)"——它是独立广告类型 (GADRewardedInterstitialAd)。
    // 若后续要做，需在 HKAdKit 加 RewardedInterstitialAdAdapting 协议 + adapter 实现并新增 unit id。
    #endif
}
