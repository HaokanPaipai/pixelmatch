import Foundation

enum DailyQuestKind: String, Codable, CaseIterable {
    case completeLevels
    case createSpecials
    case useBoosters
    case clearJelly
    case breakIce
    case clearChocolate
    case createColorBombs
    case triggerSpecialCombos
    case winWithoutBoosters

    var title: String {
        switch self {
        case .completeLevels: return L10n.tr("quest.win_levels", fallback: "Win Levels")
        case .createSpecials: return L10n.tr("quest.make_specials", fallback: "Make Specials")
        case .useBoosters: return L10n.tr("quest.use_boosters", fallback: "Use Boosters")
        case .clearJelly: return L10n.tr("quest.clear_jelly", fallback: "Clear Jelly")
        case .breakIce: return L10n.tr("quest.break_ice", fallback: "Break Ice")
        case .clearChocolate: return L10n.tr("quest.clear_chocolate", fallback: "Clear Chocolate")
        case .createColorBombs: return L10n.tr("quest.make_color_bombs", fallback: "Make Color Bombs")
        case .triggerSpecialCombos: return L10n.tr("quest.special_combos", fallback: "Special Combos")
        case .winWithoutBoosters: return L10n.tr("quest.no_booster_win", fallback: "No-Booster Wins")
        }
    }
}

private struct DailyQuestTemplate {
    let id: String
    let kind: DailyQuestKind
    let target: Int
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
        saveQuests(dailyQuestTemplates().map {
            DailyQuest(id: $0.id, kind: $0.kind, target: $0.target, progress: 0, claimed: false)
        })
    }

    func recordLevelWin(usedBooster: Bool = false) {
        increment(.completeLevels, by: 1)
        if !usedBooster {
            increment(.winWithoutBoosters, by: 1)
        }
    }

    func recordSpecialsCreated(_ count: Int) {
        guard count > 0 else { return }
        increment(.createSpecials, by: count)
    }

    func recordColorBombsCreated(_ count: Int) {
        guard count > 0 else { return }
        increment(.createColorBombs, by: count)
    }

    func recordSpecialComboActivated() {
        increment(.triggerSpecialCombos, by: 1)
    }

    func recordBoosterUsed() {
        increment(.useBoosters, by: 1)
    }

    func recordJellyCleared(_ count: Int) {
        guard count > 0 else { return }
        increment(.clearJelly, by: count)
    }

    func recordIceCleared(_ count: Int) {
        guard count > 0 else { return }
        increment(.breakIce, by: count)
    }

    func recordChocolateCleared(_ count: Int) {
        guard count > 0 else { return }
        increment(.clearChocolate, by: count)
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
        SeasonPassManager.shared.addPoints(SeasonPassManager.pointsPerQuestClaim, source: "quest")
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
        // 周挑战进度统一在此转发（原始量，不吃日常任务的活动加成）
        LiveEventManager.shared.recordWeeklyProgress(kind: kind, amount: amount)
        let adjustedAmount = amount * LiveEventManager.shared.progressMultiplier(for: kind)
        var quests = loadQuests()
        for index in quests.indices where quests[index].kind == kind && !quests[index].claimed {
            quests[index].progress = min(quests[index].target, quests[index].progress + adjustedAmount)
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

    private func dailyQuestTemplates() -> [DailyQuestTemplate] {
        let catalog = [
            DailyQuestTemplate(id: "win_levels", kind: .completeLevels, target: 3),
            DailyQuestTemplate(id: "make_specials", kind: .createSpecials, target: 12),
            DailyQuestTemplate(id: "clear_jelly", kind: .clearJelly, target: 24),
            DailyQuestTemplate(id: "break_ice", kind: .breakIce, target: 18),
            DailyQuestTemplate(id: "clear_chocolate", kind: .clearChocolate, target: 12),
            DailyQuestTemplate(id: "make_color_bombs", kind: .createColorBombs, target: 3),
            DailyQuestTemplate(id: "special_combos", kind: .triggerSpecialCombos, target: 4),
            DailyQuestTemplate(id: "no_booster_win", kind: .winWithoutBoosters, target: 2),
            DailyQuestTemplate(id: "use_boosters", kind: .useBoosters, target: 2)
        ]
        guard !catalog.isEmpty else { return [] }

        let count = min(EconomyConfig.shared.questDailyCount, catalog.count)
        let start = dailyRotationSeed % catalog.count
        return (0..<count).map { catalog[($0 + start) % catalog.count] }
    }

    private var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private var dailyRotationSeed: Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return (components.year ?? 0) * 372 + (components.month ?? 0) * 31 + (components.day ?? 0)
    }
}
