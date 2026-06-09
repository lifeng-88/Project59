import Foundation

enum DataImportService {
    enum ImportError: LocalizedError {
        case invalidFormat
        case emptyCSV
        case invalidCSVHeader

        var errorDescription: String? {
            switch self {
            case .invalidFormat: return "无法识别的文件格式"
            case .emptyCSV: return "CSV 文件为空"
            case .invalidCSVHeader: return "CSV 表头不符合 Hub 导出格式"
            }
        }
    }

    @MainActor
    static func importData(_ data: Data, into store: TaskStore) throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if let payload = try? decoder.decode(DataExportService.ExportPayload.self, from: data) {
            store.applyImportedState(payload)
            return
        }

        if let state = try? decoder.decode(PersistedAppState.self, from: data) {
            store.applyImportedState(state)
            return
        }

        if let tasks = try? decoder.decode([HubTask].self, from: data) {
            store.tasks = tasks
            store.persist()
            Task { await store.syncNotifications() }
            store.alertMessage = "已导入 \(tasks.count) 条任务"
            return
        }

        if let csvText = String(data: data, encoding: .utf8),
           csvText.contains(",") {
            let tasks = try parseCSVTasks(csvText)
            store.tasks = tasks
            store.persist()
            Task { await store.syncNotifications() }
            store.alertMessage = "已从 CSV 导入 \(tasks.count) 条任务"
            return
        }

        throw ImportError.invalidFormat
    }

    static func parseCSVTasks(_ text: String) throws -> [HubTask] {
        let rows = parseCSVRows(text)
        guard let header = rows.first, rows.count > 1 else {
            throw rows.isEmpty ? ImportError.emptyCSV : ImportError.emptyCSV
        }

        let columns = header.map { $0.lowercased() }
        guard columns.contains("title") else {
            throw ImportError.invalidCSVHeader
        }

        let iso = ISO8601DateFormatter()
        var tasks: [HubTask] = []

        for row in rows.dropFirst() where !row.allSatisfy({ $0.isEmpty }) {
            var map: [String: String] = [:]
            for (column, value) in zip(columns, row) {
                map[column] = value
            }

            let id = UUID(uuidString: map["id"] ?? "") ?? UUID()
            let title = map["title"] ?? ""
            guard !title.isEmpty else { continue }

            let category = TaskCategory.allCases.first { $0.rawValue == map["category"] }
            let priority = HubTaskPriority(rawValue: map["priority"] ?? "")
            let scheduledDate = parseDate(map["scheduleddate"] ?? "", iso: iso)
            let reminder = parseDate(map["reminderdate"] ?? "", iso: iso)
            let isCompleted = (map["iscompleted"] ?? "").lowercased() == "true"
            let createdAt = parseDate(map["createdat"] ?? "", iso: iso) ?? Date()

            tasks.append(
                HubTask(
                    id: id,
                    title: title,
                    category: category,
                    isCompleted: isCompleted,
                    scheduledDate: scheduledDate,
                    priority: priority,
                    reminderDate: reminder,
                    createdAt: createdAt,
                    completedAt: isCompleted ? createdAt : nil
                )
            )
        }

        guard !tasks.isEmpty else { throw ImportError.emptyCSV }
        return tasks
    }

    private static func parseDate(_ value: String, iso: ISO8601DateFormatter) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let date = iso.date(from: trimmed) { return date }
        return parseLooseDate(trimmed)
    }

    private static func parseLooseDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        if let date = iso.date(from: trimmed) { return date }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    /// 简易 CSV 解析（支持引号包裹字段）
    static func parseCSVRows(_ text: String) -> [[String]] {
        var rows: [[String]] = []
        var row: [String] = []
        var field = ""
        var inQuotes = false
        var index = text.startIndex

        func flushField() {
            row.append(field)
            field = ""
        }

        func flushRow() {
            flushField()
            if !row.isEmpty || !field.isEmpty {
                rows.append(row)
            }
            row = []
        }

        while index < text.endIndex {
            let char = text[index]
            if char == "\"" {
                if inQuotes, text.index(after: index) < text.endIndex, text[text.index(after: index)] == "\"" {
                    field.append("\"")
                    index = text.index(after: index)
                } else {
                    inQuotes.toggle()
                }
            } else if char == "," && !inQuotes {
                flushField()
            } else if (char == "\n" || char == "\r") && !inQuotes {
                flushRow()
                if char == "\r", text.index(after: index) < text.endIndex, text[text.index(after: index)] == "\n" {
                    index = text.index(after: index)
                }
            } else {
                field.append(char)
            }
            index = text.index(after: index)
        }
        flushRow()
        return rows.filter { !$0.allSatisfy(\.isEmpty) }
    }
}
