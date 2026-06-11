import XCTest
@testable import pixelmatch

final class SeasonPassManagerTests: XCTestCase {
    private let defaults = UserDefaults.standard
    private let passKeys = [
        "pass.seasonIndex",
        "pass.points",
        "pass.claimedFree",
        "pass.claimedPremium",
        "pass.purchasedSeason"
    ]

    private var savedDefaults: [String: Any] = [:]

    override func setUp() {
        super.setUp()
        savedDefaults = passKeys.reduce(into: [:]) { result, key in
            result[key] = defaults.object(forKey: key)
        }
    }

    override func tearDown() {
        for key in passKeys {
            if let value = savedDefaults[key] {
                defaults.set(value, forKey: key)
            } else {
                defaults.removeObject(forKey: key)
            }
        }
        super.tearDown()
    }

    func testClaimableCountIsZeroAtLevelZero() {
        let pass = SeasonPassManager.shared
        defaults.set(pass.seasonIndex(), forKey: "pass.seasonIndex")
        defaults.set(0, forKey: "pass.points")
        defaults.set([Int](), forKey: "pass.claimedFree")
        defaults.set([Int](), forKey: "pass.claimedPremium")
        defaults.removeObject(forKey: "pass.purchasedSeason")

        XCTAssertEqual(pass.level, 0)
        XCTAssertEqual(pass.claimableCount, 0)
    }

    func testLevelDoesNotDropBelowZeroForBadStoredPoints() {
        let pass = SeasonPassManager.shared
        defaults.set(pass.seasonIndex(), forKey: "pass.seasonIndex")
        defaults.set(-100, forKey: "pass.points")
        defaults.set([Int](), forKey: "pass.claimedFree")
        defaults.set([Int](), forKey: "pass.claimedPremium")

        XCTAssertEqual(pass.level, 0)
        XCTAssertEqual(pass.claimableCount, 0)
    }
}
