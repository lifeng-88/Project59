import PhotosUI
import SwiftUI

struct ProfileEditView: View {
    @EnvironmentObject private var store: TaskStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.hubLanguage) private var language

    @State private var name: String = ""
    @State private var email: String = ""
    @State private var avatarImage: UIImage?
    @State private var removeAvatar = false
    @State private var photoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: LuminaSpacing.stackMD) {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            ProfileAvatarView(
                                image: displayAvatar,
                                initials: store.userInitials,
                                size: 88
                            )
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(LuminaColor.onPrimary)
                                    .padding(6)
                                    .background(LuminaColor.primary)
                                    .clipShape(Circle())
                            }
                        }
                        .buttonStyle(.plain)

                        if displayAvatar != nil {
                            Button(L10n.tr(.profileRemoveAvatar, language: language), role: .destructive) {
                                avatarImage = nil
                                removeAvatar = true
                                photoItem = nil
                            }
                            .font(.luminaLabelMD)
                        }
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section(L10n.tr(.profileBasicInfo, language: language)) {
                TextField(L10n.tr(.profileName, language: language), text: $name)
                    .textContentType(.name)
                TextField(L10n.tr(.profileEmail, language: language), text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
            }
        }
        .scrollContentBackground(.hidden)
        .background(LuminaColor.surface)
        .navigationTitle(L10n.tr(.profileEditTitle, language: language))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(L10n.tr(.commonCancel, language: language)) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(L10n.tr(.commonSave, language: language)) {
                    store.updateProfile(
                        name: name,
                        email: email,
                        avatar: removeAvatar ? nil : avatarImage,
                        removeAvatar: removeAvatar
                    )
                    dismiss()
                }
                .fontWeight(.semibold)
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            name = store.userName
            email = store.userEmail
            avatarImage = store.profileAvatarImage
        }
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        avatarImage = image
                        removeAvatar = false
                    }
                }
            }
        }
    }

    private var displayAvatar: UIImage? {
        if removeAvatar { return nil }
        return avatarImage ?? store.profileAvatarImage
    }
}
