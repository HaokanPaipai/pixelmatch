import Foundation

enum AnalyticsEventName: String {
    case appLaunch = "app_launch"
    case tutorialComplete = "tutorial_complete"
    case levelStart = "level_start"
    case levelWin = "level_win"
    case levelFail = "level_fail"
    case specialCreated = "special_created"
    case boosterUsed = "booster_used"
    case currencyChanged = "currency_changed"
    case dailyRewardClaimed = "daily_reward_claimed"
    case questClaimed = "quest_claimed"
    case chestClaimed = "chest_claimed"
    case iapPurchaseStart = "iap_purchase_start"
    case iapPurchaseSuccess = "iap_purchase_success"
    case iapPurchaseFail = "iap_purchase_fail"
    case iapRestore = "iap_restore"
    // 广告生命周期（由 PixelMatchAdAnalyticsProvider 映射 HKAdKit 的 AdEvent）
    case adLoadStart = "ad_load_start"
    case adLoaded = "ad_loaded"
    case adLoadFailed = "ad_load_failed"
    case adImpression = "ad_impression"
    case adDismissed = "ad_dismissed"
    case adClicked = "ad_clicked"
    case adRewardEarned = "ad_reward_earned"
}

struct AnalyticsEvent: Codable {
    let name: String
    let timestamp: TimeInterval
    let properties: [String: String]
}

final class AnalyticsManager {
    static let shared = AnalyticsManager()

    private let defaults = UserDefaults.standard
    private let eventsKey = "analytics.localEvents"
    private let maxStoredEvents = 500

    private init() {}

    func track(_ name: AnalyticsEventName, properties: [String: String] = [:]) {
        var events = storedEvents
        events.append(AnalyticsEvent(name: name.rawValue,
                                     timestamp: Date().timeIntervalSince1970,
                                     properties: properties))
        if events.count > maxStoredEvents {
            events.removeFirst(events.count - maxStoredEvents)
        }
        save(events)
    }

    var storedEvents: [AnalyticsEvent] {
        guard let data = defaults.data(forKey: eventsKey),
              let events = try? JSONDecoder().decode([AnalyticsEvent].self, from: data) else {
            return []
        }
        return events
    }

    func clearLocalEvents() {
        defaults.removeObject(forKey: eventsKey)
    }

    private func save(_ events: [AnalyticsEvent]) {
        guard let data = try? JSONEncoder().encode(events) else { return }
        defaults.set(data, forKey: eventsKey)
    }
}
