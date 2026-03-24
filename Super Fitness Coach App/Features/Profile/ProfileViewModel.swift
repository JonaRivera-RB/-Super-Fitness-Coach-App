//
//  ProfileViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class ProfileViewModel {
    private(set) var userName: String = ""
    var selectedGoal: FitnessGoal = .beHealthy
    private(set) var notificationsEnabled: Bool = false
    var showGoalChanged: Bool = false

    // Body metrics
    var weightDisplay: String = ""
    var heightDisplay: String = ""
    var heightFeetDisplay: String = ""
    var heightInchesDisplay: String = ""
    var unitPreference: UnitPreference = .metric
    var isEditingBodyMetrics: Bool = false
    var bodyMetricsValidationError: String?

    // Fitness config editing (use String for reliable TextField binding)
    var sleepGoalText: String = ""
    var stepsGoalText: String = ""
    var calorieGoalText: String = ""
    var baselineRestingHRText: String = ""
    var fitnessLevel: FitnessLevel = FitnessConfig.default.fitnessLevel
    var isEditingFitnessConfig: Bool = false
    var fitnessConfigValidationError: String?

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private let userProfileRepository: UserProfileRepository
    private let healthKitManager: HealthKitManager
    private let workoutEngine: WorkoutEngine
    private let notificationService: NotificationService
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "ProfileViewModel")

    init(
        userProfileRepository: UserProfileRepository,
        healthKitManager: HealthKitManager,
        workoutEngine: WorkoutEngine,
        notificationService: NotificationService
    ) {
        self.userProfileRepository = userProfileRepository
        self.healthKitManager = healthKitManager
        self.workoutEngine = workoutEngine
        self.notificationService = notificationService
        loadProfile()
    }

    func loadProfile() {
        do {
            if let profile = try userProfileRepository.fetch() {
                userName = profile.name
                selectedGoal = profile.fitnessGoal
                unitPreference = profile.unitPreference ?? UnitConverter.defaultPreference()
                loadBodyMetricsDisplay(weightKg: profile.weightKg, heightCm: profile.heightCm)
                loadFitnessConfig(profile.effectiveFitnessConfig)
            }
        } catch {
            logger.error("Failed to load profile: \(error.localizedDescription)")
        }
        authorizationStatus = healthKitManager.authorizationStatus
    }

    private func loadFitnessConfig(_ config: FitnessConfig) {
        sleepGoalText = String(format: "%.1f", config.sleepGoalHours)
        stepsGoalText = String(format: "%.0f", config.stepsGoal)
        calorieGoalText = String(format: "%.0f", config.calorieGoal)
        baselineRestingHRText = String(format: "%.0f", config.baselineRestingHR)
        fitnessLevel = config.fitnessLevel
    }

    private func loadBodyMetricsDisplay(weightKg: Double?, heightCm: Double?) {
        guard let kg = weightKg, let cm = heightCm else {
            weightDisplay = ""
            heightDisplay = ""
            heightFeetDisplay = ""
            heightInchesDisplay = ""
            return
        }

        switch unitPreference {
        case .metric:
            weightDisplay = String(format: "%.1f", kg)
            heightDisplay = String(format: "%.1f", cm)
        case .imperial:
            weightDisplay = String(format: "%.1f", UnitConverter.kgToLbs(kg))
            let (feet, inches) = UnitConverter.cmToFeetInches(cm)
            heightFeetDisplay = "\(feet)"
            heightInchesDisplay = String(format: "%.0f", inches)
        }
    }

    // MARK: - Body Metrics Editing

    func switchUnitPreference(_ newPref: UnitPreference) {
        guard newPref != unitPreference else { return }

        // Convert current display values to the new unit system
        if unitPreference == .metric {
            // metric → imperial
            if let kg = Double(weightDisplay), kg > 0 {
                weightDisplay = String(format: "%.1f", UnitConverter.kgToLbs(kg))
            }
            if let cm = Double(heightDisplay), cm > 0 {
                let (feet, inches) = UnitConverter.cmToFeetInches(cm)
                heightFeetDisplay = "\(feet)"
                heightInchesDisplay = String(format: "%.0f", inches)
            }
        } else {
            // imperial → metric
            if let lbs = Double(weightDisplay), lbs > 0 {
                weightDisplay = String(format: "%.1f", UnitConverter.lbsToKg(lbs))
            }
            let feet = Int(heightFeetDisplay) ?? 0
            let inches = Double(heightInchesDisplay) ?? 0
            if feet > 0 || inches > 0 {
                heightDisplay = String(format: "%.1f", UnitConverter.feetInchesToCm(feet: feet, inches: inches))
            }
        }

        unitPreference = newPref
        bodyMetricsValidationError = nil
    }

    func updateBodyMetrics(weightInput: String, heightInput: String, heightFeetInput: String? = nil, heightInchesInput: String? = nil) {
        bodyMetricsValidationError = nil

        let weightKg: Double
        let heightCm: Double

        switch unitPreference {
        case .metric:
            guard let w = Double(weightInput.trimmingCharacters(in: .whitespaces)), w > 0 else {
                bodyMetricsValidationError = "Please enter a valid weight in kg."
                return
            }
            guard let h = Double(heightInput.trimmingCharacters(in: .whitespaces)), h > 0 else {
                bodyMetricsValidationError = "Please enter a valid height in cm."
                return
            }
            weightKg = w
            heightCm = h

        case .imperial:
            guard let w = Double(weightInput.trimmingCharacters(in: .whitespaces)), w > 0 else {
                bodyMetricsValidationError = "Please enter a valid weight in lbs."
                return
            }
            let feet = Int(heightFeetInput?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            let inches = Double(heightInchesInput?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            guard feet > 0 || inches > 0 else {
                bodyMetricsValidationError = "Please enter a valid height in feet/inches."
                return
            }
            weightKg = UnitConverter.lbsToKg(w)
            heightCm = UnitConverter.feetInchesToCm(feet: feet, inches: inches)
        }

        // Persist
        do {
            if let profile = try userProfileRepository.fetch() {
                profile.weightKg = weightKg
                profile.heightCm = heightCm
                profile.unitPreference = unitPreference
                try userProfileRepository.save(profile)
            }
        } catch {
            logger.error("Failed to save body metrics: \(error.localizedDescription)")
            bodyMetricsValidationError = "Failed to save. Please try again."
            return
        }

        // Trigger workout re-evaluation
        let _ = workoutEngine.generateWeeklyPlan(goal: selectedGoal, weightKg: weightKg, heightCm: heightCm)

        isEditingBodyMetrics = false
        showGoalChanged = true
    }

    // MARK: - Edit Fitness Goal

    func updateFitnessGoal(_ goal: FitnessGoal) {
        guard goal != selectedGoal else { return }
        selectedGoal = goal

        do {
            if let profile = try userProfileRepository.fetch() {
                profile.fitnessGoal = goal
                try userProfileRepository.save(profile)
            }
        } catch {
            logger.error("Failed to update fitness goal: \(error.localizedDescription)")
        }

        // Regenerate weekly plan for the new goal, including body metrics if available
        if let profile = try? userProfileRepository.fetch() {
            let _ = workoutEngine.generateWeeklyPlan(goal: goal, weightKg: profile.weightKg, heightCm: profile.heightCm)
        } else {
            let _ = workoutEngine.generateWeeklyPlan(goal: goal)
        }
        showGoalChanged = true
    }

    func dismissGoalChanged() {
        showGoalChanged = false
    }

    // MARK: - HealthKit Re-Authorization

    func requestHealthKitAuthorization() async {
        do {
            try await healthKitManager.requestAuthorization()
            authorizationStatus = healthKitManager.authorizationStatus
        } catch {
            logger.error("HealthKit re-authorization failed: \(error.localizedDescription)")
            authorizationStatus = healthKitManager.authorizationStatus
        }
    }

    // MARK: - Fitness Config Editing

    /// Save fitness config from explicit string values passed from the view's @State fields.
    func saveFitnessConfigFrom(sleep: String, steps: String, calories: String, hr: String, level: FitnessLevel) async {
        fitnessConfigValidationError = nil

        logger.info("saveFitnessConfigFrom — sleep='\(sleep)', steps='\(steps)', cal='\(calories)', hr='\(hr)'")

        guard let sleepVal = Double(sleep.trimmingCharacters(in: .whitespaces)),
              let stepsVal = Double(steps.trimmingCharacters(in: .whitespaces)),
              let calVal = Double(calories.trimmingCharacters(in: .whitespaces)),
              let hrVal = Double(hr.trimmingCharacters(in: .whitespaces)) else {
            fitnessConfigValidationError = "Please enter valid numbers for all fields."
            return
        }

        let config = FitnessConfig(
            sleepGoalHours: sleepVal,
            stepsGoal: stepsVal,
            calorieGoal: calVal,
            baselineRestingHR: hrVal,
            fitnessLevel: level
        )

        guard config.isValid else {
            fitnessConfigValidationError = "Please check your values: sleep 4-12h, steps 1k-50k, calories 100-2000, resting HR 35-120 bpm."
            return
        }

        do {
            try userProfileRepository.updateFitnessConfig(config)
            loadFitnessConfig(config)
            logger.info("Saved fitness config: sleep=\(config.sleepGoalHours), steps=\(config.stepsGoal), cal=\(config.calorieGoal), hr=\(config.baselineRestingHR)")
        } catch {
            logger.error("Failed to save fitness config: \(error.localizedDescription)")
            fitnessConfigValidationError = "Failed to save. Please try again."
            return
        }

        isEditingFitnessConfig = false
        await healthKitManager.refreshHealthData(config: config)
    }

    func cancelFitnessConfigEditing() {
        fitnessConfigValidationError = nil
        // Reload from persisted profile to discard unsaved changes
        do {
            if let profile = try userProfileRepository.fetch() {
                loadFitnessConfig(profile.effectiveFitnessConfig)
            }
        } catch {
            logger.error("Failed to reload fitness config: \(error.localizedDescription)")
        }
        isEditingFitnessConfig = false
    }

    // MARK: - Notifications

    func enableNotifications() async {
        let granted = await notificationService.requestPermission()
        notificationsEnabled = granted
    }
}
