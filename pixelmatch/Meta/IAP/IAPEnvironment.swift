//
//  IAPEnvironment.swift
//  pixelmatch
//
//  后端域名与设备标识。PixelMatch 复用 Goodlook 后端（域名见 CLAUDE.md /
//  Contracts），通过 bundle_id=com.goodloook.pixelmatch 在后端做多 App 隔离。
//

import Foundation

enum IAPEnvironment {

    /// UserDefaults 覆盖键：写 true 走沙盒，便于 Debug 包联调。
    private static let useSandboxKey = "iap.useSandbox"

    /// 生产域名（注意 goodloook 三个 o，是故意的）。
    static let productionHost = "https://www.goodloook.com/dotey/"

    /// 沙盒域名（内网，仅 Debug 联调可达）。
    static let sandboxHost = "http://10.2.206.131:8080/dotey/"

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

    /// 安装级唯一、随机生成后本地持久化（契约 _shared.md `device_id` 定义）。
    static var deviceId: String {
        if let existing = UserDefaults.standard.string(forKey: deviceIdKey), !existing.isEmpty {
            return existing
        }
        let fresh = UUID().uuidString
        UserDefaults.standard.set(fresh, forKey: deviceIdKey)
        return fresh
    }

    /// 匿名会话建立后由 /auth/device-session 回写；未建立时为空字符串。
    static var userId: String {
        get { UserDefaults.standard.string(forKey: userIdKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: userIdKey) }
    }

    static var hasSession: Bool { !userId.isEmpty }
}
