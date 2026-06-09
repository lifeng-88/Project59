import SwiftUI

struct QuickAddSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

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
            TextField("准备做什么？", text: $title, axis: .vertical)
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
                Toggle("设置日期", isOn: $hasScheduledDate)
                    .font(.luminaLabelMD)
                    .tint(LuminaColor.primary)
                if hasScheduledDate {
                    DatePicker("日期", selection: $scheduledDate, displayedComponents: .date)
                        .datePickerStyle(.graphical)
                        .tint(LuminaColor.primary)
                }
            }
        case .priority:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Text("优先级")
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                HStack(spacing: LuminaSpacing.gutter) {
                    ForEach(HubTaskPriority.allCases, id: \.self) { level in
                        Button {
                            priority = priority == level ? nil : level
                        } label: {
                            SelectableChip(title: level.displayName, isSelected: priority == level)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .reminder:
            VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                Toggle("设置提醒", isOn: $hasReminder)
                    .font(.luminaLabelMD)
                    .tint(LuminaColor.primary)
                if hasReminder {
                    DatePicker("提醒时间", selection: $reminderDate)
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
            Text("选择分类")
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)

            HStack(spacing: LuminaSpacing.gutter) {
                ForEach(TaskCategory.allCases, id: \.self) { category in
                    Button {
                        selectedCategory = selectedCategory == category ? nil : category
                    } label: {
                        SelectableChip(
                            title: category.displayName,
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
            guard hasScheduledDate else { return "无日期" }
            return scheduledDate.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
        case .priority:
            return priority.map { "\($0.displayName)优先级" } ?? "无优先级"
        case .reminder:
            guard hasReminder else { return "无提醒" }
            return reminderDate.formatted(date: .omitted, time: .shortened)
        case .tag:
            return selectedCategory?.displayName
        case nil:
            if let selectedCategory { return selectedCategory.displayName }
            if hasReminder { return reminderDate.formatted(date: .omitted, time: .shortened) }
            if let priority { return "\(priority.displayName)优先级" }
            if hasScheduledDate {
                return scheduledDate.formatted(.dateTime.month().day().locale(Locale(identifier: "zh_CN")))
            }
            return nil
        }
    }

    private var footerActions: some View {
        HStack {
            Button("取消") { dismiss() }
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
                    Text("保存")
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
