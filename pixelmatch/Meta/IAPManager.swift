//
//  IAPManager.swift
//  pixelmatch
//
//  PixelMatch 的 IAP 门面：包装共享 SDK **HKIAPKit**（CashierManager），
//  复用 Goodlook 后端（bundle_id=com.goodloook.pixelmatch 做多 App 隔离）。
//
//  购买完整链路（契约 Contracts/api/iap-overview.md）：
//    /auth/device-session → /product/getList → StoreKit 取价 →
//    /order/create → StoreKit 支付 → /transaction/verifyReceipt → 本地发放
//
//  本文件只负责"PixelMatch 侧"的编排与权益发放；签名/Cookie/验票全在
//  HKIAPKit + 4 个 Provider 内完成。
//

import StoreKit
import HKIAPKit

// MARK: - Product IDs / 本地权益映射

enum IAPProduct: String, CaseIterable {
    // Coin packs
    case coins500    = "com.goodloook.pixelmatch.coins.500"
    case coins1500   = "com.goodloook.pixelmatch.coins.1500"
    case coins5000   = "com.goodloook.pixelmatch.coins.5000"

    // Diamond packs
    case diamonds20  = "com.goodloook.pixelmatch.diamonds.20"
    case diamonds80  = "com.goodloook.pixelmatch.diamonds.80"
    case diamonds300 = "com.goodloook.pixelmatch.diamonds.300"

    // Booster packs
    case starterPack = "com.goodloook.pixelmatch.pack.starter"
    case megaPack    = "com.goodloook.pixelmatch.pack.mega"

    // No-ads (单次解锁：永久移除广告)
    case noAds       = "com.goodloook.pixelmatch.removeads"

    var displayName: String {
        switch self {
        case .coins500:    return L10n.tr("iap.coins500", fallback: "500 Coins")
        case .coins1500:   return L10n.tr("iap.coins1500", fallback: "1,500 Coins")
        case .coins5000:   return L10n.tr("iap.coins5000", fallback: "5,000 Coins")
        case .diamonds20:  return L10n.tr("iap.diamonds20", fallback: "20 Diamonds")
        case .diamonds80:  return L10n.tr("iap.diamonds80", fallback: "80 Diamonds")
        case .diamonds300: return L10n.tr("iap.diamonds300", fallback: "300 Diamonds")
        case .starterPack: return L10n.tr("iap.starter_pack", fallback: "Starter Pack")
        case .megaPack:    return L10n.tr("iap.mega_pack", fallback: "Mega Pack")
        case .noAds:       return L10n.tr("iap.remove_ads", fallback: "Remove Ads")
        }
    }

    /// 后端/StoreKit 不可用时的兜底展示价。
    var localPrice: String {
        switch self {
        case .coins500:    return "$0.99"
        case .coins1500:   return "$1.99"
        case .coins5000:   return "$4.99"
        case .diamonds20:  return "$0.99"
        case .diamonds80:  return "$2.99"
        case .diamonds300: return "$9.99"
        case .starterPack: return "$1.99"
        case .megaPack:    return "$6.99"
        case .noAds:       return "$2.99"
        }
    }

    /// 商店列表里展示"买到什么"的副文案。
    var shopRewardText: String {
        switch self {
        case .coins500:    return "+500 🪙"
        case .coins1500:   return "+1,500 🪙"
        case .coins5000:   return "+5,000 🪙"
        case .diamonds20:  return "+20 💎"
        case .diamonds80:  return "+80 💎"
        case .diamonds300: return "+300 💎"
        case .starterPack: return "+300 🪙  +10 💎  +3 🔨"
        case .megaPack:    return "+1,000 🪙  +50 💎  +boosters"
        case .noAds:       return L10n.tr("iap.remove_ads.desc", fallback: "Remove all ads forever")
        }
    }

    /// 商店真钱档位的展示顺序。Booster（金币购买）仍走 ShopDialog 原有区块。
    static var shopCatalog: [IAPProduct] {
        [.starterPack, .diamonds20, .diamonds80, .diamonds300,
         .coins500, .coins1500, .coins5000, .megaPack, .noAds]
    }

    /// 服务端验票成功后在本地发放权益（PixelMatch 经济为客户端记账）。
    func apply() {
        switch self {
        case .coins500:    PlayerData.shared.addCoins(500)
        case .coins1500:   PlayerData.shared.addCoins(1500)
        case .coins5000:   PlayerData.shared.addCoins(5000)
        case .diamonds20:  PlayerData.shared.addDiamonds(20)
        case .diamonds80:  PlayerData.shared.addDiamonds(80)
        case .diamonds300: PlayerData.shared.addDiamonds(300)
        case .starterPack:
            PlayerData.shared.addCoins(300)
            PlayerData.shared.addDiamonds(10)
            PlayerData.shared.hammerCount += 3
            PlayerData.shared.colorBombCount += 1
        case .megaPack:
            PlayerData.shared.addCoins(1000)
            PlayerData.shared.addDiamonds(50)
            PlayerData.shared.hammerCount += 10
            PlayerData.shared.shuffleCount += 5
            PlayerData.shared.colorBombCount += 3
            PlayerData.shared.extraMovesCount += 5
        case .noAds:
            PlayerData.shared.setNoAds()
        }
    }
}

// MARK: - IAP Manager

@MainActor
final class IAPManager {

    static let shared = IAPManager()
    private init() {}

    private let cashier = CashierManager.shared
    private var products: [ProductItemModel] = []
    private var didConfigure = false

    // MARK: 启动

    /// App 启动调用：注入 4 个 Provider、建匿名会话、补单、预拉商品。
    func start() {
        guard !didConfigure else { return }
        didConfigure = true

        cashier.networkProvider   = PixelMatchCashierNetworkProvider()
        cashier.userProvider      = PixelMatchCashierUserProvider()
        cashier.premiumProvider   = PixelMatchCashierPremiumProvider()
        cashier.uiProvider        = PixelMatchCashierUIProvider()
        cashier.analyticsProvider = PixelMatchCashierAnalyticsProvider()

        IAPHTTPClient.shared.ensureSession { [weak self] _ in
            // 无论会话是否建立都跑 setupIAP：补单逻辑只依赖本地未完成订单 + StoreKit。
            self?.cashier.setupIAP()
            self?.reloadProducts(completion: nil)
        }
    }

    // MARK: 商品

    /// 拉后端商品配置（按 bundle_id 过滤）并向 StoreKit 取本地化价格。
    func reloadProducts(completion: ((Bool) -> Void)?) {
        cashier.requestProductList { [weak self] list, ok in
            guard ok, let list = list else { completion?(false); return }
            self?.cashier.requestProductInfoBy(list) { filled, _ in
                self?.products = filled ?? []
                completion?(true)
            }
        }
    }

    func localizedPrice(for productID: IAPProduct) -> String {
        guard let model = products.first(where: { $0.productId == productID.rawValue }) else {
            return productID.localPrice
        }
        if let sk = model.skProduct {
            let f = NumberFormatter()
            f.numberStyle = .currency
            f.locale = sk.priceLocale
            return f.string(from: sk.price) ?? (model.price ?? productID.localPrice)
        }
        return model.price ?? productID.localPrice
    }

    // MARK: 购买

    /// 完整购买。completion 在主线程回调：(成功, 错误文案?)；用户取消时错误文案为 nil。
    func purchase(_ productID: IAPProduct, completion: @escaping (Bool, String?) -> Void) {
        IAPHTTPClient.shared.ensureSession { [weak self] sessionOK in
            guard let self = self else { return }
            guard sessionOK else {
                completion(false, L10n.tr("iap.error.network", fallback: "Network unavailable. Try again later."))
                return
            }
            self.ensureProductsThenPurchase(productID, completion: completion)
        }
    }

    private func ensureProductsThenPurchase(_ productID: IAPProduct,
                                            completion: @escaping (Bool, String?) -> Void) {
        if products.contains(where: { $0.productId == productID.rawValue }) {
            startOrderAndPay(productID, completion: completion)
        } else {
            reloadProducts { [weak self] _ in
                self?.startOrderAndPay(productID, completion: completion)
            }
        }
    }

    private func startOrderAndPay(_ productID: IAPProduct,
                                  completion: @escaping (Bool, String?) -> Void) {
        guard let model = products.first(where: { $0.productId == productID.rawValue }),
              let skProduct = model.skProduct else {
            #if DEBUG
            // 后端/StoreKit 未配置该商品时，Debug 下本地发放便于联调经济系统。
            productID.apply()
            completion(true, nil)
            #else
            completion(false, L10n.tr("iap.error.unavailable", fallback: "This item is currently unavailable."))
            #endif
            return
        }

        cashier.createOrder(model) { [weak self] orderModel, ok in
            guard ok, let orderData = orderModel?.data, orderModel?.code == "100000" else {
                completion(false, L10n.tr("iap.error.order", fallback: "Could not start the purchase. Try again."))
                return
            }
            // 必须传 productType：老入口默认按订阅处理，消耗品会错走订阅验票链
            // 而不是 transaction/creditConsumable 入账链（10=消耗品 11=单次解锁，
            // 来自后端 product_config.product_type，见 Backend V35 迁移）。
            self?.cashier.purchase(skProduct, productType: model.productType, orderData: orderData, atomically: false) { _, success, type in
                switch type {
                case .success where success:
                    // 消耗品权益由 HKIAPKit 回调 applyConsumablePurchase 发放
                    // （transactionID 幂等），这里不再 apply 防双发；
                    // noAds 走订阅链 applyVerifiedPurchase，本地再兜底一次（setNoAds 幂等）。
                    if productID == .noAds { productID.apply() }
                    completion(true, nil)
                case .paymentCancelled:
                    completion(false, nil)
                case .success, .failed, .unknown, .purchasing:
                    completion(false, L10n.tr("iap.error.failed", fallback: "Purchase failed. You were not charged."))
                @unknown default:
                    completion(false, L10n.tr("iap.error.failed", fallback: "Purchase failed. You were not charged."))
                }
            }
        }
    }

    // MARK: 恢复购买

    func restorePurchases(completion: @escaping (Bool) -> Void) {
        cashier.restorePurchases { _, result, _, state in
            // 非消耗品（去广告）的恢复发放由 CashierUserProvider.applyVerifiedPurchase 完成。
            // HKIAPKit 经 SwiftyStoreKit 回调，线程不保证；调用方（HomeScene）会刷新 SKNode/UI，
            // 故统一切回主线程再回调。
            let ok = result && (state == .success || state == .noneRestore)
            DispatchQueue.main.async { completion(ok) }
        }
    }
}
