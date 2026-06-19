import SwiftUI
import StoreKit
import UIKit

// MARK: - 主题选择

struct ThemePickerSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.hubLanguage) private var language

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: LuminaSpacing.stackMD) {
                    themePreview

                    VStack(spacing: 0) {
                        ForEach(HubAppearanceTheme.allCases, id: \.self) { theme in
                            Button {
                                store.appTheme = theme
                                store.persist()
                            } label: {
                                HStack(spacing: LuminaSpacing.stackMD) {
                                    Image(systemName: theme.icon)
                                        .font(.system(size: 22))
                                        .foregroundStyle(LuminaColor.primary)
                                        .frame(width: 36)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(theme.displayName(language: language))
                                            .font(.luminaBodyMD)
                                            .foregroundStyle(LuminaColor.onSurface)
                                        Text(theme.subtitle(language: language))
                                            .font(.luminaLabelSM)
                                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                                    }

                                    Spacer()

                                    if store.appTheme == theme {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(LuminaColor.primary)
                                    }
                                }
                                .padding(LuminaSpacing.insetMD)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(SettingsRowButtonStyle())

                            if theme != HubAppearanceTheme.allCases.last {
                                SettingsDivider()
                            }
                        }
                    }
                    .background(LuminaColor.surfaceContainerLowest)
                    .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
                    .luminaSoftShadow()
                }
                .padding(LuminaSpacing.marginPage)
            }
            .background(LuminaColor.surface)
            .navigationTitle(L10n.tr(.settingsTheme, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonDone, language: language)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(LuminaColor.surface)
    }

  private var themePreview: some View {
    VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
      Text(L10n.tr(.themePreview, language: language))
        .font(.luminaLabelMD)
        .foregroundStyle(LuminaColor.onSurfaceVariant)

      HStack(spacing: LuminaSpacing.stackMD) {
        previewCard(label: L10n.tr(.themePreviewLight, language: language), scheme: .light)
        previewCard(label: L10n.tr(.themePreviewDark, language: language), scheme: .dark)
      }
    }
  }

  private func previewCard(label: String, scheme: ColorScheme) -> some View {
    let isActive: Bool = {
      switch store.appTheme {
      case .light: return scheme == .light
      case .dark: return scheme == .dark
      case .system: return colorScheme == scheme
      }
    }()

    return VStack(alignment: .leading, spacing: 8) {
      RoundedRectangle(cornerRadius: LuminaRadius.md)
        .fill(previewSurface(for: scheme))
        .frame(height: 72)
        .overlay(alignment: .topLeading) {
          RoundedRectangle(cornerRadius: 6)
            .fill(previewPrimary(for: scheme))
            .frame(width: 48, height: 8)
            .padding(10)
        }
        .overlay(
          RoundedRectangle(cornerRadius: LuminaRadius.md)
            .strokeBorder(isActive ? LuminaColor.primary : LuminaColor.outlineVariant, lineWidth: isActive ? 2 : 1)
        )

      Text(label)
        .font(.luminaLabelSM)
        .foregroundStyle(isActive ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
    }
    .frame(maxWidth: .infinity)
  }

  private func previewSurface(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0x1F1A22) : Color(hex: 0xFFFFFF)
  }

  private func previewPrimary(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xF0A8C8) : Color(hex: 0xC45C8A)
  }
}

// MARK: - 专注目标

struct FocusGoalSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    @State private var hours: Int = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: LuminaSpacing.stackXL) {
                Text(L10n.tr(.focusGoalHint, language: language))
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Picker(L10n.tr(.settingsFocusGoal, language: language), selection: $hours) {
                    ForEach(5...40, id: \.self) { value in
                        Text(String(format: L10n.tr(.focusGoalPickerHours, language: language), value)).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 200)

                Spacer()
            }
            .padding(.top, LuminaSpacing.stackMD)
            .background(LuminaColor.surface)
            .navigationTitle(L10n.tr(.settingsFocusGoal, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonCancel, language: language)) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr(.commonSave, language: language)) {
                        store.setFocusGoalHours(hours)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                hours = store.focusGoalHours
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(LuminaColor.surface)
    }
}

// MARK: - 语言选择

struct LanguagePickerSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button {
                        store.appLanguage = language
                        store.syncDemoSampleContentIfNeeded()
                        store.persist()
                        Task { await store.syncNotifications() }
                        dismiss()
                    } label: {
                        HStack {
                            Text(language.displayName)
                                .font(.luminaBodyMD)
                                .foregroundStyle(LuminaColor.onSurface)
                            Spacer()
                            if store.appLanguage == language {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(LuminaColor.primary)
                            }
                        }
                    }
                }
            }
            .navigationTitle(L10n.tr(.settingsLanguage, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonDone, language: language)) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(LuminaColor.surface)
    }
}

// MARK: - 数据管理

struct DataManagementSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var showRestoreConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section(L10n.tr(.dataBackupSection, language: language)) {
                    Button {
                        showExportPicker = true
                    } label: {
                        Label(L10n.tr(.dataExport, language: language), systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label(L10n.tr(.dataImport, language: language), systemImage: "square.and.arrow.down")
                    }

                    if store.cloudSyncEnabled {
                        Button {
                            syncToCloud()
                        } label: {
                            Label(L10n.tr(.dataUploadCloud, language: language), systemImage: "icloud.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            showRestoreConfirm = true
                        } label: {
                            Label(L10n.tr(.dataRestoreCloud, language: language), systemImage: "icloud.and.arrow.down")
                        }
                    }
                }

                Section {
                    Toggle(L10n.tr(.dataCloudSyncToggle, language: language), isOn: Binding(
                        get: { store.cloudSyncEnabled },
                        set: { store.setCloudSyncEnabled($0) }
                    ))
                    .tint(LuminaColor.primary)

                    if let date = store.lastCloudSyncDate {
                        Text(String(format: L10n.tr(.dataLastSyncInline, language: language), date.formatted(date: .abbreviated, time: .shortened)))
                            .font(.luminaLabelSM)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                    }
                } footer: {
                    Text(L10n.tr(.dataCloudFooter, language: language))
                }
            }
            .navigationTitle(L10n.tr(.dataNavTitle, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonDone, language: language)) { dismiss() }
                }
            }
            .confirmationDialog(L10n.tr(.dataExportFormat, language: language), isPresented: $showExportPicker) {
                Button(L10n.tr(.dataExportJSON, language: language)) { store.exportData(format: .json) }
                Button(L10n.tr(.dataExportCSV, language: language)) { store.exportData(format: .csv) }
                Button(L10n.tr(.commonCancel, language: language), role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                importFile(result)
            }
            .alert(L10n.tr(.dataRestoreTitle, language: language), isPresented: $showRestoreConfirm) {
                Button(L10n.tr(.commonCancel, language: language), role: .cancel) {}
                Button(L10n.tr(.dataRestoreAction, language: language), role: .destructive) {
                    store.restoreFromCloud()
                    dismiss()
                }
            } message: {
                Text(L10n.tr(.dataRestoreMessage, language: language))
            }
        }
        .presentationDetents([.large])
        .presentationBackground(LuminaColor.surface)
    }

    private func syncToCloud() {
        do {
            try store.performCloudSync()
            store.alertMessage = L10n.tr(.alertUploadedCloud, language: language)
        } catch {
            store.alertMessage = L10n.hubErrorMessage(error, language: language)
        }
    }

    private func importFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first, url.startAccessingSecurityScopedResource() else { return }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                let data = try Data(contentsOf: url)
                try DataImportService.importData(data, into: store)
                dismiss()
            } catch {
                store.alertMessage = L10n.hubErrorMessage(error, language: language)
            }
        case .failure(let error):
            store.alertMessage = L10n.hubErrorMessage(error, language: language)
        }
    }
}

// MARK: - 隐私政策

struct LuminaPrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
                    Text("Hub · Lumina Focus")
                        .font(.luminaHeadlineMobile)

                    Group {
                        policyBlock(
                            title: L10n.tr(.privacyDataCollection, language: language),
                            body: L10n.tr(.privacyDataCollectionBody, language: language)
                        )
                        policyBlock(
                            title: L10n.tr(.privacyNotificationsSection, language: language),
                            body: L10n.tr(.privacyNotificationsBody, language: language)
                        )
                        policyBlock(
                            title: L10n.tr(.privacyThirdParty, language: language),
                            body: L10n.tr(.privacyThirdPartyBody, language: language)
                        )
                    }
                }
                .padding(LuminaSpacing.marginPage)
            }
            .background(LuminaColor.surface)
            .scrollContentBackground(.hidden)
            .navigationTitle(L10n.tr(.settingsPrivacy, language: language))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.commonClose, language: language)) { dismiss() }
                }
            }
        }
    }

    private func policyBlock(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.luminaBodyMD.weight(.semibold))
            Text(body)
                .font(.luminaBodyMD)
                .foregroundStyle(LuminaColor.onSurfaceVariant)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(LuminaSpacing.insetMD)
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
    }
}

// MARK: - 评价

enum AppReview {
    static func request() {
        if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        }
    }
}
