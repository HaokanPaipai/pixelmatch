import XCTest
@testable import pixelmatch

final class PlayerDataDailyRewardTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let keys = [
        "firstLaunch",
        "coins",
        "diamonds",
        "lastDailyReward",
        "dailyStreak",
        "wallet.pendingMutations"
    ]

    private var savedDefaults: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        savedDefaults = keys.reduce(into: [:]) { result, key in
            result[key] = defaults.object(forKey: key)
        }

        defaults.set(true, forKey: "firstLaunch")
        defaults.set(100, forKey: "coins")
        defaults.set(3, forKey: "diamonds")
        defaults.removeObject(forKey: "lastDailyReward")
        defaults.set(0, forKey: "dailyStreak")
        defaults.set([[String: Any]](), forKey: "wallet.pendingMutations")
    }

    override func tearDown() {
        for key in keys {
            if let value = savedDefaults[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testDailyRewardCanOnlyBeClaimedOncePerDay() {
        let player = PlayerData.shared

        let firstReward = player.claimDailyReward()
        let coinsAfterFirstClaim = player.coins
        let diamondsAfterFirstClaim = player.diamonds
        let streakAfterFirstClaim = player.dailyStreak
        let secondReward = player.claimDailyReward()

        XCTAssertNotNil(firstReward)
        XCTAssertNil(secondReward)
        XCTAssertEqual(player.coins, coinsAfterFirstClaim)
        XCTAssertEqual(player.diamonds, diamondsAfterFirstClaim)
        XCTAssertEqual(player.dailyStreak, streakAfterFirstClaim)
        XCTAssertFalse(player.canClaimDailyReward)
    }
}
