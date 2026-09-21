import Foundation
import Contacts

#if DEBUG
/// Generates synthetic contacts and saves them to the real Contacts store for testing.
struct ContactSeeder {
    
    func seed() async throws {
        let store = CNContactStore()
        let auth = CNContactStore.authorizationStatus(for: .contacts)
        guard auth == .authorized else {
            throw NSError(domain: "ContactSeeder", code: 1, userInfo: [NSLocalizedDescriptionKey: "Contacts access denied."])
        }
        
        let saveRequest = CNSaveRequest()
        
        // 1. A clean, unique contact
        let c1 = CNMutableContact()
        c1.givenName = "Test_Alice"
        c1.familyName = "Unique"
        c1.organizationName = "TIDY_TEST"
        c1.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0100"))]
        saveRequest.add(c1, toContainerWithIdentifier: nil)
        
        // 2. Exact Duplicates
        let c2 = CNMutableContact()
        c2.givenName = "Test_Bob"
        c2.familyName = "Duplicate"
        c2.organizationName = "TIDY_TEST"
        c2.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0200"))]
        saveRequest.add(c2, toContainerWithIdentifier: nil)
        
        let c3 = c2.mutableCopy() as! CNMutableContact
        saveRequest.add(c3, toContainerWithIdentifier: nil)
        
        // 3. Partial Duplicates (Same Phone, Different Name)
        let c4 = CNMutableContact()
        c4.givenName = "Test_Charlie"
        c4.organizationName = "TIDY_TEST"
        c4.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0300"))]
        saveRequest.add(c4, toContainerWithIdentifier: nil)
        
        let c5 = CNMutableContact()
        c5.givenName = "Test_Charles"
        c5.familyName = "Smith"
        c5.organizationName = "TIDY_TEST"
        c5.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0300"))] // Same phone
        saveRequest.add(c5, toContainerWithIdentifier: nil)
        
        // 4. Partial Duplicates (Same Name, Different Phones)
        let c6 = CNMutableContact()
        c6.givenName = "Test_Dave"
        c6.familyName = "MergeMe"
        c6.organizationName = "TIDY_TEST"
        c6.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberMobile, value: CNPhoneNumber(stringValue: "555-0400"))]
        saveRequest.add(c6, toContainerWithIdentifier: nil)
        
        let c7 = CNMutableContact()
        c7.givenName = "Test_Dave"
        c7.familyName = "MergeMe"
        c7.organizationName = "TIDY_TEST"
        c7.phoneNumbers = [CNLabeledValue(label: CNLabelPhoneNumberHome, value: CNPhoneNumber(stringValue: "555-0401"))]
        c7.emailAddresses = [CNLabeledValue(label: CNLabelWork, value: "dave@example.com")]
        saveRequest.add(c7, toContainerWithIdentifier: nil)
        
        try store.execute(saveRequest)
    }
}
#endif
