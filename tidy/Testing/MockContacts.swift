import Foundation
import Contacts

/// A mock contact provider for SwiftUI previews and Test Mode.
struct MockContacts: ContactsProviding {
    let mockContacts: [ContactItem]
    let authorization: CNAuthorizationStatus
    
    init(status: CNAuthorizationStatus = .authorized) {
        self.authorization = status
        
        self.mockContacts = [
            ContactItem(id: "c1", givenName: "Jane", familyName: "Appleseed", phoneNumbers: ["+1 (555) 123-4567"], emailAddresses: ["jane@example.com"], organizationName: "Apple", note: ""),
            // Duplicate of c1 by phone
            ContactItem(id: "c2", givenName: "Jane", familyName: "A.", phoneNumbers: ["5551234567"], emailAddresses: [], organizationName: "", note: "Duplicate"),
            
            ContactItem(id: "c3", givenName: "John", familyName: "Doe", phoneNumbers: ["+44 7700 900077"], emailAddresses: ["john.doe@work.com"], organizationName: "", note: ""),
            // Duplicate of c3 by exact name
            ContactItem(id: "c4", givenName: "John", familyName: "Doe", phoneNumbers: ["+44 800 123 4567"], emailAddresses: [], organizationName: "", note: ""),
            
            ContactItem(id: "c5", givenName: "Kate", familyName: "Bell", phoneNumbers: [], emailAddresses: ["kate@bell.com"], organizationName: "", note: ""),
            // Duplicate of c5 by email
            ContactItem(id: "c6", givenName: "Katie", familyName: "Bell", phoneNumbers: ["+1 555 999 8888"], emailAddresses: ["KATE@BELL.COM"], organizationName: "", note: "")
        ]
    }
    
    func fetchAllContacts() async throws -> [ContactItem] {
        try await Task.sleep(for: .milliseconds(100))
        return mockContacts
    }
    
    func authorizationStatus() -> CNAuthorizationStatus {
        return authorization
    }
    
    func requestAuthorization() async -> Bool {
        return authorization == .authorized
    }
}
