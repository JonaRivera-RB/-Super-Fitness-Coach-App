//
//  UserProfileRepository.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

final class UserProfileRepository {
    private let context: ModelContext
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "UserProfileRepository")

    init(context: ModelContext) {
        self.context = context
    }

    func save(_ profile: UserProfile) throws {
        // Only insert if the profile is not already managed by this context
        if profile.modelContext == nil {
            context.insert(profile)
        }
        // Force SwiftData to recognize pending changes
        if context.hasChanges {
            logger.info("save: context has changes, saving...")
        } else {
            logger.warning("save: context has NO changes — SwiftData may not have detected the mutation")
        }
        do {
            try context.save()
            logger.info("save: success")
        } catch {
            logger.error("save failed: \(error.localizedDescription)")
            throw error
        }
    }

    /// Update a specific property on the profile and save immediately.
    /// This works around SwiftData's change detection issues with Codable structs.
    func updateFitnessConfig(_ config: FitnessConfig) throws {
        guard let profile = try fetch() else {
            logger.error("updateFitnessConfig: no profile found")
            return
        }
        // Delete and re-insert to force SwiftData to detect the change
        let name = profile.name
        let goal = profile.fitnessGoal
        let onboarding = profile.onboardingCompleted
        let weight = profile.weightKg
        let height = profile.heightCm
        let unit = profile.unitPreference
        let created = profile.createdAt
        let id = profile.id

        context.delete(profile)
        try context.save()

        let newProfile = UserProfile(name: name, fitnessGoal: goal, weightKg: weight, heightCm: height, unitPreference: unit)
        newProfile.id = id
        newProfile.onboardingCompleted = onboarding
        newProfile.createdAt = created
        newProfile.fitnessConfig = config
        context.insert(newProfile)
        try context.save()
        logger.info("updateFitnessConfig: saved via delete+re-insert")
    }

    func fetch() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>()
        return try context.fetch(descriptor).first
    }
}
