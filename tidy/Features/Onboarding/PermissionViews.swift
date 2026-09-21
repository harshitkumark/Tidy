import SwiftUI
import PhotosUI

/// Banner shown when Photos access is limited.
/// Shows count of shared photos + buttons to manage or open Settings.
struct LimitedAccessBanner: View {
    let photoCount: Int
    let onManage: () -> Void
    let onOpenSettings: () -> Void

    var body: some View {
        VStack(spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)

                Text("You've shared \(photoCount) photos with tidy")
                    .font(Theme.Typography.caption())
                    .foregroundStyle(Theme.Colors.ink)

                Spacer()
            }

            HStack(spacing: Theme.Spacing.sm) {
                Button(action: onManage) {
                    Text("Select More Photos")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.mint)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.mint.opacity(0.12))
                        .clipShape(Capsule())
                }

                Button(action: onOpenSettings) {
                    Text("Allow All in Settings")
                        .font(.caption.bold())
                        .foregroundStyle(Theme.Colors.inkSecondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.Colors.ink.opacity(0.06))
                        .clipShape(Capsule())
                }

                Spacer()
            }
        }
        .padding(Theme.Spacing.sm + 4)
        .background(Color.orange.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
    }
}

/// Empty state shown when a feature requires a permission that was denied or restricted.
struct PermissionDeniedView: View {
    let permissionType: String // "Photos", "Contacts", "Calendar"
    let icon: String
    let onOpenSettings: () -> Void

    var body: some View {
        EmptyStateView(
            icon: icon,
            title: "\(permissionType) Access Needed",
            message: "tidy needs access to your \(permissionType.lowercased()) to help you find duplicates. You can enable this in Settings.",
            actionTitle: "Open Settings",
            action: onOpenSettings
        )
    }
}

// MARK: - Limited Library Picker Helper

/// Wrapper to present the system limited library picker
struct LimitedLibraryPickerButton: View {
    @State private var showingPicker = false

    var body: some View {
        Button("Select More Photos") {
            showingPicker = true
        }
        .sheet(isPresented: $showingPicker) {
            LimitedLibraryPickerRepresentable()
        }
    }
}

/// UIViewControllerRepresentable for PHPicker in limited mode
struct LimitedLibraryPickerRepresentable: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let controller = UIViewController()
        // Present the limited library picker on next run loop
        DispatchQueue.main.async {
            PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: controller)
        }
        return controller
    }

    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - Previews

#Preview("Limited Access Banner") {
    LimitedAccessBanner(
        photoCount: 23,
        onManage: {},
        onOpenSettings: {}
    )
    .padding()
}

#Preview("Permission Denied - Photos") {
    PermissionDeniedView(
        permissionType: "Photos",
        icon: "photo.on.rectangle.angled",
        onOpenSettings: {}
    )
}

#Preview("Permission Denied - Contacts") {
    PermissionDeniedView(
        permissionType: "Contacts",
        icon: "person.2",
        onOpenSettings: {}
    )
}
