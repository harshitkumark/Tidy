import SwiftUI

/// Dashboard view model: storage info + category card data
@MainActor
@Observable
final class DashboardViewModel {
    var storageInfo: StorageInfo?
    var categories: [CategoryCardData] = []
    var isLoading = true
    var totalReclaimable: Int64 = 0

    private let storageService: StorageProviding

    init(storageService: StorageProviding = StorageService()) {
        self.storageService = storageService
    }

    func load() {
        // Storage info
        storageInfo = storageService.getStorageInfo()

        // For now, use placeholder data for categories.
        // Steps 5-9 will plug in real scan results.
        categories = [
            CategoryCardData(
                id: "similar",
                title: "Similar Photos",
                icon: "photo.on.rectangle.angled",
                iconColor: Theme.Colors.mint,
                subtitle: nil,
                reclaimableSize: nil,
                count: nil,
                isLoading: true,
                permissionNeeded: false,
                destination: .similarPhotos
            ),
            CategoryCardData(
                id: "screenshots",
                title: "Screenshots",
                icon: "camera.viewfinder",
                iconColor: .blue,
                subtitle: nil,
                reclaimableSize: nil,
                count: nil,
                isLoading: true,
                permissionNeeded: false,
                destination: .screenshots
            ),
            CategoryCardData(
                id: "videos",
                title: "Large Videos",
                icon: "video.fill",
                iconColor: .purple,
                subtitle: nil,
                reclaimableSize: nil,
                count: nil,
                isLoading: true,
                permissionNeeded: false,
                destination: .largeVideos
            ),
            CategoryCardData(
                id: "contacts",
                title: "Duplicate Contacts",
                icon: "person.2.fill",
                iconColor: .orange,
                subtitle: nil,
                reclaimableSize: nil,
                count: nil,
                isLoading: true,
                permissionNeeded: false,
                destination: .duplicateContacts
            ),
        ]

        isLoading = false

        // Simulate scan completing after a delay (mock data for now)
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            updateWithMockData()
        }
    }

    /// Temporary mock data — will be replaced with real scan results
    private func updateWithMockData() {
        if let idx = categories.firstIndex(where: { $0.id == "similar" }) {
            categories[idx].reclaimableSize = 1_450_000_000
            categories[idx].count = 23
            categories[idx].subtitle = "23 groups"
            categories[idx].isLoading = false
        }
        if let idx = categories.firstIndex(where: { $0.id == "screenshots" }) {
            categories[idx].reclaimableSize = 340_000_000
            categories[idx].count = 156
            categories[idx].subtitle = "156 screenshots"
            categories[idx].isLoading = false
        }
        if let idx = categories.firstIndex(where: { $0.id == "videos" }) {
            categories[idx].reclaimableSize = 2_100_000_000
            categories[idx].count = 8
            categories[idx].subtitle = "8 videos"
            categories[idx].isLoading = false
        }
        if let idx = categories.firstIndex(where: { $0.id == "contacts" }) {
            categories[idx].count = 12
            categories[idx].subtitle = "12 duplicates"
            categories[idx].isLoading = false
        }

        totalReclaimable = categories.compactMap(\.reclaimableSize).reduce(0, +)
    }

    func updatePermissionStates(photoStatus: PermissionStatus, contactStatus: PermissionStatus) {
        if let idx = categories.firstIndex(where: { $0.id == "similar" }) {
            categories[idx].permissionNeeded = !photoStatus.isGranted && photoStatus != .notDetermined
        }
        if let idx = categories.firstIndex(where: { $0.id == "screenshots" }) {
            categories[idx].permissionNeeded = !photoStatus.isGranted && photoStatus != .notDetermined
        }
        if let idx = categories.firstIndex(where: { $0.id == "videos" }) {
            categories[idx].permissionNeeded = !photoStatus.isGranted && photoStatus != .notDetermined
        }
        if let idx = categories.firstIndex(where: { $0.id == "contacts" }) {
            categories[idx].permissionNeeded = !contactStatus.isGranted && contactStatus != .notDetermined
        }
    }

    func refresh() {
        storageInfo = storageService.getStorageInfo()
    }
}

// MARK: - Category Card Data

struct CategoryCardData: Identifiable {
    let id: String
    let title: String
    let icon: String
    let iconColor: Color
    var subtitle: String?
    var reclaimableSize: Int64?
    var count: Int?
    var isLoading: Bool
    var permissionNeeded: Bool
    let destination: DashboardDestination
}

enum DashboardDestination {
    case similarPhotos
    case screenshots
    case largeVideos
    case duplicateContacts
}
