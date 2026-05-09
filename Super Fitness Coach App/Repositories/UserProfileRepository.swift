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
        // SwiftData sometimes reports no changes even after mutations (notably with Codable structs).
        // This log is informational; we still attempt save to be safe.
        if context.hasChanges {
            logger.info("save: context has changes, saving...")
        } else {
            logger.info("save: context has NO changes (may be a no-op)")
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
        try updateFitnessConfig(profileId: profile.id, config: config)
    }

    /// Same as `updateFitnessConfig(_:)` but deterministic: updates by profile id.
    func updateFitnessConfig(profileId: UUID, config: FitnessConfig) throws {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { p in
                p.id == profileId
            }
        )
        guard let profile = try context.fetch(descriptor).first else {
            logger.error("updateFitnessConfig(profileId:): profile not found")
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
        var descriptor = FetchDescriptor<UserProfile>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first
    }

    /// Returns the most recent profile that has completed onboarding, if any.
    func fetchCompleted() throws -> UserProfile? {
        let descriptor = FetchDescriptor<UserProfile>(
            predicate: #Predicate<UserProfile> { p in
                p.onboardingCompleted == true
            },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try context.fetch(descriptor).first
    }
}
