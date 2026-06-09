import Foundation

enum ExportFormat: String, CaseIterable {
    case json
    case csv

    var fileName: String {
        "hub-export-\(formattedTimestamp).\(rawValue)"
    }

    private var formattedTimestamp: String {
        let f = DateFormatter()
        f.dateFormat = "yyyyMMdd-HHmmss"
        return f.string(from: Date())
    }
}

@MainActor
enum DataExportService {
    struct ExportPayload: Codable {
        let exportedAt: Date
        let tasks: [HubTask]
        let settings: PersistedAppState
    }

    static func makeJSONData(store: TaskStore) throws -> Data {
        let payload = ExportPayload(
            exportedAt: Date(),
            tasks: store.tasks,
            settings: store.persistedState
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(payload)
    }

    static func makeCSVData(store: TaskStore) -> Data {
        var lines = ["id,title,category,priority,scheduledDate,reminderDate,isCompleted,createdAt"]
        let formatter = ISO8601DateFormatter()

        for task in store.tasks {
            let row = [
                task.id.uuidString,
                escapeCSV(task.title),
                task.category?.rawValue ?? "",
                task.priority?.rawValue ?? "",
                task.scheduledDate.map { formatter.string(from: $0) } ?? "",
                task.reminderDate.map { formatter.string(from: $0) } ?? "",
                task.isCompleted ? "true" : "false",
                formatter.string(from: task.createdAt)
            ]
            lines.append(row.joined(separator: ","))
        }
        return Data(lines.joined(separator: "\n").utf8)
    }

    private static func escapeCSV(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
