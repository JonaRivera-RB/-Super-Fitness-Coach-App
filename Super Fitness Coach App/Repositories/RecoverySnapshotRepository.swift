//  RecoverySnapshotRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class RecoverySnapshotRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "RecoverySnapshotRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func upsertToday(
        recovery: Int,
        activity: Int,
        sleepScore: Int?,
        sleepHours: Double?,
        deepSleepHours: Double?,
        remSleepHours: Double?,
        sleepConsistencyScore: Int?,
        sleepSessionStart: Date?,
        sleepSessionEnd: Date?,
        restingHR: Double?,
        hrv: Double?,
        recoveryConfidenceRaw: String?,
        now: Date = Date()
    ) throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: #Predicate { $0.dayStart == start }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.recoveryScore = recovery
            existing.activityScore = activity
            existing.sleepScore = sleepScore
            existing.sleepHours = sleepHours
            existing.deepSleepHours = deepSleepHours
            existing.remSleepHours = remSleepHours
            existing.sleepConsistencyScore = sleepConsistencyScore
            existing.sleepSessionStart = sleepSessionStart
            existing.sleepSessionEnd = sleepSessionEnd
            existing.restingHR = restingHR
            existing.hrv = hrv
            existing.recoveryConfidenceRaw = recoveryConfidenceRaw
        } else {
            context.insert(
                RecoverySnapshot(
                    dayStart: start,
                    recoveryScore: recovery,
                    activityScore: activity,
                    sleepScore: sleepScore,
                    sleepHours: sleepHours,
                    deepSleepHours: deepSleepHours,
                    remSleepHours: remSleepHours,
                    sleepConsistencyScore: sleepConsistencyScore,
                    sleepSessionStart: sleepSessionStart,
                    sleepSessionEnd: sleepSessionEnd,
                    restingHR: restingHR,
                    hrv: hrv,
                    recoveryConfidenceRaw: recoveryConfidenceRaw
                )
            )
        }

        // Retención: no acumulamos historial infinito en SwiftData.
        try prune(keepingLastDays: 60, now: now)

        try context.save()
        logger.info("upsertToday recovery=\(recovery) activity=\(activity) sleepScore=\(sleepScore ?? -1)")
    }

    private func prune(keepingLastDays: Int, now: Date) throws {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -keepingLastDays, to: cal.startOfDay(for: now)) else { return }
        let descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: #Predicate { $0.dayStart < cutoff }
        )
        let old = try context.fetch(descriptor)
        if old.isEmpty { return }
        old.forEach { context.delete($0) }
        logger.info("prune deleted \(old.count) snapshots older than \(keepingLastDays)d")
    }

    /// Días con datos, más recientes primero, máximo `limit`.
    func fetchRecent(limit: Int, now: Date = Date()) throws -> [RecoverySnapshot] {
        let cal = Calendar.current
        guard let earliest = cal.date(byAdding: .day, value: -60, to: cal.startOfDay(for: now)) else {
            return []
        }
        var descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: #Predicate { $0.dayStart >= earliest },
            sortBy: [SortDescriptor(\.dayStart, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }
}
