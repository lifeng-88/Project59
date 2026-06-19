import SwiftUI

struct HubBottomBar: View {
    @Binding var selection: HubTab
    @Environment(\.hubLanguage) private var language

    var body: some View {
        HStack {
            ForEach(HubTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        selection = tab
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: selection == tab ? tab.selectedIcon : tab.icon)
                            .font(.system(size: 22))
                        Text(tab.title(language: language))
                            .font(.luminaLabelSM)
                    }
                    .foregroundStyle(selection == tab ? LuminaColor.primary : LuminaColor.onSurfaceVariant)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LuminaSpacing.marginPage)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(
            LuminaColor.surfaceContainerLowest.opacity(0.92)
                .shadow(color: LuminaColor.primary.opacity(0.06), radius: 10, x: 0, y: -4)
        )
    }
}
