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

    func upsertToday(recovery: Int, activity: Int, now: Date = Date()) throws {
        let cal = Calendar.current
        let start = cal.startOfDay(for: now)
        let descriptor = FetchDescriptor<RecoverySnapshot>(
            predicate: #Predicate { $0.dayStart == start }
        )
        if let existing = try context.fetch(descriptor).first {
            existing.recoveryScore = recovery
            existing.activityScore = activity
        } else {
            context.insert(RecoverySnapshot(dayStart: start, recoveryScore: recovery, activityScore: activity))
        }
        try context.save()
        logger.info("upsertToday recovery=\(recovery) activity=\(activity)")
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
