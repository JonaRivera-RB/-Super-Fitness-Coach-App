//
//  DetoxRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class DetoxRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "DetoxRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func saveProgress(_ progress: DetoxProgress) throws {
        context.insert(progress)
        do {
            try context.save()
        } catch {
            logger.warning("First saveProgress attempt failed, retrying: \(error.localizedDescription)")
            do {
                try context.save()
            } catch {
                logger.error("Retry saveProgress failed: \(error.localizedDescription)")
                throw error
            }
        }
    }

    func fetchActiveChallenge() throws -> DetoxProgress? {
        let descriptor = FetchDescriptor<DetoxProgress>(
            predicate: #Predicate<DetoxProgress> { progress in
                progress.isActive == true
            }
        )
        return try context.fetch(descriptor).first
    }
}
