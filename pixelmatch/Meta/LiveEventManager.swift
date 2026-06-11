import Foundation

enum LiveEventKind {
    case weekendCoinBonus
    case questProgressBoost(DailyQuestKind)
}

struct LiveEvent {
    let id: String
    let kind: LiveEventKind
    let title: String
    let description: String
}

final class LiveEventManager {
    static let shared = LiveEventManager()

    private let boostedQuestKinds: [DailyQuestKind] = [
        .clearJelly,
        .breakIce,
        .clearChocolate,
        .createSpecials,
        .createColorBombs,
        .triggerSpecialCombos
    ]

    private init() {}

    func activeEvents(on date: Date = Date()) -> [LiveEvent] {
        var events: [LiveEvent] = []
        if isWeekend(date) {
            events.append(LiveEvent(
                id: "weekend_coin_bonus",
                kind: .weekendCoinBonus,
                title: L10n.tr("event.weekend.title", fallback: "Weekend Coin Spark"),
                description: L10n.tr("event.weekend.desc", fallback: "Win coins x2 this weekend")
            ))
        }

        let boostedKind = boostedQuestKind(on: date)
        events.append(LiveEvent(
            id: "quest_boost_\(boostedKind.rawValue)",
            kind: .questProgressBoost(boostedKind),
            title: L10n.fmt("event.quest_boost.title", boostedKind.title, fallback: "%@ Rush"),
            description: L10n.fmt("event.quest_boost.desc", boostedKind.title, fallback: "%@ progress x2 today")
        ))
        return events
    }

    var winCoinMultiplier: Int {
        activeEvents().contains { event in
            if case .weekendCoinBonus = event.kind { return true }
            return false
        } ? 2 : 1
    }

    func progressMultiplier(for kind: DailyQuestKind) -> Int {
        activeEvents().contains { event in
            if case .questProgressBoost(let boostedKind) = event.kind {
                return boostedKind == kind
            }
            return false
        } ? 2 : 1
    }

    // MARK: - 每周挑战（ISO 周序号驱动，跨周自动作废；结构 Codable 对齐未来云控下发格式）

    struct WeeklyChallenge: Codable {
        let id: String          // "2026-W24"
        let kind: DailyQuestKind
        let target: Int
    }

    /// 周挑战模板：kind + 基准目标量（按玩家进度三档缩放）
    private static let weeklyTemplates: [(kind: DailyQuestKind, base: Int)] = [
        (.completeLevels, 12),
        (.createSpecials, 40),
        (.clearJelly, 80),
        (.breakIce, 60),
        (.triggerSpecialCombos, 12),
        (.createColorBombs, 8),
        (.winWithoutBoosters, 8)
    ]

    func weeklyChallenge(on date: Date = Date()) -> WeeklyChallenge {
        let key = weekKey(on: date)
        let seed = weekSeed(on: date)
        let template = LiveEventManager.weeklyTemplates[seed % LiveEventManager.weeklyTemplates.count]
        // 目标量按玩家进度缩放：新手 1x / 中期 1.5x / 后期 2x
        let progress = PlayerData.shared.maxUnlockedLevel
        let scale: Double = progress > 150 ? 2.0 : (progress > 50 ? 1.5 : 1.0)
        return WeeklyChallenge(id: key, kind: template.kind,
                               target: Int(Double(template.base) * scale))
    }

    var weeklyProgress: Int {
        UserDefaults.standard.integer(forKey: "weekly.\(weekKey()).progress")
    }

    var isWeeklyClaimed: Bool {
        UserDefaults.standard.bool(forKey: "weekly.\(weekKey()).claimed")
    }

    var isWeeklyComplete: Bool {
        weeklyProgress >= weeklyChallenge().target
    }

    /// 由 LiveOpsManager.increment 统一转发（覆盖全部 record* 钩子），传未加成的原始量。
    func recordWeeklyProgress(kind: DailyQuestKind, amount: Int) {
        guard amount > 0 else { return }
        let challenge = weeklyChallenge()
        guard challenge.kind == kind, !isWeeklyClaimed else { return }
        let key = "weekly.\(challenge.id).progress"
        let current = UserDefaults.standard.integer(forKey: key)
        UserDefaults.standard.set(min(challenge.target, current + amount), forKey: key)
    }

    /// 领取周挑战奖励（幂等）：金币+钻石+通行证积分（两系统互相导流）
    @discardableResult
    func claimWeeklyReward() -> RewardBundle? {
        guard isWeeklyComplete, !isWeeklyClaimed else { return nil }
        UserDefaults.standard.set(true, forKey: "weekly.\(weekKey()).claimed")
        let reward = RewardBundle(coins: 300, diamonds: 3)
        PlayerData.shared.addCoins(reward.coins)
        PlayerData.shared.addDiamonds(reward.diamonds)
        SeasonPassManager.shared.addPoints(SeasonPassManager.pointsPerWeeklyChallenge,
                                           source: "weekly_challenge")
        AnalyticsManager.shared.track(.weeklyChallengeCompleted,
                                      properties: ["week": weekKey()])
        return reward
    }

    /// 距周末（下周一零点）剩余时间的展示串，如 "2d 5h"
    var weeklyTimeLeftString: String {
        var cal = Calendar(identifier: .iso8601)
        cal.timeZone = .current
        let now = Date()
        guard let nextWeek = cal.nextDate(after: now,
                                          matching: DateComponents(hour: 0, minute: 0, weekday: 2),
                                          matchingPolicy: .nextTime) else { return "" }
        let secs = Int(nextWeek.timeIntervalSince(now))
        let days = secs / 86400, hours = (secs % 86400) / 3600
        return days > 0 ? "\(days)d \(hours)h" : "\(hours)h"
    }

    private func weekKey(on date: Date = Date()) -> String {
        let cal = Calendar(identifier: .iso8601)
        let week = cal.component(.weekOfYear, from: date)
        let year = cal.component(.yearForWeekOfYear, from: date)
        return "\(year)-W\(week)"
    }

    private func weekSeed(on date: Date) -> Int {
        let cal = Calendar(identifier: .iso8601)
        return cal.component(.yearForWeekOfYear, from: date) * 53
            + cal.component(.weekOfYear, from: date)
    }

    private func boostedQuestKind(on date: Date) -> DailyQuestKind {
        let seed = dailySeed(on: date)
        return boostedQuestKinds[seed % boostedQuestKinds.count]
    }

    private func isWeekend(_ date: Date) -> Bool {
        let weekday = Calendar.current.component(.weekday, from: date)
        return weekday == 1 || weekday == 7
    }

    private func dailySeed(on date: Date) -> Int {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        return (components.year ?? 0) * 372 + (components.month ?? 0) * 31 + (components.day ?? 0)
    }
}
