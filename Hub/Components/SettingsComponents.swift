import SwiftUI

// MARK: - 设置页通用组件

struct SettingsGroupCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
        }
        .background(LuminaColor.surfaceContainerLowest)
        .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.md))
        .luminaSoftShadow()
    }
}

struct SettingsDivider: View {
    var body: some View {
        Divider()
            .background(LuminaColor.surfaceVariant.opacity(0.35))
            .padding(.leading, 52)
    }
}

struct SettingsRowButton: View {
    let icon: String
    let title: String
    var subtitle: String?
    var trailing: String?
    var iconColor: Color = LuminaColor.primary
    var showChevron: Bool = true
    var trailingIcon: String?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            SettingsRowLabel(
                icon: icon,
                title: title,
                subtitle: subtitle,
                trailing: trailing,
                iconColor: iconColor,
                showChevron: showChevron,
                trailingIcon: trailingIcon
            )
        }
        .buttonStyle(SettingsRowButtonStyle())
    }
}

struct SettingsRowLabel: View {
    let icon: String
    let title: String
    var subtitle: String?
    var trailing: String?
    var iconColor: Color = LuminaColor.primary
    var showChevron: Bool = true
    var trailingIcon: String?

    var body: some View {
        HStack(spacing: LuminaSpacing.stackMD) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(iconColor)
                .frame(width: 28, height: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.luminaBodyMD)
                    .foregroundStyle(LuminaColor.onSurface)
                if let subtitle {
                    Text(subtitle)
                        .font(.luminaLabelSM)
                        .foregroundStyle(LuminaColor.onSurfaceVariant)
                }
            }

            Spacer(minLength: 8)

            if let trailing {
                Text(trailing)
                    .font(.luminaLabelMD)
                    .foregroundStyle(LuminaColor.onSurfaceVariant)
            }

            if let trailingIcon {
                Image(systemName: trailingIcon)
                    .font(.system(size: 14))
                    .foregroundStyle(LuminaColor.outlineVariant)
            } else if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LuminaColor.outlineVariant)
            }
        }
        .padding(LuminaSpacing.insetMD)
        .contentShape(Rectangle())
    }
}

struct SettingsToggleRow<Accessory: View>: View {
    let icon: String
    let title: String
    var subtitle: String?
    @Binding var isOn: Bool
    var iconColor: Color = LuminaColor.primary
    @ViewBuilder var accessory: () -> Accessory

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        isOn: Binding<Bool>,
        iconColor: Color = LuminaColor.primary,
        @ViewBuilder accessory: @escaping () -> Accessory = { EmptyView() }
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.iconColor = iconColor
        self.accessory = accessory
    }

    var body: some View {
        VStack(alignment: .leading, spacing: LuminaSpacing.stackSM) {
            HStack(spacing: LuminaSpacing.stackMD) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(iconColor)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.luminaBodyMD)
                        .foregroundStyle(LuminaColor.onSurface)
                    if let subtitle {
                        Text(subtitle)
                            .font(.luminaLabelSM)
                            .foregroundStyle(LuminaColor.onSurfaceVariant)
                    }
                }

                Spacer()

                Toggle("", isOn: $isOn)
                    .labelsHidden()
                    .tint(LuminaColor.primary)
            }

            accessory()
        }
        .padding(LuminaSpacing.insetMD)
    }
}

struct SettingsStatusBadge: View {
    let text: String
    var style: BadgeStyle = .primary

    enum BadgeStyle {
        case primary, success, neutral
    }

    var body: some View {
        Text(text)
            .font(.luminaLabelSM)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(foreground)
            .background(background)
            .clipShape(Capsule())
    }

    private var foreground: Color {
        switch style {
        case .primary: return LuminaColor.primary
        case .success: return LuminaColor.onPrimary
        case .neutral: return LuminaColor.onSurfaceVariant
        }
    }

    private var background: Color {
        switch style {
        case .primary: return LuminaColor.primary.opacity(0.1)
        case .success: return LuminaColor.primary
        case .neutral: return LuminaColor.surfaceContainer
        }
    }
}

struct SettingsRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? LuminaColor.surfaceContainerLow : Color.clear)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
