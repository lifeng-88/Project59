import SwiftUI

struct FocusTimerView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var ambient = AmbientSoundManager.shared

    @State private var phase: FocusPhase = .work
    @State private var secondsRemaining = 0
    @State private var totalPhaseSeconds = 1
    @State private var completedPomodoros = 0
    @State private var isRunning = false
    @State private var phaseEndDate: Date?
    @State private var timer: Timer?
    @State private var didRestoreSession = false
    @State private var sessionEnded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: LuminaSpacing.stackXL) {
                Text(phase.title(language: language))
                    .font(.luminaLabelMD)
                    .foregroundStyle(phase == .work ? LuminaColor.primary : LuminaColor.tertiary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background((phase == .work ? LuminaColor.primary : LuminaColor.tertiary).opacity(0.1))
                    .clipShape(Capsule())

                Spacer()

                ZStack {
                    Circle()
                        .stroke(LuminaColor.surfaceContainer, lineWidth: 8)
                        .frame(width: 220, height: 220)
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(ringColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 220, height: 220)
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.3), value: progress)

                    VStack(spacing: 8) {
                        Text(timeString)
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text(subtitle)
                            .font(.luminaLabelMD)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                    }
                }

                if phase == .work, store.deepFocusEnabled {
                    Label(L10n.tr(.focusDeepModeOn, language: language), systemImage: "moon.fill")
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.primary)
                }

                if completedPomodoros > 0 {
                    Text(String(format: L10n.tr(.focusCompletedCount, language: language), completedPomodoros))
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                }

                Spacer()

                HStack(spacing: LuminaSpacing.stackMD) {
                    Button(L10n.tr(.focusEnd, language: language)) {
                        endSession()
                    }
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(LuminaColor.surfaceContainer)
                    .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))

                    Button(isRunning ? L10n.tr(.focusPause, language: language) : L10n.tr(.focusStart, language: language)) {
                        isRunning ? pauseTimer() : startTimer()
                    }
                    .font(.luminaLabelMD.weight(.semibold))
                    .foregroundStyle(LuminaColor.onPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(ringColor)
                    .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                }

                if phase != .work {
                    Button(L10n.tr(.focusSkipBreak, language: language)) {
                        beginPhase(.work)
                    }
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.primary)
                }
            }
            .padding(LuminaSpacing.marginPage)
            .background(LuminaColor.surface)
            .navigationTitle(L10n.tr(.focusTimerTitle, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.focusClose, language: language)) {
                        endSession()
                    }
                }
            }
            .onAppear {
                if !didRestoreSession {
                    restoreOrStart()
                    didRestoreSession = true
                }
            }
            .onDisappear {
                if !sessionEnded {
                    pauseTimer(tick: false)
                }
                ambient.stop()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    syncRemainingFromEndDate()
                    if isRunning, secondsRemaining <= 0 {
                        handlePhaseComplete()
                    }
                } else if newPhase == .background {
                    persistSession()
                }
            }
        }
    }

    private var ringColor: Color {
        phase == .work ? LuminaColor.primary : LuminaColor.tertiary
    }

    private var subtitle: String {
        switch phase {
        case .work:
            return store.selectedAmbientSound?.title(language: language) ?? L10n.tr(.focusFocusing, language: language)
        case .shortBreak:
            return L10n.tr(.focusShortBreak, language: language)
        case .longBreak:
            return L10n.tr(.focusLongBreak, language: language)
        }
    }

    private var progress: CGFloat {
        guard totalPhaseSeconds > 0 else { return 0 }
        return 1 - CGFloat(secondsRemaining) / CGFloat(totalPhaseSeconds)
    }

    private var timeString: String {
        String(format: "%02d:%02d", max(0, secondsRemaining) / 60, max(0, secondsRemaining) % 60)
    }

    private func restoreOrStart() {
        if let saved = FocusSessionStore.load() {
            restore(from: saved)
            syncRemainingFromEndDate()
            if isRunning {
                if secondsRemaining <= 0 {
                    handlePhaseComplete()
                } else {
                    startTimer(resume: true)
                }
            }
            return
        }
        beginPhase(.work)
    }

    private func restore(from saved: PersistedFocusSession) {
        phase = FocusPhase(saved.phase)
        totalPhaseSeconds = saved.totalPhaseSeconds
        secondsRemaining = saved.secondsRemaining
        completedPomodoros = saved.completedPomodoros
        isRunning = saved.isRunning
        phaseEndDate = saved.phaseEndDate
        applyAmbientForCurrentPhase()
    }

    private func beginPhase(_ newPhase: FocusPhase) {
        pauseTimer(tick: false)
        NotificationService.cancelFocusPhaseEnd()
        phase = newPhase
        totalPhaseSeconds = secondsForPhase(newPhase)
        secondsRemaining = totalPhaseSeconds
        phaseEndDate = nil
        applyAmbientForCurrentPhase()
        persistSession()
    }

    private func applyAmbientForCurrentPhase() {
        switch phase {
        case .work:
            if let sound = store.selectedAmbientSound {
                ambient.play(sound)
            }
        case .shortBreak, .longBreak:
            ambient.stop()
        }
    }

    private func secondsForPhase(_ phase: FocusPhase) -> Int {
        switch phase {
        case .work: return store.pomodoroMinutes * 60
        case .shortBreak: return store.breakMinutes * 60
        case .longBreak: return store.longBreakMinutes * 60
        }
    }

    private func startTimer(resume: Bool = false) {
        if !resume || phaseEndDate == nil {
            phaseEndDate = Date().addingTimeInterval(TimeInterval(secondsRemaining))
        }
        isRunning = true
        schedulePhaseEndNotification()
        persistSession()

        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            DispatchQueue.main.async {
                syncRemainingFromEndDate()
                guard secondsRemaining > 0 else {
                    handlePhaseComplete()
                    return
                }
            }
        }
    }

    private func pauseTimer(tick: Bool = true, persist: Bool = true) {
        if tick {
            syncRemainingFromEndDate()
        }
        isRunning = false
        phaseEndDate = nil
        timer?.invalidate()
        timer = nil
        NotificationService.cancelFocusPhaseEnd()
        if persist {
            persistSession()
        }
    }

    private func syncRemainingFromEndDate() {
        guard isRunning, let end = phaseEndDate else { return }
        secondsRemaining = max(0, Int(ceil(end.timeIntervalSinceNow)))
    }

    private func endSession() {
        sessionEnded = true
        pauseTimer(tick: false, persist: false)
        store.clearActiveFocusSession()
        ambient.stop()
        dismiss()
    }

    private func handlePhaseComplete() {
        pauseTimer(tick: false)
        NotificationService.cancelFocusPhaseEnd()

        switch phase {
        case .work:
            completedPomodoros += 1
            store.completeFocusSession()
            if store.notificationsEnabled {
                NotificationService.notifyFocusComplete(
                    title: L10n.tr(.notifyPomodoroTitle, language: language),
                    body: String(format: L10n.tr(.notifyPomodoroBody, language: language), store.breakMinutes)
                )
            }
            let next: FocusPhase = completedPomodoros % 4 == 0 ? .longBreak : .shortBreak
            beginPhase(next)
            startTimer()
        case .shortBreak, .longBreak:
            if store.notificationsEnabled {
                NotificationService.notifyFocusComplete(
                    title: L10n.tr(.notifyBreakTitle, language: language),
                    body: L10n.tr(.notifyBreakBody, language: language)
                )
            }
            beginPhase(.work)
            startTimer()
        }
    }

    private func schedulePhaseEndNotification() {
        guard store.notificationsEnabled, let end = phaseEndDate else { return }
        let (title, body) = notificationContent(for: phase)
        NotificationService.scheduleFocusPhaseEnd(at: end, title: title, body: body)
    }

    private func notificationContent(for phase: FocusPhase) -> (String, String) {
        switch phase {
        case .work:
            return (
                L10n.tr(.notifyPomodoroTitle, language: language),
                String(format: L10n.tr(.notifyPomodoroBody, language: language), store.breakMinutes)
            )
        case .shortBreak, .longBreak:
            return (
                L10n.tr(.notifyBreakTitle, language: language),
                L10n.tr(.notifyBreakBody, language: language)
            )
        }
    }

    private func persistSession() {
        let persisted = PersistedFocusSession(
            phase: phase.persisted,
            phaseEndDate: phaseEndDate,
            secondsRemaining: secondsRemaining,
            totalPhaseSeconds: totalPhaseSeconds,
            completedPomodoros: completedPomodoros,
            isRunning: isRunning
        )
        FocusSessionStore.save(persisted)
    }
}

private enum FocusPhase {
    case work
    case shortBreak
    case longBreak

    init(_ persisted: PersistedFocusSession.Phase) {
        switch persisted {
        case .work: self = .work
        case .shortBreak: self = .shortBreak
        case .longBreak: self = .longBreak
        }
    }

    var persisted: PersistedFocusSession.Phase {
        switch self {
        case .work: return .work
        case .shortBreak: return .shortBreak
        case .longBreak: return .longBreak
        }
    }

    func title(language: AppLanguage) -> String {
        switch self {
        case .work: return L10n.tr(.focusPhaseWork, language: language)
        case .shortBreak: return L10n.tr(.focusPhaseShortBreak, language: language)
        case .longBreak: return L10n.tr(.focusPhaseLongBreak, language: language)
        }
    }
}
