import SpriteKit

/// 赛季通行证弹窗：顶部赛季信息 + 可拖动的 30 级双轨奖励列表 + 付费解锁入口。
/// 滚动用 SKCropNode + 拖拽实现；小位移视为点击（领取奖励）。
final class SeasonPassDialog: DialogNode {

    var onUnlockPremium: (() -> Void)?
    var onClose: (() -> Void)?

    private let rowHeight: CGFloat = 56
    private let scrollAreaHeight: CGFloat
    private var contentNode = SKNode()
    private var touchStartY: CGFloat?
    private var contentStartY: CGFloat = 0
    private var didDrag = false
    private var pointsLabel: SKLabelNode?

    init(sceneSize: CGSize) {
        let height = min(sceneSize.height * 0.82, 600)
        scrollAreaHeight = height - 200
        super.init(size: CGSize(width: 320, height: height), sceneSize: sceneSize)
        isUserInteractionEnabled = true
        buildUI()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        let pass = SeasonPassManager.shared
        let panelHalf = panelSize.height / 2

        addPixelTitle(L10n.tr("pass.title", fallback: "SEASON PASS"), y: panelHalf - 36)

        // 赛季倒计时 + 当前积分
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        let endLbl = SKLabelNode(fontNamed: "Courier")
        endLbl.text = L10n.fmt("pass.season_ends", fmt.string(from: pass.seasonEndDate()),
                               fallback: "Season ends: %@")
        endLbl.fontSize = 12
        endLbl.fontColor = UIColor(hex: "#7799CC")
        endLbl.verticalAlignmentMode = .center
        endLbl.position = CGPoint(x: 0, y: panelHalf - 62)
        addChild(endLbl)

        let ptsLbl = SKLabelNode(fontNamed: "Courier-Bold")
        ptsLbl.text = L10n.fmt("pass.points", pass.points, fallback: "%d pts") + "  ·  " +
            L10n.fmt("pass.level", pass.level, fallback: "LV %d")
        ptsLbl.fontSize = 14
        ptsLbl.fontColor = UIColor(hex: "#FFCC00")
        ptsLbl.verticalAlignmentMode = .center
        ptsLbl.position = CGPoint(x: 0, y: panelHalf - 84)
        addChild(ptsLbl)
        pointsLabel = ptsLbl

        // 轨道表头
        let freeHdr = SKLabelNode(fontNamed: "Courier-Bold")
        freeHdr.text = L10n.tr("pass.free_track", fallback: "FREE")
        freeHdr.fontSize = 12
        freeHdr.fontColor = UIColor(hex: "#99BBCC")
        freeHdr.position = CGPoint(x: -55, y: panelHalf - 108)
        freeHdr.verticalAlignmentMode = .center
        addChild(freeHdr)

        let premHdr = SKLabelNode(fontNamed: "Courier-Bold")
        premHdr.text = L10n.tr("pass.premium_track", fallback: "PREMIUM")
        premHdr.fontSize = 12
        premHdr.fontColor = UIColor(hex: "#FFD700")
        premHdr.position = CGPoint(x: 75, y: panelHalf - 108)
        premHdr.verticalAlignmentMode = .center
        addChild(premHdr)

        // 滚动区（crop）
        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .white,
                                size: CGSize(width: panelSize.width - 24, height: scrollAreaHeight))
        crop.maskNode = mask
        crop.position = CGPoint(x: 0, y: panelHalf - 120 - scrollAreaHeight / 2)
        crop.zPosition = 1
        addChild(crop)
        crop.addChild(contentNode)
        buildRows()
        contentNode.position = CGPoint(x: 0, y: scrollAreaHeight / 2 - rowHeight / 2)
        contentStartY = contentNode.position.y

        // 底部按钮
        let bottomY = -panelHalf + 40
        if pass.isPremium {
            let activeLbl = SKLabelNode(fontNamed: "Courier-Bold")
            activeLbl.text = L10n.tr("pass.purchased", fallback: "PREMIUM ACTIVE")
            activeLbl.fontSize = 15
            activeLbl.fontColor = UIColor(hex: "#34C759")
            activeLbl.verticalAlignmentMode = .center
            activeLbl.position = CGPoint(x: -40, y: bottomY)
            addChild(activeLbl)
        } else {
            let unlockBtn = PixelButton(title: L10n.tr("pass.unlock_cta", fallback: "UNLOCK PREMIUM"),
                                        icon: .diamond,
                                        size: CGSize(width: 210, height: 46),
                                        style: .primary,
                                        color: UIColor(hex: "#FFD700"),
                                        fontSize: 14)
            unlockBtn.position = CGPoint(x: -35, y: bottomY)
            unlockBtn.zPosition = 2
            unlockBtn.onTap = { [weak self] in self?.onUnlockPremium?() }
            addChild(unlockBtn)
        }

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"),
                                   size: CGSize(width: 80, height: 46),
                                   style: .ghost, color: UIColor(hex: "#7799CC"))
        closeBtn.position = CGPoint(x: 110, y: bottomY)
        closeBtn.zPosition = 2
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)
    }

    // MARK: - 行渲染

    private func buildRows() {
        contentNode.removeAllChildren()
        let pass = SeasonPassManager.shared
        for lv in 1...SeasonPassManager.maxLevel {
            let row = SKNode()
            row.position = CGPoint(x: 0, y: -CGFloat(lv - 1) * rowHeight)

            let reached = lv <= pass.level

            // 级别徽标
            let badge = SKShapeNode(circleOfRadius: 16)
            badge.fillColor = reached ? UIColor(hex: "#2255AA") : UIColor(hex: "#11203A")
            badge.strokeColor = reached ? UIColor(hex: "#5599FF") : UIColor(hex: "#22344F")
            badge.lineWidth = 1.5
            badge.position = CGPoint(x: -125, y: 0)
            row.addChild(badge)

            let lvLbl = SKLabelNode(fontNamed: "Courier-Bold")
            lvLbl.text = "\(lv)"
            lvLbl.fontSize = 13
            lvLbl.fontColor = reached ? .white : UIColor(hex: "#445566")
            lvLbl.verticalAlignmentMode = .center
            lvLbl.position = badge.position
            row.addChild(lvLbl)

            row.addChild(rewardCell(level: lv, premium: false, x: -55, reached: reached))
            row.addChild(rewardCell(level: lv, premium: true, x: 75, reached: reached))

            contentNode.addChild(row)
        }
    }

    private func rewardCell(level lv: Int, premium: Bool, x: CGFloat, reached: Bool) -> SKNode {
        let pass = SeasonPassManager.shared
        let reward = premium ? pass.premiumReward(at: lv) : pass.freeReward(at: lv)
        let claimed = pass.isClaimed(level: lv, premium: premium)
        let claimable = reached && !claimed && (!premium || pass.isPremium)

        let cell = SKNode()
        cell.position = CGPoint(x: x, y: 0)
        cell.name = "cell_\(lv)_\(premium ? "p" : "f")"

        let bgWidth: CGFloat = premium ? 120 : 100
        let bg = SKShapeNode(rectOf: CGSize(width: bgWidth, height: 44), cornerRadius: 8)
        bg.fillColor = claimed ? UIColor(hex: "#0A1422")
            : (claimable ? UIColor(hex: "#1A2F0F") : UIColor(hex: "#0F1E33"))
        bg.strokeColor = claimable ? UIColor(hex: "#34C759")
            : (premium ? UIColor(hex: "#806A1A") : UIColor(hex: "#1C3A5C"))
        bg.lineWidth = claimable ? 2 : 1.2
        cell.addChild(bg)

        // 奖励图标 + 数量（取 bundle 的主要成分展示）
        let (icon, amount): (PixelArtIcon, Int) = reward.diamonds > 0 && reward.coins == 0
            ? (.diamond, reward.diamonds)
            : (reward.coins > 0 ? (.coin, reward.coins) : (.gift, reward.hammer + reward.shuffle))
        let iconNode = SKSpriteNode(texture: PixelArt.shared.softIconTexture(icon, size: 26),
                                    size: CGSize(width: 22, height: 22))
        iconNode.position = CGPoint(x: -bgWidth / 2 + 20, y: 0)
        iconNode.alpha = claimed ? 0.4 : 1
        cell.addChild(iconNode)

        let amtLbl = SKLabelNode(fontNamed: "Courier-Bold")
        amtLbl.text = claimed ? L10n.tr("pass.claimed", fallback: "✓") : "×\(amount)"
        amtLbl.fontSize = 13
        amtLbl.fontColor = claimed ? UIColor(hex: "#34C759")
            : (claimable ? .white : UIColor(hex: "#667788"))
        amtLbl.verticalAlignmentMode = .center
        amtLbl.horizontalAlignmentMode = .left
        amtLbl.position = CGPoint(x: -bgWidth / 2 + 36, y: 0)
        cell.addChild(amtLbl)

        // 未解锁付费轨加小锁
        if premium && !pass.isPremium && !claimed {
            let lock = SKSpriteNode(texture: PixelArt.shared.lockBadgeTexture(size: 18),
                                    size: CGSize(width: 14, height: 14))
            lock.position = CGPoint(x: bgWidth / 2 - 14, y: 0)
            cell.addChild(lock)
        }
        return cell
    }

    // MARK: - 拖拽滚动 + 点击领取

    private var maxScroll: CGFloat {
        max(0, CGFloat(SeasonPassManager.maxLevel) * rowHeight - scrollAreaHeight)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchStartY = t.location(in: self).y
        contentStartY = contentNode.position.y
        didDrag = false
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first, let startY = touchStartY else { return }
        let dy = t.location(in: self).y - startY
        if abs(dy) > 8 { didDrag = true }
        let base = scrollAreaHeight / 2 - rowHeight / 2
        contentNode.position.y = min(base + maxScroll, max(base, contentStartY + dy))
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer { touchStartY = nil }
        guard !didDrag, let t = touches.first else { return }
        // 点击：命中奖励格则尝试领取
        let location = t.location(in: contentNode)
        for row in contentNode.children {
            for cell in row.children {
                guard let name = cell.name, name.hasPrefix("cell_") else { continue }
                let local = CGPoint(x: location.x - row.position.x - cell.position.x,
                                    y: location.y - row.position.y - cell.position.y)
                guard abs(local.x) <= 62, abs(local.y) <= 24 else { continue }
                let parts = name.split(separator: "_")
                guard parts.count == 3, let lv = Int(parts[1]) else { continue }
                let premium = parts[2] == "p"
                if SeasonPassManager.shared.claim(level: lv, premium: premium) != nil {
                    AudioManager.shared.play(.coinCollect)
                    HapticsManager.shared.win()
                    refresh()
                } else {
                    AudioManager.shared.play(.invalidSwap)
                }
                return
            }
        }
    }

    /// 领取后重建行与积分显示
    private func refresh() {
        let saved = contentNode.position
        buildRows()
        contentNode.position = saved
        let pass = SeasonPassManager.shared
        pointsLabel?.text = L10n.fmt("pass.points", pass.points, fallback: "%d pts") + "  ·  " +
            L10n.fmt("pass.level", pass.level, fallback: "LV %d")
    }
}
