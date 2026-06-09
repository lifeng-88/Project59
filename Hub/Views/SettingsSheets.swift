import SwiftUI
import StoreKit
import UIKit

// MARK: - 主题选择

struct ThemePickerSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

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
                                        Text(theme.displayName)
                                            .font(.luminaBodyMD)
                                            .foregroundStyle(LuminaColor.onSurface)
                                        Text(theme.subtitle)
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
            .navigationTitle("主题模式")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(LuminaColor.surface)
    }

  private var themePreview: some View {
    VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
      Text("预览")
        .font(.luminaLabelMD)
        .foregroundStyle(LuminaColor.onSurfaceVariant)

      HStack(spacing: LuminaSpacing.stackMD) {
        previewCard(label: "浅色", scheme: .light)
        previewCard(label: "深色", scheme: .dark)
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
    scheme == .dark ? Color(hex: 0x1C1F23) : Color(hex: 0xFFFFFF)
  }

  private func previewPrimary(for scheme: ColorScheme) -> Color {
    scheme == .dark ? Color(hex: 0xA4C9FF) : Color(hex: 0x005DA7)
  }
}

// MARK: - 专注目标

struct FocusGoalSheet: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss

    @State private var hours: Int = 20

    var body: some View {
        NavigationStack {
            VStack(spacing: LuminaSpacing.stackXL) {
                Text("设定每周专注时长目标，用于分析页进度展示。")
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Picker("小时", selection: $hours) {
                    ForEach(5...40, id: \.self) { value in
                        Text("\(value) 小时").tag(value)
                    }
                }
                .pickerStyle(.wheel)
                .frame(maxHeight: 200)

                Spacer()
            }
            .padding(.top, LuminaSpacing.stackMD)
            .background(LuminaColor.surface)
            .navigationTitle("专注目标")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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

    var body: some View {
        NavigationStack {
            List {
                ForEach(AppLanguage.allCases, id: \.self) { language in
                    Button {
                        store.appLanguage = language
                        store.persist()
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
            .navigationTitle("语言")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
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

    @State private var showExportPicker = false
    @State private var showImportPicker = false
    @State private var showRestoreConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Section("备份与恢复") {
                    Button {
                        showExportPicker = true
                    } label: {
                        Label("导出数据", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        showImportPicker = true
                    } label: {
                        Label("导入备份", systemImage: "square.and.arrow.down")
                    }

                    if store.cloudSyncEnabled {
                        Button {
                            syncToCloud()
                        } label: {
                            Label("上传到 iCloud", systemImage: "icloud.and.arrow.up")
                        }

                        Button(role: .destructive) {
                            showRestoreConfirm = true
                        } label: {
                            Label("从 iCloud 恢复", systemImage: "icloud.and.arrow.down")
                        }
                    }
                }

                Section {
                    Toggle("云端同步", isOn: Binding(
                        get: { store.cloudSyncEnabled },
                        set: { store.setCloudSyncEnabled($0) }
                    ))
                    .tint(LuminaColor.primary)

                    if let date = store.lastCloudSyncDate {
                        Text("上次同步：\(date.formatted(date: .abbreviated, time: .shortened))")
                            .font(.luminaLabelSM)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                    }
                } footer: {
                    Text("开启后，任务与设置将自动备份到 iCloud Drive。")
                }
            }
            .navigationTitle("数据与备份")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("完成") { dismiss() }
                }
            }
            .confirmationDialog("导出格式", isPresented: $showExportPicker) {
                Button("JSON（含设置）") { store.exportData(format: .json) }
                Button("CSV（任务列表）") { store.exportData(format: .csv) }
                Button("取消", role: .cancel) {}
            }
            .fileImporter(
                isPresented: $showImportPicker,
                allowedContentTypes: [.json, .commaSeparatedText, .plainText],
                allowsMultipleSelection: false
            ) { result in
                importFile(result)
            }
            .alert("从 iCloud 恢复？", isPresented: $showRestoreConfirm) {
                Button("取消", role: .cancel) {}
                Button("恢复", role: .destructive) {
                    store.restoreFromCloud()
                    dismiss()
                }
            } message: {
                Text("将用 iCloud 备份覆盖当前本地数据，此操作不可撤销。")
            }
        }
        .presentationDetents([.large])
        .presentationBackground(LuminaColor.surface)
    }

    private func syncToCloud() {
        do {
            try store.performCloudSync()
            store.alertMessage = "已上传到 iCloud"
        } catch {
            store.alertMessage = error.localizedDescription
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
                store.alertMessage = error.localizedDescription
            }
        case .failure(let error):
            store.alertMessage = error.localizedDescription
        }
    }
}

// MARK: - 隐私政策

struct LuminaPrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LuminaSpacing.stackMD) {
                    Text("Hub · Lumina Focus")
                        .font(.luminaHeadlineMobile)

                    Group {
                        policyBlock(title: "数据收集", body: "Hub 将任务与偏好设置存储在您的设备本地。若开启 iCloud 同步，数据会加密保存在您的 iCloud 账户中。")
                        policyBlock(title: "通知", body: "仅在您授权后，Hub 才会为任务提醒发送本地通知。")
                        policyBlock(title: "第三方服务", body: "本应用不使用第三方广告或分析 SDK。")
                    }
                }
                .padding(LuminaSpacing.marginPage)
            }
            .background(LuminaColor.surface)
            .scrollContentBackground(.hidden)
            .navigationTitle("隐私政策")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
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
