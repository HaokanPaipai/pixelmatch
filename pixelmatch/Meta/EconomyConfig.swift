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
