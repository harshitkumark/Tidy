import SwiftUI

@MainActor
@Observable
final class DuplicateContactsViewModel {
    // MARK: - State
    var groups: [ContactGroup] = []
    
    // We only track the operations the user wants to perform.
    // By default, we queue up a merge operation for every group.
    var operations: [ContactMergeOperation] = []
    
    var isLoading = true
    
    // Output stats
    var selectedCount: Int {
        operations.reduce(0) { $0 + $1.otherIdentifiers.count }
    }
    
    private let contactProvider: ContactsProviding
    private var hasScanned = false
    
    init(contactProvider: ContactsProviding = ContactService()) {
        self.contactProvider = contactProvider
    }
    
    // MARK: - Intents
    
    func load() async {
        guard !hasScanned else { return }
        isLoading = true
        
        do {
            let allContacts = try await contactProvider.fetchAllContacts()
            let scanner = DuplicateContactsScanner()
            self.groups = await scanner.scan(contacts: allContacts)
            
            // By default, prepare a merge operation for every group found
            self.operations = self.groups.map { group in
                let others = group.contacts.filter { $0.id != group.baseContactID }.map(\.id)
                return ContactMergeOperation(id: group.id, baseIdentifier: group.baseContactID, otherIdentifiers: others)
            }
            
            self.hasScanned = true
        } catch {
            Logger.error("Failed to load contacts: \(error)", category: .scan)
        }
        
        isLoading = false
    }
    
    func toggleOperation(for groupID: UUID) {
        if let idx = operations.firstIndex(where: { $0.id == groupID }) {
            operations.remove(at: idx)
        } else if let group = groups.first(where: { $0.id == groupID }) {
            let others = group.contacts.filter { $0.id != group.baseContactID }.map(\.id)
            let op = ContactMergeOperation(id: group.id, baseIdentifier: group.baseContactID, otherIdentifiers: others)
            operations.append(op)
        }
    }
    
    func hasOperation(for groupID: UUID) -> Bool {
        operations.contains { $0.id == groupID }
    }
}
