//
//  OnboardingViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable {
    case health = 0
    case name = 1
    case goal = 2
    case bodyMetrics = 3
}

@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .health
    var userName: String = ""
    var selectedGoal: FitnessGoal = .beHealthy
    var isRequestingHealth: Bool = false
    var healthConnectionResult: String?
    var isCompleting: Bool = false

    var weightInput: String = ""
    var heightInput: String = ""
    var heightFeetInput: String = ""
    var heightInchesInput: String = ""
    var unitPreference: UnitPreference = UnitConverter.defaultPreference()
    var isHealthKitMetricsLoaded: Bool = false
    var healthKitMetricsLabel: String? = nil

    private let profileRepository: UserProfileRepository
    private let workoutEngine: WorkoutEngine
    private let healthKitManager: HealthKitManager

    var canProceedFromName: Bool {
        !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var canProceedFromBodyMetrics: Bool {
        guard let weight = Double(weightInput), weight > 0 else { return false }
        switch unitPreference {
        case .metric:
            guard let height = Double(heightInput), height > 0 else { return false }
            return true
        case .imperial:
            guard let feet = Int(heightFeetInput), feet >= 0,
                  let inches = Double(heightInchesInput), inches >= 0,
                  feet > 0 || inches > 0 else { return false }
            return true
        }
    }

    init(
        profileRepository: UserProfileRepository,
        workoutEngine: WorkoutEngine,
        healthKitManager: HealthKitManager
    ) {
        self.profileRepository = profileRepository
        self.workoutEngine = workoutEngine
        self.healthKitManager = healthKitManager
    }

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    func loadHealthKitMetrics() async {
        async let weightResult = healthKitManager.queryLatestWeight()
        async let heightResult = healthKitManager.queryLatestHeight()

        let weightKg = await weightResult
        let heightCm = await heightResult

        var didLoad = false

        if let weightKg {
            switch unitPreference {
            case .metric:
                weightInput = String(format: "%.1f", weightKg)
            case .imperial:
                weightInput = String(format: "%.1f", UnitConverter.kgToLbs(weightKg))
            }
            didLoad = true
        }

        if let heightCm {
            switch unitPreference {
            case .metric:
                heightInput = String(format: "%.1f", heightCm)
            case .imperial:
                let (feet, inches) = UnitConverter.cmToFeetInches(heightCm)
                heightFeetInput = "\(feet)"
                heightInchesInput = String(format: "%.1f", inches)
            }
            didLoad = true
        }

        if didLoad {
            isHealthKitMetricsLoaded = true
            healthKitMetricsLabel = "Values imported from Apple Health"
        }
    }

    func switchUnitPreference(_ newPref: UnitPreference) {
        if newPref == unitPreference { return }

        switch newPref {
        case .imperial:
            // Convert weight from kg to lbs
            if let kg = Double(weightInput), kg > 0 {
                weightInput = String(format: "%.1f", UnitConverter.kgToLbs(kg))
            }
            // Convert height from cm to feet/inches
            if let cm = Double(heightInput), cm > 0 {
                let (feet, inches) = UnitConverter.cmToFeetInches(cm)
                heightFeetInput = "\(feet)"
                heightInchesInput = String(format: "%.1f", inches)
            }
        case .metric:
            // Convert weight from lbs to kg
            if let lbs = Double(weightInput), lbs > 0 {
                weightInput = String(format: "%.1f", UnitConverter.lbsToKg(lbs))
            }
            // Convert height from feet/inches to cm
            if let feet = Int(heightFeetInput), let inches = Double(heightInchesInput), feet >= 0, inches >= 0 {
                let cm = UnitConverter.feetInchesToCm(feet: feet, inches: inches)
                heightInput = String(format: "%.1f", cm)
            }
        }

        unitPreference = newPref
    }

    func connectHealthKit() async {
        isRequestingHealth = true
        defer { isRequestingHealth = false }

        do {
            try await healthKitManager.requestAuthorization()
            healthConnectionResult = "connected"
        } catch {
            // HealthKit denied — continue with default score of 50
            healthConnectionResult = "denied"
        }
    }

    func completeOnboarding() async {
        isCompleting = true
        defer { isCompleting = false }

        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)

        // Compute metric weight and height from current inputs
        var weightKg: Double?
        var heightCm: Double?

        switch unitPreference {
        case .metric:
            weightKg = Double(weightInput)
            heightCm = Double(heightInput)
        case .imperial:
            if let lbs = Double(weightInput) {
                weightKg = UnitConverter.lbsToKg(lbs)
            }
            if let feet = Int(heightFeetInput), let inches = Double(heightInchesInput) {
                heightCm = UnitConverter.feetInchesToCm(feet: feet, inches: inches)
            }
        }

        // Check if a profile already exists (re-onboarding scenario)
        if let existing = try? profileRepository.fetch() {
            existing.name = trimmedName
            existing.fitnessGoal = selectedGoal
            existing.weightKg = weightKg
            existing.heightCm = heightCm
            existing.unitPreference = unitPreference
            existing.onboardingCompleted = true
            try? profileRepository.save(existing)
        } else {
            let profile = UserProfile(
                name: trimmedName,
                fitnessGoal: selectedGoal,
                weightKg: weightKg,
                heightCm: heightCm,
                unitPreference: unitPreference
            )
            try? profileRepository.save(profile)
        }

        _ = workoutEngine.generateWeeklyPlan(goal: selectedGoal, weightKg: weightKg, heightCm: heightCm)
    }
}
