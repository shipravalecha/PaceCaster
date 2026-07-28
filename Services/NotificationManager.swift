//
//  NotificationManager.swift
//  PaceCaster
//
//  Created by Shipra Valecha on 7/22/26.
//


import Foundation
import UserNotifications
import Combine

@MainActor
final class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    static let weeklyRecapIdentifier = "weeklyRecap"

    @Published var authorizationGranted = false
    @Published var pendingDeepLinkToRecap = false

    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let current = await center.notificationSettings()
        switch current.authorizationStatus {
        case .authorized, .provisional:
            authorizationGranted = true
        case .notDetermined:
            let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
            authorizationGranted = granted
        default:
            authorizationGranted = false
        }
    }

    /// Safe to call repeatedly — replaces any existing pending request with the same identifier.
    func scheduleWeeklyRecap(weekday: Int = 1, hour: Int = 18, minute: Int = 0) {
        let content = UNMutableNotificationContent()
        content.title = "Your Weekly Recap is ready"
        content.body = "See how your training went this week."
        content.sound = .default

        var components = DateComponents()
        components.weekday = weekday   // 1 = Sunday, 2 = Monday, ... 7 = Saturday
        components.hour = hour
        components.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: Self.weeklyRecapIdentifier, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    func cancelWeeklyRecap() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.weeklyRecapIdentifier])
    }
    
    func sendMilestoneNotification(type: MilestoneType, value: Double) {
        let content = UNMutableNotificationContent()
        content.title = type.notificationTitle
        content.body = milestoneBody(for: type, value: value)
        content.sound = .default

        let request = UNNotificationRequest(identifier: "milestone-\(UUID().uuidString)", content: content, trigger: nil) // nil trigger = fires immediately
        UNUserNotificationCenter.current().add(request)
    }

    private func milestoneBody(for type: MilestoneType, value: Double) -> String {
        switch type {
        case .bestEF:
            return String(format: "Your Aerobic Baseline just hit %.2f — your best yet.", value)
        case .bestRunScore:
            return "You just posted a Run Score of \(Int(value)) — your highest yet."
        case .longestRun:
            let miles = value / 1609.344
            return String(format: "You just ran %.1f miles — your longest run yet.", miles)
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             didReceive response: UNNotificationResponse) async {
        guard response.notification.request.identifier == NotificationManager.weeklyRecapIdentifier else { return }
        await MainActor.run {
            NotificationManager.shared.pendingDeepLinkToRecap = true
        }
    }
}
