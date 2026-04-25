import UIKit
import FirebaseMessaging
import UserNotifications

final class GeckoAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        MainActor.assumeIsolated {
            if let service = NotificationService.shared {
                UNUserNotificationCenter.current().delegate = service
                Messaging.messaging().delegate = service
            }
        }
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("[GeckoAppDelegate] Failed to register for remote notifications: \(error.localizedDescription)")
        #endif
    }
}
