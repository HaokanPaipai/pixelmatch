import Foundation

/// 赛季通行证：28 天一季，免费 + 付费双轨各 30 级，纯客户端实现（本地赛季日历）。
/// 积分来源挂在现有结算钩子上（关卡胜利/星星/每日任务/周挑战），不开新埋点链路。
/// 付费解锁走 IAPManager 既有验票链（消耗品 seasonpass，每季重购，本地记录有效季）。
final class SeasonPassManager {
    static let shared = SeasonPassManager()

    private let defaults = UserDefaults.standard
    private enum Key {
        static let seasonIndex = "pass.seasonIndex"
        static let points = "pass.points"
        static let claimedFree = "pass.claimedFree"
        static let claimedPremium = "pass.claimedPremium"
        static let purchasedSeason = "pass.purchasedSeason"
    }

    /// 赛季纪元：2026-06-08（周一）。seasonIndex = 距纪元天数 / 28。
    private static let epoch: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 6; c.day = 8
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }()

    static let seasonLengthDays = 28
    static let maxLevel = 30
    static let pointsPerLevel = 100

    // 积分来源（挂现有钩子，调用方一行接入）
    static let pointsPerLevelWin = 10
    static let pointsPerBossWin = 30
    static let pointsPerStar = 5
    static let pointsPerQuestClaim = 20
    static let pointsPerWeeklyChallenge = 100

    private init() {}

    // MARK: - 赛季日历

    func seasonIndex(on date: Date = Date()) -> Int {
        let days = Calendar(identifier: .gregorian)
            .dateComponents([.day], from: SeasonPassManager.epoch, to: date).day ?? 0
        return max(0, days / SeasonPassManager.seasonLengthDays)
    }

    func seasonEndDate(on date: Date = Date()) -> Date {
        let nextIndex = seasonIndex(on: date) + 1
        return Calendar(identifier: .gregorian)
            .date(byAdding: .day,
                  value: nextIndex * SeasonPassManager.seasonLengthDays,
                  to: SeasonPassManager.epoch)!
    }

    /// 跨季自动重置：所有访问入口先经此校验。进度/领取/付费解锁均按季作废。
    private func syncSeason(now: Date = Date()) {
        let current = seasonIndex(on: now)
        guard defaults.integer(forKey: Key.seasonIndex) != current else { return }
        defaults.set(current, forKey: Key.seasonIndex)
        defaults.set(0, forKey: Key.points)
        defaults.set([Int](), forKey: Key.claimedFree)
        defaults.set([Int](), forKey: Key.claimedPremium)
        // purchasedSeason 不清：留档用于"该季是否买过"判断，跨季自然失效
    }

    // MARK: - 积分与等级

    var points: Int {
        syncSeason()
        return defaults.integer(forKey: Key.points)
    }

    var level: Int {
        max(0, min(SeasonPassManager.maxLevel, points / SeasonPassManager.pointsPerLevel))
    }

    func addPoints(_ amount: Int, source: String) {
        guard amount > 0 else { return }
        syncSeason()
        let before = level
        defaults.set(defaults.integer(forKey: Key.points) + amount, forKey: Key.points)
        AnalyticsManager.shared.track(.passPointsEarned,
                                      properties: ["amount": "\(amount)", "source": source,
                                                   "total": "\(points)"])
        if level > before {
            NotificationCenter.default.post(name: .seasonPassLevelUp, object: nil)
        }
    }

    // MARK: - 付费轨

    var isPremium: Bool {
        syncSeason()
        return defaults.integer(forKey: Key.purchasedSeason) == seasonIndex() + 1 // +1 避开默认值 0
    }

    /// IAP 验票成功后由 IAPProduct.apply() 调用（幂等：重复调用同季无副作用）
    func activatePremiumForCurrentSeason() {
        syncSeason()
        defaults.set(seasonIndex() + 1, forKey: Key.purchasedSeason)
        AnalyticsManager.shared.track(.passPurchase,
                                      properties: ["season": "\(seasonIndex())"])
    }

    // MARK: - 奖励表（30 级双轨，硬编码；经济校准：付费轨总价值 ≈ diamonds80 档 1.5 倍）

    func freeReward(at level: Int) -> RewardBundle {
        switch level {
        case 5, 15, 25: return RewardBundle(coins: 0, diamonds: 2)
        case 10:        return RewardBundle(coins: 0, diamonds: 0, hammer: 1)
        case 20:        return RewardBundle(coins: 0, diamonds: 0, shuffle: 1)
        case 30:        return RewardBundle(coins: 300, diamonds: 5)
        default:        return RewardBundle(coins: 60)
        }
    }

    func premiumReward(at level: Int) -> RewardBundle {
        switch level {
        case 3, 8, 13, 18, 23, 28: return RewardBundle(coins: 0, diamonds: 5)
        case 5, 15:                return RewardBundle(coins: 0, diamonds: 0, hammer: 1, shuffle: 1)
        case 10, 20:               return RewardBundle(coins: 250, diamonds: 3)
        case 25:                   return RewardBundle(coins: 0, diamonds: 8)
        case 30:                   return RewardBundle(coins: 500, diamonds: 15, hammer: 2, shuffle: 2)
        default:                   return RewardBundle(coins: 120)
        }
    }

    // MARK: - 领取

    func isClaimed(level: Int, premium: Bool) -> Bool {
        syncSeason()
        let key = premium ? Key.claimedPremium : Key.claimedFree
        return (defaults.array(forKey: key) as? [Int] ?? []).contains(level)
    }

    var claimableCount: Int {
        syncSeason()
        let unlockedLevel = level
        guard unlockedLevel >= 1 else { return 0 }
        var count = 0
        for lv in 1...unlockedLevel {
            if !isClaimed(level: lv, premium: false) { count += 1 }
            if isPremium && !isClaimed(level: lv, premium: true) { count += 1 }
        }
        return count
    }

    /// 领取某级奖励（幂等：已领/未达级/付费轨未解锁返回 nil）
    @discardableResult
    func claim(level lv: Int, premium: Bool) -> RewardBundle? {
        syncSeason()
        guard lv >= 1, lv <= level else { return nil }
        guard !premium || isPremium else { return nil }
        guard !isClaimed(level: lv, premium: premium) else { return nil }

        let key = premium ? Key.claimedPremium : Key.claimedFree
        var claimed = defaults.array(forKey: key) as? [Int] ?? []
        claimed.append(lv)
        defaults.set(claimed, forKey: key)

        let reward = premium ? premiumReward(at: lv) : freeReward(at: lv)
        apply(reward)
        AnalyticsManager.shared.track(.passRewardClaimed,
                                      properties: ["level": "\(lv)",
                                                   "track": premium ? "premium" : "free"])
        return reward
    }

    private func apply(_ reward: RewardBundle) {
        if reward.coins > 0 { PlayerData.shared.addCoins(reward.coins) }
        if reward.diamonds > 0 { PlayerData.shared.addDiamonds(reward.diamonds) }
        if reward.hammer > 0 { PlayerData.shared.hammerCount += reward.hammer }
        if reward.shuffle > 0 { PlayerData.shared.shuffleCount += reward.shuffle }
    }
}

extension Notification.Name {
    static let seasonPassLevelUp = Notification.Name("seasonPassLevelUp")
}
