import Foundation

/// Result of a deletion operation
enum DeletionResult: Sendable {
    case success(deletedCount: Int)
    case partialSuccess(deletedCount: Int, failedCount: Int, message: String)
    case cancelled // User cancelled the system dialog
    case dryRun(wouldDeleteCount: Int) // Test mode: nothing actually deleted
    case failure(message: String)
}

/// Protocol for the deletion service. THE ONLY place that performs deletions.
protocol DeletionProviding {
    /// Delete photo/video assets by their local identifiers
    func deleteAssets(identifiers: [String], isDryRun: Bool) async -> DeletionResult
    /// Delete contacts by their identifiers
    func deleteContacts(identifiers: [String], isDryRun: Bool) async -> DeletionResult
    /// Merge contacts: keep base, delete others, update base with merged fields
    func mergeContacts(baseIdentifier: String, otherIdentifiers: [String], isDryRun: Bool) async -> DeletionResult
}
