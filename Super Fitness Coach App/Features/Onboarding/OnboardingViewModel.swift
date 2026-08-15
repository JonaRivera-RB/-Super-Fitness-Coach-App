//
//  OnboardingViewModel.swift
//  Super Fitness Coach App
//

import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable {
    case you = 0
    case body = 1
    case done = 2
}

@Observable
final class OnboardingViewModel {
    var currentStep: OnboardingStep = .you
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

    // Sleep schedule — sin UI de horas en el onboarding: el toggle usa los
    // valores por defecto (23:00 – 7:00, buffer 60) y se afina en Ajustes.
    var sleepBedtime: Date = Date()
    var sleepWakeTime: Date = Date()
    var sleepBufferMinutes: Int = 60
    var sleepScheduleEnabled: Bool = false
    var completionError: String?

    private let profileRepository: UserProfileRepository
    private let healthKitManager: HealthKitManager

    /// Validación única por paso. El paso 2 nunca bloquea: peso y altura son
    /// opcionales y «Prefiero hacerlo después» es una salida válida.
    var canProceed: Bool {
        switch currentStep {
        case .you:  return !userName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .body: return true
        case .done: return !isCompleting
        }
    }

    var isHealthConnected: Bool {
        healthConnectionResult == "connected"
    }

    var isHealthDenied: Bool {
        healthConnectionResult == "denied"
    }

    /// Resumen de medidas para el paso 3 («64,0 kg · 168 cm»). `nil` si el
    /// usuario las dejó en blanco.
    var bodyMetricsSummary: String? {
        switch unitPreference {
        case .metric:
            guard let weight = Double(weightInput), weight > 0,
                  let height = Double(heightInput), height > 0 else { return nil }
            return "\(format(weight)) kg · \(format(height)) cm"
        case .imperial:
            guard let weight = Double(weightInput), weight > 0 else { return nil }
            let feet = Int(heightFeetInput) ?? 0
            let inches = Double(heightInchesInput) ?? 0
            guard feet > 0 || inches > 0 else { return nil }
            return "\(format(weight)) lb · \(feet)′ \(format(inches))″"
        }
    }

    private func format(_ value: Double) -> String {
        value == value.rounded()
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }

    init(
        profileRepository: UserProfileRepository,
        healthKitManager: HealthKitManager
    ) {
        self.profileRepository = profileRepository
        self.healthKitManager = healthKitManager

        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        self.sleepBedtime = cal.date(bySettingHour: 23, minute: 0, second: 0, of: startOfDay) ?? Date()
        self.sleepWakeTime = cal.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay) ?? Date()
    }

    func nextStep() {
        guard let next = OnboardingStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    func previousStep() {
        guard let prev = OnboardingStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = prev
    }

    /// «Prefiero hacerlo después»: descarta lo escrito a medias y avanza. El
    /// perfil se guarda con peso y altura en `nil`, que `UserProfile` soporta.
    func skipBodyMetrics() {
        weightInput = ""
        heightInput = ""
        heightFeetInput = ""
        heightInchesInput = ""
        isHealthKitMetricsLoaded = false
        nextStep()
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

    @MainActor
    func completeOnboarding() async {
        isCompleting = true
        defer { isCompleting = false }
        completionError = nil

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

        do {
            // Check if a profile already exists (re-onboarding scenario)
            if let existing = try profileRepository.fetch() {
                existing.name = trimmedName
                existing.fitnessGoal = selectedGoal
                existing.weightKg = weightKg
                existing.heightCm = heightCm
                existing.unitPreference = unitPreference
                existing.onboardingCompleted = true

                // Persist sleep schedule into FitnessConfig (additive/backward compatible)
                let currentConfig = existing.effectiveFitnessConfig
                let updatedConfig = updatedFitnessConfig(from: currentConfig)
                try profileRepository.save(existing)
                // Force-save FitnessConfig via delete+reinsert workaround (SwiftData Codable issue)
                try profileRepository.updateFitnessConfig(profileId: existing.id, config: updatedConfig)
            } else {
                let profile = UserProfile(
                    name: trimmedName,
                    fitnessGoal: selectedGoal,
                    weightKg: weightKg,
                    heightCm: heightCm,
                    unitPreference: unitPreference
                )
                profile.onboardingCompleted = true
                let config = updatedFitnessConfig(from: profile.effectiveFitnessConfig)
                profile.fitnessConfig = config
                try profileRepository.save(profile)
                // For a brand-new profile, fitnessConfig is persisted on insert.
            }
        } catch {
            completionError = AppLanguage.current.onboardingSaveFailed
        }
    }

    private func updatedFitnessConfig(from base: FitnessConfig) -> FitnessConfig {
        if sleepScheduleEnabled {
            let cal = Calendar.current
            let bedComps = cal.dateComponents([.hour, .minute], from: sleepBedtime)
            let wakeComps = cal.dateComponents([.hour, .minute], from: sleepWakeTime)
            let goal = SleepGoal(targetSleepTime: bedComps, targetWakeTime: wakeComps)

            if !goal.isValid {
                // Don't block onboarding; just drop the schedule if invalid.
                return FitnessConfig(
                    sleepGoalHours: base.sleepGoalHours,
                    stepsGoal: base.stepsGoal,
                    calorieGoal: base.calorieGoal,
                    baselineRestingHR: base.baselineRestingHR,
                    fitnessLevel: base.fitnessLevel,
                    liftingWeightUnit: base.liftingWeightUnit,
                    sleepGoal: nil,
                    bufferMinutes: base.bufferMinutes
                )
            }

            let clampedBuffer = max(0, min(180, sleepBufferMinutes))
            return FitnessConfig(
                sleepGoalHours: base.sleepGoalHours,
                stepsGoal: base.stepsGoal,
                calorieGoal: base.calorieGoal,
                baselineRestingHR: base.baselineRestingHR,
                fitnessLevel: base.fitnessLevel,
                liftingWeightUnit: base.liftingWeightUnit,
                sleepGoal: goal,
                bufferMinutes: clampedBuffer
            )
        } else {
            return FitnessConfig(
                sleepGoalHours: base.sleepGoalHours,
                stepsGoal: base.stepsGoal,
                calorieGoal: base.calorieGoal,
                baselineRestingHR: base.baselineRestingHR,
                fitnessLevel: base.fitnessLevel,
                liftingWeightUnit: base.liftingWeightUnit,
                sleepGoal: nil,
                bufferMinutes: base.bufferMinutes
            )
        }
    }
}
