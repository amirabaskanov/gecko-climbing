import Foundation
import Observation
import UIKit
import UserNotifications
import FirebaseMessaging

@MainActor
@Observable
final class NotificationService: NSObject {
    @MainActor static weak var shared: NotificationService?

    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var fcmToken: String?

    private let userRepository: any UserRepositoryProtocol
    private let authRepository: any AuthRepositoryProtocol

    init(
        userRepository: any UserRepositoryProtocol,
        authRepository: any AuthRepositoryProtocol
    ) {
        self.userRepository = userRepository
        self.authRepository = authRepository
        super.init()
    }

    func refreshAuthorizationStatus() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        authorizationStatus = settings.authorizationStatus
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            await refreshAuthorizationStatus()
            if granted {
                UIApplication.shared.registerForRemoteNotifications()
            }
            return granted
        } catch {
            #if DEBUG
            print("[NotificationService] requestAuthorization error: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    private func uploadFCMToken(_ token: String) async {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { return }
        do {
            try await userRepository.registerFCMToken(token, for: uid)
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to upload FCM token: \(error.localizedDescription)")
            #endif
        }
    }

    // MARK: - Local Reminders

    private enum LocalReminderID {
        static let weeklyRecap = "weekly-recap"
        static let dormantComeback = "dormant-comeback"
    }

    func refreshScheduledNotifications() async {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else {
            await cancelAllLocalReminders()
            return
        }
        await syncTimeZone(for: uid)
        let remindersEnabled: Bool
        do {
            let prefs = try await userRepository.fetchNotificationPrefs(for: uid)
            remindersEnabled = prefs.reminders
        } catch {
            remindersEnabled = false
        }
        guard remindersEnabled else {
            await cancelAllLocalReminders()
            return
        }
        await scheduleWeeklyRecap(for: uid)
        await rescheduleDormantComeback(for: uid)
    }

    private func syncTimeZone(for userId: String) async {
        do {
            try await userRepository.updateTimeZone(TimeZone.current.identifier, for: userId)
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to sync timezone: \(error.localizedDescription)")
            #endif
        }
    }

    func cancelAllLocalReminders() async {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [LocalReminderID.weeklyRecap, LocalReminderID.dormantComeback]
        )
    }

    private func scheduleWeeklyRecap(for userId: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [LocalReminderID.weeklyRecap])

        let content = UNMutableNotificationContent()
        content.title = "Your week is in"
        content.body = "See how your climbing shaped up."
        content.sound = .default
        content.userInfo = ["route": "weekly-recap"]

        var components = DateComponents()
        components.weekday = 1 // Sunday
        components.hour = 11
        components.minute = 0
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)

        let request = UNNotificationRequest(
            identifier: LocalReminderID.weeklyRecap,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to schedule weekly recap: \(error.localizedDescription)")
            #endif
        }
    }

    private func rescheduleDormantComeback(for userId: String) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [LocalReminderID.dormantComeback])

        let content = UNMutableNotificationContent()
        content.title = "Your gym misses you"
        content.body = "It's been two weeks since your last session."
        content.sound = .default
        content.userInfo = ["route": "profile:\(userId)"]

        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: 14 * 24 * 60 * 60,
            repeats: false
        )

        let request = UNNotificationRequest(
            identifier: LocalReminderID.dormantComeback,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            #if DEBUG
            print("[NotificationService] Failed to schedule dormant comeback: \(error.localizedDescription)")
            #endif
        }
    }
}

extension NotificationService: MessagingDelegate {
    nonisolated func messaging(
        _ messaging: Messaging,
        didReceiveRegistrationToken fcmToken: String?
    ) {
        guard let fcmToken else { return }
        Task { @MainActor in
            self.fcmToken = fcmToken
            await self.uploadFCMToken(fcmToken)
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let userInfo = response.notification.request.content.userInfo
        guard let route = NotificationRoute(userInfo: userInfo) else { return }
        await MainActor.run {
            DeepLinkRouter.shared?.setPendingRoute(route)
        }
    }
}
