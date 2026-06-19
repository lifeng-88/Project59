import SwiftUI

struct EditTaskSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    let task: HubTask

    @State private var title: String
    @State private var selectedCategory: TaskCategory?
    @State private var activeTool: QuickAddTool?
    @State private var scheduledDate: Date
    @State private var hasScheduledDate: Bool
    @State private var priority: HubTaskPriority?
    @State private var reminderDate: Date
    @State private var hasReminder: Bool

    init(task: HubTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _selectedCategory = State(initialValue: task.category)
        _scheduledDate = State(initialValue: task.scheduledDate ?? Date())
        _hasScheduledDate = State(initialValue: task.scheduledDate != nil)
        _priority = State(initialValue: task.priority)
        _reminderDate = State(initialValue: task.reminderDate ?? Date())
        _hasReminder = State(initialValue: task.reminderDate != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    TextField(L10n.tr(.taskTitlePlaceholder, language: language), text: $title, axis: .vertical)
                        .font(.luminaHeadlineLG)
                        .lineLimit(2...4)
                        .padding(.bottom, LuminaSpacing.stackXL)

                    toolBar
                        .padding(.bottom, activeTool == nil ? LuminaSpacing.stackXL : LuminaSpacing.stackMD)

                    toolOptions
                        .padding(.bottom, LuminaSpacing.stackXL)
                }
            }
            .padding(.horizontal, LuminaSpacing.marginPage)
            .padding(.top, LuminaSpacing.stackMD)
            .navigationTitle(L10n.tr(.editTaskTitle, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonCancel, language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr(.commonSave, language: language)) { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .background(LuminaColor.surfaceContainerLowest)
        .presentationBackground(LuminaColor.surfaceContainerLowest)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: activeTool)
    }

    @ViewBuilder
    private var toolOptions: some View {
        switch activeTool {
        case .date:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Toggle(L10n.tr(.setDate, language: language), isOn: $hasScheduledDate).tint(LuminaColor.primary)
                if hasScheduledDate {
                    DatePicker(L10n.tr(.dateLabel, language: language), selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(LuminaColor.primary)
                }
            }
        case .priority:
            HStack(spacing: LuminaSpacing.gutter) {
                ForEach(HubTaskPriority.allCases, id: \.self) { level in
                    Button { priority = priority == level ? nil : level } label: {
                        SelectableChip(title: level.displayName(language: language), isSelected: priority == level)
                    }
                    .buttonStyle(.plain)
                }
            }
        case .reminder:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Toggle(L10n.tr(.setReminder, language: language), isOn: $hasReminder).tint(LuminaColor.primary)
                if hasReminder {
                    DatePicker(L10n.tr(.reminderTimeLabel, language: language), selection: $reminderDate).tint(LuminaColor.primary)
                }
            }
        case .tag:
            HStack(spacing: LuminaSpacing.gutter) {
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    Button { selectedCategory = selectedCategory == category ? nil : category } label: {
                        SelectableChip(title: category.displayName(language: language), isSelected: selectedCategory == category)
                    }
                    .buttonStyle(.plain)
                }
            }
        case nil:
            EmptyView()
        }
    }

    private var toolBar: some View {
        HStack(spacing: LuminaSpacing.gutter) {
            ForEach(QuickAddTool.allCases, id: \.self) { tool in
                QuickAddToolButton(systemImage: tool.iconName, isSelected: activeTool == tool) {
                    withAnimation { activeTool = activeTool == tool ? nil : tool }
                }
            }
        }
    }

    private func save() {
        store.updateTask(
            task,
            title: title,
            category: selectedCategory,
            scheduledDate: hasScheduledDate ? scheduledDate : nil,
            priority: priority,
            reminderDate: hasReminder ? reminderDate : nil
        )
        dismiss()
    }
}
