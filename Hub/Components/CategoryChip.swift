import SwiftUI

struct CategoryChip: View {
    let title: String
    var isCompleted: Bool = false

    var body: some View {
        Text(title)
            .font(.luminaLabelSM)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(
                (isCompleted ? LuminaColor.outline : LuminaColor.primary)
                    .opacity(isCompleted ? 0.08 : 0.1)
            )
            .foregroundStyle(isCompleted ? LuminaColor.outline.opacity(0.5) : LuminaColor.primary)
            .clipShape(Capsule())
    }
}
