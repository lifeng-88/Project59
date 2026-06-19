import SwiftUI

extension Font {
    static let luminaDisplay = Font.system(size: 32, weight: .bold, design: .rounded)
    static let luminaHeadlineLG = Font.system(size: 24, weight: .semibold, design: .rounded)
    static let luminaHeadlineMobile = Font.system(size: 20, weight: .semibold, design: .rounded)
    static let luminaBodyLG = Font.system(size: 18, weight: .regular)
    static let luminaBodyMD = Font.system(size: 16, weight: .regular)
    static let luminaLabelMD = Font.system(size: 14, weight: .medium)
    static let luminaLabelSM = Font.system(size: 12, weight: .semibold)
}

struct LuminaSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(.luminaLabelSM)
            .tracking(0.9)
            .foregroundStyle(LuminaColor.secondary)
    }
}
