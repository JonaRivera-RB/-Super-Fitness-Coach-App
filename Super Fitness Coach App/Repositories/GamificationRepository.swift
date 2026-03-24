//
//  GamificationRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class GamificationRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "GamificationRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func saveState(_ state: GamificationState) throws {
        context.insert(state)
        do {
            try context.save()
        } catch {
            logger.warning("First saveState attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry saveState failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func fetchState() throws -> GamificationState? {
        let descriptor = FetchDescriptor<GamificationState>()
        return try context.fetch(descriptor).first
    }
}
