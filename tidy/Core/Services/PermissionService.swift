import Foundation
import Photos
import Contacts
import EventKit
import SwiftUI

/// Centralized permission service for Photos, Contacts, and Calendar.
/// Publishes observable status per permission type.
@MainActor
@Observable
final class PermissionService {
    // MARK: - Permission States

    var photoStatus: PermissionStatus = .notDetermined
    var contactStatus: PermissionStatus = .notDetermined
    var calendarStatus: PermissionStatus = .notDetermined

    /// Number of photos visible to the app (relevant for limited access)
    var limitedPhotoCount: Int = 0

    // MARK: - DEBUG: Permission Simulator
    #if DEBUG
    var simulatedPhotoStatus: SimulatedPermission = .none
    var simulatedContactStatus: SimulatedPermission = .none
    var simulatedCalendarStatus: SimulatedPermission = .none
    #endif

    private let photoLibraryObserver = PhotoLibraryChangeObserver()

    init() {
        refreshAllStatuses()
        setupLibraryObserver()
    }

    // MARK: - Refresh

    func refreshAllStatuses() {
        refreshPhotoStatus()
        refreshContactStatus()
        refreshCalendarStatus()
    }

    func refreshPhotoStatus() {
        #if DEBUG
        if simulatedPhotoStatus != .none {
            photoStatus = simulatedPhotoStatus.toPermissionStatus
            if photoStatus == .limited {
                limitedPhotoCount = 23 // mock count
            }
            return
        }
        #endif

        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        photoStatus = PermissionStatus.from(phStatus: status)

        if photoStatus == .limited || photoStatus == .authorized {
            let fetchResult = PHAsset.fetchAssets(with: nil)
            limitedPhotoCount = fetchResult.count
        }
    }

    func refreshContactStatus() {
        #if DEBUG
        if simulatedContactStatus != .none {
            contactStatus = simulatedContactStatus.toPermissionStatus
            return
        }
        #endif

        let status = CNContactStore.authorizationStatus(for: .contacts)
        contactStatus = PermissionStatus.from(cnStatus: status)
    }

    func refreshCalendarStatus() {
        #if DEBUG
        if simulatedCalendarStatus != .none {
            calendarStatus = simulatedCalendarStatus.toPermissionStatus
            return
        }
        #endif

        let status = EKEventStore.authorizationStatus(for: .event)
        calendarStatus = PermissionStatus.from(ekStatus: status)
    }

    // MARK: - Request Permissions

    func requestPhotoAccess() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        photoStatus = PermissionStatus.from(phStatus: status)
        if photoStatus == .limited || photoStatus == .authorized {
            let fetchResult = PHAsset.fetchAssets(with: nil)
            limitedPhotoCount = fetchResult.count
        }
    }

    func requestContactAccess() async {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            contactStatus = granted ? .authorized : .denied
        } catch {
            Logger.error("Contact permission error: \(error.localizedDescription)", category: .permissions)
            contactStatus = .denied
        }
    }

    func requestCalendarAccess() async {
        let store = EKEventStore()
        do {
            let granted = try await store.requestFullAccessToEvents()
            calendarStatus = granted ? .authorized : .denied
        } catch {
            Logger.error("Calendar permission error: \(error.localizedDescription)", category: .permissions)
            calendarStatus = .denied
        }
    }

    // MARK: - Helpers

    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    // MARK: - Library Observer

    private func setupLibraryObserver() {
        photoLibraryObserver.onChange = { [weak self] in
            Task { @MainActor in
                self?.refreshPhotoStatus()
            }
        }
    }

    /// Call when app returns to foreground to detect permission changes
    func handleScenePhaseActive() {
        refreshAllStatuses()
    }
}

// MARK: - Permission Status Enum

enum PermissionStatus: String, Sendable {
    case notDetermined
    case authorized
    case limited    // Photos only
    case denied
    case restricted

    var isGranted: Bool {
        self == .authorized || self == .limited
    }

    static func from(phStatus: PHAuthorizationStatus) -> PermissionStatus {
        switch phStatus {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .limited: return .limited
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func from(cnStatus: CNAuthorizationStatus) -> PermissionStatus {
        switch cnStatus {
        case .notDetermined: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        @unknown default: return .denied
        }
    }

    static func from(ekStatus: EKAuthorizationStatus) -> PermissionStatus {
        switch ekStatus {
        case .notDetermined: return .notDetermined
        case .fullAccess: return .authorized
        case .denied: return .denied
        case .restricted: return .restricted
        case .writeOnly: return .limited
        @unknown default: return .denied
        }
    }
}

// MARK: - Simulated Permission Helpers

#if DEBUG
extension SimulatedPermission {
    var toPermissionStatus: PermissionStatus {
        switch self {
        case .none: return .notDetermined
        case .authorized: return .authorized
        case .denied: return .denied
        case .limited: return .limited
        case .restricted: return .restricted
        }
    }
}
#endif

// MARK: - PHPhotoLibraryChangeObserver

final class PhotoLibraryChangeObserver: NSObject, PHPhotoLibraryChangeObserver, Sendable {
    // Use nonisolated(unsafe) since PHPhotoLibraryChangeObserver callback is on arbitrary queue
    nonisolated(unsafe) var onChange: (() -> Void)?

    override init() {
        super.init()
        // Only register if we have at least limited access
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status == .authorized || status == .limited {
            PHPhotoLibrary.shared().register(self)
        }
    }

    deinit {
        PHPhotoLibrary.shared().unregister(self)
    }

    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        onChange?()
    }
}
