import SwiftUI

struct TaskCheckbox: View {
    let isChecked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .strokeBorder(
                        isChecked ? LuminaColor.primary : LuminaColor.outlineVariant,
                        lineWidth: 2
                    )
                    .background(
                        Circle().fill(isChecked ? LuminaColor.primary : .clear)
                    )
                    .frame(width: 24, height: 24)

                if isChecked {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(LuminaColor.onPrimary)
                }
            }
        }
        .buttonStyle(.plain)
    }
}
