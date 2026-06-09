import SwiftUI

/// 弹窗内可选项 Chip（分类、标签等）
struct SelectableChip: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.luminaLabelSM)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
            .background(
                Capsule()
                    .fill(isSelected ? LuminaColor.primary.opacity(0.12) : LuminaColor.surfaceContainer)
            )
            .overlay(
                Capsule()
                    .strokeBorder(
                        isSelected ? LuminaColor.primary.opacity(0.4) : LuminaColor.outlineVariant.opacity(0.5),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

/// 弹窗顶部工具栏圆形按钮
struct QuickAddToolButton: View {
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(isSelected ? LuminaColor.primary.opacity(0.12) : LuminaColor.surfaceContainer)
                )
                .overlay(
                    Circle()
                        .strokeBorder(
                            isSelected ? LuminaColor.primary.opacity(0.45) : Color.clear,
                            lineWidth: 1.5
                        )
                )
                .scaleEffect(isSelected ? 1.06 : 1)
        }
        .buttonStyle(ScaleButtonStyle())
        .animation(.spring(response: 0.28, dampingFraction: 0.72), value: isSelected)
    }
}

private struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}
