import Foundation

final class LivesManager {

    static let shared = LivesManager()
    private init() {}

    private let defaults = UserDefaults.standard
    private let maxLives = GameConstants.maxLives
    private let refillInterval: TimeInterval = TimeInterval(GameConstants.lifeRefillMinutes * 60)

    private enum Key {
        static let livesCount   = "livesCount"
        static let lastLostTime = "lastLostTime"
    }

    // MARK: - Current Lives

    var currentLives: Int {
        get {
            syncLives()
            let stored = defaults.integer(forKey: Key.livesCount)
            return stored == 0 ? maxLives : min(stored, maxLives)
        }
        set { defaults.set(max(0, min(newValue, maxLives)), forKey: Key.livesCount) }
    }

    var isFull: Bool { currentLives >= maxLives }

    // MARK: - Time Until Next Life

    var secondsUntilNextLife: Int {
        guard !isFull else { return 0 }
        guard let lastLost = defaults.object(forKey: Key.lastLostTime) as? Date else { return 0 }
        let elapsed = Date().timeIntervalSince(lastLost)
        let remaining = refillInterval - elapsed.truncatingRemainder(dividingBy: refillInterval)
        return max(0, Int(remaining))
    }

    var timeUntilNextLifeString: String {
        let secs = secondsUntilNextLife
        let m = secs / 60, s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Life Operations

    func spendLife() -> Bool {
        syncLives()
        guard currentLives > 0 else { return false }
        let newCount = currentLives - 1
        currentLives = newCount
        if newCount < maxLives && defaults.object(forKey: Key.lastLostTime) == nil {
            defaults.set(Date(), forKey: Key.lastLostTime)
        }
        return true
    }

    func refillLives(for diamonds: Int = 0) -> Bool {
        if diamonds == 0 {
            currentLives = maxLives
            defaults.removeObject(forKey: Key.lastLostTime)
            return true
        }
        let cost = 15
        guard PlayerData.shared.spendDiamonds(cost) else { return false }
        currentLives = maxLives
        defaults.removeObject(forKey: Key.lastLostTime)
        return true
    }

    // MARK: - Auto-Sync

    private func syncLives() {
        guard let lastLost = defaults.object(forKey: Key.lastLostTime) as? Date else { return }
        let stored = defaults.integer(forKey: Key.livesCount)
        guard stored < maxLives else { return }

        let elapsed = Date().timeIntervalSince(lastLost)
        let gained = Int(elapsed / refillInterval)
        guard gained > 0 else { return }

        let newCount = min(maxLives, stored + gained)
        defaults.set(newCount, forKey: Key.livesCount)

        if newCount >= maxLives {
            defaults.removeObject(forKey: Key.lastLostTime)
        } else {
            let newRef = lastLost.addingTimeInterval(Double(gained) * refillInterval)
            defaults.set(newRef, forKey: Key.lastLostTime)
        }
    }
}
