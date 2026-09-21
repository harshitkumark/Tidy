import Foundation
import EventKit

/// Protocol for calendar access. Enables mocking.
protocol CalendarProviding: Sendable {
    /// Fetch past events older than the given date
    func fetchPastEvents(olderThan date: Date) async throws -> [CalendarEvent]
    /// Current authorization status
    func authorizationStatus() -> EKAuthorizationStatus
    /// Request calendar authorization (iOS 17 full access)
    func requestFullAccess() async -> Bool
}

/// Lightweight calendar event representation
struct CalendarEvent: Identifiable, Hashable, Sendable {
    let id: String // EKEvent.eventIdentifier
    let title: String
    let startDate: Date
    let endDate: Date
    let calendarName: String
    let isAllDay: Bool
}
