import SwiftUI

struct TodayView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hubLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var searchText = ""
    @State private var isSearching = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.locale = locale
        f.setLocalizedDateFormatFromTemplate(language == .en ? "MMMdEEEE" : "MMMdEEEE")
        return f
    }

    private var displayedTasks: [HubTask] {
        store.filteredTasks(search: searchText, todayOnly: true)
    }

    private var activeTasks: [HubTask] {
        displayedTasks.filter { !$0.isCompleted }
    }

    private var completedTasks: [HubTask] {
        displayedTasks.filter(\.isCompleted)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HubTopBar(
                    title: L10n.tr(.todayTitle, language: language),
                    onMenu: { store.showSideMenu = true },
                    onSearch: { withAnimation { isSearching.toggle() } }
                )

                if isSearching {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(LuminaColor.outline)
                        TextField(L10n.tr(.todaySearch, language: language), text: $searchText)
                            .font(.luminaBodyMD)
                        if !searchText.isEmpty {
                            Button { searchText = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(LuminaColor.outline)
                            }
                        }
                    }
                    .padding(LuminaSpacing.insetMD)
                    .background(LuminaColor.surfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                    .luminaSoftShadow()
                    .padding(.horizontal, LuminaSpacing.marginPage)
                    .padding(.bottom, LuminaSpacing.stackMD)
                }

                VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                    VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                        Text(dateFormatter.string(from: Date()))
                            .font(.luminaDisplay)
                            .foregroundStyle(LuminaColor.onBackground)

                        Text(String(format: L10n.tr(.todayRemaining, language: language), store.remainingCount))
                            .font(.luminaLabelMD)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                    }
                    .padding(.top, LuminaSpacing.stackSM)

                    if activeTasks.isEmpty && completedTasks.isEmpty {
                        emptyState
                    } else {
                        VStack(spacing: LuminaSpacing.stackMD) {
                            ForEach(Array(activeTasks.enumerated()), id: \.element.id) { index, task in
                                taskRow(task)

                                if index == 1 {
                                    inspirationCard
                                }
                            }

                            if !completedTasks.isEmpty {
                                LuminaSectionLabel(title: L10n.tr(.todayCompleted, language: language))
                                    .padding(.top, LuminaSpacing.stackMD)
                                    .padding(.horizontal, 4)

                                ForEach(completedTasks) { task in
                                    taskRow(task)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, LuminaSpacing.marginPage)
                .padding(.bottom, LuminaSpacing.stackXL)
            }
        }
        .background(LuminaColor.surface.opacity(0.001))
        .refreshable {
            await store.refreshFromCloudAndNotifications()
        }
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
            Image(systemName: "checklist")
                .font(.system(size: 40))
                .foregroundStyle(LuminaColor.outline)
            Text(searchText.isEmpty
                ? L10n.tr(.todayEmptyNoTasks, language: language)
                : L10n.tr(.todayEmptyNoResults, language: language))
                .font(.luminaBodyLG)
                .foregroundStyle(LuminaColor.outline)
            if searchText.isEmpty {
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

    private var inspirationCard: some View {
        ZStack(alignment: .bottomLeading) {
            LuminaColor.inspirationGradient(colorScheme: colorScheme)
            LinearGradient(
                colors: [.clear, LuminaColor.scrim.opacity(colorScheme == .dark ? 0.55 : 0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            Text(L10n.tr(.todayInspiration, language: language))
                .font(.luminaLabelMD)
                .italic()
                .foregroundStyle(colorScheme == .dark ? LuminaColor.onPrimaryContainer : .white)
                .padding(LuminaSpacing.insetMD)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 120)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.lg))
        .luminaSoftShadow()
    }
}
