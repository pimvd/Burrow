import Foundation
import OSLog
import UserNotifications

extension Notification.Name {
    /// Posted when the parent taps the monthly backup reminder.
    static let kidtopiaOpenExportScreen = Notification.Name("kidtopia.openExportScreen")
}

/// Schedules the monthly "make a backup" reminder.
///
/// iCloud sync is automatic and continuous; this reminder is about the extra
/// copy the parent keeps themselves. Nothing is scheduled until they turn it on
/// and grant notification permission.
@MainActor
final class BackupReminderService: NSObject {
    static let shared = BackupReminderService()

    private static let requestIdentifier = "kidtopia.backup.monthly"
    private static let enabledDefaultsKey = "kidtopia.backupReminderEnabled"

    private let logger = Logger(subsystem: "com.pvd.kidtopia", category: "Notifications")
    private let center = UNUserNotificationCenter.current()

    private override init() {
        super.init()
    }

    var isReminderEnabled: Bool {
        UserDefaults.standard.bool(forKey: Self.enabledDefaultsKey)
    }

    /// Makes this service the notification delegate so a tap can open the export
    /// screen directly.
    func registerAsDelegate() {
        center.delegate = self
    }

    func setReminderEnabled(_ enabled: Bool) async {
        UserDefaults.standard.set(enabled, forKey: Self.enabledDefaultsKey)

        guard enabled else {
            center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
            return
        }

        guard await requestAuthorization() else {
            UserDefaults.standard.set(false, forKey: Self.enabledDefaultsKey)
            return
        }
        await scheduleMonthlyReminder()
    }

    /// Re-arms the reminder on launch when the parent enabled it earlier.
    func scheduleMonthlyReminderIfAuthorized() async {
        guard isReminderEnabled else { return }
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
                || settings.authorizationStatus == .provisional else {
            return
        }
        await scheduleMonthlyReminder()
    }

    private func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            logger.error("Notification permission failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    private func scheduleMonthlyReminder() async {
        let content = UNMutableNotificationContent()
        content.title = String(
            localized: "Time for a backup",
            comment: "Monthly backup reminder title"
        )
        content.body = String(
            localized: "Export your profiles and tiles as an extra copy next to iCloud.",
            comment: "Monthly backup reminder body"
        )
        content.sound = .default

        // Day 1 of every month at 10:00 local time.
        var components = DateComponents()
        components.day = 1
        components.hour = 10
        components.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.requestIdentifier,
            content: content,
            trigger: trigger
        )

        center.removePendingNotificationRequests(withIdentifiers: [Self.requestIdentifier])
        do {
            try await center.add(request)
        } catch {
            logger.error("Could not schedule the reminder: \(error.localizedDescription, privacy: .public)")
        }
    }
}

extension BackupReminderService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        Task { @MainActor in
            if identifier == Self.requestIdentifier {
                NotificationCenter.default.post(name: .kidtopiaOpenExportScreen, object: nil)
            }
            completionHandler()
        }
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // A reminder that fires while a child is using the app stays quiet.
        completionHandler([])
    }
}
