import Foundation

/// Protocol for device storage info. Enables mocking for Test Mode.
protocol StorageProviding {
    func getStorageInfo() -> StorageInfo
}
