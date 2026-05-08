import UIKit
import SpriteKit

class GameViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let skView = view as? SKView else { return }

        // Performance settings
        skView.ignoresSiblingOrder = true
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsDrawCount = false
        skView.preferredFramesPerSecond = 60
        skView.shouldCullNonVisibleNodes = true

        // Initialize services
        AdManager.shared.initialize()
        GameCenterManager.shared.rootViewController = self
        GameCenterManager.shared.authenticate()

        // Use UIScreen.main.bounds rather than skView.bounds: in viewDidLoad
        // the SKView's frame still reflects the storyboard design-time size,
        // not the real device screen. UIScreen.main.bounds is always correct.
        let screenSize = UIScreen.main.bounds.size
        let scene = LoadingScene(size: screenSize)
        scene.scaleMode = .aspectFill
        skView.presentScene(scene)
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
}
