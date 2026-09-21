import Foundation
import Contacts

/// Real implementation of ContactsProviding. Fetches contacts from CNContactStore.
final class ContactService: ContactsProviding {
    private let store = CNContactStore()
    
    // The keys we need to fetch to perform duplicate detection
    private let keysToFetch: [CNKeyDescriptor] = [
        CNContactIdentifierKey as CNKeyDescriptor,
        CNContactGivenNameKey as CNKeyDescriptor,
        CNContactFamilyNameKey as CNKeyDescriptor,
        CNContactPhoneNumbersKey as CNKeyDescriptor,
        CNContactEmailAddressesKey as CNKeyDescriptor,
        CNContactOrganizationNameKey as CNKeyDescriptor,
        CNContactNoteKey as CNKeyDescriptor
    ]
    
    func fetchAllContacts() async throws -> [ContactItem] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var items: [ContactItem] = []
                let request = CNContactFetchRequest(keysToFetch: self.keysToFetch)
                
                do {
                    try self.store.enumerateContacts(with: request) { contact, _ in
                        let phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
                        let emails = contact.emailAddresses.map { String($0.value) }
                        
                        let item = ContactItem(
                            id: contact.identifier,
                            givenName: contact.givenName,
                            familyName: contact.familyName,
                            phoneNumbers: phoneNumbers,
                            emailAddresses: emails,
                            organizationName: contact.organizationName,
                            note: contact.note
                        )
                        items.append(item)
                    }
                    continuation.resume(returning: items)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    func authorizationStatus() -> CNAuthorizationStatus {
        return CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func requestAuthorization() async -> Bool {
        do {
            return try await store.requestAccess(for: .contacts)
        } catch {
            return false
        }
    }
}
