//
//  TerminalNotificationService.swift
//  sora
//

import AppKit
import Foundation
import UserNotifications

/// Delivers terminal notification requests through macOS Notification Center.
/// Authorization is intentionally deferred until a terminal first asks to
/// notify, rather than prompting at app launch. Each request carries the
/// emitting session's id so a click can reveal that tab.
final class TerminalNotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = TerminalNotificationService()

    static let sessionIDKey = "sessionID"

    private let center = UNUserNotificationCenter.current()
    private var isRequestingAuthorization = false
    private var pending: (message: String, sessionID: UUID?)?

    func configure() {
        center.delegate = self
    }

    func post(message: String, sessionID: UUID? = nil) {
        guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        DispatchQueue.main.async { [weak self] in
            self?.checkAuthorization(for: message, sessionID: sessionID)
        }
    }

    private func checkAuthorization(for message: String, sessionID: UUID?) {
        center.getNotificationSettings { [weak self] settings in
            DispatchQueue.main.async {
                self?.handle(
                    settings.authorizationStatus,
                    message: message,
                    sessionID: sessionID
                )
            }
        }
    }

    private func handle(_ status: UNAuthorizationStatus, message: String, sessionID: UUID?) {
        switch status {
        case .authorized, .provisional:
            deliver(message, sessionID: sessionID)
        case .notDetermined:
            // A terminal can emit repeatedly while the permission sheet is
            // open. Keep only the latest request rather than releasing a storm.
            pending = (message, sessionID)
            guard !isRequestingAuthorization else { return }

            isRequestingAuthorization = true
            center.requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isRequestingAuthorization = false

                    let pending = self.pending
                    self.pending = nil

                    if let error {
                        NSLog("Sora: notification authorization failed: %@", String(describing: error))
                    }
                    if granted, let pending {
                        self.deliver(pending.message, sessionID: pending.sessionID)
                    }
                }
            }
        case .denied:
            break
        @unknown default:
            break
        }
    }

    private func deliver(_ message: String, sessionID: UUID?) {
        let content = UNMutableNotificationContent()
        content.title = "Sora"
        content.body = message
        content.sound = .default
        if let sessionID {
            content.userInfo = [Self.sessionIDKey: sessionID.uuidString]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        center.add(request) { error in
            if let error {
                NSLog("Sora: terminal notification failed: %@", String(describing: error))
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let sessionID = (response.notification.request.content.userInfo[Self.sessionIDKey] as? String)
            .flatMap(UUID.init(uuidString:))
        DispatchQueue.main.async {
            if let sessionID {
                TerminalManager.revealSession(id: sessionID)
            } else {
                NSApp.activate()
            }
            completionHandler()
        }
    }
}
