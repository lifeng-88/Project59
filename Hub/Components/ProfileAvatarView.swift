import SwiftUI

struct ProfileAvatarView: View {
    let image: UIImage?
    let initials: String
    var size: CGFloat = 52

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    LuminaColor.primaryFixed,
                                    LuminaColor.primaryFixedDim.opacity(0.6)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text(initials)
                        .font(.system(size: size * 0.32, weight: .semibold, design: .rounded))
                        .foregroundStyle(LuminaColor.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(
            Circle()
                .strokeBorder(LuminaColor.primary.opacity(0.18), lineWidth: 2)
        )
    }
}
