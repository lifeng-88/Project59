import Foundation

enum CloudSyncService {
    static let containerIdentifier = "iCloud.com.lumina.hub"

    enum SyncError: LocalizedError {
        case iCloudUnavailable
        case encodingFailed

        var errorDescription: String? {
            switch self {
            case .iCloudUnavailable: return "未登录 iCloud 或 iCloud Drive 未开启"
            case .encodingFailed: return "数据编码失败"
            }
        }
    }

    static func sync(state: PersistedAppState) throws -> Date {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        ) else {
            throw SyncError.iCloudUnavailable
        }

        let hubDirectory = containerURL
            .appendingPathComponent("Documents", isDirectory: true)
            .appendingPathComponent("Hub", isDirectory: true)

        try FileManager.default.createDirectory(at: hubDirectory, withIntermediateDirectories: true)

        let fileURL = hubDirectory.appendingPathComponent("backup.json")
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else {
            throw SyncError.encodingFailed
        }
        try data.write(to: fileURL, options: .atomic)
        return Date()
    }

    static func loadBackup() throws -> PersistedAppState? {
        guard let containerURL = FileManager.default.url(
            forUbiquityContainerIdentifier: containerIdentifier
        ) else {
            throw SyncError.iCloudUnavailable
        }
        let fileURL = containerURL
            .appendingPathComponent("Documents/Hub/backup.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return nil }
        let data = try Data(contentsOf: fileURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(PersistedAppState.self, from: data)
    }
}
