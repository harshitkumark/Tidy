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
    private let photoProvider: PhotoLibraryProviding
    private let contactProvider: ContactsProviding
    
    init(
        storageService: StorageProviding = StorageService(),
        photoProvider: PhotoLibraryProviding = PhotoService(),
        contactProvider: ContactsProviding = ContactService()
    ) {
        self.storageService = storageService
        self.photoProvider = photoProvider
        self.contactProvider = contactProvider
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

        // Start background scans
        Task {
            await scanAllCategories()
        }
    }

    /// Performs real background scans to populate the Dashboard metrics
    private func scanAllCategories() async {
        // We'll update the categories concurrently where possible
        
        async let photos = try? photoProvider.fetchAllPhotos()
        async let videos = try? photoProvider.fetchAllVideos()
        async let contacts = try? contactProvider.fetchAllContacts()
        
        // 1. Screenshots & Large Videos
        if let allPhotos = await photos {
            let screenshots = allPhotos.filter { $0.isScreenshot }
            let screenshotSize = screenshots.reduce(0) { $0 + $1.fileSize }
            updateCategory(id: "screenshots", count: screenshots.count, reclaimable: screenshotSize)
            
            // Similar Photos (Heavy scan)
            // We run this in the background, but only if they have photos
            if !allPhotos.isEmpty {
                let scanner = SimilarPhotosScanner(photoProvider: photoProvider)
                if let groups = try? await scanner.scan(photos: allPhotos, progressHandler: { _, _ in }) {
                    let duplicateItems = groups.flatMap { g in g.items.filter { $0.id != g.bestItemID } }
                    let similarSize = duplicateItems.reduce(0) { $0 + $1.fileSize }
                    updateCategory(id: "similar", count: duplicateItems.count, reclaimable: similarSize, subtitle: "\(groups.count) groups")
                } else {
                    updateCategory(id: "similar", count: 0, reclaimable: 0)
                }
            } else {
                updateCategory(id: "similar", count: 0, reclaimable: 0)
            }
        } else {
            updateCategory(id: "screenshots", count: 0, reclaimable: 0)
            updateCategory(id: "similar", count: 0, reclaimable: 0)
        }
        
        if let allVideos = await videos {
            let largeVideos = allVideos.filter { $0.fileSize >= 50 * 1024 * 1024 }
            let videoSize = largeVideos.reduce(0) { $0 + $1.fileSize }
            updateCategory(id: "videos", count: largeVideos.count, reclaimable: videoSize)
        } else {
            updateCategory(id: "videos", count: 0, reclaimable: 0)
        }
        
        // 2. Contacts
        if let allContacts = await contacts {
            let scanner = DuplicateContactsScanner()
            let duplicateGroups = await scanner.scan(contacts: allContacts)
            let duplicateCount = duplicateGroups.reduce(0) { $0 + ($1.contacts.count - 1) }
            updateCategory(id: "contacts", count: duplicateCount, reclaimable: 0, subtitle: "\(duplicateGroups.count) groups")
        } else {
            updateCategory(id: "contacts", count: 0, reclaimable: 0)
        }
        
        // Finalize Total
        totalReclaimable = categories.compactMap(\.reclaimableSize).reduce(0, +)
    }
    
    private func updateCategory(id: String, count: Int, reclaimable: Int64, subtitle: String? = nil) {
        if let idx = categories.firstIndex(where: { $0.id == id }) {
            categories[idx].count = count
            if reclaimable > 0 { categories[idx].reclaimableSize = reclaimable }
            if let subtitle = subtitle { categories[idx].subtitle = subtitle }
            categories[idx].isLoading = false
        }
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
    case testMode
}
