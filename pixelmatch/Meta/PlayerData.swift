import Foundation

final class PlayerData {

    static let shared = PlayerData()
    private let defaults = UserDefaults.standard

    private init() {}

    // MARK: - Keys

    private enum Key {
        static let noAds            = "noAds"
        static let winStreak        = "winStreak"
        static let maxUnlockedLevel = "maxUnlockedLevel"
        static let levelStars       = "levelStars"
        static let levelBestScore   = "levelBestScore"
        static let coins            = "coins"
        static let diamonds         = "diamonds"
        static let totalScore       = "totalScore"
        static let totalMatches     = "totalMatches"
        static let livesCount       = "livesCount"
        static let lastLifeTime     = "lastLifeTime"
        static let lastDailyReward  = "lastDailyReward"
        static let dailyStreak      = "dailyStreak"
        static let soundEnabled     = "soundEnabled"
        static let musicEnabled     = "musicEnabled"
        static let vibrateEnabled   = "vibrateEnabled"
        static let playerName       = "playerName"
        static let firstLaunch      = "firstLaunch"
        static let totalPlayTime    = "totalPlayTime"
        static let boosterHammer    = "boosterHammer"
        static let boosterShuffle   = "boosterShuffle"
        static let boosterExtraMoves = "boosterExtraMoves"
        static let boosterColorBomb = "boosterColorBomb"
        static let tutorialComplete = "tutorialComplete"
    }

    // MARK: - Progress

    var maxUnlockedLevel: Int {
        get { max(1, defaults.integer(forKey: Key.maxUnlockedLevel)) }
        set { defaults.set(newValue, forKey: Key.maxUnlockedLevel) }
    }

    func stars(forLevel id: Int) -> Int {
        let d = defaults.dictionary(forKey: Key.levelStars) as? [String: Int] ?? [:]
        return d["\(id)"] ?? 0
    }

    func setStars(_ stars: Int, forLevel id: Int) {
        var d = defaults.dictionary(forKey: Key.levelStars) as? [String: Int] ?? [:]
        let current = d["\(id)"] ?? 0
        if stars > current { d["\(id)"] = stars }
        defaults.set(d, forKey: Key.levelStars)
    }

    func bestScore(forLevel id: Int) -> Int {
        let d = defaults.dictionary(forKey: Key.levelBestScore) as? [String: Int] ?? [:]
        return d["\(id)"] ?? 0
    }

    func setBestScore(_ score: Int, forLevel id: Int) {
        var d = defaults.dictionary(forKey: Key.levelBestScore) as? [String: Int] ?? [:]
        let current = d["\(id)"] ?? 0
        if score > current { d["\(id)"] = score }
        defaults.set(d, forKey: Key.levelBestScore)
    }

    func unlockLevel(_ id: Int) {
        if id > maxUnlockedLevel { maxUnlockedLevel = id }
    }

    func isLevelUnlocked(_ id: Int) -> Bool {
        id <= maxUnlockedLevel
    }

    var totalStars: Int {
        let d = defaults.dictionary(forKey: Key.levelStars) as? [String: Int] ?? [:]
        return d.values.reduce(0, +)
    }

    // MARK: - Currency

    var coins: Int {
        get {
            let v = defaults.integer(forKey: Key.coins)
            return v == 0 && !defaults.bool(forKey: Key.firstLaunch) ? EconomyConfig.shared.startingCoins : v
        }
        set { defaults.set(newValue, forKey: Key.coins) }
    }

    var diamonds: Int {
        get {
            let v = defaults.integer(forKey: Key.diamonds)
            return v == 0 && !defaults.bool(forKey: Key.firstLaunch) ? EconomyConfig.shared.startingDiamonds : v
        }
        set { defaults.set(newValue, forKey: Key.diamonds) }
    }

    func spendCoins(_ amount: Int) -> Bool {
        guard coins >= amount else { return false }
        coins -= amount
        AnalyticsManager.shared.track(.currencyChanged,
                                      properties: ["currency": "coins", "delta": "-\(amount)", "reason": "spend"])
        return true
    }

    func addCoins(_ amount: Int) {
        coins += amount
        AnalyticsManager.shared.track(.currencyChanged,
                                      properties: ["currency": "coins", "delta": "\(amount)", "reason": "earn"])
    }

    func spendDiamonds(_ amount: Int) -> Bool {
        guard diamonds >= amount else { return false }
        diamonds -= amount
        AnalyticsManager.shared.track(.currencyChanged,
                                      properties: ["currency": "diamonds", "delta": "-\(amount)", "reason": "spend"])
        return true
    }

    func addDiamonds(_ amount: Int) {
        diamonds += amount
        AnalyticsManager.shared.track(.currencyChanged,
                                      properties: ["currency": "diamonds", "delta": "\(amount)", "reason": "earn"])
    }

    // MARK: - Stats

    var totalScore: Int {
        get { defaults.integer(forKey: Key.totalScore) }
        set { defaults.set(newValue, forKey: Key.totalScore) }
    }

    var totalMatches: Int {
        get { defaults.integer(forKey: Key.totalMatches) }
        set { defaults.set(newValue, forKey: Key.totalMatches) }
    }

    // MARK: - Settings

    var soundEnabled: Bool {
        get { defaults.object(forKey: Key.soundEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.soundEnabled) }
    }

    var musicEnabled: Bool {
        get { defaults.object(forKey: Key.musicEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.musicEnabled) }
    }

    var vibrateEnabled: Bool {
        get { defaults.object(forKey: Key.vibrateEnabled) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Key.vibrateEnabled) }
    }

    var playerName: String {
        get { defaults.string(forKey: Key.playerName) ?? "Pixel Hero" }
        set { defaults.set(newValue, forKey: Key.playerName) }
    }

    // MARK: - Boosters

    var hammerCount: Int {
        get { defaults.integer(forKey: Key.boosterHammer) }
        set { defaults.set(newValue, forKey: Key.boosterHammer) }
    }

    var shuffleCount: Int {
        get { defaults.integer(forKey: Key.boosterShuffle) }
        set { defaults.set(newValue, forKey: Key.boosterShuffle) }
    }

    var extraMovesCount: Int {
        get { defaults.integer(forKey: Key.boosterExtraMoves) }
        set { defaults.set(newValue, forKey: Key.boosterExtraMoves) }
    }

    var colorBombCount: Int {
        get { defaults.integer(forKey: Key.boosterColorBomb) }
        set { defaults.set(newValue, forKey: Key.boosterColorBomb) }
    }

    func useBooster(_ type: BoosterType) -> Bool {
        switch type {
        case .hammer:
            guard hammerCount > 0 else { return false }
            hammerCount -= 1; return true
        case .shuffle:
            guard shuffleCount > 0 else { return false }
            shuffleCount -= 1; return true
        case .extraMoves:
            guard extraMovesCount > 0 else { return false }
            extraMovesCount -= 1; return true
        case .colorBomb:
            guard colorBombCount > 0 else { return false }
            colorBombCount -= 1; return true
        }
    }

    // MARK: - Daily Reward

    var lastDailyRewardDate: Date? {
        get { defaults.object(forKey: Key.lastDailyReward) as? Date }
        set { defaults.set(newValue, forKey: Key.lastDailyReward) }
    }

    var dailyStreak: Int {
        get { defaults.integer(forKey: Key.dailyStreak) }
        set { defaults.set(newValue, forKey: Key.dailyStreak) }
    }

    var canClaimDailyReward: Bool {
        guard let last = lastDailyRewardDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    func claimDailyReward() -> (coins: Int, diamonds: Int) {
        let streak = min(dailyStreak + 1, EconomyConfig.shared.dailyStreakCap)
        dailyStreak = streak
        lastDailyRewardDate = Date()

        let reward = EconomyConfig.shared.dailyReward(for: streak)

        addCoins(reward.coins)
        if reward.diamonds > 0 { addDiamonds(reward.diamonds) }
        AnalyticsManager.shared.track(.dailyRewardClaimed,
                                      properties: ["streak": "\(streak)",
                                                   "coins": "\(reward.coins)",
                                                   "diamonds": "\(reward.diamonds)"])

        return reward
    }

    // MARK: - First Launch

    var isFirstLaunch: Bool {
        get { !defaults.bool(forKey: Key.firstLaunch) }
        set { defaults.set(!newValue, forKey: Key.firstLaunch) }
    }

    func completeFirstLaunch() {
        if isFirstLaunch {
            coins = EconomyConfig.shared.startingCoins
            diamonds = EconomyConfig.shared.startingDiamonds
            hammerCount = 2
            shuffleCount = 2
            extraMovesCount = 1
            colorBombCount = 1
            isFirstLaunch = false
        }
    }

    // MARK: - Tutorial

    var tutorialComplete: Bool {
        get { defaults.bool(forKey: Key.tutorialComplete) }
    }

    func setTutorialComplete() {
        defaults.set(true, forKey: Key.tutorialComplete)
        AnalyticsManager.shared.track(.tutorialComplete)
    }

    // MARK: - Win Streak

    var winStreak: Int {
        get { defaults.integer(forKey: Key.winStreak) }
        set { defaults.set(newValue, forKey: Key.winStreak) }
    }

    func recordWin() -> Int {
        winStreak += 1
        return winStreak
    }

    func resetWinStreak() {
        winStreak = 0
    }

    // MARK: - Purchases

    var noAds: Bool {
        get { defaults.bool(forKey: Key.noAds) }
    }

    func setNoAds() {
        defaults.set(true, forKey: Key.noAds)
    }
}

enum BoosterType: CaseIterable {
    case hammer, shuffle, extraMoves, colorBomb

    var name: String {
        switch self {
        case .hammer: return "Hammer"
        case .shuffle: return "Shuffle"
        case .extraMoves: return "+5 Moves"
        case .colorBomb: return "Color Bomb"
        }
    }

    var cost: Int {
        EconomyConfig.shared.boosterCost(self)
    }

    var iconPixels: [[UInt8]] {
        switch self {
        case .hammer: return PixelIcons.hammer
        case .shuffle: return PixelIcons.shuffle
        case .extraMoves: return PixelIcons.moves
        case .colorBomb: return PixelIcons.bomb
        }
    }
}
