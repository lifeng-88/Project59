import SwiftUI

enum SettingsTasksListScope {
    case all
    case completed
}

struct SettingsTasksListView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    let scope: SettingsTasksListScope

    private var title: String {
        switch scope {
        case .all:
            L10n.tr(.settingsAllTasks, language: language)
        case .completed:
            L10n.tr(.settingsCompleted, language: language)
        }
    }

    private var tasks: [HubTask] {
        switch scope {
        case .all:
            store.tasks.sorted { !$0.isCompleted && $1.isCompleted }
        case .completed:
            store.completedTasks
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
                HubTopBar(title: title, showMenu: false, onBack: { dismiss() })

                if tasks.isEmpty {
                    emptyState
                        .padding(.horizontal, LuminaSpacing.marginPage)
                } else {
                    Text(String(format: L10n.tr(.settingsTasksListCount, language: language), tasks.count))
                        .font(.luminaLabelMD)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                        .padding(.horizontal, LuminaSpacing.marginPage)

                    VStack(spacing: LuminaSpacing.stackMD) {
                        ForEach(tasks) { task in
                            taskRow(task)
                        }
                    }
                    .padding(.horizontal, LuminaSpacing.marginPage)
                }
            }
            .padding(.bottom, LuminaSpacing.stackXL)
        }
        .background(LuminaColor.surface)
        .navigationBarHidden(true)
    }

    private func taskRow(_ task: HubTask) -> some View {
        TaskRowView(task: task) {
            withAnimation(.easeInOut(duration: 0.2)) {
                store.toggle(task)
            }
        }
        .onTapGesture {
            store.taskToEdit = task
        }
        .contextMenu {
            Button {
                store.taskToEdit = task
            } label: {
                Label(L10n.tr(.commonEdit, language: language), systemImage: "pencil")
            }
            Button(role: .destructive) {
                withAnimation { store.deleteTask(task) }
            } label: {
                Label(L10n.tr(.commonDelete, language: language), systemImage: "trash")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Image(systemName: scope == .completed ? "checkmark.circle" : "checklist")
                .font(.system(size: 40))
                .foregroundStyle(LuminaColor.outline)
            Text(scope == .completed
                ? L10n.tr(.settingsCompletedEmpty, language: language)
                : L10n.tr(.todayEmptyNoTasks, language: language))
                .font(.luminaBodyLG)
                .foregroundStyle(LuminaColor.outline)
            if scope == .all {
                Button(L10n.tr(.todayAddFirst, language: language)) {
                    store.showQuickAdd = true
                }
                .font(.luminaLabelMD)
                .foregroundStyle(LuminaColor.primary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LuminaSpacing.stackXL)
    }
}
