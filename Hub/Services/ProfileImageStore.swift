import UIKit

enum ProfileImageStore {
    private static let fileName = "profile-avatar.jpg"

    private static var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent(fileName)
    }

    static func save(_ image: UIImage) throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = image.jpegData(compressionQuality: 0.85) else {
            throw StoreError.encodingFailed
        }
        try data.write(to: fileURL, options: .atomic)
    }

    static func load() -> UIImage? {
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL) else { return nil }
        return UIImage(data: data)
    }

    static func delete() {
        try? FileManager.default.removeItem(at: fileURL)
    }

    enum StoreError: LocalizedError {
        case encodingFailed

        var errorDescription: String? {
            message(language: .zhHans)
        }

        func message(language: AppLanguage) -> String {
            switch self {
            case .encodingFailed: return L10n.tr(.errorAvatarSaveFailed, language: language)
            }
        }
    }
}
