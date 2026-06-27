import SwiftUI

struct FocusModeSettingsView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language
    @ObservedObject private var ambient = AmbientSoundManager.shared
    @State private var showFocusGuide = false

    private let focusOptions = [25, 30, 45, 60]
    private let shortBreakOptions = [5, 10]
    private let longBreakOptions = [15, 20, 30]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HubTopBar(
                    title: L10n.tr(.focusModeTitle, language: language),
                    showMenu: false,
                    showSearch: false,
                    onBack: { dismiss() },
                    trailing: {
                        Button { showFocusGuide = true } label: {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 20))
                                .foregroundStyle(LuminaColor.onSurface)
                                .frame(width: 40, height: 40)
                        }
                    }
                )

                VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                    pomodoroSection
                    deepFocusSection
                    ambientSection
                    startButton
                }
                .padding(.horizontal, LuminaSpacing.marginPage)
                .padding(.top, LuminaSpacing.stackMD)
                .padding(.bottom, LuminaSpacing.stackXL)
            }
        }
        .background(LuminaColor.surface)
        .navigationBarHidden(true)
        .navigationDestination(isPresented: $showFocusGuide) {
            FocusModeGuideView()
        }
        .onDisappear {
            if !store.showFocusTimer {
                ambient.stop()
            }
        }
    }

    private var pomodoroSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            sectionTitle(L10n.tr(.focusPomodoroSettings, language: language))

            VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
                    HStack {
                        Text(L10n.tr(.focusDuration, language: language))
                            .font(.luminaBodyMD.weight(.medium))
                        Spacer()
                        Text(String(format: L10n.tr(.focusMinutesUnit, language: language), store.pomodoroMinutes))
                            .font(.luminaBodyLG.weight(.bold))
                            .foregroundStyle(LuminaColor.primary)
                    }

                    Picker(L10n.tr(.focusDuration, language: language), selection: $store.pomodoroMinutes) {
                        ForEach(focusOptions, id: \.self) { minutes in
                            Text(String(format: L10n.tr(.focusMinutesUnit, language: language), minutes)).tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: store.pomodoroMinutes) { _, _ in store.persist() }
                }

                HStack(spacing: LuminaSpacing.gutter) {
                    segmentGroup(
                        title: L10n.tr(.focusShortBreak, language: language),
                        options: shortBreakOptions,
                        selection: $store.breakMinutes
                    )
                    segmentGroup(
                        title: L10n.tr(.focusLongBreak, language: language),
                        options: longBreakOptions,
                        selection: $store.longBreakMinutes
                    )
                }
            }
            .padding(LuminaSpacing.insetMD)
            .background(LuminaColor.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
            .luminaSoftShadow()
        }
    }

    private func segmentGroup(title: String, options: [Int], selection: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            Text(title)
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onSurfaceVariant)

            HStack(spacing: 4) {
                ForEach(options, id: \.self) { value in
                    Button {
                        selection.wrappedValue = value
                        store.persist()
                    } label: {
                        Text("\(value)m")
                            .font(.luminaLabelMD)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selection.wrappedValue == value ? LuminaColor.surfaceContainerLowest : .clear)
                            .foregroundStyle(selection.wrappedValue == value ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(
                                color: selection.wrappedValue == value
                                    ? LuminaColor.scrim.opacity(0.12)
                                    : .clear,
                                radius: 4,
                                y: 2
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(LuminaColor.surfaceContainerLow)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        }
        .frame(maxWidth: .infinity)
    }

    private var deepFocusSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            sectionTitle(L10n.tr(.focusEnhanceSection, language: language))

            HStack(spacing: LuminaSpacing.stackMD) {
                Circle()
                    .fill(LuminaColor.primaryFixed)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(LuminaColor.primary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr(.focusDeepMode, language: language))
                        .font(.luminaBodyMD.weight(.semibold))
                    Text(L10n.tr(.focusDeepModeSubtitle, language: language))
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                }

                Spacer()

                Toggle("", isOn: $store.deepFocusEnabled)
                    .labelsHidden()
                    .tint(LuminaColor.primary)
                    .onChange(of: store.deepFocusEnabled) { _, _ in store.persist() }
            }
            .padding(LuminaSpacing.insetMD)
            .background(LuminaColor.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
            .luminaSoftShadow()
        }
    }

    private var ambientSection: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
            sectionTitle(L10n.tr(.focusAmbientSection, language: language))

            VStack(spacing: LuminaSpacing.stackSM) {
                ForEach(AmbientSound.allCases) { sound in
                    ambientRow(sound)
                }
            }
        }
    }

    private func ambientRow(_ sound: AmbientSound) -> some View {
        let selected = store.selectedAmbientSound == sound
        let playing = ambient.playingSound == sound
        return Button {
            store.selectedAmbientSound = sound
            store.persist()
            ambient.toggle(sound)
        } label: {
            HStack(spacing: LuminaSpacing.stackMD) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(LuminaColor.surfaceContainerHigh)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: sound.icon)
                            .foregroundStyle(selected ? LuminaColor.primary : LuminaColor.secondary)
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(sound.title(language: language))
                        .font(.luminaBodyMD.weight(.semibold))
                        .foregroundStyle(LuminaColor.onSurface)
                    Text(sound.subtitle(language: language))
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                }

                Spacer()

                Image(systemName: playing ? "pause.circle.fill" : "play.circle")
                    .font(.system(size: 28))
                    .foregroundStyle(playing ? LuminaColor.primary : LuminaColor.outlineVariant)
            }
            .padding(LuminaSpacing.insetMD)
            .background(LuminaColor.surfaceContainerLowest)
            .overlay(
                RoundedRectangle(cornerRadius: LuminaRadius.md)
                    .strokeBorder(selected ? LuminaColor.primary : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
            .luminaSoftShadow()
        }
        .buttonStyle(.plain)
    }

    private var startButton: some View {
        VStack(spacing: LuminaSpacing.stackMD) {
            Button {
                store.startFocusSession()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text(L10n.tr(.settingsStartFocusNow, language: language))
                }
                .font(.luminaLabelMD.weight(.semibold))
                .foregroundStyle(LuminaColor.onPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LuminaColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                .luminaFABShadow()
            }
            .buttonStyle(.plain)

            Text(L10n.tr(.focusSettingsEffectiveHint, language: language))
                .font(.luminaLabelSM)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
                .frame(maxWidth: .infinity)
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.luminaLabelMD)
            .foregroundStyle(LuminaColor.onSurfaceVariant)
            .padding(.horizontal, 4)
    }
}
