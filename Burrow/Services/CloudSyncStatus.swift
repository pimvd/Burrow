import CloudKit
import CoreData
import Foundation
import Observation
import OSLog

/// What Burrow can honestly tell the parent about iCloud.
///
/// Two different mechanisms carry a family's data and the export screen explains
/// both. CloudKit mirrors the profiles, tiles and playlist entries continuously,
/// which is what this type reports on. The audio and video files themselves live
/// in `Documents/Media` and travel only in the device's own iCloud backup or in
/// an export, so they are never part of `lastSyncDate`.
@Observable
@MainActor
final class CloudSyncStatus {
    enum State: Equatable {
        /// Mirroring is on and iCloud accepted the most recent change.
        case synced
        /// Mirroring is on, but nothing has come back from iCloud yet.
        case waiting
        /// Mirroring is on and the last attempt failed.
        case failed
        /// No usable iCloud account, so nothing leaves this device.
        case noAccount
        /// The store could not be opened against CloudKit at all.
        case localOnly
    }

    static let containerIdentifier = "iCloud.com.pvd.burrow"

    private(set) var state: State = .waiting
    /// End of the last successful exchange with iCloud, kept across launches so
    /// the screen is not blank before the first sync of the session.
    private(set) var lastSyncDate: Date?

    private static let lastSyncDefaultsKey = "burrow.cloud.lastSyncDate"

    @ObservationIgnored private let logger = Logger(subsystem: "com.pvd.burrow", category: "CloudSync")
    @ObservationIgnored private var eventObserver: NSObjectProtocol?

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: Self.lastSyncDefaultsKey) as? Date

        guard ModelContainerFactory.isCloudBacked else {
            state = .localOnly
            return
        }

        state = lastSyncDate == nil ? .waiting : .synced
        observeMirroringEvents()
    }

    deinit {
        if let eventObserver {
            NotificationCenter.default.removeObserver(eventObserver)
        }
    }

    /// Re-checks the iCloud account. Cheap enough to call every time the export
    /// screen appears, and it is the only way to notice a parent signing out.
    func refresh() async {
        guard ModelContainerFactory.isCloudBacked else {
            state = .localOnly
            return
        }

        do {
            let status = try await CKContainer(identifier: Self.containerIdentifier).accountStatus()
            switch status {
            case .available:
                // Leave a failure standing; only a later successful event clears
                // it. Otherwise a healthy account would mask a broken sync.
                if state == .noAccount {
                    state = lastSyncDate == nil ? .waiting : .synced
                }
            case .noAccount, .restricted, .couldNotDetermine, .temporarilyUnavailable:
                state = .noAccount
            @unknown default:
                state = .noAccount
            }
        } catch {
            logger.error("Could not read the iCloud account status: \(error.localizedDescription, privacy: .public)")
            state = .noAccount
        }
    }

    /// SwiftData mirrors through `NSPersistentCloudKitContainer`, which posts an
    /// event whenever a setup, import or export finishes.
    private func observeMirroringEvents() {
        eventObserver = NotificationCenter.default.addObserver(
            forName: NSPersistentCloudKitContainer.eventChangedNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let key = NSPersistentCloudKitContainer.eventNotificationUserInfoKey
            guard let event = notification.userInfo?[key] as? NSPersistentCloudKitContainer.Event else {
                return
            }
            MainActor.assumeIsolated {
                self?.handle(event)
            }
        }
    }

    private func handle(_ event: NSPersistentCloudKitContainer.Event) {
        // An event without an end date is still running.
        guard let endDate = event.endDate else { return }

        guard event.succeeded else {
            logger.error("iCloud \(String(describing: event.type), privacy: .public) failed: \(event.error?.localizedDescription ?? "unknown", privacy: .public)")
            state = .failed
            return
        }

        state = .synced

        // Setup finishing says the connection works, not that data moved, so it
        // does not count as a sync the parent should read a time off.
        guard event.type == .import || event.type == .export else { return }
        lastSyncDate = endDate
        UserDefaults.standard.set(endDate, forKey: Self.lastSyncDefaultsKey)
    }
}
