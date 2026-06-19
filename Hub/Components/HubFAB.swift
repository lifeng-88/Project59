import SwiftUI

struct HubFAB: View {
    @Environment(\.colorScheme) private var colorScheme
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(LuminaColor.onPrimary)
                .frame(width: 58, height: 58)
                .background(LuminaColor.primaryGradient(colorScheme: colorScheme))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.35), lineWidth: 1)
                )
                .luminaFABShadow()
        }
        .buttonStyle(.plain)
    }
}
