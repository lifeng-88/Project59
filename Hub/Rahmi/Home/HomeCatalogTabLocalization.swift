//
//  HomeCatalogTabLocalization.swift
//  Rahmi
//
//  `/v1/catalogs` 的 `catalog` 常为英语或缺翻译；二级 Tab 展示前按 `catalogId`（`home.catalog.id.*`）
//  与归一化英文名（`home.catalog.preset.*`）映射到 String Catalog，与 `AppLanguageStore` 一致。
//

import Foundation

enum HomeCatalogTabLocalization {
    /// 二级分类条展示用文案（大写风格与 `HomeView.secondaryTagTitles` 一致）。
    static func displayTitle(for catalog: Catalog) -> String {
        let idKey = "home.catalog.id.\(catalog.id)"
        let byId = AppLanguageStore.localized(idKey)
        if byId != idKey {
            return byId.uppercased(with: Locale.current)
        }
        if let presetKey = presetLocalizationKey(forServerName: catalog.name) {
            let s = AppLanguageStore.localized(presetKey)
            if s != presetKey {
                return s.uppercased(with: Locale.current)
            }
        }
        return catalog.name.uppercased(with: Locale.current)
    }

    /// 与 `displayTitle` 相同逻辑，供读屏等使用。
    static func accessibilityLabel(for catalog: Catalog) -> String {
        displayTitle(for: catalog)
    }

    private static func presetLocalizationKey(forServerName name: String) -> String? {
        let folded = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "en"))
            .lowercased()
        let collapsed = folded
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
        let compact = collapsed.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")

        switch compact {
        case "hot", "trending", "popular", "fire", "trend", "top hits", "hits":
            return "home.catalog.preset.hot"
        case "new", "new arrivals", "brand new", "latest":
            return "home.catalog.preset.new"
        case "funny", "fun", "comedy", "meme", "memes", "humor", "humour":
            return "home.catalog.preset.funny"
        case "viral":
            return "home.catalog.preset.viral"
        case "dance", "dancing":
            return "home.primary.dance"
        case "music", "song", "songs", "audio":
            return "home.catalog.preset.music"
        case "anime", "manga":
            return "home.catalog.preset.anime"
        case "movie", "movies", "film", "films", "cinematic":
            return "home.catalog.preset.movie"
        case "pet", "pets", "animal", "animals", "cute":
            return "home.catalog.preset.pet"
        case "sport", "sports":
            return "home.catalog.preset.sports"
        case "fashion", "style", "outfit", "outfits":
            return "home.catalog.preset.fashion"
        case "beauty", "makeup", "glam":
            return "home.catalog.preset.beauty"
        case "game", "games", "gaming":
            return "home.catalog.preset.game"
        case "photo", "photos":
            return "home.primary.image"
        case "video", "videos", "clip", "clips":
            return "home.primary.video"
        default:
            break
        }
        if compact.hasPrefix("hot ") { return "home.catalog.preset.hot" }
        if compact.hasPrefix("new ") { return "home.catalog.preset.new" }
        return nil
    }
}
