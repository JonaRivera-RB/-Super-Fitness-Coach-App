//
//  WorkoutView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData

struct WorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    var imageLoader: ExerciseImageLoader?
    var trainingPlanVM: TrainingPlanViewModel?
    var onNewTrainingPlan: (() -> Void)?
    var onStartTrainingWorkout: ((Int) -> Void)?

    // @Query observes SwiftData directly — always hydrated, no timing issues
    @Query(
        filter: #Predicate<TrainingPlan> { $0.planStatusRaw == "active" },
        sort: \TrainingPlan.createdAt,
        order: .reverse
    ) private var activePlans: [TrainingPlan]

    private var activePlan: TrainingPlan? { activePlans.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let plan = activePlan {
                        trainingPlanSection(plan: plan)
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
            .task { await viewModel.loadSession() }
        }
    }

    // MARK: - No Plan Banner

    private var noPlanBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36)).foregroundStyle(.blue)
            Text("No training plan yet").font(.headline)
            Text("Create a personalized plan based on your goals, available days, and priority muscles.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { onNewTrainingPlan?() } label: {
                Label("Create Training Plan", systemImage: "plus")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }

    // MARK: - Training Plan Section

    private func trainingPlanSection(plan: TrainingPlan) -> some View {
        let weekIndex = plan.currentWeek - 1
        let currentWeekDays: [TrainingDayPlan] = weekIndex >= 0 && weekIndex < plan.weeks.count
            ? plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
            : []

        return VStack(spacing: 14) {
            weekProgressHeader(plan: plan, days: currentWeekDays)
            todayCard(plan: plan, days: currentWeekDays)
            weekOverview(plan: plan, days: currentWeekDays)
        }
        .id("\(plan.id)-\(currentWeekDays.map(\.dayStatusRaw).joined())")
    }

    // MARK: - Week Progress Header

    private func weekProgressHeader(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        let completed = days.filter { !$0.isRestDay && $0.dayStatus == .completed }.count
        let training = days.filter { !$0.isRestDay }.count
        let totalWeeks = plan.preferences.planDurationWeeks
        let currentWeek = plan.currentWeek
        let progressText = totalWeeks > 0 ? "Semana \(currentWeek) / \(totalWeeks)" : ""
        let progressFraction = totalWeeks > 0 ? Double(currentWeek) / Double(totalWeeks) : 0
        let p = WeeklyProgressionEngine.progression(for: currentWeek)
        let phaseLabel: String
        switch p.weekInCycle {
        case 1: phaseLabel = "Base week"
        case 2: phaseLabel = "+5% weight week"
        case 3: phaseLabel = "+10% volume week"
        case 4: phaseLabel = "Deload week"
        default: phaseLabel = ""
        }

        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressText).font(.title3).fontWeight(.bold)
                    Text(phaseLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completed)/\(training)")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.green)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray4)).frame(height: 6)
                    Capsule().fill(Color.blue)
                        .frame(width: geo.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.07)))
    }

    // MARK: - Today Card

    @ViewBuilder
    private func todayCard(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        let today = todayDayOfWeek
        let todayPlanIndex = days.firstIndex(where: { $0.dayOfWeek == today })
        let todayStatus: DayStatus? = todayPlanIndex.map { days[$0].dayStatus }

        if todayStatus == .skipped {
            skippedDayCard
        } else if todayStatus == .completed {
            dayCompletedCard(day: days[todayPlanIndex!])
        } else {
            let displayIndex = resolveDisplayIndex(days: days, todayPlanIndex: todayPlanIndex, today: today)
            if let idx = displayIndex {
                let day = days[idx]
                if day.isRestDay {
                    restDayCard
                } else if day.dayStatus == .completed {
                    dayCompletedCard(day: day)
                } else {
                    todayWorkoutCard(day: day, dayIndex: idx, isActuallyToday: day.dayOfWeek == today)
                }
            } else if days.contains(where: { !$0.isRestDay && $0.dayStatus == .pending }) {
                noWorkoutTodayCard
            } else {
                weekCompleteCard(days: days)
            }
        }
    }

    private var todayDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private func resolveDisplayIndex(days: [TrainingDayPlan], todayPlanIndex: Int?, today: Int) -> Int? {
        if let idx = todayPlanIndex {
            let day = days[idx]
            if day.isRestDay { return idx }
            if day.dayStatus == .pending { return idx }
            if day.dayStatus == .completed { return idx }
        }
        // Find next pending training day after today
        return days.indices.first { i in
            !days[i].isRestDay && days[i].dayStatus == .pending && days[i].dayOfWeek > today
        }
    }

    private func todayWorkoutCard(day: TrainingDayPlan, dayIndex: Int, isActuallyToday: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isActuallyToday ? "Today's Workout" : "Next Workout — \(shortDayLabel(day.dayOfWeek))")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(day.muscleGroups, id: \.self) { group in
                            Text(group.rawValue.capitalized)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)").font(.title2).fontWeight(.bold)
                    Text("exercises").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? Color.orange : Color.blue.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(exercise.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets)×\(exercise.reps)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    if exercise.id != day.exercises.prefix(4).last?.id { Divider() }
                }
                if day.exercises.count > 4 {
                    Text("+\(day.exercises.count - 4) more")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }

            Button { onStartTrainingWorkout?(dayIndex) } label: {
                Label("Start Workout", systemImage: "play.fill")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(.green)

            if isActuallyToday {
                HStack(spacing: 12) {
                    Button { trainingPlanVM?.skipDay(at: dayIndex) } label: {
                        Label("Skip Today", systemImage: "forward.fill").font(.subheadline)
                    }
                    .buttonStyle(.bordered).tint(.orange).controlSize(.small)

                    if trainingPlanVM?.canReschedule(at: dayIndex) == true {
                        Button { trainingPlanVM?.rescheduleDay(at: dayIndex) } label: {
                            Label("Reschedule", systemImage: "arrow.uturn.right").font(.subheadline)
                        }
                        .buttonStyle(.bordered).tint(.blue).controlSize(.small)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: .green.opacity(0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 36)).foregroundStyle(.purple)
            Text("Rest Day").font(.title3).fontWeight(.bold)
            Text("Your body recovers and grows stronger on rest days.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple.opacity(0.07)))
    }

    private func dayCompletedCard(day: TrainingDayPlan) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(.green)
            Text("Today's workout done").font(.headline)
            Text(day.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " & "))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.07)))
    }

    private var noWorkoutTodayCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 36)).foregroundStyle(.blue)
            Text("No workout today").font(.headline)
            Text("Your next training session is coming up. Check the week overview below.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.07)))
    }

    private var skippedDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 36)).foregroundStyle(.orange)
            Text("Workout bloqueado").font(.title3).fontWeight(.bold)
            Text("Saltaste el entrenamiento de hoy. Vuelve mañana para retomar tu plan.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    /// Week is only "complete" when ALL training days are completed (skipped ≠ complete).
    private func weekCompleteCard(days: [TrainingDayPlan]) -> some View {
        let trainingDays = days.filter { !$0.isRestDay }
        guard !trainingDays.isEmpty else {
            return AnyView(noWorkoutTodayCard)
        }
        let allCompleted = trainingDays.allSatisfy { $0.dayStatus == .completed }

        return AnyView(VStack(spacing: 10) {
            Image(systemName: allCompleted ? "trophy.fill" : "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(allCompleted ? .yellow : .orange)
            Text(allCompleted ? "Week complete! 🏆" : "No more workouts this week")
                .font(.headline)
            Text(allCompleted
                 ? "All workouts done. Great job!"
                 : "Some sessions were skipped. Keep going next week.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(allCompleted ? Color.yellow.opacity(0.07) : Color.orange.opacity(0.07))))
    }

    // MARK: - Week Overview

    private func weekOverview(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This Week").font(.headline)
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { idx, day in
                    dayPill(day: day)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func dayPill(day: TrainingDayPlan) -> some View {
        let today = todayDayOfWeek
        let status = day.dayStatus
        let isPast = day.dayOfWeek < today && status == .pending
        let isToday = day.dayOfWeek == today

        return VStack(spacing: 4) {
            Text(shortDayLabel(day.dayOfWeek))
                .font(.system(size: 9)).fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(isPast ? Color.gray.opacity(0.2) : pillColor(status: status, isRestDay: day.isRestDay))
                    .frame(width: 32, height: 32)
                pillIcon(status: status, isRestDay: day.isRestDay, isPast: isPast)
            }

            if !day.isRestDay && !day.muscleGroups.isEmpty && !isPast {
                Text(day.muscleGroups.first?.rawValue.prefix(3).capitalized ?? "")
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(isToday ? Color.blue.opacity(0.1) : Color.clear))
        .opacity(isPast ? 0.45 : 1.0)
    }

    @ViewBuilder
    private func pillIcon(status: DayStatus, isRestDay: Bool, isPast: Bool) -> some View {
        if isRestDay {
            Image(systemName: "moon.fill").font(.caption2).foregroundStyle(.white.opacity(0.8))
        } else if isPast {
            Image(systemName: "minus").font(.system(size: 8)).foregroundStyle(.gray)
        } else {
            switch status {
            case .completed:
                Image(systemName: "checkmark").font(.caption).fontWeight(.bold).foregroundStyle(.white)
            case .skipped:
                Image(systemName: "forward.fill").font(.system(size: 8)).foregroundStyle(.white)
            case .rescheduled:
                Image(systemName: "arrow.uturn.right").font(.system(size: 8)).foregroundStyle(.white)
            case .pending, .unavailable:
                EmptyView()
            }
        }
    }

    private func pillColor(status: DayStatus, isRestDay: Bool) -> Color {
        if isRestDay { return .purple.opacity(0.5) }
        switch status {
        case .completed:   return .green
        case .skipped:     return .orange
        case .rescheduled: return .blue
        case .pending, .unavailable: return .gray.opacity(0.4)
        }
    }

    // MARK: - Legacy Workout Section

    private var legacyWorkoutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Quick Workout").font(.headline)
                Spacer()
                Text("\(viewModel.completedCount)/\(viewModel.totalCount)")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            if let label = viewModel.adjustmentLabel {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                    Text(label).font(.caption)
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
                Text(exercise.name.capitalized).font(.subheadline)
                    .fontWeight(index == viewModel.currentExerciseIndex ? .semibold : .regular)
                    .strikethrough(exercise.isCompleted)
                Text("\(exercise.sets)×\(exercise.reps) · \(exercise.target.capitalized)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            if exercise.isCompleted {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else if index == viewModel.currentExerciseIndex {
                Button("Done") { Task { await viewModel.completeExercise(at: index) } }
                    .buttonStyle(.borderedProminent).controlSize(.mini).tint(.green)
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Completion Card

    private var completionCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 48)).foregroundStyle(.green)
            Text("Workout Complete").font(.title2).fontWeight(.bold)
            Text("+20 points earned").font(.subheadline).foregroundStyle(.orange).fontWeight(.medium)
        }
        .padding(24).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.07)))
    }

    // MARK: - Helpers

    private func shortDayLabel(_ dayOfWeek: Int) -> String {
        ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"][safe: dayOfWeek - 1] ?? "?"
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
