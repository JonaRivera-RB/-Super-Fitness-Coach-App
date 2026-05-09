//
//  WatchWorkoutView.swift
//  Super Fitness Coach Watch App
//

import SwiftUI

struct WatchWorkoutView: View {
    @ObservedObject var sessionManager: WatchSessionManager
    @State private var exercises: [WatchExercise] = []

    var body: some View {
        List {
            ForEach(exercises.indices, id: \.self) { index in
                Button {
                    markCompleted(at: index)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(exercises[index].name)
                                .font(.footnote)
                                .fontWeight(.medium)
                                .lineLimit(2)
                            Text("\(exercises[index].sets)×\(exercises[index].reps)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if exercises[index].isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .disabled(exercises[index].isCompleted)
            }
        }
        .navigationTitle("Workout")
        .onAppear {
            exercises = sessionManager.exercises
        }
    }

    private func markCompleted(at index: Int) {
        guard index < exercises.count, !exercises[index].isCompleted else { return }

        exercises[index].isCompleted = true

        let update = WatchCompletionUpdate(
            exerciseId: exercises[index].id,
            sessionId: "", // Session ID is managed by the iOS app
            completedAt: Date()
        )
        sessionManager.sendExerciseCompletion(update)
    }
}
