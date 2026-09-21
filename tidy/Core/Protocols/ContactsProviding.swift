import Foundation
import Contacts

/// Lightweight contact representation for duplicate detection
struct ContactItem: Identifiable, Hashable, Sendable {
    let id: String // CNContact.identifier
    let givenName: String
    let familyName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    let organizationName: String
    let note: String

    var fullName: String {
        [givenName, familyName].filter { !$0.isEmpty }.joined(separator: " ")
    }
}

/// Protocol for contacts access. Enables mocking.
protocol ContactsProviding: Sendable {
    /// Fetch all contacts as lightweight items
    func fetchAllContacts() async throws -> [ContactItem]
    /// Current authorization status
    func authorizationStatus() -> CNAuthorizationStatus
    /// Request contacts authorization
    func requestAuthorization() async -> Bool
}
