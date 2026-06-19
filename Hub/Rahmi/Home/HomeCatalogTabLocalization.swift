//
//  HomeCatalogTabLocalization.swift
//  Rahmi
//
//  `/v1/catalogs` 的 `catalog` 常为英语或缺翻译；二级 Tab 展示前按 `catalogId`（`home.catalog.id.*`）
//  与归一化英文名（`home.catalog.preset.*`）映射到 String Catalog，与 `AppLanguageStore` 一致。
//

import Foundation

enum HomeCatalogTabLocalization {
    private static var displayLocale: Locale {
        let raw = UserDefaults.standard.string(forKey: "rahmi.appLanguagePreference") ?? "system"
        let code = AppLanguageStore.catalogLanguageCode(for: AppLanguagePreference.from(storage: raw))
        return Locale(identifier: code)
    }

    /// 二级分类条展示用文案（大写风格与 `HomeView.secondaryTagTitles` 一致）。
    static func displayTitle(for catalog: Catalog) -> String {
        let idKey = "home.catalog.id.\(catalog.id)"
        let byId = AppLanguageStore.localized(idKey)
        if byId != idKey {
            return byId.uppercased(with: displayLocale)
        }
        if let presetKey = presetLocalizationKey(forServerName: catalog.name)
            ?? chinesePresetLocalizationKey(forServerName: catalog.name) {
            let s = AppLanguageStore.localized(presetKey)
            if s != presetKey {
                return s.uppercased(with: displayLocale)
            }
        }
        let rawUpper = catalog.name.uppercased(with: displayLocale)
        if shouldAvoidCJKFallback(rawUpper) {
            return AppLanguageStore.localized("home.catalog.fallback").uppercased(with: displayLocale)
        }
        return rawUpper
    }

    /// 与 `displayTitle` 相同逻辑，供读屏等使用。
    static func accessibilityLabel(for catalog: Catalog) -> String {
        displayTitle(for: catalog)
    }

    private static func shouldAvoidCJKFallback(_ text: String) -> Bool {
        guard AppLanguageStore.prefersWesternCatalogUIForDisplay else { return false }
        return RahmiTextStyle.containsCJK(in: text)
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

    /// 服务端 `locale=zh-TW` 等场景下 catalog 名常为中文；西文界面映射到 preset 键。
    private static func chinesePresetLocalizationKey(forServerName name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed {
        case "热门", "最热", "火爆", "熱門", "最熱", "爆款", "推荐", "推薦", "精选", "精選":
            return "home.catalog.preset.hot"
        case "新品", "最新", "上新":
            return "home.catalog.preset.new"
        case "搞笑", "有趣", "幽默", "段子":
            return "home.catalog.preset.funny"
        case "病毒", "刷屏", "网红":
            return "home.catalog.preset.viral"
        case "舞蹈", "跳舞", "舞", "熱舞":
            return "home.primary.dance"
        case "音乐", "音樂", "歌曲", "音频", "音頻":
            return "home.catalog.preset.music"
        case "动漫", "動漫", "二次元":
            return "home.catalog.preset.anime"
        case "电影", "電影", "影视", "影視", "大片":
            return "home.catalog.preset.movie"
        case "宠物", "寵物", "萌宠", "萌寵", "动物", "動物", "可爱", "可愛":
            return "home.catalog.preset.pet"
        case "运动", "運動", "体育", "體育":
            return "home.catalog.preset.sports"
        case "时尚", "時尚", "穿搭", "潮流":
            return "home.catalog.preset.fashion"
        case "美妆", "美妝", "化妆", "化妝", "颜值", "顏值":
            return "home.catalog.preset.beauty"
        case "游戏", "遊戲", "电竞", "電競":
            return "home.catalog.preset.game"
        case "图片", "圖片", "图像", "圖像", "照片", "写真":
            return "home.primary.image"
        case "视频", "視頻", "影片", "短片", "短視頻":
            return "home.primary.video"
        default:
            break
        }
        if trimmed.contains("热门") || trimmed.contains("熱門") || trimmed.contains("爆款") { return "home.catalog.preset.hot" }
        if trimmed.contains("新品") || trimmed.contains("最新") { return "home.catalog.preset.new" }
        if trimmed.contains("搞笑") || trimmed.contains("有趣") { return "home.catalog.preset.funny" }
        if trimmed.contains("舞蹈") || trimmed.contains("跳舞") { return "home.primary.dance" }
        if trimmed.contains("视频") || trimmed.contains("視頻") { return "home.primary.video" }
        if trimmed.contains("图片") || trimmed.contains("圖片") { return "home.primary.image" }
        return nil
    }
}
