//
//  WalletSyncManager.swift
//  pixelmatch
//
//  云端钱包同步（契约 Contracts/api/game-wallet.md）。
//
//  职责：
//    1. PlayerData 货币 setter 钩子把每次变化量记入本地持久化队列；
//    2. 在会话建立后 / 进后台 / IAP 成功后 / 变更 debounce 时批量 flush 到
//       POST wallet/sync（mutation_id 幂等，重复上报服务端只入账一次）；
//    3. flush 成功且队列清空时，用响应中的服务端权威余额覆盖本地；
//    4. 首启对账（reconcile）：服务端有余额 = 删除重装 → 播种本地；
//       服务端无记录 = 老玩家首次升级/新玩家 → 上报 baseline。
//
//  线程约定：全部在主线程使用（SpriteKit 游戏逻辑与 IAPHTTPClient 回调均在主线程）。
//

import Foundation
import UIKit

/// 钱包币种，rawValue 与契约 currency 字符串一致。
enum WalletCurrency: String, CaseIterable {
    case coins
    case diamonds
    case hammer
    case shuffle
    case extraMoves = "extra_moves"
    case colorBomb = "color_bomb"
}

final class WalletSyncManager {

    static let shared = WalletSyncManager()
    private init() {}

    private enum Key {
        static let queue = "wallet.pendingMutations"
        static let baselined = "wallet.baselined"
    }

    /// 单次请求最多携带的 mutation 数（服务端上限 200，留余量）。
    private static let flushBatchSize = 100
    /// 队列超过该长度时把非 IAP 变更按币种合并，防止长期离线无限膨胀。
    private static let compactThreshold = 500

    private var started = false
    private var flushInFlight = false
    private var debounceWork: DispatchWorkItem?

    /// IAP 发放上下文：非空时钩子 mutation 用确定性 id（iap_<txn>_<currency>），
    /// 类型记 iap_grant，补单/重放在服务端被幂等去重。
    private var iapTransactionID: String?

    // MARK: - 队列

    private var pending: [[String: Any]] {
        get { UserDefaults.standard.array(forKey: Key.queue) as? [[String: Any]] ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Key.queue) }
    }

    /// PlayerData setter 钩子入口。
    func noteChange(_ currency: WalletCurrency, delta: Int) {
        guard delta != 0 else { return }
        var mutation: [String: Any] = [
            "currency": currency.rawValue,
            "delta": delta
        ]
        if let txn = iapTransactionID {
            mutation["mutation_id"] = "iap_\(txn)_\(currency.rawValue)"
            mutation["change_type"] = "iap_grant"
        } else {
            mutation["mutation_id"] = UUID().uuidString.replacingOccurrences(of: "-", with: "")
            mutation["change_type"] = delta > 0 ? "earn" : "use"
        }
        var queue = pending
        queue.append(mutation)
        pending = queue
        compactIfNeeded()
        scheduleDebouncedFlush()
    }

    /// IAP 消耗品发放包裹：body 内产生的变更带确定性 mutation_id，并立刻 flush
    /// （真金白银，最小化"已发放未上报"窗口）。
    func withIAPGrant(transactionID: String, _ body: () -> Void) {
        iapTransactionID = transactionID.isEmpty ? nil : transactionID
        body()
        iapTransactionID = nil
        flush()
    }

    /// 长期离线保护：非 IAP 变更按币种合并成单条（IAP 条目保留幂等 id 不合并）。
    private func compactIfNeeded() {
        var queue = pending
        guard queue.count > Self.compactThreshold else { return }
        var merged: [String: Int] = [:]
        var kept: [[String: Any]] = []
        for m in queue {
            let type = m["change_type"] as? String ?? ""
            if type == "iap_grant" || type == "baseline" {
                kept.append(m)
            } else {
                let currency = m["currency"] as? String ?? ""
                merged[currency, default: 0] += m["delta"] as? Int ?? 0
            }
        }
        for (currency, delta) in merged where delta != 0 {
            kept.append([
                "mutation_id": UUID().uuidString.replacingOccurrences(of: "-", with: ""),
                "currency": currency,
                "delta": delta,
                "change_type": delta > 0 ? "earn" : "use",
                "remark": "compacted"
            ])
        }
        queue = kept
        pending = queue
    }

    // MARK: - 启动 / 对账

    /// 会话建立成功后调用（IAPHTTPClient.ensureSession 成功路径）。幂等。
    func start() {
        if !started {
            started = true
            NotificationCenter.default.addObserver(
                forName: UIApplication.didEnterBackgroundNotification,
                object: nil, queue: .main
            ) { [weak self] _ in
                self?.flush()
            }
        }
        if UserDefaults.standard.bool(forKey: Key.baselined) {
            flush()
        } else {
            reconcile()
        }
    }

    /// 首启对账。失败不置 baselined 标记，下次启动重试。
    private func reconcile() {
        IAPHTTPClient.shared.post(path: "wallet/get", parameters: [:]) { [weak self] envelope, ok in
            guard let self = self, ok,
                  let result = envelope?["result"] as? [String: Any],
                  let raw = result["balances"] as? [String: Any] else { return }

            var serverBalances: [WalletCurrency: Int] = [:]
            for (key, value) in raw {
                if let currency = WalletCurrency(rawValue: key), let n = value as? Int {
                    serverBalances[currency] = n
                }
            }

            if serverBalances.isEmpty {
                self.enqueueBaseline()
            } else {
                // 服务端有余额 = 删除重装：丢弃本地队列（含 completeFirstLaunch 重发的
                // 初始资源，防止反复重装薅初始币），以服务端为准播种本地。
                self.pending = self.pending.filter { ($0["change_type"] as? String) == "iap_grant" }
                PlayerData.shared.applyServerBalances(serverBalances)
            }
            UserDefaults.standard.set(true, forKey: Key.baselined)
            self.flush()
        }
    }

    /// 老玩家首次升级 / 新玩家：把当前本地余额作为基线上报。
    /// 基线 = 本地余额 - 队列中尚未上报的增量（这些增量随后会正常入账，避免双计）。
    private func enqueueBaseline() {
        var queuedDelta: [String: Int] = [:]
        for m in pending {
            let currency = m["currency"] as? String ?? ""
            queuedDelta[currency, default: 0] += m["delta"] as? Int ?? 0
        }
        var queue = pending
        for currency in WalletCurrency.allCases {
            let baseline = PlayerData.shared.walletBalance(of: currency)
                - (queuedDelta[currency.rawValue] ?? 0)
            guard baseline > 0 else { continue }
            queue.append([
                "mutation_id": "baseline_\(IAPDeviceIdentity.deviceId)_\(currency.rawValue)",
                "currency": currency.rawValue,
                "delta": baseline,
                "change_type": "baseline"
            ])
        }
        pending = queue
    }

    // MARK: - Flush

    private func scheduleDebouncedFlush() {
        debounceWork?.cancel()
        let work = DispatchWorkItem { [weak self] in self?.flush() }
        debounceWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5, execute: work)
    }

    /// 立即批量上报队列（≤100/次，剩余递归续传）。
    /// 响应的权威余额仅在队列已清空时覆盖本地（否则本地还有未上报增量，服务端值是旧的）。
    func flush() {
        guard started, !flushInFlight, IAPDeviceIdentity.hasSession else { return }
        guard UserDefaults.standard.bool(forKey: Key.baselined) else { return }
        let batch = Array(pending.prefix(Self.flushBatchSize))
        guard !batch.isEmpty else { return }

        flushInFlight = true
        IAPHTTPClient.shared.post(path: "wallet/sync",
                                  parameters: ["mutations": batch]) { [weak self] envelope, ok in
            guard let self = self else { return }
            self.flushInFlight = false
            guard ok, let result = envelope?["result"] as? [String: Any] else { return }

            let sentIds = Set(batch.compactMap { $0["mutation_id"] as? String })
            self.pending = self.pending.filter {
                !sentIds.contains(($0["mutation_id"] as? String) ?? "")
            }

            if self.pending.isEmpty {
                if let raw = result["balances"] as? [String: Any] {
                    var balances: [WalletCurrency: Int] = [:]
                    for (key, value) in raw {
                        if let currency = WalletCurrency(rawValue: key), let n = value as? Int {
                            balances[currency] = n
                        }
                    }
                    if !balances.isEmpty {
                        PlayerData.shared.applyServerBalances(balances)
                    }
                }
            } else {
                self.flush()
            }
        }
    }
}
