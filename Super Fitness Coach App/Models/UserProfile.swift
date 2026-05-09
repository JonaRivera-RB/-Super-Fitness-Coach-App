//
//  UserProfile.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var fitnessGoal: FitnessGoal
    var onboardingCompleted: Bool
    var createdAt: Date

    // Body metrics (always stored in metric units)
    var weightKg: Double?
    var heightCm: Double?
    var unitPreference: UnitPreference?

    // Personalized fitness configuration
    var fitnessConfig: FitnessConfig?

    // Training plan preferences (nil for users who haven't configured a plan)
    var trainingPreferences: TrainingPreferences?

    /// Returns fitnessConfig or default values if not configured.
    var effectiveFitnessConfig: FitnessConfig {
        fitnessConfig ?? .default
    }

    init(name: String, fitnessGoal: FitnessGoal,
         weightKg: Double? = nil, heightCm: Double? = nil,
         unitPreference: UnitPreference? = nil) {
        self.id = UUID()
        self.name = name
        self.fitnessGoal = fitnessGoal
        self.onboardingCompleted = true
        self.createdAt = Date()
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.unitPreference = unitPreference
    }
}

enum FitnessGoal: String, Codable, CaseIterable {
    case loseWeight = "Lose Weight"
    case gainMuscle = "Gain Muscle"
    case beHealthy = "Be Healthy"
}
