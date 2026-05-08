import GameKit
import UIKit

final class GameCenterManager: NSObject {
    static let shared = GameCenterManager()
    private override init() {}

    private(set) var isAuthenticated = false
    var rootViewController: UIViewController?

    // Leaderboard IDs — set these in App Store Connect
    enum Leaderboard: String {
        case totalScore    = "com.pixelmatch.leaderboard.totalscore"
        case highestLevel  = "com.pixelmatch.leaderboard.highestlevel"
        case totalStars    = "com.pixelmatch.leaderboard.totalstars"
    }

    // Achievement IDs
    enum Achievement: String {
        case firstMatch    = "com.pixelmatch.achievement.firstmatch"
        case level10       = "com.pixelmatch.achievement.level10"
        case level50       = "com.pixelmatch.achievement.level50"
        case level100      = "com.pixelmatch.achievement.level100"
        case collector     = "com.pixelmatch.achievement.collector"     // 1000 gems collected
        case comboCrazy    = "com.pixelmatch.achievement.combocrazy"   // 5× combo
        case specialMaster = "com.pixelmatch.achievement.specialmaster" // 50 specials created
        case perfectScore  = "com.pixelmatch.achievement.perfectscore"  // 3 stars on 10 levels
    }

    func authenticate() {
        let player = GKLocalPlayer.local
        player.authenticateHandler = { [weak self] vc, error in
            guard let self = self else { return }
            if let vc = vc, let root = self.rootViewController {
                root.present(vc, animated: true)
            } else if player.isAuthenticated {
                self.isAuthenticated = true
                self.syncPlayerData()
            }
        }
    }

    private func syncPlayerData() {
        submitScore(PlayerData.shared.totalScore, to: .totalScore)
        submitScore(PlayerData.shared.maxUnlockedLevel, to: .highestLevel)
        submitScore(PlayerData.shared.totalStars, to: .totalStars)
    }

    func submitScore(_ score: Int, to leaderboard: Leaderboard) {
        guard isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                   leaderboardIDs: [leaderboard.rawValue]) { error in
            if let error = error {
                print("GC submitScore error: \(error)")
            }
        }
    }

    func reportAchievement(_ id: Achievement, percentComplete: Double = 100) {
        guard isAuthenticated else { return }
        let achievement = GKAchievement(identifier: id.rawValue)
        achievement.percentComplete = percentComplete
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { error in
            if let error = error {
                print("GC achievement error: \(error)")
            }
        }
    }

    func showLeaderboard(from vc: UIViewController) {
        guard isAuthenticated else {
            authenticate()
            return
        }
        let gcVC = GKGameCenterViewController(leaderboardID: Leaderboard.totalScore.rawValue,
                                              playerScope: .global,
                                              timeScope: .allTime)
        gcVC.gameCenterDelegate = self
        vc.present(gcVC, animated: true)
    }

    func showAchievements(from vc: UIViewController) {
        guard isAuthenticated else { return }
        let gcVC = GKGameCenterViewController(state: .achievements)
        gcVC.gameCenterDelegate = self
        vc.present(gcVC, animated: true)
    }

    // MARK: - Achievement Checks

    func checkAchievements() {
        let data = PlayerData.shared
        if data.totalMatches >= 1 { reportAchievement(.firstMatch) }
        if data.maxUnlockedLevel >= 10  { reportAchievement(.level10) }
        if data.maxUnlockedLevel >= 50  { reportAchievement(.level50) }
        if data.maxUnlockedLevel >= 100 { reportAchievement(.level100) }

        let starsProgress = min(Double(data.totalStars) / 30.0 * 100, 100)
        reportAchievement(.perfectScore, percentComplete: starsProgress)
    }
}

extension GameCenterManager: GKGameCenterControllerDelegate {
    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
