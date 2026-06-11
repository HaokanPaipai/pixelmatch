//
//  IAPEnvironment.swift
//  pixelmatch
//
//  后端域名与设备标识。PixelMatch 复用 Goodlook 后端（域名见 CLAUDE.md /
//  Contracts），通过 bundle_id=com.goodloook.pixelmatch 在后端做多 App 隔离。
//

import Foundation
import Security

enum IAPEnvironment {

    /// UserDefaults 覆盖键：写 true 走沙盒，便于 Debug 包联调。
    private static let useSandboxKey = "iap.useSandbox"

    /// 生产域名（注意 goodloook 三个 o，是故意的）。
    static let productionHost = "https://www.goodloook.com/"

    /// 沙盒域名（内网，仅 Debug 联调可达）。
    static let sandboxHost = "http://10.2.206.131:8080/"

    /// API 根域名，含末尾 `/`。HKIAPKit 会在其后直接拼相对路径。
    static var baseHost: String {
        UserDefaults.standard.bool(forKey: useSandboxKey) ? sandboxHost : productionHost
    }

    static func setUseSandbox(_ on: Bool) {
        UserDefaults.standard.set(on, forKey: useSandboxKey)
    }

    /// 后端多 App 区分键：随 IAP 请求体注入，后端按此隔离商品/订单/购买。
    /// 见 Contracts/api/iap-overview.md「多 App 区分机制」。
    static var bundleId: String {
        Bundle.main.bundleIdentifier ?? "com.goodloook.pixelmatch"
    }
}

/// 匿名设备身份。PixelMatch 无登录体系，仅靠持久化的 device_id 建立匿名会话。
enum IAPDeviceIdentity {

    private static let deviceIdKey = "iap.device_id"
    private static let userIdKey = "iap.user_id"

    /// 设备唯一、随机生成后持久化到 **Keychain**（契约 _shared.md `device_id` 定义）。
    ///
    /// 用 Keychain 而非 UserDefaults：删除 App 重装后仍是同一 device_id →
    /// /auth/device-session 返回同一匿名用户（后端 regAndLogin 按 device_id 幂等）→
    /// 服务端钱包（game-wallet.md）、purchases、订单补单全部连续，权益可恢复。
    /// 老版本存 UserDefaults 的值在首次读取时迁移进 Keychain。
    static var deviceId: String {
        if let existing = IAPKeychain.read(deviceIdKey), !existing.isEmpty {
            return existing
        }
        // 旧版本迁移：UserDefaults 里有值则写回 Keychain 继续沿用
        if let legacy = UserDefaults.standard.string(forKey: deviceIdKey), !legacy.isEmpty {
            IAPKeychain.write(deviceIdKey, value: legacy)
            return legacy
        }
        let fresh = UUID().uuidString
        IAPKeychain.write(deviceIdKey, value: fresh)
        return fresh
    }

    /// 匿名会话建立后由 /auth/device-session 回写；未建立时为空字符串。
    /// 注意：仍存 UserDefaults——重装后应清空会话态，强制重新走 device-session
    /// （同 device_id 会拿回同一用户，并刷新 Cookie / purchase 快照）。
    static var userId: String {
        get { UserDefaults.standard.string(forKey: userIdKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userIdKey) }
    }

    static var hasSession: Bool { !userId.isEmpty }
}

/// 最小 Keychain 字符串读写（kSecClassGenericPassword）。
/// 仅 device_id 使用；无第三方依赖（PixelMatch 不用 CocoaPods/KeychainAccess）。
enum IAPKeychain {

    private static let service = "com.goodloook.pixelmatch.iap"

    static func read(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func write(_ key: String, value: String) {
        guard let data = value.data(using: .utf8) else { return }
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        var attrs = base
        attrs[kSecValueData as String] = data
        // 设备解锁后可读即可；不随 iCloud/迁移同步到其他设备（device_id 语义是"本设备"）
        attrs[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let status = SecItemAdd(attrs as CFDictionary, nil)
        if status == errSecDuplicateItem {
            SecItemUpdate(base as CFDictionary,
                          [kSecValueData as String: data] as CFDictionary)
        }
    }
}
