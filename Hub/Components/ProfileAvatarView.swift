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
                    Circle().fill(LuminaColor.primary.opacity(0.12))
                    Text(initials)
                        .font(.luminaHeadlineMobile)
                        .foregroundStyle(LuminaColor.primary)
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
    }
}
