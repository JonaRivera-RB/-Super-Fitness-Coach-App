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
    /// Notificación one-shot cuando ya hay datos de recuperación de hoy (sustituye al recordatorio fijo a las 8:00).
    static let recoveryDataReadyNotificationIdentifier = "recovery-data-ready"
    static let restTimerNotificationIdentifier = "rest-timer-finished"
    private static let lastRecoveryDataReadyNotifiedDayKey = "com.superfitnesscoach.lastRecoveryDataReadyNotifiedDayStart"

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

    // MARK: - Recovery data ready (after sleep sync / wake)

    /// Emite un recordatorio local **una vez por día** cuando los datos de recuperación de hoy ya son fiables
    /// (misma noción de “hoy listo” que en Home: sesión de sueño + confianza media/alta + score).
    /// Dispara a ~1 s (no a las 8:00) y deja de programar notificaciones repetitivas a hora fija.
    func scheduleRecoveryDataReadyIfNeeded(recoveryScore: Int) async {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        if let prev = UserDefaults.standard.object(forKey: Self.lastRecoveryDataReadyNotifiedDayKey) as? TimeInterval {
            let prevDay = Date(timeIntervalSince1970: prev)
            if cal.isDate(prevDay, inSameDayAs: todayStart) {
                return
            }
        }

        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized else {
            logger.info("Notifications not authorized, skipping data-ready")
            return
        }

        // Quitar notificación antigua a las 8:00 (repetitiva) y cualquier one-shot duplicada del nuevo tipo.
        center.removePendingNotificationRequests(withIdentifiers: [
            Self.dailyNotificationIdentifier,
            Self.recoveryDataReadyNotificationIdentifier
        ])

        let lang = AppLanguage.current
        let emoji = recoveryScore < 40 ? "🔴" : recoveryScore < 70 ? "🟡" : "🟢"
        let tip = Self.recommendationLine(recoveryScore: recoveryScore, language: lang)
        let content = UNMutableNotificationContent()
        content.title = lang.notificationRecoveryDataReadyTitle
        content.body = lang.notificationRecoveryDataReadyBody(score: recoveryScore, emoji: emoji, tip: tip)
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.recoveryDataReadyNotificationIdentifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
            UserDefaults.standard.set(todayStart.timeIntervalSince1970, forKey: Self.lastRecoveryDataReadyNotifiedDayKey)
            logger.info("Recovery data ready notification scheduled (one-shot) score=\(recoveryScore)")
        } catch {
            logger.error("Failed to schedule data-ready notification: \(error.localizedDescription)")
        }
    }

    private static func recommendationLine(recoveryScore: Int, language: AppLanguage) -> String {
        switch language {
        case .spanish:
            switch recoveryScore {
            case ..<40: return "Prioriza descanso y movilidad suave."
            case 40..<70: return "Intensidad moderada encaja bien con tu recuperación de hoy."
            default: return "Buena recuperación para entrenar según tu plan."
            }
        case .english:
            switch recoveryScore {
            case ..<40: return "Prioritize rest and light mobility."
            case 40..<70: return "Moderate intensity fits today’s recovery."
            default: return "Good recovery—train as planned."
            }
        }
    }

    // MARK: - Cancel All

    /// Remove all pending notifications.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }

    // MARK: - Rest timer notification (Workout)

    func scheduleRestTimerFinishedNotification(
        fireAt date: Date,
        exerciseName: String?,
        restSeconds: Int
    ) async {
        let settings = await center.notificationSettings()
        if settings.authorizationStatus != .authorized {
            let granted = await requestPermission()
            guard granted else { return }
        }

        let restText: String = {
            if restSeconds <= 0 { return "" }
            if restSeconds < 60 { return "\(restSeconds)s" }
            let m = restSeconds / 60
            let s = restSeconds % 60
            return s == 0 ? "\(m)m" : "\(m)m \(s)s"
        }()

        let content = UNMutableNotificationContent()
        content.title = "Descanso listo"
        if let exerciseName, !exerciseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            content.body = "Siguiente serie: \(exerciseName)\(restText.isEmpty ? "" : " (\(restText))")"
        } else {
            content.body = "Ya puedes hacer tu siguiente serie.\(restText.isEmpty ? "" : " (\(restText))")"
        }
        content.subtitle = "Tu Coach"
        content.sound = .default

        let seconds = max(1, date.timeIntervalSinceNow)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: seconds, repeats: false)
        let request = UNNotificationRequest(
            identifier: Self.restTimerNotificationIdentifier,
            content: content,
            trigger: trigger
        )
        do {
            try await center.add(request)
        } catch {
            logger.error("Failed to schedule rest timer notification: \(error.localizedDescription)")
        }
    }

    func cancelRestTimerNotification() {
        center.removePendingNotificationRequests(withIdentifiers: [Self.restTimerNotificationIdentifier])
    }

    /// Estado actual de autorización (para mostrar en Perfil sin pulsar de nuevo).
    func authorizationGranted() async -> Bool {
        let settings = await center.notificationSettings()
        return settings.authorizationStatus == .authorized
    }
}
