//
//  WorkoutExecutorView.swift
//  Super Fitness Coach App
//

import SwiftUI

/// Workout execution screen inspired by Strong/Hevy:
/// - One exercise at a time with all sets visible
/// - Tap-to-log with pre-filled weights from plan
/// - Integrated rest timer
/// - Auto-advance on completion
struct WorkoutExecutorView: View {
    @Bindable var viewModel: WorkoutExecutorViewModel
    @Environment(\.dismiss) private var dismiss

    var onWorkoutComplete: (([WorkoutLog]) -> Void)?

    @State private var weightInputs: [[String]] = []
    @State private var repsInputs: [[String]] = []
    @State private var showFeedback = false
    @State private var showExerciseDetail = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                exerciseProgressBar

                if !viewModel.exercises.isEmpty && !viewModel.isWorkoutComplete {
                    coachBanner
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }

                if viewModel.isWorkoutComplete {
                    workoutCompleteScreen
                } else if viewModel.exercises.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text("No hay ejercicios")
                            .font(.headline)
                        Text("No se pudieron cargar ejercicios para hoy. Revisa tu plan o rutina.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            exerciseHeader
                            setsTable
                            restTimerBanner
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Entreno")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(viewModel.currentExerciseIndex + 1) / \(viewModel.exercises.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
            }
            .onAppear {
                viewModel.buildDailyExercises()
                // Wait for exercises to be built before initializing inputs
                if !viewModel.exercises.isEmpty {
                    buildInputs()
                }
            }
            .onChange(of: viewModel.exercises.count) { _, count in
                if count > 0 {
                    buildInputs()
                }
            }
            .onDisappear {
                viewModel.stopRestTimer()
            }
            .onChange(of: viewModel.isWorkoutComplete) { _, complete in
                if complete {
                    onWorkoutComplete?(viewModel.completedLogs)
                }
            }
            .onChange(of: viewModel.currentExerciseIndex) { _, _ in
                // Scroll to top when exercise changes
            }
        }
    }

    // MARK: - Workout Complete Screen

    private var workoutCompleteScreen: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(.yellow)
            Text("¡Workout completado!")
                .font(.title).fontWeight(.bold)
            Text("\(viewModel.exercises.count) ejercicios · \(viewModel.completedLogs.flatMap(\.sets).count) sets")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
            VStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Label("Ver resumen", systemImage: "chart.bar.fill")
                        .fontWeight(.semibold).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).controlSize(.large)

                Button("Cerrar") { dismiss() }
                    .buttonStyle(.bordered).controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Coach (gym)

    private func coachAccessibilitySummary(exercise: PlannedExercise?) -> String {
        var parts: [String] = []
        if !viewModel.gymCoachMessage.isEmpty {
            parts.append(viewModel.gymCoachMessage)
        }
        if viewModel.isRestTimerActive, let ex = exercise {
            parts.append(GymCoach.restFocus(exercise: ex, restSecondsRemaining: viewModel.restTimerSeconds))
        }
        return parts.joined(separator: " ")
    }

    private var coachBanner: some View {
        let idx = viewModel.currentExerciseIndex
        let exercise = viewModel.exercises.indices.contains(idx) ? viewModel.exercises[idx] : nil

        return Group {
            if !viewModel.gymCoachMessage.isEmpty || viewModel.isRestTimerActive {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundStyle(.teal)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 6) {
                        if !viewModel.gymCoachMessage.isEmpty {
                            Text(viewModel.gymCoachMessage)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if viewModel.isRestTimerActive, let ex = exercise {
                            Text(GymCoach.restFocus(exercise: ex, restSecondsRemaining: viewModel.restTimerSeconds))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14).fill(Color.teal.opacity(0.1)))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(coachAccessibilitySummary(exercise: exercise))
            }
        }
    }

    // MARK: - Progress Bar

    private var exerciseProgressBar: some View {
        GeometryReader { geo in
            let total = max(viewModel.exercises.count, 1)
            let completed = viewModel.exercises.indices.filter { idx in
                viewModel.completedSets.indices.contains(idx) &&
                viewModel.completedSets[idx].allSatisfy { $0 }
            }.count
            let fraction = CGFloat(completed) / CGFloat(total)

            ZStack(alignment: .leading) {
                Rectangle().fill(Color(.systemGray5))
                Rectangle().fill(Color.green)
                    .frame(width: geo.size.width * fraction)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        let exercise = viewModel.exercises[viewModel.currentExerciseIndex]

        return VStack(spacing: 8) {
            Button {
                showExerciseDetail = true
            } label: {
                VStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Ver detalle")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showExerciseDetail) {
                ExerciseDetailView(exercise: exercise)
            }

            if let cap = targetWeightCaption(exercise) {
                Text(cap)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(exercise.muscleGroup.rawValue.capitalized, systemImage: "figure.strengthtraining.traditional")
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.blue.opacity(0.1)))

                if exercise.isCompound {
                    Text("Compound")
                        .font(.caption)
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Color.orange.opacity(0.1)))
                }

                if !exercise.equipment.isEmpty {
                    Label(exercise.equipment, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Sets Table (Strong-style)

    private var setsTable: some View {
        let exerciseIdx = viewModel.currentExerciseIndex
        let exercise = viewModel.exercises[exerciseIdx]

        return VStack(spacing: 0) {
            // Table header
            HStack {
                Text("SET")
                    .frame(width: 36, alignment: .leading)
                Text("PREVIOUS")
                    .frame(maxWidth: .infinity, alignment: .center)
                Text("KG")
                    .frame(width: 70, alignment: .center)
                Text("REPS")
                    .frame(width: 60, alignment: .center)
                Text("")
                    .frame(width: 40)
            }
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Set rows
            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                setRow(exerciseIndex: exerciseIdx, setIndex: setIndex, exercise: exercise)
                if setIndex < exercise.sets - 1 {
                    Divider().padding(.horizontal, 12)
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func setRow(exerciseIndex: Int, setIndex: Int, exercise: PlannedExercise) -> some View {
        let isCompleted = viewModel.completedSets[safe: exerciseIndex]?[safe: setIndex] ?? false

        return HStack(spacing: 0) {
            // Set number
            Text("\(setIndex + 1)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(isCompleted ? .green : .primary)
                .frame(width: 36, alignment: .leading)

            // Previous (suggested weight × reps)
            Text(viewModel.previousDisplay(catalogExerciseId: exercise.effectiveCatalogId, setIndex: setIndex))
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            // Weight input
            TextField("0", text: weightBinding(exerciseIndex: exerciseIndex, setIndex: setIndex))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 70)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground)))
                .disabled(isCompleted)
                .accessibilityLabel("Weight for set \(setIndex + 1)")

            // Reps input
            TextField("0", text: repsBinding(exerciseIndex: exerciseIndex, setIndex: setIndex))
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 60)
                .padding(.vertical, 6)
                .background(RoundedRectangle(cornerRadius: 6).fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground)))
                .disabled(isCompleted)
                .accessibilityLabel("Reps for set \(setIndex + 1)")

            // Check button
            Button {
                completeSetAction(exerciseIndex: exerciseIndex, setIndex: setIndex)
            } label: {
                HStack(spacing: 6) {
                    if isCompleted && (viewModel.prSets[safe: exerciseIndex]?[safe: setIndex] ?? false) {
                        Text("PR")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Color.purple))
                    }
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title3)
                        .foregroundStyle(isCompleted ? .green : .gray.opacity(0.4))
                }
            }
            .disabled(isCompleted)
            .frame(width: 40)
            .accessibilityLabel(isCompleted ? "Set \(setIndex + 1) done" : "Complete set \(setIndex + 1)")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isCompleted ? Color.green.opacity(0.03) : Color.clear)
    }

    // MARK: - Rest Timer Banner

    @ViewBuilder
    private var restTimerBanner: some View {
        if viewModel.isRestTimerActive {
            HStack {
                Image(systemName: "timer")
                    .foregroundStyle(.blue)
                Text("Descanso")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(viewModel.restTimerSeconds)s")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.blue)
                    .monospacedDigit()
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.blue.opacity(0.08)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Descanso, \(viewModel.restTimerSeconds) segundos")
        }
    }

    private func targetWeightCaption(_ exercise: PlannedExercise) -> String? {
        let minW = exercise.suggestedWeight
        if let maxW = exercise.targetWeightMax, maxW > minW + 0.01 {
            return String(format: "Objetivo: %.0f–%.0f kg", minW, maxW)
        }
        if minW > 0 {
            return String(format: "Objetivo: %.0f kg", minW)
        }
        return nil
    }

    // MARK: - Actions

    private func completeSetAction(exerciseIndex: Int, setIndex: Int) {
        let weight = Double(weightInputs[safe: exerciseIndex]?[safe: setIndex] ?? "0") ?? 0
        let reps = Int(repsInputs[safe: exerciseIndex]?[safe: setIndex] ?? "0") ?? 0
        viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weight, reps: reps)
    }

    // MARK: - Input Management

    private func buildInputs() {
        weightInputs = viewModel.exercises.map { ex in
            (0..<ex.sets).map { idx in
                String(format: "%.0f", viewModel.defaultWeight(exercise: ex, setIndex: idx))
            }
        }
        repsInputs = viewModel.exercises.map { ex in
            (0..<ex.sets).map { idx in
                "\(viewModel.defaultReps(exercise: ex, setIndex: idx))"
            }
        }
    }

    private func weightBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { weightInputs[safe: exerciseIndex]?[safe: setIndex] ?? "" },
            set: { val in
                guard exerciseIndex < weightInputs.count, setIndex < weightInputs[exerciseIndex].count else { return }
                weightInputs[exerciseIndex][setIndex] = val
            }
        )
    }

    private func repsBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { repsInputs[safe: exerciseIndex]?[safe: setIndex] ?? "" },
            set: { val in
                guard exerciseIndex < repsInputs.count, setIndex < repsInputs[exerciseIndex].count else { return }
                repsInputs[exerciseIndex][setIndex] = val
            }
        )
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
