import Foundation

/// Analyzes a list of contacts to find duplicates based on name, phone, or email.
struct DuplicateContactsScanner: Sendable {
    
    /// Scans the provided contacts and returns grouped duplicates.
    func scan(contacts: [ContactItem]) async -> [ContactGroup] {
        var groups: [ContactGroup] = []
        var processedIDs = Set<String>()
        
        // Helper to normalize phone numbers for comparison
        let normalizePhone = { (phone: String) -> String in
            phone.components(separatedBy: CharacterSet.decimalDigits.inverted).joined()
        }
        
        // Helper to normalize emails
        let normalizeEmail = { (email: String) -> String in
            email.trimmingCharacters(in: .whitespaces).lowercased()
        }
        
        for i in 0..<contacts.count {
            let source = contacts[i]
            if processedIDs.contains(source.id) { continue }
            
            var duplicates: [ContactItem] = [source]
            var matchReasons: Set<String> = []
            processedIDs.insert(source.id)
            
            let sourcePhones = Set(source.phoneNumbers.map(normalizePhone).filter { !$0.isEmpty })
            let sourceEmails = Set(source.emailAddresses.map(normalizeEmail).filter { !$0.isEmpty })
            
            for j in (i + 1)..<contacts.count {
                let target = contacts[j]
                if processedIDs.contains(target.id) { continue }
                
                var isDuplicate = false
                
                // 1. Check exact name match (if both have names)
                let nameMatch = !source.fullName.isEmpty && source.fullName.lowercased() == target.fullName.lowercased()
                if nameMatch {
                    isDuplicate = true
                    matchReasons.insert("Same Name")
                }
                
                // 2. Check phone number overlap
                let targetPhones = Set(target.phoneNumbers.map(normalizePhone).filter { !$0.isEmpty })
                if !sourcePhones.isDisjoint(with: targetPhones) {
                    isDuplicate = true
                    matchReasons.insert("Same Phone")
                }
                
                // 3. Check email overlap
                let targetEmails = Set(target.emailAddresses.map(normalizeEmail).filter { !$0.isEmpty })
                if !sourceEmails.isDisjoint(with: targetEmails) {
                    isDuplicate = true
                    matchReasons.insert("Same Email")
                }
                
                if isDuplicate {
                    duplicates.append(target)
                    processedIDs.insert(target.id)
                }
            }
            
            if duplicates.count > 1 {
                // Determine the "base" contact to merge into (the one with the most information)
                let baseContact = determineBaseContact(in: duplicates)
                let reason = matchReasons.isEmpty ? "Possible Duplicate" : matchReasons.joined(separator: " & ")
                
                let group = ContactGroup(
                    id: UUID(),
                    contacts: duplicates,
                    matchReason: reason,
                    baseContactID: baseContact.id
                )
                groups.append(group)
            }
        }
        
        // Sort groups by name of the base contact
        return groups.sorted { $0.contacts.first?.fullName ?? "" < $1.contacts.first?.fullName ?? "" }
    }
    
    private func determineBaseContact(in contacts: [ContactItem]) -> ContactItem {
        guard let first = contacts.first else { fatalError("Empty contact list") }
        
        return contacts.max { a, b in
            // Score based on how many fields are populated
            let scoreA = score(for: a)
            let scoreB = score(for: b)
            
            if scoreA != scoreB {
                return scoreA < scoreB
            }
            return a.id < b.id // Deterministic tie-breaker
        } ?? first
    }
    
    private func score(for contact: ContactItem) -> Int {
        var score = 0
        if !contact.givenName.isEmpty { score += 1 }
        if !contact.familyName.isEmpty { score += 1 }
        if !contact.organizationName.isEmpty { score += 1 }
        score += contact.phoneNumbers.count * 2
        score += contact.emailAddresses.count * 2
        return score
    }
}
