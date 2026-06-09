import SwiftUI

struct SideMenuView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: LuminaSpacing.stackXL) {
                    header

                    menuSection(title: L10n.tr(.menuNav, language: language)) {
                        ForEach(HubTab.allCases, id: \.self) { tab in
                            menuRow(
                                icon: tab.icon,
                                title: tab.title(language: language),
                                isSelected: store.selectedTab == tab
                            ) {
                                store.selectedTab = tab
                                dismiss()
                            }
                            if tab != HubTab.allCases.last {
                                SettingsDivider()
                            }
                        }
                    }

                    menuSection(title: L10n.tr(.menuShortcuts, language: language)) {
                        menuRow(icon: "plus.circle.fill", title: L10n.tr(.menuNewTask, language: language)) {
                            dismiss()
                            store.showQuickAdd = true
                        }
                        SettingsDivider()
                        menuRow(icon: "bolt.fill", title: L10n.tr(.menuStartFocus, language: language)) {
                            dismiss()
                            store.startFocusSession()
                        }
                    }
                }
                .padding(LuminaSpacing.marginPage)
                .padding(.top, LuminaSpacing.stackMD)
            }
            .background(LuminaColor.surface)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr(.menuClose, language: language)) { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: LuminaSpacing.stackMD) {
            ProfileAvatarView(
                image: store.profileAvatarImage,
                initials: store.userInitials,
                size: 48
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(store.userName)
                    .font(.luminaHeadlineMobile)
                    .foregroundStyle(LuminaColor.onSurface)
                Text(store.userEmail)
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
                    .lineLimit(1)
            }
            Spacer()
        }
    }

    private func menuSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            LuminaSectionLabel(title: title)
            VStack(spacing: 0) {
                content()
            }
            .background(LuminaColor.surfaceContainerLowest)
            .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
            .luminaSoftShadow()
        }
    }

    private func menuRow(
        icon: String,
        title: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: LuminaSpacing.stackMD) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                    .frame(width: 28)
                Text(title)
                    .font(.luminaBodyMD)
                    .foregroundStyle(isSelected ? LuminaColor.primary : LuminaColor.onSurface)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(LuminaColor.primary)
                }
            }
            .padding(LuminaSpacing.insetMD)
            .contentShape(Rectangle())
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}
