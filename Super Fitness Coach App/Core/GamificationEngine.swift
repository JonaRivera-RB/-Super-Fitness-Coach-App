//
//  GamificationEngine.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class GamificationEngine {
    private(set) var totalPoints: Int = 0
    private(set) var currentLevel: Int = 1
    private(set) var currentStreak: Int = 0
    private(set) var personalBestStreak: Int = 0
    private(set) var badges: [Badge] = []
    private(set) var workoutsCompleted: Int = 0
    private(set) var detoxDaysCompleted: Int = 0
    /// Último día en que se **contó** un entreno para la racha (un solo incremento por día calendario).
    private(set) var lastStreakWorkoutDay: Date?

    private let repository: GamificationRepository
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "GamificationEngine")

    init(repository: GamificationRepository) {
        self.repository = repository
        loadState()
    }

    // MARK: - Points

    static func pointsForAction(_ action: PointAction) -> Int {
        switch action {
        case .workoutCompleted: return 20
        case .workoutStarted:  return 10
        case .goodSleep:       return 10
        case .detoxDay:        return 15
        case .detoxComplete:   return 100
        }
    }

    func awardPoints(_ points: Int, for action: PointAction) {
        totalPoints += points

        if action == .workoutCompleted {
            workoutsCompleted += 1
        }
        if action == .detoxDay || action == .detoxComplete {
            if action == .detoxDay {
                detoxDaysCompleted += 1
            }
        }

        currentLevel = Self.calculateLevel(totalPoints: totalPoints)
        persistState()
    }

    // MARK: - Level

    static func calculateLevel(totalPoints: Int) -> Int {
        guard totalPoints > 0 else { return 1 }
        let pts = Double(totalPoints)
        let level = Int(floor((sqrt(1.0 + 8.0 * pts / 100.0) - 1.0) / 2.0) + 1.0)
        return min(max(level, 1), 100)
    }

    // MARK: - Streaks

    /// “Medianoche” configurable: damos margen tras las 00:00 para cerrar el día.
    /// Regla producto: el día cuenta hasta las 00:30 (hora local).
    private static let streakDayGraceMinutes: Int = 30

    /// Inicio del “día de racha” para una fecha dada. Se calcula restando el margen y usando startOfDay.
    /// Ej.: con margen 30m, el bloque del martes va de mar 00:30 → mié 00:29.
    private func streakDayStart(for date: Date, calendar: Calendar = .current) -> Date {
        let grace = TimeInterval(Self.streakDayGraceMinutes * 60)
        return calendar.startOfDay(for: date.addingTimeInterval(-grace))
    }

    /// Actualiza la racha de **días consecutivos con al menos un entreno** (no un incremento por cada entreno el mismo día).
    func updateStreak(hasActionToday: Bool) {
        if hasActionToday {
            let calendar = Calendar.current
            let now = Date()
            let todayStart = streakDayStart(for: now, calendar: calendar)

            if let last = lastStreakWorkoutDay {
                let lastStart = streakDayStart(for: last, calendar: calendar)
                if lastStart == todayStart {
                    // Ya se contó la racha por otro entreno hoy (p. ej. Mi rutina + plan guiado).
                    return
                }
                if let yesterday = calendar.date(byAdding: .day, value: -1, to: todayStart),
                   lastStart == yesterday {
                    currentStreak += 1
                } else {
                    // Más de un día sin contar: nueva racha desde hoy.
                    currentStreak = 1
                }
            } else {
                // Sin fecha persistida (primera vez o migración): asegurar al menos 1; si ya había racha guardada, no sumar de golpe.
                if currentStreak < 1 {
                    currentStreak = 1
                }
            }

            lastStreakWorkoutDay = now
            if currentStreak > personalBestStreak {
                personalBestStreak = currentStreak
            }
        } else {
            if currentStreak > personalBestStreak {
                personalBestStreak = currentStreak
            }
            currentStreak = 0
            lastStreakWorkoutDay = nil
        }
        persistState()
    }

    /// Si el último entreno que contó para la racha fue **hace 2+ días calendario**, la racha se pierde (no basta con abrir feedback).
    /// Llamar al arrancar y al refrescar pantallas que muestran la racha.
    func invalidateStaleStreakIfNeeded(calendar: Calendar = .current) {
        guard let last = lastStreakWorkoutDay else {
            // Sin fecha de último entreno no puede haber racha > 0 (estado incoherente p. ej. migración o persistencia).
            if currentStreak > 0 {
                currentStreak = 0
                persistState()
            }
            return
        }
        let todayStart = streakDayStart(for: Date(), calendar: calendar)
        let lastStart = streakDayStart(for: last, calendar: calendar)
        guard let dayCount = calendar.dateComponents([.day], from: lastStart, to: todayStart).day else {
            return
        }
        // 0 = mismo día, 1 = ayer (aún puedes entrenar hoy), ≥2 = saltaste al menos un día → racha rota
        if dayCount >= 2 {
            currentStreak = 0
            lastStreakWorkoutDay = nil
            persistState()
        }
    }

    /// Racha para mostrar en UI: devuelve la racha vigente y se auto-resetea cuando ya venció el plazo del día
    /// (con margen `streakDayGraceMinutes`).
    func displayedStreak(calendar: Calendar = .current, reference: Date = Date()) -> Int {
        // Asegura que si el usuario no entrenó en el “día de racha” requerido, la UI ya muestre 0.
        invalidateStaleStreakIfNeeded(calendar: calendar)
        return currentStreak
    }

    // MARK: - Badges

    func checkBadges() -> [Badge] {
        var newBadges: [Badge] = []
        for milestone in BadgeMilestone.allCases {
            let alreadyEarned = badges.contains { $0.id == milestone.rawValue }
            if !alreadyEarned && Self.isMilestoneReached(
                milestone: milestone,
                totalPoints: totalPoints,
                currentStreak: currentStreak,
                workoutsCompleted: workoutsCompleted,
                detoxDaysCompleted: detoxDaysCompleted,
                currentLevel: currentLevel
            ) {
                let badge = Badge(id: milestone.rawValue, name: milestone.rawValue, earnedAt: Date())
                badges.append(badge)
                newBadges.append(badge)
            }
        }
        if !newBadges.isEmpty {
            persistState()
        }
        return newBadges
    }

    static func isMilestoneReached(
        milestone: BadgeMilestone,
        totalPoints: Int,
        currentStreak: Int,
        workoutsCompleted: Int,
        detoxDaysCompleted: Int,
        currentLevel: Int
    ) -> Bool {
        switch milestone {
        case .sevenDaysNoAlcohol:
            return detoxDaysCompleted >= 7
        case .fiveConsecutiveWorkouts:
            return currentStreak >= 5
        case .firstWorkout:
            return workoutsCompleted >= 1
        case .levelTenReached:
            return currentLevel >= 10
        case .thirtyDayStreak:
            return currentStreak >= 30
        }
    }

    // MARK: - Persistence

    private func loadState() {
        do {
            if let state = try repository.fetchState() {
                totalPoints = state.totalPoints
                currentLevel = state.currentLevel
                currentStreak = state.currentStreak
                personalBestStreak = state.personalBestStreak
                badges = state.badges
                workoutsCompleted = state.workoutsCompleted
                detoxDaysCompleted = state.detoxDaysCompleted
                lastStreakWorkoutDay = state.lastActionDate
            }
            invalidateStaleStreakIfNeeded()
        } catch {
            logger.error("Failed to load gamification state: \(error.localizedDescription)")
        }
    }

    private func persistState() {
        do {
            if let state = try repository.fetchState() {
                state.totalPoints = totalPoints
                state.currentLevel = currentLevel
                state.currentStreak = currentStreak
                state.personalBestStreak = personalBestStreak
                state.badges = badges
                state.workoutsCompleted = workoutsCompleted
                state.detoxDaysCompleted = detoxDaysCompleted
                state.lastActionDate = lastStreakWorkoutDay
                try repository.saveState(state)
            } else {
                let state = GamificationState()
                state.totalPoints = totalPoints
                state.currentLevel = currentLevel
                state.currentStreak = currentStreak
                state.personalBestStreak = personalBestStreak
                state.badges = badges
                state.workoutsCompleted = workoutsCompleted
                state.detoxDaysCompleted = detoxDaysCompleted
                state.lastActionDate = lastStreakWorkoutDay
                try repository.saveState(state)
            }
        } catch {
            logger.error("Failed to persist gamification state: \(error.localizedDescription)")
        }
    }
}
