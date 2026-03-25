//
//  TrainingPreferencesView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct TrainingPreferencesView: View {
    @Bindable var viewModel: TrainingPreferencesViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                goalSection
                levelSection
                restDaysSection
                musclePrioritySection
                cardioSection
                durationSection
                generateSection
            }
            .navigationTitle("Training Plan")
            .onChange(of: viewModel.didGenerate) { _, generated in
                if generated {
                    dismiss()
                }
            }
        }
    }

    // MARK: - Goal Picker (Req 1.1)

    private var goalSection: some View {
        Section("Goal") {
            Picker("Fitness Goal", selection: $viewModel.goal) {
                ForEach(FitnessGoal.allCases, id: \.self) { goal in
                    Text(goal.rawValue).tag(goal)
                }
            }
            .accessibilityLabel("Fitness goal")
        }
    }

    // MARK: - Training Days Stepper (Req 1.1)

    private var daysSection: some View {
        Section("Training Days") {
            Stepper(
                "Days per week: \(viewModel.trainingDaysPerWeek)",
                value: $viewModel.trainingDaysPerWeek,
                in: 3...6
            )
            .accessibilityLabel("Training days per week, \(viewModel.trainingDaysPerWeek)")
        }
    }

    // MARK: - Experience Level Picker (Req 1.1)

    private var levelSection: some View {
        Section("Experience Level") {
            Picker("Level", selection: $viewModel.experienceLevel) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    Text(level.rawValue.capitalized).tag(level)
                }
            }
            .accessibilityLabel("Experience level")
        }
    }

    // MARK: - Muscle Priority Selector (Req 1.3)

    private var musclePrioritySection: some View {
        Section {
            ForEach(MuscleGroup.allCases) { muscle in
                Button {
                    viewModel.toggleMuscle(muscle)
                } label: {
                    HStack {
                        Text(muscle.rawValue.capitalized)
                            .foregroundStyle(.primary)
                        Spacer()
                        if viewModel.priorityMuscles.contains(muscle) {
                            Image(systemName: "checkmark")
                                .foregroundStyle(.blue)
                                .fontWeight(.semibold)
                        }
                    }
                }
                .accessibilityLabel("\(muscle.rawValue.capitalized)\(viewModel.priorityMuscles.contains(muscle) ? ", selected" : "")")
            }

            if viewModel.priorityMuscles.count >= 2 {
                Text("Maximum of 2 priority muscles reached")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .accessibilityLabel("Maximum of 2 priority muscles reached")
            }
        } header: {
            Text("Priority Muscles (max 2)")
        }
    }

    // MARK: - Cardio Toggle (Req 1.1)

    private var cardioSection: some View {
        Section("Cardio") {
            Toggle("Include Cardio", isOn: $viewModel.wantsCardio)
                .accessibilityLabel("Include cardio in plan")
        }
    }

    // MARK: - Duration Picker (Req 1.5)

    private var durationSection: some View {
        Section("Plan Duration") {
            Picker("Weeks", selection: $viewModel.planDurationWeeks) {
                Text("4 weeks").tag(4)
                Text("6 weeks").tag(6)
                Text("8 weeks").tag(8)
            }
            .pickerStyle(.segmented)
            .accessibilityLabel("Plan duration in weeks")
        }
    }

    // MARK: - Training Days Selector

    private let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

    private var restDaysSection: some View {
        Section {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { day in
                    let isTraining = !viewModel.restDays.contains(day)
                    Button {
                        if isTraining {
                            // Can only remove a training day if we'd still have >= 3
                            if viewModel.trainingDaysPerWeek > 3 {
                                viewModel.restDays.insert(day)
                                viewModel.trainingDaysPerWeek -= 1
                            }
                        } else {
                            // Can only add a training day if we'd still have <= 6
                            if viewModel.trainingDaysPerWeek < 6 {
                                viewModel.restDays.remove(day)
                                viewModel.trainingDaysPerWeek += 1
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Text(dayNames[day - 1])
                                .font(.caption2)
                                .fontWeight(.semibold)
                            Circle()
                                .fill(isTraining ? Color.blue : Color(.systemGray4))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Image(systemName: isTraining ? "dumbbell.fill" : "moon.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(.white)
                                )
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dayNames[day - 1]), \(isTraining ? "training day" : "rest day")")
                }
            }
            .padding(.vertical, 4)

            HStack {
                Label("\(viewModel.trainingDaysPerWeek) training", systemImage: "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(.blue)
                Spacer()
                Label("\(7 - viewModel.trainingDaysPerWeek) rest", systemImage: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            Text("Weekly Schedule — tap to toggle")
        } footer: {
            Text("Blue = training day · Gray = rest day")
                .font(.caption2)
        }
    }

    // MARK: - Generate Button (Req 1.2)

    private var generateSection: some View {
        Section {
            Button {
                Task {
                    await viewModel.generatePlan()
                }
            } label: {
                HStack {
                    Spacer()
                    if viewModel.isGenerating {
                        ProgressView()
                            .padding(.trailing, 8)
                    }
                    Text(viewModel.isGenerating ? "Generating..." : "Generate Plan")
                        .fontWeight(.semibold)
                    Spacer()
                }
            }
            .disabled(viewModel.isGenerating)
            .accessibilityLabel(viewModel.isGenerating ? "Generating plan" : "Generate training plan")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Error: \(error)")
            }
        }
    }
}
