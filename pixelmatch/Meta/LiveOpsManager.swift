import Foundation

enum DailyQuestKind: String, Codable {
    case completeLevels
    case createSpecials
    case useBoosters

    var title: String {
        switch self {
        case .completeLevels: return "Win Levels"
        case .createSpecials: return "Make Specials"
        case .useBoosters: return "Use Boosters"
        }
    }
}

struct DailyQuest: Codable {
    let id: String
    let kind: DailyQuestKind
    let target: Int
    var progress: Int
    var claimed: Bool

    var isComplete: Bool { progress >= target }
    var displayText: String { "\(kind.title): \(min(progress, target))/\(target)" }
}

struct RewardBundle {
    var coins: Int = 0
    var diamonds: Int = 0
    var hammer: Int = 0
    var shuffle: Int = 0
}

final class LiveOpsManager {
    static let shared = LiveOpsManager()

    private let defaults = UserDefaults.standard
    private let questDateKey = "liveops.questDate"
    private let questsKey = "liveops.quests"
    private let claimedChestStarsKey = "liveops.claimedChestStars"

    private init() {}

    var quests: [DailyQuest] {
        refreshDailyQuestsIfNeeded()
        return loadQuests()
    }

    var completedUnclaimedQuestCount: Int {
        quests.filter { $0.isComplete && !$0.claimed }.count
    }

    var chestProgress: (current: Int, target: Int) {
        let target = EconomyConfig.shared.chestStarInterval
        let claimed = defaults.integer(forKey: claimedChestStarsKey)
        let current = max(0, PlayerData.shared.totalStars - claimed)
        return (min(current, target), target)
    }

    var canClaimChest: Bool {
        chestProgress.current >= chestProgress.target
    }

    func refreshDailyQuestsIfNeeded() {
        guard defaults.string(forKey: questDateKey) != todayKey else { return }
        defaults.set(todayKey, forKey: questDateKey)
        saveQuests([
            DailyQuest(id: "win_levels", kind: .completeLevels, target: 3, progress: 0, claimed: false),
            DailyQuest(id: "make_specials", kind: .createSpecials, target: 12, progress: 0, claimed: false),
            DailyQuest(id: "use_boosters", kind: .useBoosters, target: 2, progress: 0, claimed: false)
        ])
    }

    func recordLevelWin() {
        increment(.completeLevels, by: 1)
    }

    func recordSpecialsCreated(_ count: Int) {
        guard count > 0 else { return }
        increment(.createSpecials, by: count)
    }

    func recordBoosterUsed() {
        increment(.useBoosters, by: 1)
    }

    func claimQuest(id: String) -> RewardBundle? {
        var quests = loadQuests()
        guard let index = quests.firstIndex(where: { $0.id == id }),
              quests[index].isComplete,
              !quests[index].claimed else { return nil }

        quests[index].claimed = true
        saveQuests(quests)

        let reward = RewardBundle(coins: EconomyConfig.shared.questRewardCoins,
                                  diamonds: EconomyConfig.shared.questRewardDiamonds)
        apply(reward)
        AnalyticsManager.shared.track(.questClaimed,
                                      properties: ["quest": id,
                                                   "coins": "\(reward.coins)",
                                                   "diamonds": "\(reward.diamonds)"])
        return reward
    }

    func claimChest() -> RewardBundle? {
        guard canClaimChest else { return nil }
        let target = EconomyConfig.shared.chestStarInterval
        let claimed = defaults.integer(forKey: claimedChestStarsKey)
        defaults.set(claimed + target, forKey: claimedChestStarsKey)

        let reward = RewardBundle(coins: EconomyConfig.shared.chestCoins,
                                  diamonds: EconomyConfig.shared.chestDiamonds,
                                  hammer: EconomyConfig.shared.chestHammer,
                                  shuffle: EconomyConfig.shared.chestShuffle)
        apply(reward)
        AnalyticsManager.shared.track(.chestClaimed,
                                      properties: ["coins": "\(reward.coins)",
                                                   "diamonds": "\(reward.diamonds)",
                                                   "hammer": "\(reward.hammer)",
                                                   "shuffle": "\(reward.shuffle)"])
        return reward
    }

    private func increment(_ kind: DailyQuestKind, by amount: Int) {
        refreshDailyQuestsIfNeeded()
        var quests = loadQuests()
        for index in quests.indices where quests[index].kind == kind && !quests[index].claimed {
            quests[index].progress = min(quests[index].target, quests[index].progress + amount)
        }
        saveQuests(quests)
    }

    private func apply(_ reward: RewardBundle) {
        if reward.coins > 0 { PlayerData.shared.addCoins(reward.coins) }
        if reward.diamonds > 0 { PlayerData.shared.addDiamonds(reward.diamonds) }
        if reward.hammer > 0 { PlayerData.shared.hammerCount += reward.hammer }
        if reward.shuffle > 0 { PlayerData.shared.shuffleCount += reward.shuffle }
    }

    private func loadQuests() -> [DailyQuest] {
        guard let data = defaults.data(forKey: questsKey),
              let quests = try? JSONDecoder().decode([DailyQuest].self, from: data) else {
            return []
        }
        return quests
    }

    private func saveQuests(_ quests: [DailyQuest]) {
        guard let data = try? JSONEncoder().encode(quests) else { return }
        defaults.set(data, forKey: questsKey)
    }

    private var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }
}
