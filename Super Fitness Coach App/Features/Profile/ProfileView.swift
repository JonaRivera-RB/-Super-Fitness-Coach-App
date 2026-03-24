//
//  ProfileView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct ProfileView: View {
    @Bindable var viewModel: ProfileViewModel

    // Local @State for fitness config editing (immune to viewModel re-renders)
    @State private var editSleep: String = ""
    @State private var editSteps: String = ""
    @State private var editCalories: String = ""
    @State private var editHR: String = ""
    @State private var editFitnessLevel: FitnessLevel = .beginner

    // Local @State for body metrics editing
    @State private var editWeight: String = ""
    @State private var editHeight: String = ""
    @State private var editHeightFeet: String = ""
    @State private var editHeightInches: String = ""

    var body: some View {
        NavigationStack {
            List {
                userSection
                bodyMetricsSection
                fitnessGoalsSection
                fitnessGoalSection
                healthSection
                notificationsSection
            }
            .navigationTitle("Profile")
            .alert("Plan Updated", isPresented: $viewModel.showGoalChanged) {
                Button("OK", role: .cancel) {
                    viewModel.dismissGoalChanged()
                }
            } message: {
                Text("Your weekly plan has been regenerated.")
            }
        }
    }

    // MARK: - User Info

    private var userSection: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(viewModel.userName)
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text(viewModel.selectedGoal.rawValue)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.userName), goal: \(viewModel.selectedGoal.rawValue)")
        }
    }

    // MARK: - Fitness Goal

    private var fitnessGoalSection: some View {
        Section("Fitness Goal") {
            ForEach(FitnessGoal.allCases, id: \.self) { goal in
                Button {
                    viewModel.updateFitnessGoal(goal)
                } label: {
                    HStack {
                        Label(goal.rawValue, systemImage: goalIcon(for: goal))
                            .foregroundStyle(.primary)
                        Spacer()
                        if goal == viewModel.selectedGoal {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .accessibilityLabel("\(goal.rawValue)\(goal == viewModel.selectedGoal ? ", selected" : "")")
            }
        }
    }

    // MARK: - Health

    private var healthSection: some View {
        Section("Apple Health") {
            HStack {
                Label("HealthKit", systemImage: "heart.fill")
                    .foregroundStyle(.red)
                Spacer()
                switch viewModel.authorizationStatus {
                case .authorized:
                    Text("Connected")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                case .denied:
                    Text("Denied")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                case .unavailable:
                    Text("Unavailable")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                case .notDetermined:
                    Button("Connect") {
                        Task {
                            await viewModel.requestHealthKitAuthorization()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("HealthKit: \(viewModel.authorizationStatus == .authorized ? "Connected" : "Not connected")")
        }
    }

    // MARK: - Notifications

    private var notificationsSection: some View {
        Section("Notifications") {
            HStack {
                Label("Daily Reminder", systemImage: "bell.fill")
                    .foregroundStyle(.orange)
                Spacer()
                if viewModel.notificationsEnabled {
                    Text("Enabled")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                } else {
                    Button("Enable") {
                        Task {
                            await viewModel.enableNotifications()
                        }
                    }
                    .font(.subheadline)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Daily reminder: \(viewModel.notificationsEnabled ? "Enabled" : "Disabled")")
        }
    }

    // MARK: - Body Metrics

    private var bodyMetricsSection: some View {
        Section("Body Metrics") {
            // Unit preference picker
            Picker("Units", selection: Binding(
                get: { viewModel.unitPreference },
                set: { viewModel.switchUnitPreference($0) }
            )) {
                Text("Metric").tag(UnitPreference.metric)
                Text("Imperial").tag(UnitPreference.imperial)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Unit preference")

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
                Label("Weight", systemImage: "scalemass")
                Spacer()
                if viewModel.weightDisplay.isEmpty {
                    Text("Not set")
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(viewModel.weightDisplay) \(viewModel.unitPreference == .metric ? "kg" : "lbs")")
                        .foregroundStyle(.secondary)
                }
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label("Height", systemImage: "ruler")
                Spacer()
                if viewModel.unitPreference == .metric {
                    if viewModel.heightDisplay.isEmpty {
                        Text("Not set")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.heightDisplay) cm")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    if viewModel.heightFeetDisplay.isEmpty && viewModel.heightInchesDisplay.isEmpty {
                        Text("Not set")
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(viewModel.heightFeetDisplay) ft \(viewModel.heightInchesDisplay) in")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .accessibilityElement(children: .combine)

            Button("Edit") {
                editWeight = viewModel.weightDisplay
                editHeight = viewModel.heightDisplay
                editHeightFeet = viewModel.heightFeetDisplay
                editHeightInches = viewModel.heightInchesDisplay
                viewModel.isEditingBodyMetrics = true
                viewModel.bodyMetricsValidationError = nil
            }
            .accessibilityLabel("Edit body metrics")
        }
    }

    private var bodyMetricsEditingFields: some View {
        Group {
            HStack {
                Label("Weight", systemImage: "scalemass")
                TextField(viewModel.unitPreference == .metric ? "kg" : "lbs", text: $editWeight)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .accessibilityLabel("Weight in \(viewModel.unitPreference == .metric ? "kilograms" : "pounds")")
            }

            if viewModel.unitPreference == .metric {
                HStack {
                    Label("Height", systemImage: "ruler")
                    TextField("cm", text: $editHeight)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .accessibilityLabel("Height in centimeters")
                }
            } else {
                HStack {
                    Label("Height", systemImage: "ruler")
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
                Button("Cancel") {
                    viewModel.isEditingBodyMetrics = false
                    viewModel.bodyMetricsValidationError = nil
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Cancel editing body metrics")

                Spacer()

                Button("Save") {
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
                .accessibilityLabel("Save body metrics")
            }
        }
    }

    // MARK: - Fitness Goals (FitnessConfig)

    private var fitnessGoalsSection: some View {
        Section("Fitness Goals") {
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

    private var fitnessGoalsDisplayFields: some View {
        Group {
            HStack {
                Label("Sleep Goal", systemImage: "bed.double")
                Spacer()
                Text("\(viewModel.sleepGoalText)h")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label("Steps Goal", systemImage: "figure.walk")
                Spacer()
                Text(viewModel.stepsGoalText)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label("Calorie Goal", systemImage: "flame")
                Spacer()
                Text("\(viewModel.calorieGoalText) kcal")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label("Baseline HR", systemImage: "heart")
                Spacer()
                Text("\(viewModel.baselineRestingHRText) bpm")
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            HStack {
                Label("Fitness Level", systemImage: "figure.strengthtraining.traditional")
                Spacer()
                Text(viewModel.fitnessLevel.rawValue.capitalized)
                    .foregroundStyle(.secondary)
            }
            .accessibilityElement(children: .combine)

            Button("Edit") {
                editSleep = viewModel.sleepGoalText
                editSteps = viewModel.stepsGoalText
                editCalories = viewModel.calorieGoalText
                editHR = viewModel.baselineRestingHRText
                editFitnessLevel = viewModel.fitnessLevel
                print("[ProfileView] Edit tapped — copied sleep='\(editSleep)', steps='\(editSteps)', cal='\(editCalories)', hr='\(editHR)'")
                viewModel.isEditingFitnessConfig = true
                viewModel.fitnessConfigValidationError = nil
            }
            .accessibilityLabel("Edit fitness goals")
        }
    }

    private var fitnessGoalsEditingFields: some View {
        Group {
            HStack {
                Label("Sleep Goal", systemImage: "bed.double")
                Spacer()
                TextField("hours", text: $editSleep)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Sleep goal in hours, 4 to 12")
                Text("h")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Label("Steps Goal", systemImage: "figure.walk")
                Spacer()
                TextField("steps", text: $editSteps)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Steps goal, 1000 to 50000")
            }

            HStack {
                Label("Calorie Goal", systemImage: "flame")
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
                Label("Baseline HR", systemImage: "heart")
                Spacer()
                TextField("bpm", text: $editHR)
                    .keyboardType(.numberPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 80)
                    .accessibilityLabel("Baseline resting heart rate, 35 to 120")
                Text("bpm")
                    .foregroundStyle(.secondary)
            }

            Picker("Fitness Level", selection: $editFitnessLevel) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .accessibilityLabel("Fitness level")

            HStack {
                Button("Cancel") {
                    viewModel.cancelFitnessConfigEditing()
                }
                .foregroundStyle(.red)
                .accessibilityLabel("Cancel editing fitness goals")

                Spacer()

                Button("Save") {
                    Task {
                        print("[ProfileView] Save tapped — editSleep='\(editSleep)', editSteps='\(editSteps)', editCal='\(editCalories)', editHR='\(editHR)'")
                        await viewModel.saveFitnessConfigFrom(
                            sleep: editSleep,
                            steps: editSteps,
                            calories: editCalories,
                            hr: editHR,
                            level: editFitnessLevel
                        )
                    }
                }
                .fontWeight(.semibold)
                .accessibilityLabel("Save fitness goals")
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
