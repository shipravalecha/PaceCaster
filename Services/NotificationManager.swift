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
    static let countdownIdentifierPrefix = "goalRaceCountdown-"

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

    // Safe to call repeatedly - replaces any existing pending request with the same identifier.
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
            return String(format: "Your Aerobic Baseline just hit %.2f - your best yet.", value)
        case .bestRunScore:
            return "You just posted a Run Score of \(Int(value)) - your highest yet."
        case .longestRun:
            let miles = value / 1609.344
            return String(format: "You just ran %.1f miles - your longest run yet.", miles)
        }
    }

    // Schedules daily 7am countdown notifications for the final 7 days before a goal race.
    // Cancels and replaces any previously scheduled countdown notifications.
    func scheduleGoalRaceCountdown(raceDate: Date, raceLabel: String) {
        cancelGoalRaceCountdown()

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let raceDay = calendar.startOfDay(for: raceDate)

        guard raceDay >= today else { return } // race already passed, nothing to schedule

        let daysUntilRace = calendar.dateComponents([.day], from: today, to: raceDay).day ?? 0
        let windowStart = max(0, daysUntilRace - 7)

        // Schedule one notification per day from 7 days out through race day itself.
        for offset in windowStart...daysUntilRace {
            guard let fireDate = calendar.date(byAdding: .day, value: offset, to: today) else { continue }
            let daysRemaining = daysUntilRace - offset
            guard daysRemaining >= 0 else { continue }

            // Don't schedule a notification for a time that's already passed today.
            var fireComponents = calendar.dateComponents([.year, .month, .day], from: fireDate)
            fireComponents.hour = 7
            fireComponents.minute = 0
            guard let candidateDate = calendar.date(from: fireComponents), candidateDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            if daysRemaining == 0 {
                content.title = "🏁 Race Day!"
                content.body = "Good luck on your \(raceLabel) today."
            } else {
                content.title = "🏁 \(daysRemaining) day\(daysRemaining == 1 ? "" : "s") to your \(raceLabel)"
                content.body = "Your training block is almost done - stay sharp."
            }
            content.sound = .default

            var triggerComponents = DateComponents()
            triggerComponents.year = fireComponents.year
            triggerComponents.month = fireComponents.month
            triggerComponents.day = fireComponents.day
            triggerComponents.hour = 7
            triggerComponents.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: triggerComponents, repeats: false)
            let identifier = "\(Self.countdownIdentifierPrefix)\(offset)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        }
    }

    func cancelGoalRaceCountdown() {
        UNUserNotificationCenter.current().getPendingNotificationRequests { requests in
            let idsToCancel = requests
                .map { $0.identifier }
                .filter { $0.hasPrefix(Self.countdownIdentifierPrefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: idsToCancel)
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             willPresent notification: UNNotification,
                                             withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                             didReceive response: UNNotificationResponse,
                                             withCompletionHandler completionHandler: @escaping () -> Void) {
        let identifier = response.notification.request.identifier
        DispatchQueue.main.async {
            if identifier == NotificationManager.weeklyRecapIdentifier {
                NotificationManager.shared.pendingDeepLinkToRecap = true
            }
            // Milestone notifications (identifier starts with "milestone-") currently
            // have no deep link - tapping them just opens the app normally, which is fine.
            completionHandler()
        }
    }
}
