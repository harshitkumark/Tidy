import Foundation

/// Reads device storage capacity using URLResourceValues.
/// Note: On simulator this returns the Mac's disk, not an iPhone's.
struct StorageService: StorageProviding {
    func getStorageInfo() -> StorageInfo {
        let url = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try url.resourceValues(forKeys: [
                .volumeTotalCapacityKey,
                .volumeAvailableCapacityForImportantUsageKey
            ])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacityForImportantUsage ?? 0)
            let used = max(total - free, 0)
            return StorageInfo(totalCapacity: total, usedCapacity: used, freeCapacity: free)
        } catch {
            Logger.error("Failed to read storage info: \(error.localizedDescription)", category: .general)
            return StorageInfo(totalCapacity: 0, usedCapacity: 0, freeCapacity: 0)
        }
    }
}
