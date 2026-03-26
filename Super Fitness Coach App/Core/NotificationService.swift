//
//  NotificationService.swift
//  Super Fitness Coach App
//

import Foundation
import UserNotifications
import os

final class NotificationService {
    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "NotificationService")

    static let dailyNotificationIdentifier = "daily-fitness-notification"

    // MARK: - Request Permission

    /// Request notification permission. Returns true if granted.
    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            if !granted {
                logger.info("Notification permission denied by user")
            }
            return granted
        } catch {
            logger.error("Failed to request notification permission: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Schedule Daily Notification

    /// Schedule a daily notification at 8:00 AM local time with the recovery score, status emoji, and recommendation.
    /// Removes all pending notifications first to ensure exactly one is scheduled.
    func scheduleDailyNotification(
        recoveryScore: Int,
        statusEmoji: String,
        recommendation: String
    ) async {
        // Remove existing notifications before scheduling a new one
        center.removeAllPendingNotificationRequests()

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            logger.info("Notifications not authorized, skipping schedule")
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Tu coach"
        content.body = "Recuperación hoy: \(recoveryScore) \(statusEmoji). \(recommendation)"
        content.sound = .default

        var dateComponents = DateComponents()
        dateComponents.hour = 8
        dateComponents.minute = 0

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)

        let request = UNNotificationRequest(
            identifier: Self.dailyNotificationIdentifier,
            content: content,
            trigger: trigger
        )

        do {
            try await center.add(request)
            logger.info("Daily notification scheduled at 8:00 AM")
        } catch {
            logger.error("Failed to schedule notification: \(error.localizedDescription)")
        }
    }

    // MARK: - Cancel All

    /// Remove all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    /// Estado actual de autorización (para mostrar en Perfil sin pulsar de nuevo).
    func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
