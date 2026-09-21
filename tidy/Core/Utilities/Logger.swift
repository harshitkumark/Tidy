import Foundation
import os.log

/// Lightweight logger using os.log. No third-party dependencies.
enum Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.tidy"

    private static let general = os.Logger(subsystem: subsystem, category: "general")
    private static let scan = os.Logger(subsystem: subsystem, category: "scan")
    private static let deletion = os.Logger(subsystem: subsystem, category: "deletion")
    private static let permissions = os.Logger(subsystem: subsystem, category: "permissions")
    private static let performance = os.Logger(subsystem: subsystem, category: "performance")

    static func info(_ message: String, category: Category = .general) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func debug(_ message: String, category: Category = .general) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    static func warning(_ message: String, category: Category = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    static func error(_ message: String, category: Category = .general) {
        logger(for: category).error("\(message, privacy: .public)")
    }

    enum Category {
        case general, scan, deletion, permissions, performance
    }

    private static func logger(for category: Category) -> os.Logger {
        switch category {
        case .general: return general
        case .scan: return scan
        case .deletion: return deletion
        case .permissions: return permissions
        case .performance: return performance
        }
    }
}
