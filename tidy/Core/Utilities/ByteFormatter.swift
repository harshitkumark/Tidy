import Foundation

/// Human-readable file size formatting
enum ByteFormatter {
    static func format(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: bytes)
    }

    /// Short format: "1.4 GB" instead of "1.4 gigabytes"
    static func formatShort(_ bytes: Int64) -> String {
        let absBytes = abs(bytes)
        switch absBytes {
        case 0..<1_024:
            return "\(bytes) B"
        case 1_024..<1_048_576:
            return String(format: "%.1f KB", Double(bytes) / 1_024)
        case 1_048_576..<1_073_741_824:
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        default:
            return String(format: "%.2f GB", Double(bytes) / 1_073_741_824)
        }
    }
}
