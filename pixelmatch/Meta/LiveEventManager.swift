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
