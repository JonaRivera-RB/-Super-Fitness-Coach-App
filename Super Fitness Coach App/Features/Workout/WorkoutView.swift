//
//  WorkoutView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct WorkoutView: View {
    @Bindable var viewModel: WorkoutViewModel
    var imageLoader: ExerciseImageLoader?

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading workout…")
                } else if viewModel.exercises.isEmpty {
                    emptyState
                } else if viewModel.isSessionComplete {
                    completionView
                } else {
                    workoutContent
                }
            }
            .navigationTitle(viewModel.workoutType.rawValue.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await viewModel.loadSession()
            }
        }
    }

    // MARK: - Workout Content

    private var workoutContent: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                progressHeader
                adjustmentBanner

                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(Array(viewModel.exercises.enumerated()), id: \.element.id) { index, exercise in
                            ExerciseCard(
                                exercise: exercise,
                                index: index,
                                isCurrent: index == viewModel.currentExerciseIndex,
                                imageLoader: imageLoader,
                                onComplete: {
                                    Task { await viewModel.completeExercise(at: index) }
                                }
                            )
                            .id(exercise.id)
                        }
                    }
                    .padding()
                }
            }
            .onChange(of: viewModel.currentExerciseIndex) { _, newIndex in
                guard newIndex < viewModel.exercises.count else { return }
                withAnimation {
                    proxy.scrollTo(viewModel.exercises[newIndex].id, anchor: .center)
                }
            }
            .onAppear {
                if viewModel.currentExerciseIndex < viewModel.exercises.count {
                    proxy.scrollTo(
                        viewModel.exercises[viewModel.currentExerciseIndex].id,
                        anchor: .center
                    )
                }
            }
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            ProgressView(value: viewModel.progressFraction)
                .tint(.green)

            Text("\(viewModel.completedCount) of \(viewModel.totalCount) exercises")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.completedCount) of \(viewModel.totalCount) exercises completed")
    }

    // MARK: - Adjustment Banner

    @ViewBuilder
    private var adjustmentBanner: some View {
        if let label = viewModel.adjustmentLabel {
            HStack {
                Image(systemName: "info.circle.fill")
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(.orange)
            .padding(.horizontal)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.1))
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "Rest Day",
            systemImage: "bed.double.fill",
            description: Text("No exercises scheduled for today. Enjoy your rest!")
        )
    }

    // MARK: - Completion View

    private var completionView: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green)

            Text("Workout Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("+20 points earned")
                .font(.headline)
                .foregroundStyle(.orange)

            Text("\(viewModel.completedCount) exercises finished")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Workout complete. \(viewModel.completedCount) exercises finished. 20 points earned.")
    }
}

// MARK: - Exercise Card

private struct ExerciseCard: View {
    let exercise: SessionExercise
    let index: Int
    let isCurrent: Bool
    var imageLoader: ExerciseImageLoader?
    let onComplete: () -> Void

    @State private var showInstructions = false
    @State private var exerciseImageData: Data?
    @State private var isLoadingImage = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Exercise media: GIF if available, otherwise icon header
            exerciseMedia

            // Exercise Info
            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name.capitalized)
                    .font(.headline)
                    .lineLimit(2)

                HStack(spacing: 12) {
                    Label(exercise.target.capitalized, systemImage: "figure.strengthtraining.traditional")
                    Label(exercise.equipment.capitalized, systemImage: "dumbbell.fill")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 16) {
                    Label("\(exercise.sets) sets", systemImage: "repeat")
                    Label("\(exercise.reps) reps", systemImage: "number")
                }
                .font(.subheadline)
                .fontWeight(.medium)
            }

            // Instructions toggle
            if !exercise.instructions.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showInstructions.toggle()
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "list.bullet")
                        Text(showInstructions ? "Hide Instructions" : "How to do it")
                            .font(.subheadline)
                        Spacer()
                        Image(systemName: showInstructions ? "chevron.up" : "chevron.down")
                            .font(.caption)
                    }
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showInstructions {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(exercise.instructions.enumerated()), id: \.offset) { step, instruction in
                            HStack(alignment: .top, spacing: 8) {
                                Text("\(step + 1).")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 20, alignment: .trailing)
                                Text(instruction)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }

            // Complete Button
            if exercise.isCompleted {
                Label("Completed", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Button(action: onComplete) {
                    Label("Mark Complete", systemImage: "checkmark")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(isCurrent ? .green : .blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemBackground))
                .shadow(color: isCurrent ? .green.opacity(0.3) : .black.opacity(0.08),
                        radius: isCurrent ? 8 : 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isCurrent ? Color.green : Color.clear, lineWidth: 2)
        )
        .opacity(exercise.isCompleted ? 0.7 : 1.0)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityDescription)
        .task {
            guard exerciseImageData == nil, let loader = imageLoader else { return }
            isLoadingImage = true
            exerciseImageData = await loader.loadImageData(exerciseId: exercise.id)
            isLoadingImage = false
        }
    }

    @ViewBuilder
    private var exerciseMedia: some View {
        if let data = exerciseImageData {
            AnimatedGIFView(data: data)
                .frame(maxHeight: 200)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if isLoadingImage {
            ProgressView()
                .frame(height: 120)
        } else {
            exerciseIconHeader
        }
    }

    private var exerciseIconHeader: some View {
        HStack(spacing: 12) {
            Image(systemName: exerciseIcon)
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 50, height: 50)
                .background(Color.blue.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.target.capitalized)
                    .font(.caption)
                    .foregroundStyle(.blue)
                    .fontWeight(.medium)
                Text(exercise.equipment.capitalized)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }

    private var exerciseIcon: String {
        switch exercise.target.lowercased() {
        case let t where t.contains("pectoral") || t.contains("chest"):
            return "figure.strengthtraining.traditional"
        case let t where t.contains("delt") || t.contains("shoulder"):
            return "figure.arms.open"
        case let t where t.contains("quad") || t.contains("hamstring") || t.contains("glute") || t.contains("calve"):
            return "figure.walk"
        case let t where t.contains("lat") || t.contains("back") || t.contains("trap"):
            return "figure.rowing"
        case let t where t.contains("bicep") || t.contains("tricep") || t.contains("forearm"):
            return "dumbbell.fill"
        case let t where t.contains("ab") || t.contains("core"):
            return "figure.core.training"
        case let t where t.contains("cardio"):
            return "figure.run"
        default:
            return "figure.mixed.cardio"
        }
    }

    private var accessibilityDescription: String {
        let status = exercise.isCompleted ? "Completed" : (isCurrent ? "Current exercise" : "")
        return "\(exercise.name), \(exercise.target), \(exercise.equipment), \(exercise.sets) sets, \(exercise.reps) reps. \(status)"
    }
}
