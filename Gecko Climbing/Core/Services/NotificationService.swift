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
            print("[NotificationService] requestAuthorization error: \(error.localizedDescription)")
            return false
        }
    }

    private func uploadFCMToken(_ token: String) async {
        let uid = authRepository.currentUserId
        guard !uid.isEmpty else { return }
        do {
            try await userRepository.registerFCMToken(token, for: uid)
        } catch {
            print("[NotificationService] Failed to upload FCM token: \(error.localizedDescription)")
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
