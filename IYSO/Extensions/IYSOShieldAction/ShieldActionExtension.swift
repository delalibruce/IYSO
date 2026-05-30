import Foundation
import ManagedSettings
import UserNotifications

private enum IYSOShieldShared {
    static let appGroupID = "group.app.iyso"
    static let openCameraRequestKey = "com.delali.digicam.openCameraOnActivate"
}

final class ShieldActionExtension: ShieldActionDelegate {
    private func markOpenCameraRequest() {
        UserDefaults(suiteName: IYSOShieldShared.appGroupID)?
            .set(true, forKey: IYSOShieldShared.openCameraRequestKey)
    }

    private func deliverReturnNotification() {
        let content = UNMutableNotificationContent()
        content.title = "Return to IYSO"
        content.body = "Tap to keep shooting."
        content.sound = .default
        content.userInfo = ["iysoDeepLink": "iyso://camera"]

        let request = UNNotificationRequest(
            identifier: "iyso.returnFromShield.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 0.05, repeats: false)
        )
        UNUserNotificationCenter.current().add(request)
    }

    private func handlePrimary(completionHandler: @escaping (ShieldActionResponse) -> Void) {
        markOpenCameraRequest()
        deliverReturnNotification()
        completionHandler(.close)
    }

    override func handle(
        action: ShieldAction,
        for application: ApplicationToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handlePrimary(completionHandler: completionHandler)
        default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for category: ActivityCategoryToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handlePrimary(completionHandler: completionHandler)
        default:
            completionHandler(.close)
        }
    }

    override func handle(
        action: ShieldAction,
        for webDomain: WebDomainToken,
        completionHandler: @escaping (ShieldActionResponse) -> Void
    ) {
        switch action {
        case .primaryButtonPressed:
            handlePrimary(completionHandler: completionHandler)
        default:
            completionHandler(.close)
        }
    }
}
