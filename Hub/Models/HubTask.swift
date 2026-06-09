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

    var displayName: String { rawValue }
}

enum HubTaskPriority: String, Codable, CaseIterable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
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
        switch self {
        case .rain: return "雨声"
        case .forest: return "森林"
        case .whiteNoise: return "白噪音"
        case .cafe: return "咖啡馆"
        }
    }

    var subtitle: String {
        switch self {
        case .rain: return "窗外的绵绵细雨"
        case .forest: return "清晨的鸟鸣与微风"
        case .whiteNoise: return "平稳舒适的基础背景"
        case .cafe: return "温和的背景感"
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
        switch self {
        case .light: return "浅色模式"
        case .dark: return "深色模式"
        case .system: return "跟随系统"
        }
    }

    var subtitle: String {
        switch self {
        case .light: return "始终使用浅色界面"
        case .dark: return "始终使用深色界面"
        case .system: return "随系统外观自动切换"
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

    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .en: return "English"
        }
    }
}
