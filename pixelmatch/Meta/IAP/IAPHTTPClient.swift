//
//  IAPHTTPClient.swift
//  pixelmatch
//
//  PixelMatch 没有现成网络层，这里实现 HKIAPKit 接入所需的最小 HTTP 客户端：
//    - 注入公共体参数（source / device_id / user_id / bundle_id）
//    - 注入 X-* 公共 Header 并按契约算法签名（X-Sign）
//    - Cookie 认证（URLSession 共享 HTTPCookieStorage 自动持久化）
//    - 解析统一信封 { name, errcode, msg, result }
//    - 匿名设备会话 /auth/device-session（PixelMatch 无登录 UI）
//
//  契约：Contracts/api/_shared.md、user.md（/auth/device-session）。
//

import Foundation
import UIKit

final class IAPHTTPClient {

    static let shared = IAPHTTPClient()

    private let session: URLSession

    private init() {
        let cfg = URLSessionConfiguration.default
        cfg.httpCookieStorage = .shared           // 跨请求/跨启动持久化 user_id/device_id Cookie
        cfg.httpShouldSetCookies = true
        cfg.httpCookieAcceptPolicy = .always
        cfg.timeoutIntervalForRequest = 20
        session = URLSession(configuration: cfg)
    }

    // MARK: - 匿名会话

    /// 确保已建立匿名会话（拿到 user_id + 写入 Cookie）。已有会话直接回调。
    func ensureSession(completion: @escaping (Bool) -> Void) {
        if IAPDeviceIdentity.hasSession {
            WalletSyncManager.shared.start()
            completion(true)
            return
        }
        post(path: "auth/device-session",
             parameters: ["device_id": IAPDeviceIdentity.deviceId]) { envelope, ok in
            guard ok,
                  let result = envelope?["result"] as? [String: Any],
                  let user = result["user"] as? [String: Any] else {
                completion(false); return
            }
            // user_id 后端为整数；统一存成字符串供后续公参/契约使用。
            if let uid = user["user_id"] as? Int {
                IAPDeviceIdentity.userId = "\(uid)"
            } else if let uid = user["user_id"] as? String {
                IAPDeviceIdentity.userId = uid
            }
            // 静默恢复单次解锁：device_id 在 Keychain 持久化 → 重装后同一匿名用户，
            // 响应的 purchase 快照（purchases 表）会带回 removeads（契约 iap-overview.md）。
            if let purchase = user["purchase"] as? [String: Any],
               let pid = purchase["product_id"] as? String,
               pid == IAPProduct.noAds.rawValue,
               ((purchase["cancellation_date_ms"] as? String) ?? "").isEmpty {
                PlayerData.shared.setNoAds()
            }
            if IAPDeviceIdentity.hasSession {
                // 会话就绪后启动云端钱包同步（重装场景在此完成余额播种）。
                WalletSyncManager.shared.start()
            }
            completion(IAPDeviceIdentity.hasSession)
        }
    }

    // MARK: - POST

    /// 发起一次 POST，回调返回解析后的完整信封字典与成功标志（errcode == "100000"）。
    func post(path: String,
              parameters: [String: Any],
              completion: @escaping ([String: Any]?, Bool) -> Void) {

        guard let url = URL(string: IAPEnvironment.baseHost + path) else {
            completion(nil, false); return
        }

        // 1. 公共体参数（契约 _shared.md：source/device_id/user_id 必传）
        var body = parameters
        body["source"] = "1"                                  // 1 = iOS
        body["device_id"] = IAPDeviceIdentity.deviceId
        body["user_id"] = IAPDeviceIdentity.userId             // 未建会话时为 ""
        if body["bundle_id"] == nil {
            body["bundle_id"] = IAPEnvironment.bundleId         // 多 App 区分
        }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])

        // 2. X-* 公共 Header（驼峰 key 参与签名，X-Sign 自身除外）
        let signParams = commonHeaderParams()
        for (camelKey, value) in signParams where !value.isEmpty {
            req.setValue(value, forHTTPHeaderField: headerName(for: camelKey))
        }
        req.setValue(IAPSignUtil.sign(signParams), forHTTPHeaderField: "X-Sign")

        let mainCompletion: ([String: Any]?, Bool) -> Void = { env, ok in
            DispatchQueue.main.async { completion(env, ok) }
        }

        session.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
                mainCompletion(nil, false); return
            }
            let errcode = (json["errcode"] as? String) ?? ""
            if errcode == "300" {
                // 会话过期：清空本地会话，下一次调用会重新匿名注册。
                IAPDeviceIdentity.userId = ""
            }
            mainCompletion(json, errcode == "100000")
        }.resume()
    }

    // MARK: - 公共 Header

    /// 参与签名的公共参数（驼峰 key）。空值由 SignUtil 过滤。
    private func commonHeaderParams() -> [String: String] {
        let screen = UIScreen.main.nativeBounds
        return [
            "requestId": IAPSignUtil.nonce(),
            "deviceId": IAPDeviceIdentity.deviceId,
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "",
            "appBuild": Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "",
            "deviceModel": Self.hardwareModel(),
            "osVersion": UIDevice.current.systemVersion,
            "screenSize": "\(Int(screen.width))x\(Int(screen.height))",
            "deviceRegion": Locale.current.regionCode ?? "",
            "channel": "appstore",
            "networkType": "wifi",
            "lang": Locale.preferredLanguages.first ?? "en",
            "timestamp": IAPSignUtil.timestampMs(),
            "nonce": IAPSignUtil.nonce()
        ]
    }

    /// 驼峰 key → X- Header 名。如 requestId → X-Request-Id。
    private func headerName(for camelKey: String) -> String {
        var out = "X"
        for ch in camelKey {
            if ch.isUppercase { out += "-\(ch)" }
            else if out == "X" { out += "-\(String(ch).uppercased())" }
            else { out.append(ch) }
        }
        return out
    }

    private static func hardwareModel() -> String {
        var sysinfo = utsname()
        uname(&sysinfo)
        let mirror = Mirror(reflecting: sysinfo.machine)
        let id = mirror.children.reduce(into: "") { acc, e in
            if let v = e.value as? Int8, v != 0 { acc.append(Character(UnicodeScalar(UInt8(v)))) }
        }
        return id.isEmpty ? "iPhone" : id
    }
}
