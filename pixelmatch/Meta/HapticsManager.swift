import UIKit

final class HapticsManager {
    static let shared = HapticsManager()
    private init() {}

    private lazy var lightImpact   = UIImpactFeedbackGenerator(style: .light)
    private lazy var mediumImpact  = UIImpactFeedbackGenerator(style: .medium)
    private lazy var heavyImpact   = UIImpactFeedbackGenerator(style: .heavy)
    private lazy var rigidImpact   = UIImpactFeedbackGenerator(style: .rigid)
    private lazy var softImpact    = UIImpactFeedbackGenerator(style: .soft)
    private lazy var selectionFB   = UISelectionFeedbackGenerator()
    private lazy var notificationFB = UINotificationFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        heavyImpact.prepare()
        selectionFB.prepare()
        notificationFB.prepare()
    }

    private var enabled: Bool { PlayerData.shared.vibrateEnabled }

    func tap()          { guard enabled else { return }; lightImpact.impactOccurred() }
    func select()       { guard enabled else { return }; selectionFB.selectionChanged() }
    func swap()         { guard enabled else { return }; mediumImpact.impactOccurred(intensity: 0.7) }
    func match()        { guard enabled else { return }; rigidImpact.impactOccurred(intensity: 0.9) }
    func special()      { guard enabled else { return }; heavyImpact.impactOccurred() }
    func invalidSwap()  { guard enabled else { return }; notificationFB.notificationOccurred(.warning) }
    func win()          { guard enabled else { return }; notificationFB.notificationOccurred(.success) }
    func lose()         { guard enabled else { return }; notificationFB.notificationOccurred(.error) }
    func cascade()      { guard enabled else { return }; softImpact.impactOccurred(intensity: 0.6) }
    func colorBomb()    { guard enabled else { return }; heavyImpact.impactOccurred(); DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { self.heavyImpact.impactOccurred() } }
}
