import SwiftUI

struct HubTopBar<Trailing: View>: View {
    let title: String
    var showMenu: Bool = true
    var showSearch: Bool = true
    var onMenu: (() -> Void)?
    var onSearch: (() -> Void)?
    var onBack: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(
        title: String,
        showMenu: Bool = true,
        showSearch: Bool = true,
        onMenu: (() -> Void)? = nil,
        onSearch: (() -> Void)? = nil,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.showMenu = showMenu
        self.showSearch = showSearch
        self.onMenu = onMenu
        self.onSearch = onSearch
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(LuminaColor.onSurface)
                        .frame(width: 40, height: 40)
                }
            } else if showMenu {
                Button { onMenu?() } label: {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 20))
                        .foregroundStyle(LuminaColor.primary)
                        .frame(width: 40, height: 40)
                }
            }

            Text(title)
                .font(.luminaHeadlineMobile)
                .foregroundStyle(LuminaColor.onSurface)

            Spacer()

            trailing()

            if showSearch {
                Button { onSearch?() } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 20))
                        .foregroundStyle(LuminaColor.primary)
                        .frame(width: 40, height: 40)
                }
            }
        }
        .padding(.horizontal, LuminaSpacing.marginPage)
        .frame(height: 64)
        .background(LuminaColor.surface)
    }
}
