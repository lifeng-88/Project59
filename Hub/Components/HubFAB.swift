import SwiftUI

struct HubFAB: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(LuminaColor.onPrimary)
                .frame(width: 56, height: 56)
                .background(LuminaColor.primary)
                .clipShape(RoundedRectangle(cornerRadius: LuminaRadius.lg))
                .luminaFABShadow()
        }
        .buttonStyle(.plain)
    }
}
