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

// MARK: - 广告频次配置（由 PixelMatchAdConfigProvider 读取）

/// 广告频次常量。Google 单元 ID 已迁出到 pixelmatch-AdConfig.plist（HKAdKit v1.2 范式）。
/// 命名 `AdFrequencyConfig` 避开 HKAdKit 导出的 public struct AdConfig 名字冲突。
/// PixelMatch 暂未接云控，集中在此调参；上线前云控接入后改 provider 即可。
/// TODO: 接入云控（cloud-control key 命名参照 goodlook 的 i18n_show_* 系列）。
enum AdFrequencyConfig {

    static let openAdDailyCap        = 10
    static let openAdMinInterval     : TimeInterval = 300   // 5min
    static let rewardedDailyCap      = 10
    static let interstitialDailyCap  = 20
    /// 关卡间触发，60s 内最多一次（避免连失/连胜疯狂插）
    static let interstitialMinInterval: TimeInterval = 60

    /// 频次存储用的 UserDefaults suite 名（多 App 隔离）。
    static let frequencySuiteName    = "com.goodloook.pixelmatch.ads"
}
