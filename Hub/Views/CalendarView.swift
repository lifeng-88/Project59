import SwiftUI

struct CalendarView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hubLanguage) private var language
    @Environment(\.locale) private var locale
    @State private var displayedMonth = Date()

    private var weekdaySymbols: [String] {
        L10n.weekdaySymbols(language: language)
    }

    private var tasksOnSelectedDay: [HubTask] {
        store.tasks(on: store.calendarSelectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HubTopBar(title: L10n.tr(.tabCalendar, language: language), onMenu: { store.showSideMenu = true })

                VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                    monthCard
                    scheduleSection
                    if tasksOnSelectedDay.isEmpty {
                        emptySuggestion
                    }
                }
                .padding(.horizontal, LuminaSpacing.marginPage)
                .padding(.top, LuminaSpacing.stackMD)
                .padding(.bottom, LuminaSpacing.stackXL)
            }
        }
        .scrollContentBackground(.hidden)
        .background(LuminaColor.surface.opacity(0.001))
        .refreshable {
            await store.refreshFromCloudAndNotifications()
        }
    }

    private var monthCard: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            HStack {
                Text(monthTitle)
                    .font(.luminaHeadlineMobile)
                Spacer()
                HStack(spacing: LuminaSpacing.stackSM) {
                    Button(action: jumpToToday) {
                        Text(L10n.tr(.calendarToday, language: language))
                            .font(.luminaLabelMD.weight(.semibold))
                            .foregroundStyle(LuminaColor.primary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(LuminaColor.primary.opacity(colorScheme == .dark ? 0.18 : 0.1))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button { shiftMonth(by: -1) } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(LuminaColor.surfaceContainer.opacity(colorScheme == .dark ? 0.5 : 0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                    Button { shiftMonth(by: 1) } label: {
                        Image(systemName: "chevron.right")
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                            .frame(width: 32, height: 32)
                            .background(LuminaColor.surfaceContainer.opacity(colorScheme == .dark ? 0.5 : 0.65))
                            .clipShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 16) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.outline)
                }
                ForEach(calendarDays, id: \.self) { day in
                    dayCell(day)
                }
            }
            .padding(.vertical, LuminaSpacing.stackSM)
            .padding(.horizontal, LuminaSpacing.stackSM)
            .background(
                RoundedRectangle(cornerRadius: LuminaRadius.sm)
                    .fill(LuminaColor.surfaceContainerLow.opacity(colorScheme == .dark ? 0.45 : 0.55))
            )
        }
        .padding(LuminaSpacing.insetMD)
        .background {
            ZStack {
                LuminaColor.calendarMonthCardGradient(colorScheme: colorScheme)

                Circle()
                    .fill(LuminaColor.primary.opacity(colorScheme == .dark ? 0.14 : 0.08))
                    .frame(width: 140, height: 140)
                    .offset(x: 110, y: -52)
                    .blur(radius: 1)

                Circle()
                    .fill(LuminaColor.tertiary.opacity(colorScheme == .dark ? 0.12 : 0.07))
                    .frame(width: 96, height: 96)
                    .offset(x: -100, y: 28)
                    .blur(radius: 1)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .overlay {
            RoundedRectangle(cornerRadius: LuminaRadius.md)
                .strokeBorder(
                    LuminaColor.outlineVariant.opacity(colorScheme == .dark ? 0.35 : 0.45),
                    lineWidth: 1
                )
        }
        .luminaSoftShadow()
    }

    private func dayCell(_ day: CalendarDay) -> some View {
        Button {
            if let date = day.date {
                store.calendarSelectedDate = date
            }
        } label: {
            ZStack {
                if day.isSelected {
                    Circle()
                        .fill(LuminaColor.primary)
                        .frame(width: 32, height: 32)
                } else if day.isToday {
                    Circle()
                        .stroke(LuminaColor.primary.opacity(colorScheme == .dark ? 0.65 : 0.45), lineWidth: 1.5)
                        .frame(width: 32, height: 32)
                }
                VStack(spacing: 2) {
                    Text(day.isPadding ? "" : "\(day.number)")
                        .font(.luminaBodyMD)
                        .foregroundStyle(dayForeground(day))
                    if day.hasEvent && !day.isSelected {
                        Circle().fill(LuminaColor.primary).frame(width: 4, height: 4)
                    } else {
                        Color.clear.frame(height: 4)
                    }
                }
            }
            .frame(height: 36)
        }
        .buttonStyle(.plain)
        .disabled(day.isPadding)
    }

    private func dayForeground(_ day: CalendarDay) -> Color {
        if day.isSelected { return LuminaColor.onPrimary }
        if day.isPadding { return LuminaColor.onSurfaceVariant.opacity(0.3) }
        if day.isToday { return LuminaColor.primary }
        return LuminaColor.onSurface
    }

    private var scheduleSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(dayHeaderLabel)
                        .font(.luminaLabelSM)
                        .tracking(0.8)
                        .foregroundStyle(LuminaColor.primary)
                    Text(selectedDateTitle)
                        .font(.luminaHeadlineLG)
                }
                Spacer()
                Text(String(format: L10n.tr(.calendarPendingTasks, language: language), tasksOnSelectedDay.filter { !$0.isCompleted }.count))
                    .font(.luminaLabelSM)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(LuminaColor.secondaryContainer)
                    .foregroundStyle(LuminaColor.onSecondaryContainer)
                    .clipShape(Capsule())
            }

            if tasksOnSelectedDay.isEmpty {
                Text(L10n.tr(.calendarNoSchedule, language: language))
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.outline)
            } else {
                VStack(spacing: LuminaSpacing.stackMD) {
                    ForEach(tasksOnSelectedDay) { task in
                        taskTimelineRow(task)
                            .onTapGesture { store.taskToEdit = task }
                            .contextMenu {
                                Button { store.taskToEdit = task } label: {
                                    Label(L10n.tr(.commonEdit, language: language), systemImage: "pencil")
                                }
                                Button(role: .destructive) {
                                    store.deleteTask(task)
                                } label: {
                                    Label(L10n.tr(.commonDelete, language: language), systemImage: "trash")
                                }
                            }
                    }
                }
            }

            if Calendar.current.isDateInToday(store.calendarSelectedDate) {
                nowMarker
            }
        }
    }

    private func taskTimelineRow(_ task: HubTask) -> some View {
        HStack(alignment: .top, spacing: LuminaSpacing.stackMD + 8) {
            Text(timeLabel(for: task))
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.outline)
                .frame(width: 44, alignment: .trailing)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(task.title)
                        .font(.luminaBodyMD.weight(.bold))
                        .strikethrough(task.isCompleted)
                    Spacer()
                    if let category = task.category {
                        Text(category.displayName(language: language))
                            .font(.luminaLabelSM)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(categoryColor(category).opacity(0.1))
                            .foregroundStyle(categoryColor(category))
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
                if let priority = task.priority {
                    Text(String(format: L10n.tr(.priorityLevelSuffix, language: language), priority.displayName(language: language)))
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                }
            }
            .padding(LuminaSpacing.insetMD)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LuminaColor.surfaceContainerLowest)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(categoryColor(task.category ?? .work))
                    .frame(width: 4)
            }
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
            .luminaSoftShadow()
            .opacity(task.isCompleted ? 0.7 : 1)
        }
    }

    private func timeLabel(for task: HubTask) -> String {
        if let reminder = task.reminderDate {
            return reminder.formatted(date: .omitted, time: .shortened)
        }
        return L10n.tr(.calendarAllDay, language: language)
    }

    private func categoryColor(_ category: TaskCategory) -> Color {
        switch category {
        case .work: return LuminaColor.primary
        case .personal: return LuminaColor.tertiaryContainer
        case .deepFocus: return LuminaColor.outline
        }
    }

    private var nowMarker: some View {
        HStack(spacing: LuminaSpacing.stackMD + 8) {
            Text(Date().formatted(date: .omitted, time: .shortened))
                .font(.luminaLabelSM.weight(.bold))
                .foregroundStyle(LuminaColor.primary)
                .frame(width: 44, alignment: .trailing)
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(LuminaColor.primary.opacity(0.3))
                    .frame(height: 2)
                Circle()
                    .fill(LuminaColor.primary)
                    .frame(width: 12, height: 12)
                    .overlay(Circle().stroke(LuminaColor.surfaceContainerLowest, lineWidth: 2))
                    .offset(x: -6)
            }
        }
    }

    private var emptySuggestion: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Text(L10n.tr(.calendarEmptyTitle, language: language))
                .font(.luminaBodyLG)
                .foregroundStyle(LuminaColor.outline)
                .multilineTextAlignment(.center)

            HStack(spacing: LuminaSpacing.stackMD) {
                Button {
                    store.prepareQuickAdd(for: store.calendarSelectedDate)
                    store.showQuickAdd = true
                } label: {
                    Label(L10n.tr(.calendarAddTask, language: language), systemImage: "plus.circle.fill")
                        .font(.luminaLabelMD.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LuminaColor.primary)
                        .foregroundStyle(LuminaColor.onPrimary)
                        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    store.startFocusSession()
                } label: {
                    Label(L10n.tr(.calendarStartFocus, language: language), systemImage: "bolt.fill")
                        .font(.luminaLabelMD.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(LuminaColor.surfaceContainer)
                        .foregroundStyle(LuminaColor.primary)
                        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, LuminaSpacing.stackXL)
    }

    private var monthTitle: String {
        displayedMonth.formatted(.dateTime.year().month().locale(locale))
    }

    private var selectedDateTitle: String {
        store.calendarSelectedDate.formatted(.dateTime.month().day().locale(locale))
    }

    private var dayHeaderLabel: String {
        if Calendar.current.isDateInToday(store.calendarSelectedDate) {
            return L10n.tr(.calendarToday, language: language)
        }
        return L10n.tr(.calendarDaySelected, language: language)
    }

    private func shiftMonth(by value: Int) {
        if let newDate = Calendar.current.date(byAdding: .month, value: value, to: displayedMonth) {
            displayedMonth = newDate
        }
    }

    private func jumpToToday() {
        let today = Date()
        displayedMonth = today
        store.calendarSelectedDate = today
    }

    private var calendarDays: [CalendarDay] {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month], from: displayedMonth)
        guard let firstOfMonth = cal.date(from: comps),
              let range = cal.range(of: .day, in: .month, for: firstOfMonth) else { return [] }

        let leading = cal.component(.weekday, from: firstOfMonth) - 1
        var days: [CalendarDay] = []

        for _ in 0..<leading {
            days.append(CalendarDay(number: 0, isPadding: true, date: nil, hasEvent: false, isSelected: false, isToday: false))
        }

        for day in range {
            var components = comps
            components.day = day
            let date = cal.date(from: components)
            let isSelected = date.map { cal.isDate($0, inSameDayAs: store.calendarSelectedDate) } ?? false
            let hasEvent = date.map { store.hasTasks(on: $0) } ?? false
            let isToday = date.map { cal.isDateInToday($0) } ?? false
            days.append(CalendarDay(number: day, isPadding: false, date: date, hasEvent: hasEvent, isSelected: isSelected, isToday: isToday))
        }
        return days
    }
}

private struct CalendarDay: Hashable {
    let number: Int
    let isPadding: Bool
    let date: Date?
    let hasEvent: Bool
    let isSelected: Bool
    let isToday: Bool
}
