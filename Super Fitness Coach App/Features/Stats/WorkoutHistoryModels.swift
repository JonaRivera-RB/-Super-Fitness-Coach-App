//
//  WorkoutHistoryModels.swift
//  Super Fitness Coach App
//

import Foundation

/// Una sesión deduplicada por ejercicio + día (estado final del día).
struct WorkoutHistoryRow: Identifiable {
    var id: UUID { log.id }
    let log: WorkoutLog
    let exerciseName: String
    let date: Date
    let setsCount: Int
    let volumeText: String
    let bestSetText: String
}

/// Un hito de PR (e1RM estimado Epley supera el mejor previo del mismo ejercicio).
struct PRRecordRow: Identifiable {
    let id: UUID
    let date: Date
    let exerciseName: String
    let headline: String
    let subtitle: String
}

enum WorkoutHistoryAnalyzer {

    static func estimate1RM(weight: Double, reps: Int) -> Double {
        let r = max(1, reps)
        return weight * (1.0 + Double(r) / 30.0)
    }

    static func bestE1RM(in log: WorkoutLog) -> Double {
        log.sets.map { estimate1RM(weight: $0.weight, reps: $0.reps) }.max() ?? 0
    }

    static func totalVolume(_ log: WorkoutLog) -> Double {
        log.sets.reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// Varias filas pueden existir por el mismo día (un guardado por serie); nos quedamos con la que tiene más series.
    static func dedupeLatestPerDay(_ logs: [WorkoutLog]) -> [WorkoutLog] {
        let cal = Calendar.current
        var map: [String: WorkoutLog] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.date)
            let key = "\(log.exerciseId)|\(day.timeIntervalSince1970)"
            if let existing = map[key] {
                if log.sets.count > existing.sets.count {
                    map[key] = log
                } else if log.sets.count == existing.sets.count, log.date > existing.date {
                    map[key] = log
                }
            } else {
                map[key] = log
            }
        }
        return map.values.sorted { $0.date > $1.date }
    }

    static func buildHistoryRows(
        from logs: [WorkoutLog],
        nameForExercise: (String, String?) -> String
    ) -> [WorkoutHistoryRow] {
        let deduped = dedupeLatestPerDay(logs)
        return deduped.map { log in
            let name = nameForExercise(log.exerciseId, log.notes)
            let vol = totalVolume(log)
            let bestSet = log.sets.max(by: { estimate1RM(weight: $0.weight, reps: $0.reps) < estimate1RM(weight: $1.weight, reps: $1.reps) })
            let bestLine: String
            if let b = bestSet {
                bestLine = String(format: "Mejor serie · %.0f kg × %d (≈%.0f kg e1RM)", b.weight, b.reps, estimate1RM(weight: b.weight, reps: b.reps))
            } else {
                bestLine = "—"
            }
            return WorkoutHistoryRow(
                log: log,
                exerciseName: name,
                date: log.date,
                setsCount: log.sets.count,
                volumeText: String(format: "Volumen total · %.0f (suma peso×reps)", vol),
                bestSetText: bestLine
            )
        }
    }

    /// PRs cronológicos: solo cuando el mejor e1RM de la sesión supera el mejor previo del mismo `exerciseId`.
    static func buildPRRows(
        from logs: [WorkoutLog],
        nameForExercise: (String, String?) -> String
    ) -> [PRRecordRow] {
        let deduped = dedupeLatestPerDay(logs)
        let byDate = deduped.sorted { $0.date < $1.date }

        var bestSoFar: [String: Double] = [:]
        var rows: [PRRecordRow] = []

        for log in byDate {
            let eid = log.exerciseId
            let current = bestE1RM(in: log)
            guard current > 0.01 else { continue }

            if let p = bestSoFar[eid] {
                if current > p + 0.01 {
                    let name = nameForExercise(eid, log.notes)
                    let bestSet = log.sets.max(by: { estimate1RM(weight: $0.weight, reps: $0.reps) < estimate1RM(weight: $1.weight, reps: $1.reps) })
                    let setStr: String
                    if let b = bestSet {
                        setStr = String(format: "%.0f kg × %d", b.weight, b.reps)
                    } else {
                        setStr = "—"
                    }
                    let pct = p > 0.01 ? ((current - p) / p) * 100 : 0
                    let sub = String(format: "e1RM %.0f → %.0f kg (+%.0f%%)", p, current, pct)
                    rows.append(PRRecordRow(
                        id: UUID(),
                        date: log.date,
                        exerciseName: name,
                        headline: setStr,
                        subtitle: sub
                    ))
                }
                bestSoFar[eid] = max(p, current)
            } else {
                bestSoFar[eid] = current
            }
        }

        return rows.sorted { $0.date > $1.date }
    }
}
