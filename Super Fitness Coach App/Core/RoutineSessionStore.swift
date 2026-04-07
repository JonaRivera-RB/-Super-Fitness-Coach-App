//
//  RoutineSessionStore.swift
//  Super Fitness Coach App
//

import Foundation

/// Persistencia de `sessionId` para «Mi rutina»: una sesión por rutina y día calendario.
/// Extraído para poder testear cambio de día sin depender del reloj real.
enum RoutineSessionStore {
    /// Clave en UserDefaults (misma que usa `ContentView` al completar).
    static func storageKey(routineId: UUID, calendarDay: Date, calendar: Calendar) -> String {
        let start = calendar.startOfDay(for: calendarDay)
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = calendar.timeZone
        return "routineSession|\(routineId.uuidString)|\(df.string(from: start))"
    }

    static func loadOrCreateSessionId(
        routineId: UUID,
        referenceDate: Date = Date(),
        calendar: Calendar = .current,
        defaults: UserDefaults = .standard
    ) -> (sessionId: String, storageKey: String) {
        let key = storageKey(routineId: routineId, calendarDay: referenceDate, calendar: calendar)
        if let existing = defaults.string(forKey: key), !existing.isEmpty {
            return (existing, key)
        }
        let newId = UUID().uuidString
        defaults.set(newId, forKey: key)
        return (newId, key)
    }
}
