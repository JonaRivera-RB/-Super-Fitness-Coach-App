//
//  ProfileView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel
    @Environment(\.appLanguage) private var lang
    @AppStorage(AppLanguage.storageKey) private var languageCode: String = AppLanguage.spanish.rawValue

    // Local @State for fitness config editing (immune to viewModel re-renders)
    @State private var editSleep: String = ""
    @State private var editSteps: String = ""
    @State private var editCalories: String = ""
    @State private var editHR: String = ""
    @State private var editFitnessLevel: FitnessLevel = .beginner
    @State private var editLiftingWeightUnit: LiftingWeightUnit = .kilograms

    // Local @State for body metrics editing
    @State private var editWeight: String = ""
    @State private var editHeight: String = ""
    @State private var editHeightFeet: String = ""
    @State private var editHeightInches: String = ""

    // Local @State for sleep schedule editing
    @State private var editBedtime: Date = Date()
    @State private var editWakeTime: Date = Date()
    @State private var editBufferMinutes: Int = 60

    var body: some View {
        NavigationStack {
            List {
                languageSection
                userSection
                bodyMetricsSection
                fitnessGoalsSection
                fitnessGoalSection
                healthSection
                notificationsSection
            }
            .navigationTitle(lang.profileTitle)
            .task {
                await viewModel.refreshConnectionStatus()
            }
            .alert(lang.alertPlanUpdatedTitle, isPresented: $viewModel.showGoalChanged) {
                Button(lang.ok, role: .cancel) {
                    viewModel.dismissGoalChanged()
                }
            } message: {
                Text(lang.alertPlanUpdatedMessage)
            }
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section(lang.sectionLanguage) {
            Picker(lang.sectionLanguage, selection: $languageCode) {
                ForEach(AppLanguage.allCases, id: \.rawValue) { code in
                    Text(code.nativePickerLabel).tag(code.rawValue)
                }
            }
        }
    }

    // MARK: - User Info

    private var userSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(AppSemanticPalette.systemBlue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.userName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(viewModel.selectedGoal.displayName(lang))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.userName), goal: \(viewModel.selectedGoal.displayName(lang))")
        }
    }

    // MARK: - Fitness Goal

    private var fitnessGoalSection: some View {
        Section(lang.sectionFitnessGoal) {
            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                Button {
                    viewModel.updateFitnessGoal(goal)
                } label: {
                    HStack {
                        Label(goal.displayName(lang), systemImage: goalIcon(for: goal))
                            .foregroundStyle(.primary)
                        Spacer()
                        if goal == viewModel.selectedGoal {
                            Image(systemName: "checkmark")
                                .foregroundStyle(AppSemanticPalette.systemBlue)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .accessibilityLabel(goal.displayName(lang))
            }
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section(lang.sectionAppleHealth) {
            HStack {
                Label(lang.labelHealthKit, systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Spacer()
                switch viewModel.authorizationStatus {
                case .authorized:
                    Text(lang.healthConnected)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                case .denied:
                    Text(lang.healthDenied)
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                case .unavailable:
                    Text(lang.healthUnavailable)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                case .notDetermined:
                    Button(lang.healthConnect) {
                        Task {
                            await viewModel.requestHealthKitAuthorization()
                            await viewModel.refreshConnectionStatus()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(lang.labelHealthKit): \(viewModel.authorizationStatus == .authorized ? lang.healthConnected : lang.healthConnect)")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section(lang.sectionNotifications) {
            HStack {
                Label(lang.labelDailyReminder, systemImage: "bell.fill")
                    .foregroundStyle(.orange)
                Spacer()
                if viewModel.notificationsEnabled {
                    Text(lang.notificationsOn)
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else {
                    Button(lang.notificationsEnable) {
                        Task {
                            await viewModel.enableNotifications()
                            await viewModel.refreshConnectionStatus()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(lang.labelDailyReminder): \(viewModel.notificationsEnabled ? lang.notificationsOn : lang.notificationsEnable)")
        }
    }

    // MARK: - Body Metrics

    private var bodyMetricsSection: some View {
        Section(lang.sectionBodyMetrics) {
            // Unit preference picker
            Picker(lang.unitsLabel, selection: Binding(
                get: { viewModel.unitPreference },
                set: { viewModel.switchUnitPreference($0) }
            )) {
                Text(lang.unitMetric).tag(UnitPreference.metric)
                Text(lang.unitImperial).tag(UnitPreference.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(lang.unitsLabel)

            if viewModel.isEditingBodyMetrics {
                bodyMetricsEditingFields
            } else {
                bodyMetricsDisplayFields
            }

            if let error = viewModel.bodyMetricsValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Validation error: \(error)")
            }
        }
    }

    private var bodyMetricsDisplayFields: some View {
        Group {
            HStack {
                Label(lang.labelWeight, systemImage: "scalemass")
                Spacer()
                if viewModel.weightDisplay.isEmpty {
                    Text(lang.notSet)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(viewModel.weightDisplay) \(viewModel.unitPreference == .metric ? "kg" : "lbs")")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelHeight, systemImage: "ruler")
                Spacer()
                if viewModel.unitPreference == .metric {
                    if viewModel.heightDisplay.isEmpty {
                        Text(lang.notSet)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.heightDisplay) cm")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if viewModel.heightFeetDisplay.isEmpty && viewModel.heightInchesDisplay.isEmpty {
                        Text(lang.notSet)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.heightFeetDisplay) ft \(viewModel.heightInchesDisplay) in")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Button(lang.edit) {
                editWeight = viewModel.weightDisplay
                editHeight = viewModel.heightDisplay
                editHeightFeet = viewModel.heightFeetDisplay
                editHeightInches = viewModel.heightInchesDisplay
                viewModel.isEditingBodyMetrics = true
                viewModel.bodyMetricsValidationError = nil
            }
            .accessibilityLabel(lang.edit)
        }
    }

    private var bodyMetricsEditingFields: some View {
        Group {
            HStack {
                Label(lang.labelWeight, systemImage: "scalemass")
                TextField(viewModel.unitPreference == .metric ? "kg" : "lbs", text: $editWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Weight in \(viewModel.unitPreference == .metric ? "kilograms" : "pounds")")
            }

            if viewModel.unitPreference == .metric {
                HStack {
                    Label(lang.labelHeight, systemImage: "ruler")
                    TextField("cm", text: $editHeight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Height in centimeters")
                }
            } else {
                HStack {
                    Label(lang.labelHeight, systemImage: "ruler")
                    TextField("ft", text: $editHeightFeet)
                        .keyboardType(.numberPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Height feet")
                    Text("ft")
                    TextField("in", text: $editHeightInches)
                        .keyboardType(.decimalPad)
                        .frame(width: 40)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Height inches")
                    Text("in")
                }
            }

            HStack {
                Button(lang.cancel) {
                    viewModel.isEditingBodyMetrics = false
                    viewModel.bodyMetricsValidationError = nil
                }
                .foregroundStyle(.red)
                .accessibilityLabel(lang.cancel)

                Spacer()

                Button(lang.save) {
                    if viewModel.unitPreference == .metric {
                        viewModel.updateBodyMetrics(
                            weightInput: editWeight,
                            heightInput: editHeight
                        )
                    } else {
                        viewModel.updateBodyMetrics(
                            weightInput: editWeight,
                            heightInput: "",
                            heightFeetInput: editHeightFeet,
                            heightInchesInput: editHeightInches
                        )
                    }
                }
                .fontWeight(.semibold)
                .accessibilityLabel(lang.save)
            }
        }
    }

    // MARK: - Fitness Goals (FitnessConfig)

    private var fitnessGoalsSection: some View {
        Section(lang.sectionFitnessGoals) {
            sleepScheduleSectionContent

            if viewModel.isEditingFitnessConfig {
                fitnessGoalsEditingFields
            } else {
                fitnessGoalsDisplayFields
            }

            if let error = viewModel.fitnessConfigValidationError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Validation error: \(error)")
            }
        }
    }

    private var sleepScheduleSectionContent: some View {
        Group {
            if viewModel.isEditingSleepSchedule {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(lang.labelBedtime, systemImage: "moon.stars")
                        Spacer()
                        DatePicker("", selection: $editBedtime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Label(lang.labelWake, systemImage: "sunrise")
                        Spacer()
                        DatePicker("", selection: $editWakeTime, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                    HStack {
                        Label(lang.labelBuffer, systemImage: "slider.horizontal.3")
                        Spacer()
                        Stepper("\(editBufferMinutes) \(lang.minutesShort)", value: $editBufferMinutes, in: 0...180, step: 5)
                            .labelsHidden()
                        Text("\(editBufferMinutes) \(lang.minutesShort)")
                            .foregroundStyle(.secondary)
                    }

                    if let error = viewModel.sleepScheduleValidationError {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }

                    HStack {
                        Button(lang.cancel) {
                            viewModel.cancelSleepScheduleEditing()
                        }
                        .foregroundStyle(.red)

                        Spacer()

                        Button(lang.save) {
                            Task {
                                await viewModel.saveSleepSchedule(
                                    bedtime: editBedtime,
                                    wakeTime: editWakeTime,
                                    bufferMinutes: editBufferMinutes
                                )
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
                .onAppear {
                    editBedtime = viewModel.sleepGoalBedtime
                    editWakeTime = viewModel.sleepGoalWakeTime
                    editBufferMinutes = viewModel.bufferMinutes
                }
            } else {
                HStack {
                    Label(lang.labelSleepSchedule, systemImage: "bed.double.fill")
                    Spacer()
                    Text(sleepScheduleSummary)
                        .foregroundStyle(.secondary)
                }
                Button(lang.editSleepSchedule) {
                    // Preload local state from viewModel
                    editBedtime = viewModel.sleepGoalBedtime
                    editWakeTime = viewModel.sleepGoalWakeTime
                    editBufferMinutes = viewModel.bufferMinutes
                    viewModel.beginSleepScheduleEditing()
                }
            }
        }
    }

    private var sleepScheduleSummary: String {
        let cal = Calendar.current
        let startOfDay = cal.startOfDay(for: Date())
        let bed: Date
        let wake: Date

        if let goal = viewModel.sleepGoal {
            bed = cal.date(bySettingHour: goal.targetSleepTime.hour, minute: goal.targetSleepTime.minute, second: 0, of: startOfDay) ?? startOfDay
            wake = cal.date(bySettingHour: goal.targetWakeTime.hour, minute: goal.targetWakeTime.minute, second: 0, of: startOfDay) ?? startOfDay
        } else {
            return lang.sleepScheduleNotSet
        }

        let bedStr = DateFormatter.localizedString(from: bed, dateStyle: .none, timeStyle: .short)
        let wakeStr = DateFormatter.localizedString(from: wake, dateStyle: .none, timeStyle: .short)
        return "\(bedStr)–\(wakeStr) (+\(viewModel.bufferMinutes)m)"
    }

    private var fitnessGoalsDisplayFields: some View {
        Group {
            HStack {
                Label(lang.labelSleepGoal, systemImage: "bed.double")
                Spacer()
                Text("\(viewModel.sleepGoalText)\(lang.hoursSuffix)")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelStepsGoal, systemImage: "figure.walk")
                Spacer()
                Text(viewModel.stepsGoalText)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelCalorieGoal, systemImage: "flame")
                Spacer()
                Text("\(viewModel.calorieGoalText) kcal")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelBaselineHR, systemImage: "heart")
                Spacer()
                Text("\(viewModel.baselineRestingHRText) bpm")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelFitnessLevel, systemImage: "figure.strengthtraining.traditional")
                Spacer()
                Text(viewModel.fitnessLevel.displayName(lang))
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label(lang.labelGymWeightUnit, systemImage: "dumbbell.fill")
                Spacer()
                Text(viewModel.liftingWeightUnit == .kilograms ? lang.liftingUnitKilograms : lang.liftingUnitPounds)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Button(lang.edit) {
                editSleep = viewModel.sleepGoalText
                editSteps = viewModel.stepsGoalText
                editCalories = viewModel.calorieGoalText
                editHR = viewModel.baselineRestingHRText
                editFitnessLevel = viewModel.fitnessLevel
                editLiftingWeightUnit = viewModel.liftingWeightUnit
                print("[ProfileView] Edit tapped — copied sleep='\(editSleep)', steps='\(editSteps)', cal='\(editCalories)', hr='\(editHR)'")
                viewModel.isEditingFitnessConfig = true
                viewModel.fitnessConfigValidationError = nil
            }
            .accessibilityLabel(lang.edit)
        }
    }

    private var fitnessGoalsEditingFields: some View {
        Group {
            HStack {
                Label(lang.labelSleepGoal, systemImage: "bed.double")
                Spacer()
                TextField("hours", text: $editSleep)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Sleep goal in hours, 4 to 12")
                Text(lang.hoursSuffix)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label(lang.labelStepsGoal, systemImage: "figure.walk")
                Spacer()
                TextField("steps", text: $editSteps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Steps goal, 1000 to 50000")
            }

            HStack {
                Label(lang.labelCalorieGoal, systemImage: "flame")
                Spacer()
                TextField("kcal", text: $editCalories)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Calorie goal, 100 to 2000")
                Text("kcal")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label(lang.labelBaselineHR, systemImage: "heart")
                Spacer()
                TextField("bpm", text: $editHR)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Baseline resting heart rate, 35 to 120")
                Text("bpm")
                    .foregroundStyle(.secondary)
            }

            Picker(lang.pickerFitnessLevel, selection: $editFitnessLevel) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Text(level.displayName(lang)).tag(level)
                }
            }
            .accessibilityLabel(lang.labelFitnessLevel)

            VStack(alignment: .leading, spacing: 6) {
                Text(lang.gymWeightSectionTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Picker(lang.gymWeightPickerAccessibility, selection: $editLiftingWeightUnit) {
                    Text(lang.liftingUnitKilograms).tag(LiftingWeightUnit.kilograms)
                    Text(lang.liftingUnitPounds).tag(LiftingWeightUnit.pounds)
                }
                .pickerStyle(.segmented)
                Text(lang.gymWeightFooter)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Button(lang.cancel) {
                    viewModel.cancelFitnessConfigEditing()
                }
                .foregroundStyle(.red)
                .accessibilityLabel(lang.cancel)

                Spacer()

                Button(lang.save) {
                    Task {
                        print("[ProfileView] Save tapped — editSleep='\(editSleep)', editSteps='\(editSteps)', editCal='\(editCalories)', editHR='\(editHR)'")
                        await viewModel.saveFitnessConfigFrom(
                            sleep: editSleep,
                            steps: editSteps,
                            calories: editCalories,
                            hr: editHR,
                            level: editFitnessLevel,
                            liftingUnit: editLiftingWeightUnit
                        )
                    }
                }
                .fontWeight(.semibold)
                .accessibilityLabel(lang.save)
            }
        }
    }

    // MARK: - Helpers

    private func goalIcon(for goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "flame"
        case .gainMuscle: return "dumbbell"
        case .beHealthy: return "heart.circle"
        }
    }
}
