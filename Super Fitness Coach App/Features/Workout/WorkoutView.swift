//
//  WorkoutView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct WorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    var imageLoader: ExerciseImageLoader?

    // Training plan integration
    var trainingPlanVM: TrainingPlanViewModel?
    var onNewTrainingPlan: (() -> Void)?
    var onStartTrainingWorkout: ((Int) -> Void)?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let planVM = trainingPlanVM, planVM.plan != nil {
                        trainingPlanSection(planVM: planVM)
                    } else {
                        noPlanBanner
                    }

                    if !viewModel.exercises.isEmpty && !viewModel.isSessionComplete {
                        legacyWorkoutSection
                    } else if viewModel.isSessionComplete {
                        completionCard
                    }
                }
                .padding()
            }
            .navigationTitle("Workout")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            onNewTrainingPlan?()
                        } label: {
                            Label("New Training Plan", systemImage: "plus.circle")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("Workout options")
                    }
                }
            }
            .task {
                await viewModel.loadSession()
            }
        }
    }

    // MARK: - No Plan Banner

    private var noPlanBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36))
                .foregroundStyle(.blue)

            Text("No training plan yet")
                .font(.headline)

            Text("Create a personalized plan based on your goals, available days, and priority muscles.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                onNewTrainingPlan?()
            } label: {
                Label("Create Training Plan", systemImage: "plus")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
        .accessibilityElement(children: .contain)
    }

    // MARK: - Training Plan Section

    private func trainingPlanSection(planVM: TrainingPlanViewModel) -> some View {
        VStack(spacing: 14) {
            // Week progress header
            weekProgressHeader(planVM: planVM)

            // Today's workout card or rest day
            todayCard(planVM: planVM)

            // Week overview (compact day pills)
            weekOverview(planVM: planVM)
        }
    }

    // MARK: - Week Progress Header

    private func weekProgressHeader(planVM: TrainingPlanViewModel) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(planVM.progressText)
                        .font(.title3)
                        .fontWeight(.bold)
                    Text(weekPhaseLabel(planVM: planVM))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                // Completed days this week
                let completed = planVM.currentWeekDays.filter { $0.dayStatus == .completed }.count
                let training = planVM.currentWeekDays.filter { !$0.isRestDay }.count
                Text("\(completed)/\(training)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.green)
                    .accessibilityLabel("\(completed) of \(training) workouts completed this week")
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray4)).frame(height: 6)
                    Capsule().fill(Color.blue)
                        .frame(width: geo.size.width * planVM.progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.07)))
    }

    // MARK: - Today Card

    private func todayCard(planVM: TrainingPlanViewModel) -> some View {
        let todayIndex = findTodayIndex(planVM: planVM)

        return Group {
            if let idx = todayIndex {
                let day = planVM.currentWeekDays[idx]
                if day.isRestDay {
                    restDayCard
                } else if day.dayStatus == .completed {
                    dayCompletedCard(day: day)
                } else {
                    todayWorkoutCard(day: day, dayIndex: idx, planVM: planVM)
                }
            } else {
                // All days done or no matching day
                allDoneCard
            }
        }
    }

    private func todayWorkoutCard(day: TrainingDayPlan, dayIndex: Int, planVM: TrainingPlanViewModel) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Workout")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(day.muscleGroups, id: \.self) { group in
                            Text(group.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("exercises")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            // Exercise preview list (compact)
            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? Color.orange : Color.blue.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(exercise.name)
                            .font(.subheadline)
                            .lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets)×\(exercise.reps)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    if exercise.id != day.exercises.prefix(4).last?.id {
                        Divider()
                    }
                }
                if day.exercises.count > 4 {
                    Text("+\(day.exercises.count - 4) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            // Start workout button
            Button {
                onStartTrainingWorkout?(dayIndex)
            } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.green)

            // Skip / Reschedule row
            HStack(spacing: 12) {
                Button {
                    planVM.skipDay(at: dayIndex)
                } label: {
                    Label("Skip", systemImage: "forward.fill")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)
                .tint(.orange)
                .controlSize(.small)

                if planVM.canReschedule(at: dayIndex) {
                    Button {
                        planVM.rescheduleDay(at: dayIndex)
                    } label: {
                        Label("Reschedule", systemImage: "arrow.uturn.right")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)
                    .controlSize(.small)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: .green.opacity(0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill")
                .font(.system(size: 36))
                .foregroundStyle(.purple)
            Text("Rest Day")
                .font(.title3)
                .fontWeight(.bold)
            Text("Your body recovers and grows stronger on rest days. Enjoy it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple.opacity(0.07)))
    }

    private func dayCompletedCard(day: TrainingDayPlan) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 36))
                .foregroundStyle(.green)
            Text("Today's workout done")
                .font(.headline)
            Text(day.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " & "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.07)))
    }

    private var allDoneCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 36))
                .foregroundStyle(.yellow)
            Text("Week complete")
                .font(.headline)
            Text("All workouts for this week are done. Great job.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.yellow.opacity(0.07)))
    }

    // MARK: - Week Overview (Day Pills)

    private func weekOverview(planVM: TrainingPlanViewModel) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week")
                .font(.headline)

            HStack(spacing: 6) {
                ForEach(Array(planVM.currentWeekDays.enumerated()), id: \.offset) { idx, day in
                    dayPill(day: day, index: idx, planVM: planVM)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func dayPill(day: TrainingDayPlan, index: Int, planVM: TrainingPlanViewModel) -> some View {
        let isToday = index == findTodayIndex(planVM: planVM)

        return VStack(spacing: 4) {
            Text(shortDayLabel(day.dayOfWeek))
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(dayPillColor(day))
                    .frame(width: 32, height: 32)

                if day.isRestDay {
                    Image(systemName: "moon.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.8))
                } else {
                    dayPillIcon(day)
                }
            }

            if !day.isRestDay && !day.muscleGroups.isEmpty {
                Text(day.muscleGroups.first?.rawValue.prefix(3).capitalized ?? "")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isToday ? Color.blue.opacity(0.08) : Color.clear)
        )
        .accessibilityLabel(dayAccessibility(day: day, isToday: isToday))
    }

    @ViewBuilder
    private func dayPillIcon(_ day: TrainingDayPlan) -> some View {
        switch day.dayStatus {
        case .completed:
            Image(systemName: "checkmark")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        case .skipped:
            Image(systemName: "forward.fill")
                .font(.system(size: 8))
                .foregroundStyle(.white)
        case .rescheduled:
            Image(systemName: "arrow.uturn.right")
                .font(.system(size: 8))
                .foregroundStyle(.white)
        case .pending:
            Text("\(day.exercises.count)")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.white)
        }
    }

    // MARK: - Legacy Workout Section

    private var legacyWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Workout")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let label = viewModel.adjustmentLabel {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                    Text(label)
                        .font(.caption)
                }
                .foregroundStyle(.orange)
            }

            ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                legacyExerciseRow(exercise: exercise, index: index)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func legacyExerciseRow(exercise: SessionExercise, index: Int) -> some View {
        HStack {
            Circle()
                .fill(exercise.isCompleted ? Color.green : (index == viewModel.currentExerciseIndex ? Color.blue : Color.gray.opacity(0.3)))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name.capitalized)
                    .font(.subheadline)
                    .fontWeight(index == viewModel.currentExerciseIndex ? .semibold : .regular)
                    .strikethrough(exercise.isCompleted)
                Text("\(exercise.sets)×\(exercise.reps) · \(exercise.target.capitalized)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if exercise.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else if index == viewModel.currentExerciseIndex {
                Button("Done") {
                    Task { await viewModel.completeExercise(at: index) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
                .tint(.green)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Completion Card

    private var completionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green)
            Text("Workout Complete")
                .font(.title2)
                .fontWeight(.bold)
            Text("+20 points earned")
                .font(.subheadline)
                .foregroundStyle(.orange)
                .fontWeight(.medium)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.07)))
    }

    // MARK: - Helpers

    private func findTodayIndex(planVM: TrainingPlanViewModel) -> Int? {
        // Find first pending non-rest day, or first pending day
        if let idx = planVM.currentWeekDays.firstIndex(where: { $0.dayStatus == .pending && !$0.isRestDay }) {
            return idx
        }
        return planVM.currentWeekDays.firstIndex(where: { $0.dayStatus == .pending })
    }

    private func weekPhaseLabel(planVM: TrainingPlanViewModel) -> String {
        let progression = WeeklyProgressionEngine.progression(for: planVM.currentWeek)
        switch progression.weekInCycle {
        case 1: return "Base week"
        case 2: return "+5% weight week"
        case 3: return "+10% volume week"
        case 4: return "Deload week"
        default: return ""
        }
    }

    private func shortDayLabel(_ dayOfWeek: Int) -> String {
        switch dayOfWeek {
        case 1: return "M"
        case 2: return "T"
        case 3: return "W"
        case 4: return "T"
        case 5: return "F"
        case 6: return "S"
        case 7: return "S"
        default: return "?"
        }
    }

    private func dayPillColor(_ day: TrainingDayPlan) -> Color {
        if day.isRestDay { return .purple.opacity(0.5) }
        switch day.dayStatus {
        case .completed: return .green
        case .skipped: return .orange
        case .rescheduled: return .blue
        case .pending: return .gray.opacity(0.4)
        }
    }

    private func dayAccessibility(day: TrainingDayPlan, isToday: Bool) -> String {
        let todayLabel = isToday ? "Today, " : ""
        let muscles = day.muscleGroups.map { $0.rawValue }.joined(separator: " and ")
        return "\(todayLabel)\(day.isRestDay ? "Rest day" : muscles), \(day.dayStatus.rawValue)"
    }
}
