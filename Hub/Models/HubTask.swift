import Foundation

struct HubTask: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var category: TaskCategory?
    var isCompleted: Bool
    var scheduledDate: Date?
    var priority: HubTaskPriority?
    var reminderDate: Date?
    var createdAt: Date
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        category: TaskCategory? = nil,
        isCompleted: Bool = false,
        scheduledDate: Date? = nil,
        priority: HubTaskPriority? = nil,
        reminderDate: Date? = nil,
        createdAt: Date = Date(),
        completedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.category = category
        self.isCompleted = isCompleted
        self.scheduledDate = scheduledDate
        self.priority = priority
        self.reminderDate = reminderDate
        self.createdAt = createdAt
        self.completedAt = completedAt
    }
}

enum TaskCategory: String, Codable, CaseIterable {
    case work = "工作"
    case deepFocus = "深度专注"
    case personal = "生活"

    var displayName: String {
        displayName(language: .zhHans)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .work: return L10n.tr(.categoryWork, language: language)
        case .deepFocus: return L10n.tr(.categoryDeepFocus, language: language)
        case .personal: return L10n.tr(.categoryPersonal, language: language)
        }
    }
}

enum HubTaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        displayName(language: .zhHans)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .low: return L10n.tr(.priorityLow, language: language)
        case .medium: return L10n.tr(.priorityMedium, language: language)
        case .high: return L10n.tr(.priorityHigh, language: language)
        }
    }
}

enum AmbientSound: String, Codable, CaseIterable, Identifiable {
    case rain
    case forest
    case whiteNoise
    case cafe

    var id: String { rawValue }

    var title: String {
        title(language: .zhHans)
    }

    var subtitle: String {
        subtitle(language: .zhHans)
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .rain: return L10n.tr(.ambientRain, language: language)
        case .forest: return L10n.tr(.ambientForest, language: language)
        case .whiteNoise: return L10n.tr(.ambientWhiteNoise, language: language)
        case .cafe: return L10n.tr(.ambientCafe, language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .rain: return L10n.tr(.ambientRainSubtitle, language: language)
        case .forest: return L10n.tr(.ambientForestSubtitle, language: language)
        case .whiteNoise: return L10n.tr(.ambientWhiteNoiseSubtitle, language: language)
        case .cafe: return L10n.tr(.ambientCafeSubtitle, language: language)
        }
    }

    var icon: String {
        switch self {
        case .rain: return "cloud.rain.fill"
        case .forest: return "leaf.fill"
        case .whiteNoise: return "waveform"
        case .cafe: return "cup.and.saucer.fill"
        }
    }
}

enum HubAppearanceTheme: String, Codable, CaseIterable {
    case light
    case dark
    case system

    var displayName: String {
        displayName(language: .zhHans)
    }

    var subtitle: String {
        subtitle(language: .zhHans)
    }

    func displayName(language: AppLanguage) -> String {
        switch self {
        case .light: return L10n.tr(.themeLight, language: language)
        case .dark: return L10n.tr(.themeDark, language: language)
        case .system: return L10n.tr(.themeSystem, language: language)
        }
    }

    func subtitle(language: AppLanguage) -> String {
        switch self {
        case .light: return L10n.tr(.themeLightSubtitle, language: language)
        case .dark: return L10n.tr(.themeDarkSubtitle, language: language)
        case .system: return L10n.tr(.themeSystemSubtitle, language: language)
        }
    }

    var icon: String {
        switch self {
        case .light: return "sun.max.fill"
        case .dark: return "moon.fill"
        case .system: return "circle.lefthalf.filled"
        }
    }
}

enum AppLanguage: String, Codable, CaseIterable {
    case zhHans = "zh-Hans"
    case en = "en"

    static func defaultFromSystem() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        return preferred.hasPrefix("zh") ? .zhHans : .en
    }

    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}
