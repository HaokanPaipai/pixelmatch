import SpriteKit

// MARK: - Shop Dialog

/// 全局商店弹窗：真钱档位（IAP）+ 金币道具区。
/// 可从主页、游戏内（钻石/金币不足引导）、地图页（补体力引导）打开，
/// 通过 `focus` 指定初始滚动定位的区块，`source` 记录打开来源埋点。
final class ShopDialog: DialogNode {

    /// 初始定位区块：钻石不足 → .diamonds；金币不足 → .coins。
    enum Section {
        case diamonds, coins, boosters
    }

    var onClose: (() -> Void)?
    var onCurrencyChanged: (() -> Void)?
    private var purchaseInFlight = false

    private let dialogSize: CGSize
    private let viewportHeight: CGFloat
    private let viewportTop: CGFloat
    private let viewportBottom: CGFloat
    private let scrollNode = SKNode()
    private var contentHeight: CGFloat = 0
    private var touchStartY: CGFloat = 0
    private var scrollStartY: CGFloat = 0
    private var isTrackingScroll = false
    private var didDrag = false
    /// IAP 行的购买按钮，按 product 索引；异步拉到的本地化价格在 refreshPrices() 里刷新。
    private var iapPriceButtons: [IAPProduct: PixelButton] = [:]
    /// Booster 行的"已拥有 ×N"标签，购买成功后即时刷新。
    private var boosterCountLabels: [BoosterType: SKLabelNode] = [:]
    /// 各区块首行在 scrollNode 中的 y 锚点，供 focus 初始定位。
    private var sectionAnchors: [Section: CGFloat] = [:]

    private static let diamondPacks: Set<IAPProduct> = [.diamonds20, .diamonds80, .diamonds300]
    private static let coinPacks: Set<IAPProduct> = [.coins500, .coins1500, .coins5000]

    init(sceneSize: CGSize, safeAreaInsets: UIEdgeInsets,
         focus: Section? = nil, source: String) {
        let width = min(sceneSize.width - safeAreaInsets.left - safeAreaInsets.right - 32, 320)
        let height = min(sceneSize.height - safeAreaInsets.top - safeAreaInsets.bottom - 40, 520)
        dialogSize = CGSize(width: width, height: height)
        viewportTop = height / 2 - 66
        viewportBottom = -height / 2 + 78
        viewportHeight = viewportTop - viewportBottom

        super.init(size: dialogSize, sceneSize: sceneSize)
        isUserInteractionEnabled = true
        buildUI()
        scrollTo(focus)
        AnalyticsManager.shared.track(.shopOpen, properties: ["source": source])
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI() {
        addPixelTitle(L10n.tr("shop.title", fallback: "🛒 SHOP"), y: dialogSize.height / 2 - 34)

        let closeBtn = PixelButton(title: L10n.tr("common.close", fallback: "CLOSE"),
                                   size: CGSize(width: 240, height: 44),
                                   style: .secondary, fontSize: 16)
        closeBtn.position = CGPoint(x: 0, y: -dialogSize.height / 2 + 38)
        closeBtn.zPosition = 20
        closeBtn.onTap = { [weak self] in self?.onClose?() }
        addChild(closeBtn)

        let clip = SKCropNode()
        let mask = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 24, height: viewportHeight), cornerRadius: 8)
        mask.fillColor = .white
        mask.position = CGPoint(x: 0, y: (viewportTop + viewportBottom) / 2)
        clip.maskNode = mask
        clip.zPosition = 1
        addChild(clip)

        scrollNode.position = CGPoint(x: 0, y: viewportTop)
        clip.addChild(scrollNode)

        var yPos: CGFloat = -36

        // 真钱档位：走 HKIAPKit（复用 Goodlook 后端）
        for product in IAPProduct.shopCatalog {
            if Self.diamondPacks.contains(product), sectionAnchors[.diamonds] == nil {
                sectionAnchors[.diamonds] = yPos
            }
            if Self.coinPacks.contains(product), sectionAnchors[.coins] == nil {
                sectionAnchors[.coins] = yPos
            }
            addIAPItem(product: product, y: yPos)
            yPos -= 80
        }

        // 恢复购买
        addRestoreRow(y: yPos)
        yPos -= 64

        // Booster section
        yPos -= 20
        let boosterTitle = SKLabelNode(fontNamed: "Courier-Bold")
        boosterTitle.text = L10n.tr("shop.boosters", fallback: "──── BOOSTERS ────")
        boosterTitle.fontSize = 14
        boosterTitle.fontColor = UIColor(hex: "#7799CC")
        boosterTitle.verticalAlignmentMode = .center
        boosterTitle.position = CGPoint(x: 0, y: yPos)
        scrollNode.addChild(boosterTitle)
        sectionAnchors[.boosters] = yPos
        yPos -= 60

        for type in BoosterType.allCases {
            addBoosterItem(type: type, y: yPos)
            yPos -= 55
        }

        contentHeight = abs(yPos) + 24

        // 异步刷新真钱档位的价格（启动时已拉过，这里再刷一次保证 StoreKit 本地化生效）。
        IAPManager.shared.reloadProducts { [weak self] _ in
            Task { @MainActor in self?.refreshPrices() }
        }
    }

    /// 把指定区块的首行滚动到视口顶部附近。
    private func scrollTo(_ section: Section?) {
        guard let section, let anchor = sectionAnchors[section] else { return }
        scrollNode.position.y = clampScrollY(viewportTop - 44 - anchor)
    }

    // MARK: - IAP rows

    /// 真钱档位一行：左侧标题 + 奖励文案，右侧本地化价格按钮（noAds 已购显示 OWNED）。
    private func addIAPItem(product: IAPProduct, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 40, height: 68), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = product.displayName
        nameLbl.fontSize = 14
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -dialogSize.width / 2 + 34, y: y + 13)
        scrollNode.addChild(nameLbl)

        // 长奖励文案在窄屏不能挤进价格按钮（noAds 的"Remove all ads forever" 偏长）。
        let maxRewardWidth = dialogSize.width - 40 - 34 - 120
        let reward = product.shopRewardPreview
        addRewardPreview(coins: reward.coins,
                         diamonds: reward.diamonds,
                         suffix: reward.suffix,
                         position: CGPoint(x: -dialogSize.width / 2 + 34, y: y - 13),
                         maxWidth: maxRewardWidth,
                         fontSize: 12)

        let isOwned = (product == .noAds) && PlayerData.shared.noAds
        let title = isOwned
            ? L10n.tr("iap.owned", fallback: "OWNED")
            : IAPManager.shared.localizedPrice(for: product)
        let buyBtn = PixelButton(title: title,
                                  size: CGSize(width: 110, height: 38),
                                  style: isOwned ? .secondary : .primary,
                                  color: UIColor(hex: "#FF9500"),
                                  fontSize: 13)
        buyBtn.position = CGPoint(x: dialogSize.width / 2 - 78, y: y)
        if isOwned {
            buyBtn.setEnabled(false)
        } else {
            buyBtn.onTap = { [weak self] in self?.buy(product) }
        }
        scrollNode.addChild(buyBtn)
        iapPriceButtons[product] = buyBtn
    }

    private func addRewardPreview(coins: Int,
                                  diamonds: Int,
                                  suffix: String?,
                                  position: CGPoint,
                                  maxWidth: CGFloat,
                                  fontSize: CGFloat) {
        let rewardNode = SKNode()
        rewardNode.position = position
        var nextX: CGFloat = 0

        let items = [
            coins > 0 ? CurrencyAmountItem(.coins, coins) : nil,
            diamonds > 0 ? CurrencyAmountItem(.diamonds, diamonds) : nil
        ].compactMap { $0 }

        if !items.isEmpty {
            let amountNode = CurrencyAmountsNode(items: items,
                                                 amountPrefix: "+",
                                                 fontSize: fontSize,
                                                 iconSize: fontSize + 3,
                                                 spacing: 10,
                                                 alignment: .leading)
            amountNode.position = .zero
            rewardNode.addChild(amountNode)
            nextX = amountNode.contentWidth + 8
        }

        if let suffix, !suffix.isEmpty {
            let suffixLbl = SKLabelNode(fontNamed: "Courier")
            suffixLbl.text = suffix
            suffixLbl.fontSize = fontSize
            suffixLbl.fontColor = items.isEmpty ? UIColor(hex: "#AF52DE") : UIColor(hex: "#99BBCC")
            suffixLbl.verticalAlignmentMode = .center
            suffixLbl.horizontalAlignmentMode = .left
            suffixLbl.position = CGPoint(x: nextX, y: 0)
            rewardNode.addChild(suffixLbl)
        }

        guard !rewardNode.children.isEmpty else { return }
        scrollNode.addChild(rewardNode)

        let width = rewardNode.calculateAccumulatedFrame().width
        if width > maxWidth {
            rewardNode.setScale(max(0.7, maxWidth / max(width, 1)))
        }
    }

    /// "Restore Purchases" 一行：苹果上架要求非消耗品商店暴露该入口。
    private func addRestoreRow(y: CGFloat) {
        let restoreBtn = PixelButton(title: L10n.tr("iap.restore", fallback: "Restore Purchases"),
                                     size: CGSize(width: 220, height: 36),
                                     style: .ghost,
                                     color: UIColor(hex: "#7799CC"),
                                     fontSize: 12)
        restoreBtn.position = CGPoint(x: 0, y: y)
        restoreBtn.onTap = { [weak self] in self?.restore() }
        scrollNode.addChild(restoreBtn)
    }

    private func buy(_ product: IAPProduct) {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        AudioManager.shared.play(.buttonTap)
        let btn = iapPriceButtons[product]
        let originalTitle = product == .noAds ? IAPManager.shared.localizedPrice(for: product) : nil
        btn?.setTitle(L10n.tr("iap.processing", fallback: "..."))
        btn?.setEnabled(false)

        IAPManager.shared.purchase(product) { [weak self] ok, errMsg in
            Task { @MainActor in
                guard let self = self else { return }
                self.purchaseInFlight = false
                if ok {
                    AudioManager.shared.play(.coinCollect)
                    self.onCurrencyChanged?()
                    self.refreshPrices()
                } else {
                    // 失败/取消都恢复按钮态；errMsg == nil 表示用户取消，不弹错。
                    if product == .noAds {
                        btn?.setTitle(originalTitle ?? IAPManager.shared.localizedPrice(for: product))
                    } else {
                        btn?.setTitle(IAPManager.shared.localizedPrice(for: product))
                    }
                    btn?.setEnabled(true)
                    if let msg = errMsg {
                        PixelMatchCashierUIProvider().showToast(message: msg)
                    }
                }
            }
        }
    }

    private func restore() {
        AudioManager.shared.play(.buttonTap)
        IAPManager.shared.restorePurchases { [weak self] ok in
            Task { @MainActor in
                let provider = PixelMatchCashierUIProvider()
                if ok {
                    provider.showToast(message: L10n.tr("iap.restore.success",
                                                         fallback: "Purchases restored"))
                    self?.refreshPrices()
                    self?.onCurrencyChanged?()
                } else {
                    provider.showToast(message: L10n.tr("iap.restore.failed",
                                                         fallback: "Nothing to restore"))
                }
            }
        }
    }

    /// 重渲染所有 IAP 行的价格/已购态。在异步取价完成、购买成功、Restore 成功后调用。
    private func refreshPrices() {
        for (product, btn) in iapPriceButtons {
            let isOwned = (product == .noAds) && PlayerData.shared.noAds
            if isOwned {
                btn.setTitle(L10n.tr("iap.owned", fallback: "OWNED"))
                btn.setEnabled(false)
            } else {
                btn.setTitle(IAPManager.shared.localizedPrice(for: product))
                btn.setEnabled(true)
            }
        }
    }

    private func addShopItem(name: String, diamonds: Int, coins: Int, price: String, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 40, height: 64), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let nameLbl = SKLabelNode(fontNamed: "Courier-Bold")
        nameLbl.text = name
        nameLbl.fontSize = 14
        nameLbl.fontColor = .white
        nameLbl.verticalAlignmentMode = .center
        nameLbl.horizontalAlignmentMode = .left
        nameLbl.position = CGPoint(x: -dialogSize.width / 2 + 34, y: y + 12)
        scrollNode.addChild(nameLbl)

        addRewardPreview(coins: coins,
                         diamonds: diamonds,
                         suffix: nil,
                         position: CGPoint(x: -dialogSize.width / 2 + 34, y: y - 12),
                         maxWidth: dialogSize.width - 40 - 34 - 120,
                         fontSize: 13)

        let buyBtn = PixelButton(title: price,
                                  size: CGSize(width: 110, height: 36),
                                  style: .primary,
                                  color: UIColor(hex: "#FF9500"),
                                  fontSize: 13)
        buyBtn.position = CGPoint(x: dialogSize.width / 2 - 78, y: y)
        buyBtn.onTap = { AudioManager.shared.play(.buttonTap) }
        scrollNode.addChild(buyBtn)
    }

    private func addBoosterItem(type: BoosterType, y: CGFloat) {
        let bg = SKShapeNode(rectOf: CGSize(width: dialogSize.width - 40, height: 48), cornerRadius: 8)
        bg.fillColor = UIColor(hex: "#0F1E33")
        bg.strokeColor = UIColor(hex: "#1C3A5C")
        bg.lineWidth = 1.5
        bg.position = CGPoint(x: 0, y: y)
        scrollNode.addChild(bg)

        let icon = SKSpriteNode(texture: PixelArt.shared.softIconTexture(type.artIcon, size: 32),
                                size: CGSize(width: 28, height: 28))
        icon.position = CGPoint(x: -dialogSize.width / 2 + 40, y: y)
        scrollNode.addChild(icon)

        let lbl = SKLabelNode(fontNamed: "Courier-Bold")
        lbl.text = type.name
        lbl.fontSize = 14
        lbl.fontColor = .white
        lbl.verticalAlignmentMode = .center
        lbl.horizontalAlignmentMode = .left
        lbl.position = CGPoint(x: -dialogSize.width / 2 + 70, y: y + 9)
        scrollNode.addChild(lbl)

        let countLbl = SKLabelNode(fontNamed: "Courier-Bold")
        countLbl.text = "×\(ownedCount(of: type))"
        countLbl.fontSize = 11
        countLbl.fontColor = UIColor(hex: "#7799CC")
        countLbl.verticalAlignmentMode = .center
        countLbl.horizontalAlignmentMode = .left
        countLbl.position = CGPoint(x: -dialogSize.width / 2 + 70, y: y - 11)
        scrollNode.addChild(countLbl)
        boosterCountLabels[type] = countLbl

        let buyBtn = PixelButton(title: "\(type.cost)",
                                  icon: .coin,
                                  size: CGSize(width: 90, height: 34),
                                  style: .primary,
                                  color: UIColor(hex: "#FFCC00"),
                                  fontSize: 13)
        buyBtn.onTap = { [weak self] in
            guard let self = self else { return }
            if PlayerData.shared.spendCoins(type.cost) {
                PlayerData.shared.addBooster(type)
                AudioManager.shared.play(.coinCollect)
                self.boosterCountLabels[type]?.text = "×\(self.ownedCount(of: type))"
                self.onCurrencyChanged?()
            } else {
                PixelMatchCashierUIProvider().showToast(
                    message: L10n.tr("shop.not_enough_coins", fallback: "Not enough coins!"))
            }
        }
        buyBtn.position = CGPoint(x: dialogSize.width / 2 - 70, y: y)
        scrollNode.addChild(buyBtn)
    }

    private func ownedCount(of type: BoosterType) -> Int {
        switch type {
        case .hammer: return PlayerData.shared.hammerCount
        case .shuffle: return PlayerData.shared.shuffleCount
        case .extraMoves: return PlayerData.shared.extraMovesCount
        case .colorBomb: return PlayerData.shared.colorBombCount
        }
    }

    private func clampScrollY(_ y: CGFloat) -> CGFloat {
        let minY = viewportTop
        let maxY = max(minY, viewportBottom + contentHeight)
        return max(minY, min(maxY, y))
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let loc = touch.location(in: self)
        isTrackingScroll = abs(loc.x) <= dialogSize.width / 2 - 12
            && loc.y <= viewportTop
            && loc.y >= viewportBottom
        didDrag = false
        touchStartY = loc.y
        scrollStartY = scrollNode.position.y
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard isTrackingScroll, let touch = touches.first else { return }
        let currentY = touch.location(in: self).y
        if abs(currentY - touchStartY) > 4 { didDrag = true }
        scrollNode.position.y = clampScrollY(scrollStartY + currentY - touchStartY)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        defer {
            isTrackingScroll = false
            didDrag = false
        }
        guard !didDrag, let touch = touches.first else { return }
        let loc = touch.location(in: self)
        let closeY = -dialogSize.height / 2 + 38
        if abs(loc.x) <= 120 && abs(loc.y - closeY) <= 26 {
            onClose?()
        }
    }
}

// MARK: - Buy Booster Dialog

/// 游戏内点道具但数量为 0 时的轻量购买确认：
/// 金币足够 → 就地用金币买 1 个并继续道具流程，不打断对局；
/// 金币不足 → 引导打开 ShopDialog 金币区。
final class BuyBoosterDialog: DialogNode {

    var onBuy: (() -> Void)?
    var onGetCoins: (() -> Void)?
    var onCancel: (() -> Void)?

    init(sceneSize: CGSize, type: BoosterType) {
        super.init(size: CGSize(width: 280, height: 320), sceneSize: sceneSize)
        buildUI(type: type)
    }

    required init?(coder: NSCoder) { fatalError() }

    private func buildUI(type: BoosterType) {
        addPixelTitle(type.name, y: 120, size: 20)

        let icon = SKSpriteNode(texture: PixelArt.shared.softIconTexture(type.artIcon, size: 64),
                                size: CGSize(width: 56, height: 56))
        icon.position = CGPoint(x: 0, y: 62)
        addChild(icon)

        let affordable = PlayerData.shared.coins >= type.cost

        let costText = L10n.fmt("shop.booster_cost", type.cost, fallback: "Cost: %d")
        let costParts = CurrencyText.surroundingAmount(in: costText, amount: type.cost)
        let costNode = CurrencyAmountNode(kind: .coins,
                                          amount: type.cost,
                                          leadingText: costParts.leading,
                                          trailingText: costParts.trailing,
                                          fontSize: 16,
                                          iconSize: 18,
                                          fontColor: UIColor(hex: "#FFCC00"))
        costNode.position = CGPoint(x: 0, y: 12)
        addChild(costNode)

        let balanceText = L10n.fmt("shop.your_coins", PlayerData.shared.coins, fallback: "You have: %d")
        let balanceParts = CurrencyText.surroundingAmount(in: balanceText, amount: PlayerData.shared.coins)
        let balanceNode = CurrencyAmountNode(kind: .coins,
                                             amount: PlayerData.shared.coins,
                                             leadingText: balanceParts.leading,
                                             trailingText: balanceParts.trailing,
                                             fontSize: 13,
                                             iconSize: 15,
                                             fontColor: affordable ? UIColor(hex: "#7799CC") : UIColor(hex: "#FF3B30"))
        balanceNode.position = CGPoint(x: 0, y: -16)
        addChild(balanceNode)

        let primaryTitle = affordable
            ? L10n.tr("shop.buy_one", fallback: "BUY ×1")
            : L10n.tr("shop.get_coins", fallback: "GET COINS")
        let primaryBtn = PixelButton(title: primaryTitle,
                                     icon: .coin,
                                     size: CGSize(width: 220, height: 48),
                                     style: .primary,
                                     color: UIColor(hex: affordable ? "#34C759" : "#FF9500"))
        primaryBtn.position = CGPoint(x: 0, y: -62)
        primaryBtn.onTap = { [weak self] in
            if affordable {
                self?.onBuy?()
            } else {
                self?.onGetCoins?()
            }
        }
        addChild(primaryBtn)

        let cancelBtn = PixelButton(title: L10n.upper(L10n.tr("common.cancel", fallback: "Cancel")),
                                    size: CGSize(width: 220, height: 44),
                                    style: .secondary, fontSize: 14)
        cancelBtn.position = CGPoint(x: 0, y: -118)
        cancelBtn.onTap = { [weak self] in self?.onCancel?() }
        addChild(cancelBtn)
    }
}
