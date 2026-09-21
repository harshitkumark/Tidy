import Foundation

/// Lightweight photo metadata. Never holds PHAsset or full-size image data.
struct PhotoItem: Identifiable, Hashable, Sendable {
    let id: String // localIdentifier
    let creationDate: Date?
    let fileSize: Int64 // bytes
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isScreenshot: Bool
    let isInUserAlbum: Bool
    let isOnDevice: Bool

    var pixelCount: Int { pixelWidth * pixelHeight }
    var resolution: String { "\(pixelWidth) × \(pixelHeight)" }
}

/// A group of similar or duplicate photos
struct PhotoGroup: Identifiable, Sendable {
    let id: UUID
    var items: [PhotoItem]
    var bestItemID: String // localIdentifier of the "best" pick

    /// Total size of all non-best items (reclaimable if user keeps the best)
    var reclaimableSize: Int64 {
        items.filter { $0.id != bestItemID }.reduce(0) { $0 + $1.fileSize }
    }

    /// Total size of all items in the group
    var totalSize: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }
}

/// Lightweight video metadata
struct VideoItem: Identifiable, Hashable, Sendable {
    let id: String // localIdentifier
    let creationDate: Date?
    let fileSize: Int64
    let duration: TimeInterval // seconds
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isOnDevice: Bool

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// A group of duplicate contacts
struct ContactGroup: Identifiable, Sendable {
    let id: UUID
    var contacts: [ContactItem]
    var matchReason: String // e.g. "Same phone number"
    var baseContactID: String // the richest contact, used as merge base
}

/// Device storage information
struct StorageInfo: Sendable {
    let totalCapacity: Int64
    let usedCapacity: Int64
    let freeCapacity: Int64

    var usedFraction: Double {
        guard totalCapacity > 0 else { return 0 }
        return Double(usedCapacity) / Double(totalCapacity)
    }
}

/// Items selected for cleanup across all categories, sent to ReviewView
struct CleanupSelection: Sendable {
    var photoIdentifiers: Set<String> = []
    var videoIdentifiers: Set<String> = []
    var contactIdentifiers: Set<String> = [] // for deletion
    var contactMergeGroups: [ContactMergeOperation] = [] // for merging

    var isEmpty: Bool {
        photoIdentifiers.isEmpty && videoIdentifiers.isEmpty &&
        contactIdentifiers.isEmpty && contactMergeGroups.isEmpty
    }

    var totalItemCount: Int {
        photoIdentifiers.count + videoIdentifiers.count +
        contactIdentifiers.count + contactMergeGroups.reduce(0) { $0 + $1.otherIdentifiers.count }
    }
}

/// A contact merge operation: keep base, delete others
struct ContactMergeOperation: Identifiable, Sendable {
    let id: UUID
    let baseIdentifier: String
    let otherIdentifiers: [String]
}
