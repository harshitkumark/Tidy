import SwiftUI

@MainActor
@Observable
final class ReviewViewModel {
    
    // MARK: - State
    var isProcessing = false
    var progressMessage = ""
    var errorMessages: [String] = []
    
    // Summary of what will be deleted
    var photoCount: Int = 0
    var videoCount: Int = 0
    var contactDeleteCount: Int = 0
    var contactMergeCount: Int = 0
    
    var totalItemCount: Int {
        photoCount + videoCount + contactDeleteCount + contactMergeCount
    }
    
    // Results
    var isFinished = false
    var successfullyDeletedPhotos = 0
    var successfullyDeletedVideos = 0
    var successfullyMergedContacts = 0
    var successfullyDeletedContacts = 0 // from merges
    
    private let deletionProvider: DeletionProviding
    
    init(deletionProvider: DeletionProviding = DeletionService()) {
        self.deletionProvider = deletionProvider
    }
    
    func prepare(with selection: CleanupSelection) {
        photoCount = selection.photoIdentifiers.count
        videoCount = selection.videoIdentifiers.count
        contactDeleteCount = selection.contactIdentifiers.count
        contactMergeCount = selection.contactMergeGroups.count
    }
    
    func executeDeletion(selection: CleanupSelection, isDryRun: Bool, onComplete: @escaping (Int, Int64) -> Void) async {
        guard !isProcessing else { return }
        isProcessing = true
        errorMessages.removeAll()
        
        var totalDeletedItems = 0
        var totalBytesFreed: Int64 = 0 // We don't accurately know this unless we pass the full items in, but we can just say "Items deleted" for now, or update app state.
        
        // 1. Photos
        if !selection.photoIdentifiers.isEmpty {
            progressMessage = "Deleting \(selection.photoIdentifiers.count) photos..."
            let result = await deletionProvider.deleteAssets(identifiers: Array(selection.photoIdentifiers), isDryRun: isDryRun)
            handleResult(result, for: "Photos", deletedCount: &successfullyDeletedPhotos, totalCount: &totalDeletedItems)
        }
        
        // 2. Videos
        if !selection.videoIdentifiers.isEmpty {
            progressMessage = "Deleting \(selection.videoIdentifiers.count) videos..."
            let result = await deletionProvider.deleteAssets(identifiers: Array(selection.videoIdentifiers), isDryRun: isDryRun)
            handleResult(result, for: "Videos", deletedCount: &successfullyDeletedVideos, totalCount: &totalDeletedItems)
        }
        
        // 3. Contacts (Merges)
        if !selection.contactMergeGroups.isEmpty {
            progressMessage = "Merging \(selection.contactMergeGroups.count) contact groups..."
            for group in selection.contactMergeGroups {
                let result = await deletionProvider.mergeContacts(
                    baseIdentifier: group.baseIdentifier,
                    otherIdentifiers: group.otherIdentifiers,
                    isDryRun: isDryRun
                )
                
                switch result {
                case .success(let count), .partialSuccess(let count, _, _):
                    successfullyMergedContacts += 1
                    successfullyDeletedContacts += count
                    totalDeletedItems += count
                case .dryRun(let count):
                    successfullyMergedContacts += 1
                    successfullyDeletedContacts += count
                    totalDeletedItems += count
                case .failure(let msg):
                    errorMessages.append("Contact Merge Failed: \(msg)")
                case .cancelled:
                    break
                }
            }
        }
        
        isProcessing = false
        isFinished = true
        
        // Notify caller to update global AppState
        onComplete(totalDeletedItems, 0)
    }
    
    private func handleResult(_ result: DeletionResult, for category: String, deletedCount: inout Int, totalCount: inout Int) {
        switch result {
        case .success(let count):
            deletedCount += count
            totalCount += count
        case .partialSuccess(let count, let failed, let msg):
            deletedCount += count
            totalCount += count
            errorMessages.append("\(category): \(count) deleted, \(failed) failed. (\(msg))")
        case .dryRun(let count):
            deletedCount += count
            totalCount += count
            errorMessages.append("DRY RUN: Would have deleted \(count) \(category.lowercased())")
        case .failure(let msg):
            errorMessages.append("\(category) Deletion Failed: \(msg)")
        case .cancelled:
            errorMessages.append("\(category) Deletion Cancelled by user.")
        }
    }
}
