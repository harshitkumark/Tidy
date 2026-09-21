import Foundation
import Photos
import Contacts

/// Handles the actual physical deletion of assets and contacts from the system.
/// Implements dry-run safety for Test Mode.
actor DeletionService: DeletionProviding {
    
    // MARK: - Photos & Videos
    
    func deleteAssets(identifiers: [String], isDryRun: Bool) async -> DeletionResult {
        guard !identifiers.isEmpty else { return .success(deletedCount: 0) }
        
        if isDryRun {
            Logger.info("DRY RUN: Would delete \(identifiers.count) photo/video assets", category: .deletion)
            try? await Task.sleep(for: .seconds(1)) // Simulate work
            return .dryRun(wouldDeleteCount: identifiers.count)
        }
        
        let fetchOptions = PHFetchOptions()
        let assetsToDelete = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: fetchOptions)
        
        guard assetsToDelete.count > 0 else {
            return .failure(message: "Could not find any of the requested assets in the library.")
        }
        
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(assetsToDelete)
            }
            Logger.info("Successfully deleted \(assetsToDelete.count) assets", category: .deletion)
            return .success(deletedCount: assetsToDelete.count)
        } catch {
            let nsError = error as NSError
            // Check if user cancelled the system prompt
            if nsError.domain == "com.apple.photos.error" && nsError.code == 3072 { // 3072 is often UserCancelled
                return .cancelled
            }
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError {
                return .cancelled
            }
            Logger.error("Failed to delete assets: \(error.localizedDescription)", category: .deletion)
            return .failure(message: error.localizedDescription)
        }
    }
    
    // MARK: - Contacts (Deletion)
    
    func deleteContacts(identifiers: [String], isDryRun: Bool) async -> DeletionResult {
        guard !identifiers.isEmpty else { return .success(deletedCount: 0) }
        
        if isDryRun {
            Logger.info("DRY RUN: Would delete \(identifiers.count) contacts", category: .deletion)
            try? await Task.sleep(for: .seconds(1))
            return .dryRun(wouldDeleteCount: identifiers.count)
        }
        
        let store = CNContactStore()
        let request = CNSaveRequest()
        
        var foundCount = 0
        for id in identifiers {
            do {
                let contact = try store.unifiedContact(withIdentifier: id, keysToFetch: [])
                if let mutable = contact.mutableCopy() as? CNMutableContact {
                    request.delete(mutable)
                    foundCount += 1
                }
            } catch {
                Logger.warning("Could not find contact \(id) for deletion", category: .deletion)
            }
        }
        
        guard foundCount > 0 else {
            return .failure(message: "None of the requested contacts could be found.")
        }
        
        do {
            try store.execute(request)
            Logger.info("Successfully deleted \(foundCount) contacts", category: .deletion)
            return .success(deletedCount: foundCount)
        } catch {
            Logger.error("Failed to execute contact deletion: \(error.localizedDescription)", category: .deletion)
            return .failure(message: error.localizedDescription)
        }
    }
    
    // MARK: - Contacts (Merge)
    
    func mergeContacts(baseIdentifier: String, otherIdentifiers: [String], isDryRun: Bool) async -> DeletionResult {
        guard !otherIdentifiers.isEmpty else { return .success(deletedCount: 0) }
        
        if isDryRun {
            Logger.info("DRY RUN: Would merge \(otherIdentifiers.count) contacts into \(baseIdentifier)", category: .deletion)
            try? await Task.sleep(for: .seconds(1))
            return .dryRun(wouldDeleteCount: otherIdentifiers.count)
        }
        
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor,
            CNContactOrganizationNameKey as CNKeyDescriptor,
            CNContactNoteKey as CNKeyDescriptor
        ]
        
        do {
            let baseContact = try store.unifiedContact(withIdentifier: baseIdentifier, keysToFetch: keys)
            guard let mutableBase = baseContact.mutableCopy() as? CNMutableContact else {
                return .failure(message: "Failed to make base contact mutable.")
            }
            
            var existingPhones = Set(mutableBase.phoneNumbers.map { $0.value.stringValue })
            var existingEmails = Set(mutableBase.emailAddresses.map { String($0.value) })
            
            let request = CNSaveRequest()
            var deletedCount = 0
            
            for otherID in otherIdentifiers {
                guard let otherContact = try? store.unifiedContact(withIdentifier: otherID, keysToFetch: keys) else { continue }
                
                // Merge Phones
                for phone in otherContact.phoneNumbers {
                    if !existingPhones.contains(phone.value.stringValue) {
                        mutableBase.phoneNumbers.append(phone)
                        existingPhones.insert(phone.value.stringValue)
                    }
                }
                
                // Merge Emails
                for email in otherContact.emailAddresses {
                    if !existingEmails.contains(String(email.value)) {
                        mutableBase.emailAddresses.append(email)
                        existingEmails.insert(String(email.value))
                    }
                }
                
                // Merge name parts if missing
                if mutableBase.givenName.isEmpty && !otherContact.givenName.isEmpty { mutableBase.givenName = otherContact.givenName }
                if mutableBase.familyName.isEmpty && !otherContact.familyName.isEmpty { mutableBase.familyName = otherContact.familyName }
                if mutableBase.organizationName.isEmpty && !otherContact.organizationName.isEmpty { mutableBase.organizationName = otherContact.organizationName }
                
                // Queue deletion of the merged duplicate
                if let mutableOther = otherContact.mutableCopy() as? CNMutableContact {
                    request.delete(mutableOther)
                    deletedCount += 1
                }
            }
            
            // Queue update for base contact
            request.update(mutableBase)
            
            try store.execute(request)
            Logger.info("Successfully merged \(deletedCount) contacts into \(baseIdentifier)", category: .deletion)
            return .success(deletedCount: deletedCount)
            
        } catch {
            Logger.error("Failed to merge contacts: \(error.localizedDescription)", category: .deletion)
            return .failure(message: error.localizedDescription)
        }
    }
}
