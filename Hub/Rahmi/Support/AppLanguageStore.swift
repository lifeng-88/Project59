//
//  AppLanguageStore.swift
//  Rahmi
//
//  应用内语言偏好 + SwiftUI Locale；与模板接口 `locale` 参数对齐。
//

import Combine
import Foundation
import SwiftUI
import UIKit

/// 用户可选的应用界面语言（跟随系统 / 多语言）
enum AppLanguagePreference: String, CaseIterable, Identifiable {
    case system
    case english = "en"
    /// 繁體中文（String Catalog `zh-Hant`）
    case traditionalChinese = "zh-Hant"
    case portuguese = "pt"
    case spanish = "es"
    case japanese = "ja"
    case french = "fr"
    case german = "de"

    var id: String { rawValue }

    var storageValue: String {
        switch self {
        case .system: return "system"
        default: return rawValue
        }
    }

    static func from(storage: String) -> AppLanguagePreference {
        switch storage {
        case "system": return .system
        case AppLanguagePreference.english.rawValue: return .english
        case AppLanguagePreference.traditionalChinese.rawValue: return .traditionalChinese
        /// 舊版偏好（簡體代碼）遷移到繁體
        case "zh-Hans": return .traditionalChinese
        case AppLanguagePreference.portuguese.rawValue: return .portuguese
        case AppLanguagePreference.spanish.rawValue: return .spanish
        case AppLanguagePreference.japanese.rawValue: return .japanese
        case AppLanguagePreference.french.rawValue: return .french
        case AppLanguagePreference.german.rawValue: return .german
        default: return .system
        }
    }
}

@MainActor
final class AppLanguageStore: ObservableObject {
    private static let userDefaultsKey = "rahmi.appLanguagePreference"

    /// 与 `Localizable.xcstrings` 中 `zh-Hant` 变体对齐
    nonisolated static var traditionalChineseLocale: Locale {
        Locale(identifier: "zh-Hant")
    }

    private var cancellables = Set<AnyCancellable>()

    @Published private(set) var preference: AppLanguagePreference {
        didSet {
            UserDefaults.standard.set(preference.storageValue, forKey: Self.userDefaultsKey)
        }
    }

    init() {
        if UserDefaults.standard.string(forKey: Self.userDefaultsKey) == "zh-Hans" {
            UserDefaults.standard.set(AppLanguagePreference.traditionalChinese.rawValue, forKey: Self.userDefaultsKey)
        }
        let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? "system"
        preference = AppLanguagePreference.from(storage: raw)

        /// 在「跟随系统」下，用户从系统设置切换语言回到本应用时刷新界面
        NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        /// 从后台回到前台时再刷一次（部分系统版本上 `NSLocale` 通知不可靠）
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    /// 供根视图在 `scenePhase == .active` 时调用，与前台通知互补
    func refreshUITextForPossibleSystemLocaleChange() {
        objectWillChange.send()
    }

    /// 从 `Localizable.xcstrings` 编译出的 `*.lproj/Localizable.strings` 取文案。
    /// 不用 `LocalizedStringResource`：Hub 工程无 `zh-Hans` 变体，系统简体下 iOS 16+ 会退回显示 key（如 `my.profile.title`）。
    nonisolated static func localized(_ key: String) -> String {
        localizedFromStringCatalog(key: key)
    }

    /// 按当前偏好选择 `语言.lproj`，再查 `Localizable` 表；未命中时回退英语。
    nonisolated private static func localizedFromStringCatalog(key: String) -> String {
        let bundle = bundleForLocalizedTable()
        var value = bundle.localizedString(forKey: key, value: nil, table: nil)
        if value == key, bundle !== Bundle.main,
           let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            value = enBundle.localizedString(forKey: key, value: nil, table: nil)
        }
        return value
    }

    /// 与 `catalogLanguageCode` 一致，映射到 Xcode 生成的 `.lproj` 目录名（`en`、`zh-Hant` 等）。
    nonisolated private static func bundleForLocalizedTable() -> Bundle {
        let langCode = catalogLanguageCode(
            for: AppLanguagePreference.from(storage: UserDefaults.standard.string(forKey: userDefaultsKey) ?? "system")
        )
        if let path = Bundle.main.path(forResource: langCode, ofType: "lproj"),
           let bundle = Bundle(path: path) {
            return bundle
        }
        return .main
    }

    /// String Catalog / `.lproj` 目录名（`zh-Hans` 系统语言映射到 `zh-Hant` 变体）。
    nonisolated static func catalogLanguageCode(for preference: AppLanguagePreference) -> String {
        switch preference {
        case .english:
            return "en"
        case .traditionalChinese:
            return "zh-Hant"
        case .portuguese:
            return "pt"
        case .spanish:
            return "es"
        case .japanese:
            return "ja"
        case .french:
            return "fr"
        case .german:
            return "de"
        case .system:
            let preferred = Locale.preferredLanguages.first ?? ""
            if preferred.hasPrefix("zh") { return "zh-Hant" }
            if preferred.hasPrefix("pt") { return "pt" }
            if preferred.hasPrefix("es") { return "es" }
            if preferred.hasPrefix("ja") { return "ja" }
            if preferred.hasPrefix("fr") { return "fr" }
            if preferred.hasPrefix("de") { return "de" }
            return "en"
        }
    }

    nonisolated private static func localeForCatalogLanguageCode(_ code: String) -> Locale {
        Locale(identifier: code)
    }

    func setPreference(_ value: AppLanguagePreference) {
        guard preference != value else { return }
        preference = value
    }

    /// 供 SwiftUI `environment(\.locale)`：与 String Catalog 语言变体一致（避免系统 `zh-Hans` 找不到 `zh-Hant` 文案）。
    var effectiveLocale: Locale {
        Self.localeForCatalogLanguageCode(Self.catalogLanguageCode(for: preference))
    }

    /// 与 `/v1/catalogs`、模板列表、`POST /v1/users/{id}/locale` 的 `language` 等一致（短标识）
    var templateAPICatalogLocaleIdentifier: String {
        Self.apiCatalogLocaleCode(for: preference)
    }

    /// 从 UserDefaults 读取当前偏好，供非 MainActor 代码（如 `UserLocaleReporter`）上报语言
    nonisolated static func localeCodeForUserLocaleAPIReporting() -> String {
        let raw = UserDefaults.standard.string(forKey: Self.userDefaultsKey) ?? "system"
        return apiCatalogLocaleCode(for: AppLanguagePreference.from(storage: raw))
    }

    nonisolated private static func apiCatalogLocaleCode(for preference: AppLanguagePreference) -> String {
        switch preference {
        case .english:
            return "en"
        case .traditionalChinese:
            /// 與常見後端 `/v1/catalogs`、`/v1/template_tabs` 的 `locale` 約定一致（`zh-Hant` 部分環境會回退英語）
            return "zh-TW"
        case .portuguese:
            return "pt"
        case .spanish:
            return "es"
        case .japanese:
            return "ja"
        case .french:
            return "fr"
        case .german:
            return "de"
        case .system:
            let id = Locale.autoupdatingCurrent.identifier
            if id.hasPrefix("zh") { return "zh-TW" }
            if id.hasPrefix("pt") { return "pt" }
            if id.hasPrefix("es") { return "es" }
            if id.hasPrefix("ja") { return "ja" }
            if id.hasPrefix("fr") { return "fr" }
            if id.hasPrefix("de") { return "de" }
            return "en"
        }
    }

    /// 设置页「语言」一行右侧摘要（跟随系统时附带当前系统界面语言说明）
    var currentLanguageDisplayName: String {
        switch preference {
        case .system:
            let base = Self.localized("language.option.system")
            let sys = Self.systemPrimaryLanguageDisplayName()
            if sys.isEmpty { return base }
            return "\(base) · \(sys)"
        case .english:
            return Self.localized("language.option.english")
        case .traditionalChinese:
            return Self.localized("language.option.chinese")
        case .portuguese:
            return Self.localized("language.option.portuguese")
        case .spanish:
            return Self.localized("language.option.spanish")
        case .japanese:
            return Self.localized("language.option.japanese")
        case .french:
            return Self.localized("language.option.french")
        case .german:
            return Self.localized("language.option.german")
        }
    }

    /// 设备首选语言在系统中的本地化名称，用于「跟随系统」旁注
    nonisolated private static func systemPrimaryLanguageDisplayName() -> String {
        guard let first = Locale.preferredLanguages.first else { return "" }
        let code = String(first.prefix(while: { $0 != "-" }))
        return Locale.current.localizedString(forLanguageCode: code) ?? code
    }
}

// MARK: - SwiftUI：随语言偏好刷新（静态 `localized` 不会自动订阅 ObservableObject）

struct BBBAppLanguageRefreshModifier: ViewModifier {
    @EnvironmentObject private var appLanguage: AppLanguageStore

    func body(content: Content) -> some View {
        let _ = appLanguage.preference
        content
    }
}

extension View {
    /// 挂接在依赖 `AppLanguageStore.localized` 的根容器上，使 `preference` 变化时重算 `body`。
    func rahmiRefreshOnAppLanguage() -> some View {
        modifier(BBBAppLanguageRefreshModifier())
    }
}
