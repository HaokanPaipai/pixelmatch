import XCTest
import SpriteKit
@testable import pixelmatch

final class DialogLayoutTests: XCTestCase {

    func testOutOfMovesButtonsStayInsidePanelAcrossAdAndHintStates() {
        let defaults = UserDefaults.standard
        let originalNoAds = defaults.object(forKey: "noAds")
        defer {
            if let originalNoAds {
                defaults.set(originalNoAds, forKey: "noAds")
            } else {
                defaults.removeObject(forKey: "noAds")
            }
        }

        for noAds in [false, true] {
            defaults.set(noAds, forKey: "noAds")

            for hint in [nil, "Need 1 more jelly"] as [String?] {
                let dialog = OutOfMovesDialog(sceneSize: CGSize(width: 320, height: 568),
                                              hintText: hint)
                let expectedButtons = noAds
                    ? ["outOfMoves.continue", "outOfMoves.quit"]
                    : ["outOfMoves.continue", "outOfMoves.ad", "outOfMoves.quit"]

                for name in expectedButtons {
                    guard let button = dialog.childNode(withName: name) else {
                        XCTFail("Missing \(name) for noAds=\(noAds), hint=\(hint != nil)")
                        continue
                    }
                    assert(button, staysInside: dialog, name: name)
                }
            }
        }
    }

    private func assert(_ node: SKNode, staysInside dialog: DialogNode, name: String) {
        let frame = node.calculateAccumulatedFrame()
        let halfW = dialog.panelSize.width / 2
        let halfH = dialog.panelSize.height / 2
        let padding: CGFloat = 5

        XCTAssertGreaterThanOrEqual(frame.minX, -halfW + padding, "\(name) exceeds left edge")
        XCTAssertLessThanOrEqual(frame.maxX, halfW - padding, "\(name) exceeds right edge")
        XCTAssertGreaterThanOrEqual(frame.minY, -halfH + padding, "\(name) exceeds bottom edge")
        XCTAssertLessThanOrEqual(frame.maxY, halfH - padding, "\(name) exceeds top edge")
    }
}
