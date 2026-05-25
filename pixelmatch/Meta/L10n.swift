import Foundation
import UIKit

enum L10n {
    // 统一的本地化入口，缺失翻译时使用英文兜底，避免界面直接显示 key。
    static func tr(_ key: String, fallback: String? = nil) -> String {
        NSLocalizedString(key, tableName: "Localizable", bundle: .main, value: fallback ?? key, comment: "")
    }

    static func fmt(_ key: String, _ args: CVarArg..., fallback: String? = nil) -> String {
        String(format: tr(key, fallback: fallback), locale: Locale.current, arguments: args)
    }

    static func upper(_ text: String) -> String {
        text.uppercased(with: Locale.current)
    }

    static var isRTL: Bool {
        let code = Locale.current.languageCode ?? "en"
        return Locale.characterDirection(forLanguage: code) == .rightToLeft
    }
}
