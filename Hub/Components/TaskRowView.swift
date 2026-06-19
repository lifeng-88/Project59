import SwiftUI

struct TaskRowView: View {
    @Environment(\.hubLanguage) private var language

    let task: HubTask
    let onToggle: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: LuminaSpacing.stackMD) {
            TaskCheckbox(isChecked: task.isCompleted, action: onToggle)

            VStack(alignment: .leading, spacing: 6) {
                Text(task.title)
                    .font(.luminaBodyMD)
                    .foregroundStyle(task.isCompleted ? LuminaColor.outline : LuminaColor.onSurface)
                    .strikethrough(task.isCompleted, color: LuminaColor.outline)
                    .opacity(task.isCompleted ? 0.4 : 1)

                metadataRow
            }

            Spacer(minLength: 0)
        }
        .padding(LuminaSpacing.insetMD)
        .frame(minHeight: 64)
        .background(
            task.isCompleted
                ? LuminaColor.surfaceContainerLow.opacity(0.5)
                : LuminaColor.surfaceContainerLowest
        )
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.lg))
        .luminaSoftShadow()
    }

    @ViewBuilder
    private var metadataRow: some View {
        let hasMeta = task.category != nil || task.priority != nil || task.reminderDate != nil || task.scheduledDate != nil
        if hasMeta {
            HStack(spacing: 6) {
                if let category = task.category {
                    CategoryChip(title: category.displayName(language: language), isCompleted: task.isCompleted)
                }
                if let priority = task.priority, !task.isCompleted {
                    metaBadge(
                        text: String(format: L10n.tr(.priorityBadge, language: language), priority.displayName(language: language)),
                        color: priorityColor(priority)
                    )
                }
                if let reminder = task.reminderDate, !task.isCompleted {
                    metaBadge(text: reminder.formatted(date: .omitted, time: .shortened), color: LuminaColor.outline)
                } else if let scheduled = task.scheduledDate, !Calendar.current.isDateInToday(scheduled), !task.isCompleted {
                    metaBadge(
                        text: scheduled.formatted(.dateTime.month().day()),
                        color: LuminaColor.outline
                    )
                }
            }
        }
    }

    private func metaBadge(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.08))
            .clipShape(Capsule())
    }

    private func priorityColor(_ priority: HubTaskPriority) -> Color {
        switch priority {
        case .low: return LuminaColor.outline
        case .medium: return LuminaColor.tertiary
        case .high: return LuminaColor.error
        }
    }
}
