//
//  IAPSignUtil.swift
//  pixelmatch
//
//  请求签名工具。算法与 Goodlook iOS `SignUtil.swift` / Backend `SignUtil.java`
//  完全一致——PixelMatch 复用 Goodlook 后端，签名必须逐字节对齐，否则
//  CommonParamInterceptor 会拒绝请求（除非后端开了 -Dsign.skip=true）。
//
//  算法：
//    1. 取所有公共 Header 参数（驼峰 key，不含 sign 本身）
//    2. 过滤空值，按 key ASCII 升序
//    3. 拼接 key1=val1&key2=val2，追加 &secret={signSecret}
//    4. MD5，大写十六进制
//
//  契约来源：Contracts/api/_shared.md「签名算法」段落。
//

import Foundation
import CommonCrypto

enum IAPSignUtil {

    /// 与 Backend config.properties `sign.secret` / Goodlook `SignUtil.kSignSecret` 保持一致。
    static let signSecret = "gl_sign_2026_goodloook"

    static func sign(_ params: [String: String], secret: String = signSecret) -> String {
        let sorted = params.sorted { $0.key < $1.key }
        var parts: [String] = []
        for (key, value) in sorted where !value.isEmpty {
            parts.append("\(key)=\(value)")
        }
        let raw = parts.joined(separator: "&") + "&secret=\(secret)"
        return md5Upper(raw)
    }

    /// X-Timestamp：Unix 毫秒时间戳字符串。
    static func timestampMs() -> String {
        "\(Int64(Date().timeIntervalSince1970 * 1000))"
    }

    /// X-Request-Id / X-Nonce：去掉连字符的 UUID。
    static func nonce() -> String {
        UUID().uuidString.replacingOccurrences(of: "-", with: "")
    }

    private static func md5Upper(_ input: String) -> String {
        guard let data = input.data(using: .utf8) else { return "" }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { _ = CC_MD5($0.baseAddress, CC_LONG(data.count), &digest) }
        return digest.map { String(format: "%02X", $0) }.joined()
    }
}
