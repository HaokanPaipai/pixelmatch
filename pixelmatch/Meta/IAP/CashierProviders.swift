//
//  CashierProviders.swift
//  pixelmatch
//
//  HKIAPKit 4 个解耦协议的 PixelMatch 实现。HKIAPKit 把"App 特化"部分外推给
//  宿主：网络、用户态、UI、埋点。参考 goodlook 的 `Providers/Goodlook*.swift`，
//  但 PixelMatch 是单机 SpriteKit 游戏（无 UserLoginManager / NetworkTool / UIKit 容器），
//  这里给出最小适配。
//

import UIKit
import HKIAPKit
import SwiftyJSON

// MARK: - Network

/// 走 IAPHTTPClient（签名 + Cookie + 公参）。返回完整信封 JSON 给 HKIAPKit。
final class PixelMatchCashierNetworkProvider: CashierNetworkProvider {

    var baseHost: String { IAPEnvironment.baseHost }

    func post(path: String,
              parameters: [String: Any],
              completion: @escaping (JSON?, Bool) -> Void) {
        IAPHTTPClient.shared.post(path: path, parameters: parameters) { envelope, ok in
            guard let envelope = envelope else { completion(nil, false); return }
            completion(JSON(envelope), ok)
        }
    }
}

// MARK: - User

/// PixelMatch 无登录体系：匿名设备会话即"已登录"。游戏内只有消耗品 + 单次
/// 解锁（去广告），没有自动续订订阅，故 currentPurchase 恒为 nil。
final class PixelMatchCashierUserProvider: CashierUserProvider {

    var isLoggedIn: Bool { IAPDeviceIdentity.hasSession }

    var currentPurchase: CashierPurchaseSnapshot? { nil }

    /// 服务端验票/恢复成功后回写。只处理**单次解锁**（去广告）这类幂等权益——
    /// 消耗品（金币/钻石）的发放走 `applyConsumablePurchase`，靠 transactionID 去重，
    /// 这里不再处理（避免 updateReceipt 每次启动重复发放）。
    func applyVerifiedPurchase(_ data: VerifyTransactionDataModel) {
        guard let pid = data.productId, !pid.isEmpty,
              let product = IAPProduct(rawValue: pid),
              product == .noAds else { return }
        PlayerData.shared.setNoAds()
    }

    /// HKIAPKit v1.1 新增钩子：消耗品入账。按 transactionID 去重，保证补单 / restore
    /// 时不会双发。amount 由 HKIAPKit 经 ProductBundle.consumableAmount 推断，PixelMatch
    /// 没用 ProductBundle plist（IAPProduct enum 自带 apply() 逻辑），所以这里仍按 productID
    /// 路由到 IAPProduct.apply()，仅做幂等。
    func applyConsumablePurchase(productID: String, amount: Int, transactionID: String) {
        guard let product = IAPProduct(rawValue: productID), product != .noAds else { return }

        let key = "iap_consumed_tx_\(transactionID)"
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: key) else { return }
        defaults.set(true, forKey: key)

        // 经 withIAPGrant 包裹：发放产生的钱包 mutation 用确定性 id
        // （iap_<txn>_<currency>），服务端按 mutation_id 幂等，补单/重放不双发。
        WalletSyncManager.shared.withIAPGrant(transactionID: transactionID) {
            product.apply()
        }
    }

    func refreshUserInfo() { /* 单机无远端用户模型，无需刷新 */ }
}

// MARK: - UI

/// SpriteKit 游戏没有 UIKit 容器，统一挂到当前 key window 的顶层 VC 上。
final class PixelMatchCashierUIProvider: CashierUIProvider {

    func showToast(message: String) {
        DispatchQueue.main.async {
            guard let view = Self.topViewController()?.view else { return }
            let label = PaddingLabel()
            label.text = message
            label.numberOfLines = 0
            label.textColor = .white
            label.font = .systemFont(ofSize: 14, weight: .medium)
            label.backgroundColor = UIColor.black.withAlphaComponent(0.82)
            label.textAlignment = .center
            label.layer.cornerRadius = 10
            label.clipsToBounds = true
            label.alpha = 0
            label.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(label)
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                label.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -80),
                label.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 32),
                label.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -32)
            ])
            UIView.animate(withDuration: 0.2, animations: { label.alpha = 1 }) { _ in
                UIView.animate(withDuration: 0.3, delay: 1.8, options: []) {
                    label.alpha = 0
                } completion: { _ in label.removeFromSuperview() }
            }
        }
    }

    func presentAlert(title: String, message: String) {
        DispatchQueue.main.async {
            guard let top = Self.topViewController() else { return }
            let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("common.ok", fallback: "OK"), style: .cancel))
            top.present(alert, animated: true)
        }
    }

    func showTransferConfirmation(onConfirm: @escaping () -> Void) {
        // PixelMatch 无订阅，理论上不会触发订阅转移；保留实现保证协议完整。
        DispatchQueue.main.async {
            guard let top = Self.topViewController() else { return }
            let alert = UIAlertController(
                title: L10n.tr("iap.transfer.title", fallback: "Subscription Linked Elsewhere"),
                message: L10n.tr("iap.transfer.message", fallback: "Transfer it to this device?"),
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: L10n.tr("iap.transfer.confirm", fallback: "Transfer"),
                                          style: .destructive) { _ in onConfirm() })
            alert.addAction(UIAlertAction(title: L10n.tr("common.cancel", fallback: "Cancel"), style: .cancel))
            top.present(alert, animated: true)
        }
    }

    static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
        var top = (scene?.windows.first { $0.isKeyWindow } ?? scene?.windows.first)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// 带内边距的 toast 标签。
    private final class PaddingLabel: UILabel {
        private let inset = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
        override func drawText(in rect: CGRect) { super.drawText(in: rect.inset(by: inset)) }
        override var intrinsicContentSize: CGSize {
            let s = super.intrinsicContentSize
            return CGSize(width: s.width + inset.left + inset.right,
                          height: s.height + inset.top + inset.bottom)
        }
    }
}

// MARK: - Premium

/// PixelMatch 没有订阅，只有「去广告」单次解锁。所以：
/// · isPremium  = noAds 标志（IAP 唯一付费层级）
/// · currentTier = "noads"（用 App 自定义字符串，nil 表未付费）
/// · premiumExpiresAt = noAds 时返回 .distantFuture（单次解锁无到期）
/// · tierIncludes 固定返回 isPremium（无细粒度特权矩阵）
///
/// 该 Provider 是 HKIAPKit v1.1 引入的第 5 个 Provider（INTEGRATION.md Step 5）；
/// HKAdKit 经由 CashierManager.shared.isPremium 复用此判断（[[PixelMatchAdUserProvider]]），
/// 避免 noAds 状态出现两套真相。
final class PixelMatchCashierPremiumProvider: CashierPremiumProvider {

    var isPremium: Bool { PlayerData.shared.noAds }

    var currentTier: String? { PlayerData.shared.noAds ? "noads" : nil }

    var premiumExpiresAt: Date? { PlayerData.shared.noAds ? .distantFuture : nil }

    func tierIncludes(_ feature: String) -> Bool { isPremium }
}

// MARK: - Analytics

/// 桥接到 PixelMatch 既有 AnalyticsManager（本地事件存储）。
final class PixelMatchCashierAnalyticsProvider: CashierAnalyticsProvider {

    func track(_ event: CashierAnalyticsEvent) {
        switch event {
        case .purchaseStart(let pid):
            AnalyticsManager.shared.track(.iapPurchaseStart, properties: ["product_id": pid])
        case .purchaseSuccess(let pid):
            AnalyticsManager.shared.track(.iapPurchaseSuccess, properties: ["product_id": pid])
        case .purchaseFail(let pid, let reason):
            var props = ["reason": reason]
            if let pid = pid { props["product_id"] = pid }
            AnalyticsManager.shared.track(.iapPurchaseFail, properties: props)
        }
    }
}
