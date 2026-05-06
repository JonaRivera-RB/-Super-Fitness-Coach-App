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
    /// Unidad para pesas en gimnasio (plan/logs siguen en kg).
    var liftingWeightUnit: LiftingWeightUnit = .kilograms
    var isEditingFitnessConfig: Bool = false
    var fitnessConfigValidationError: String?

    // Sleep schedule editing (bedtime/wake time + buffer)
    private(set) var sleepGoal: SleepGoal? = nil
    private(set) var sleepGoalBedtime: Date = Date()
    private(set) var sleepGoalWakeTime: Date = Date()
    private(set) var bufferMinutes: Int = 60
    var isEditingSleepSchedule: Bool = false
    var sleepScheduleValidationError: String?

    private(set) var authorizationStatus: AuthorizationStatus = .notDetermined

    private let userProfileRepository: UserProfileRepository
    private let healthKitManager: HealthKitManager
    private let notificationService: NotificationService
    private let logger = Logger(subsystem: "com.superfitnesscoach", category: "ProfileViewModel")

    init(
        userProfileRepository: UserProfileRepository,
        healthKitManager: HealthKitManager,
        notificationService: NotificationService
    ) {
        self.userProfileRepository = userProfileRepository
        self.healthKitManager = healthKitManager
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
        Task { @MainActor in
            notificationsEnabled = await notificationService.authorizationGranted()
        }
    }

    /// Sincroniza HealthKit y notificaciones con el sistema (útil al abrir Perfil).
    func refreshConnectionStatus() async {
        authorizationStatus = healthKitManager.authorizationStatus
        notificationsEnabled = await notificationService.authorizationGranted()
    }

    private func loadFitnessConfig(_ config: FitnessConfig) {
        sleepGoalText = String(format: "%.1f", config.effectiveSleepGoalHours)
        stepsGoalText = String(format: "%.0f", config.stepsGoal)
        calorieGoalText = String(format: "%.0f", config.calorieGoal)
        baselineRestingHRText = String(format: "%.0f", config.baselineRestingHR)
        fitnessLevel = config.fitnessLevel
        liftingWeightUnit = config.liftingWeightUnit

        sleepGoal = config.sleepGoal
        bufferMinutes = config.bufferMinutes
        let (bed, wake) = Self.defaultPickerDates(from: config.sleepGoal)
        sleepGoalBedtime = bed
        sleepGoalWakeTime = wake
    }

    private static func defaultPickerDates(from goal: SleepGoal?) -> (bed: Date, wake: Date) {
        let cal = Calendar.current
        let now = Date()
        let startOfDay = cal.startOfDay(for: now)

        func dateFor(_ comps: DateComponents, fallbackHour: Int, fallbackMinute: Int) -> Date {
            let hour = comps.hour ?? fallbackHour
            let minute = comps.minute ?? fallbackMinute
            return cal.date(bySettingHour: hour, minute: minute, second: 0, of: startOfDay) ?? startOfDay
        }

        if let goal {
            let bed = dateFor(goal.targetSleepTime.asDateComponents, fallbackHour: 23, fallbackMinute: 0)
            let wake = dateFor(goal.targetWakeTime.asDateComponents, fallbackHour: 7, fallbackMinute: 0)
            return (bed, wake)
        } else {
            let bed = cal.date(bySettingHour: 23, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            let wake = cal.date(bySettingHour: 7, minute: 0, second: 0, of: startOfDay) ?? startOfDay
            return (bed, wake)
        }
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
            let L = AppLanguage.current
            guard let w = Double(weightInput.trimmingCharacters(in: .whitespaces)), w > 0 else {
                bodyMetricsValidationError = L.validationWeightKg
                return
            }
            guard let h = Double(heightInput.trimmingCharacters(in: .whitespaces)), h > 0 else {
                bodyMetricsValidationError = L.validationHeightCm
                return
            }
            weightKg = w
            heightCm = h

        case .imperial:
            let L = AppLanguage.current
            guard let w = Double(weightInput.trimmingCharacters(in: .whitespaces)), w > 0 else {
                bodyMetricsValidationError = L.validationWeightLbs
                return
            }
            let feet = Int(heightFeetInput?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            let inches = Double(heightInchesInput?.trimmingCharacters(in: .whitespaces) ?? "") ?? 0
            guard feet > 0 || inches > 0 else {
                bodyMetricsValidationError = L.validationHeightImperial
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
            bodyMetricsValidationError = AppLanguage.current.validationSaveFailed
            return
        }

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
    func saveFitnessConfigFrom(sleep: String, steps: String, calories: String, hr: String, level: FitnessLevel, liftingUnit: LiftingWeightUnit) async {
        fitnessConfigValidationError = nil

        logger.info("saveFitnessConfigFrom — sleep='\(sleep)', steps='\(steps)', cal='\(calories)', hr='\(hr)', lift=\(liftingUnit.rawValue)")

        guard let sleepVal = Double(sleep.trimmingCharacters(in: .whitespaces)),
              let stepsVal = Double(steps.trimmingCharacters(in: .whitespaces)),
              let calVal = Double(calories.trimmingCharacters(in: .whitespaces)),
              let hrVal = Double(hr.trimmingCharacters(in: .whitespaces)) else {
            fitnessConfigValidationError = AppLanguage.current.validationFitnessNumbers
            return
        }

        // Preserve sleep schedule fields while editing numeric goals.
        let existingSchedule: (SleepGoal?, Int) = (sleepGoal, bufferMinutes)

        let config = FitnessConfig(
            sleepGoalHours: sleepVal,
            stepsGoal: stepsVal,
            calorieGoal: calVal,
            baselineRestingHR: hrVal,
            fitnessLevel: level,
            liftingWeightUnit: liftingUnit,
            sleepGoal: existingSchedule.0,
            bufferMinutes: existingSchedule.1
        )

        guard config.isValid else {
            fitnessConfigValidationError = AppLanguage.current.validationFitnessRanges
            return
        }

        do {
            try userProfileRepository.updateFitnessConfig(config)
            loadFitnessConfig(config)
            logger.info("Saved fitness config: sleep=\(config.sleepGoalHours), steps=\(config.stepsGoal), cal=\(config.calorieGoal), hr=\(config.baselineRestingHR)")
        } catch {
            logger.error("Failed to save fitness config: \(error.localizedDescription)")
            fitnessConfigValidationError = AppLanguage.current.validationSaveFailed
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

    // MARK: - Sleep Schedule Editing

    func beginSleepScheduleEditing() {
        sleepScheduleValidationError = nil
        let (bed, wake) = Self.defaultPickerDates(from: sleepGoal)
        sleepGoalBedtime = bed
        sleepGoalWakeTime = wake
        isEditingSleepSchedule = true
    }

    func cancelSleepScheduleEditing() {
        sleepScheduleValidationError = nil
        // Reload persisted values to discard unsaved changes
        do {
            if let profile = try userProfileRepository.fetch() {
                loadFitnessConfig(profile.effectiveFitnessConfig)
            }
        } catch {
            logger.error("Failed to reload sleep schedule: \(error.localizedDescription)")
        }
        isEditingSleepSchedule = false
    }

    func saveSleepSchedule(bedtime: Date, wakeTime: Date, bufferMinutes: Int) async {
        sleepScheduleValidationError = nil

        let cal = Calendar.current
        let bedComps = cal.dateComponents([.hour, .minute], from: bedtime)
        let wakeComps = cal.dateComponents([.hour, .minute], from: wakeTime)
        let goal = SleepGoal(targetSleepTime: bedComps, targetWakeTime: wakeComps)

        guard goal.isValid else {
            let L = AppLanguage.current
            if (bedComps.hour == wakeComps.hour) && (bedComps.minute == wakeComps.minute) {
                sleepScheduleValidationError = L.validationBedtimeWakeSame
            } else {
                sleepScheduleValidationError = L.validationSleepWindowShort
            }
            return
        }

        let clampedBuffer = max(0, min(180, bufferMinutes))

        // Merge into existing FitnessConfig so we don't wipe other fields.
        let existing: FitnessConfig
        do {
            existing = (try userProfileRepository.fetch()?.effectiveFitnessConfig) ?? .default
        } catch {
            existing = .default
        }

        let derivedHours = min(12, max(4, goal.durationHours))
        let updated = FitnessConfig(
            sleepGoalHours: derivedHours,
            stepsGoal: existing.stepsGoal,
            calorieGoal: existing.calorieGoal,
            baselineRestingHR: existing.baselineRestingHR,
            fitnessLevel: existing.fitnessLevel,
            liftingWeightUnit: existing.liftingWeightUnit,
            sleepGoal: goal,
            bufferMinutes: clampedBuffer
        )

        do {
            try userProfileRepository.updateFitnessConfig(updated)
            loadFitnessConfig(updated)
            logger.info("Saved sleep schedule: bed=\(goal.targetSleepTime.hour):\(goal.targetSleepTime.minute) wake=\(goal.targetWakeTime.hour):\(goal.targetWakeTime.minute) buffer=\(clampedBuffer)m")
        } catch {
            logger.error("Failed to save sleep schedule: \(error.localizedDescription)")
            sleepScheduleValidationError = AppLanguage.current.validationSaveFailed
            return
        }

        isEditingSleepSchedule = false
        await healthKitManager.refreshHealthData(config: updated)
    }

    // MARK: - Notifications

    func enableNotifications() async {
        let granted = await notificationService.requestPermission()
        notificationsEnabled = granted
    }
}
