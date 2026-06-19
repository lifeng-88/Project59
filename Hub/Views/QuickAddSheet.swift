import SwiftUI

struct QuickAddSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language
    @Environment(\.locale) private var locale

    @State private var title = ""
    @State private var selectedCategory: TaskCategory?
    @State private var activeTool: QuickAddTool?
    @State private var scheduledDate = Date()
    @State private var hasScheduledDate = true
    @State private var priority: HubTaskPriority?
    @State private var reminderDate = Date()
    @State private var hasReminder = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField(L10n.tr(.quickAddPlaceholder, language: language), text: $title, axis: .vertical)
                .font(.luminaHeadlineLG)
                .foregroundStyle(LuminaColor.onSurface)
                .lineLimit(2...4)
                .padding(.bottom, LuminaSpacing.stackXL)

            toolBar
                .padding(.bottom, activeTool == nil ? LuminaSpacing.stackXL : LuminaSpacing.stackMD)

            toolOptions
                .padding(.bottom, LuminaSpacing.stackXL)

            Divider()
                .background(LuminaColor.surfaceVariant.opacity(0.3))
                .padding(.bottom, LuminaSpacing.stackMD)

            footerActions
        }
        .padding(.horizontal, LuminaSpacing.marginPage)
        .padding(.top, LuminaSpacing.stackMD)
        .padding(.bottom, LuminaSpacing.stackXL)
        .background(LuminaColor.surfaceContainerLowest)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: activeTool)
        .onAppear {
            if let prefill = store.quickAddPrefillDate {
                scheduledDate = prefill
                hasScheduledDate = true
            }
        }
        .onDisappear {
            store.clearQuickAddPrefill()
        }
        .presentationBackground(LuminaColor.surfaceContainerLowest)
    }

    @ViewBuilder
    private var toolOptions: some View {
        switch activeTool {
        case .date:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Toggle(L10n.tr(.setDate, language: language), isOn: $hasScheduledDate)
                    .font(.luminaLabelMD)
                    .tint(LuminaColor.primary)
                if hasScheduledDate {
                    DatePicker(L10n.tr(.dateLabel, language: language), selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(LuminaColor.primary)
                }
            }
        case .priority:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Text(L10n.tr(.prioritySection, language: language))
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                HStack(spacing: LuminaSpacing.gutter) {
                    ForEach(HubTaskPriority.allCases, id: \.self) { level in
                        Button {
                            priority = priority == level ? nil : level
                        } label: {
                            SelectableChip(title: level.displayName(language: language), isSelected: priority == level)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .reminder:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Toggle(L10n.tr(.setReminder, language: language), isOn: $hasReminder)
                    .font(.luminaLabelMD)
                    .tint(LuminaColor.primary)
                if hasReminder {
                    DatePicker(L10n.tr(.reminderTimeLabel, language: language), selection: $reminderDate)
                        .datePickerStyle(.compact)
                        .tint(LuminaColor.primary)
                }
            }
        case .tag:
            categoryPicker
        case nil:
            EmptyView()
        }
    }

    private var toolBar: some View {
        HStack(spacing: LuminaSpacing.gutter) {
            ForEach(QuickAddTool.allCases, id: \.self) { tool in
                QuickAddToolButton(
                    systemImage: tool.iconName,
                    isSelected: activeTool == tool
                ) {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                        activeTool = activeTool == tool ? nil : tool
                    }
                }
            }

            Spacer(minLength: 8)

            if let meta = toolMetaLabel {
                Text(meta)
                    .font(.luminaLabelSM)
                    .foregroundStyle(LuminaColor.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(LuminaColor.primary.opacity(0.08))
                    .clipShape(Capsule())
            }
        }
    }

    private var categoryPicker: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            Text(L10n.tr(.chooseCategory, language: language))
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)

            HStack(spacing: LuminaSpacing.gutter) {
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = selectedCategory == category ? nil : category
                    } label: {
                        SelectableChip(
                            title: category.displayName(language: language),
                            isSelected: selectedCategory == category
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var toolMetaLabel: String? {
        switch activeTool {
        case .date:
            guard hasScheduledDate else { return L10n.tr(.noDate, language: language) }
            return scheduledDate.formatted(.dateTime.month().day().locale(locale))
        case .priority:
            return priority.map {
                String(format: L10n.tr(.priorityLevelSuffix, language: language), $0.displayName(language: language))
            } ?? L10n.tr(.noPriority, language: language)
        case .reminder:
            guard hasReminder else { return L10n.tr(.noReminder, language: language) }
            return reminderDate.formatted(date: .omitted, time: .shortened)
        case .tag:
            return selectedCategory?.displayName(language: language)
        case nil:
            if let selectedCategory { return selectedCategory.displayName(language: language) }
            if hasReminder { return reminderDate.formatted(date: .omitted, time: .shortened) }
            if let priority {
                return String(format: L10n.tr(.priorityLevelSuffix, language: language), priority.displayName(language: language))
            }
            if hasScheduledDate {
                return scheduledDate.formatted(.dateTime.month().day().locale(locale))
            }
            return nil
        }
    }

    private var footerActions: some View {
        HStack {
            Button(L10n.tr(.commonCancel, language: language)) { dismiss() }
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.secondary)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)

            Spacer()

            Button {
                store.addTask(
                    title: title,
                    category: selectedCategory,
                    scheduledDate: hasScheduledDate ? scheduledDate : nil,
                    priority: priority,
                    reminderDate: hasReminder ? reminderDate : nil
                )
                dismiss()
            } label: {
                HStack(spacing: 8) {
                    Text(L10n.tr(.commonSave, language: language))
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                }
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.onPrimary)
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(LuminaColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                .luminaFABShadow()
            }
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

enum QuickAddTool: CaseIterable {
    case date, priority, reminder, tag

    var iconName: String {
        switch self {
        case .date: return "calendar"
        case .priority: return "exclamationmark"
        case .reminder: return "bell"
        case .tag: return "tag.fill"
        }
    }
}
