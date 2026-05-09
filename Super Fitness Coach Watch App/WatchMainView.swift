//
//  WatchMainView.swift
//  Super Fitness Coach Watch App
//

import SwiftUI

struct WatchMainView: View {
    @ObservedObject var sessionManager: WatchSessionManager

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                // Recovery Score
                Text("\(sessionManager.recoveryScore)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(scoreColor)

                // Status Indicator
                Text(statusLabel)
                    .font(.caption)
                    .foregroundStyle(scoreColor)

                Divider()

                // Start Workout
                if !sessionManager.exercises.isEmpty {
                    NavigationLink {
                        WatchWorkoutView(sessionManager: sessionManager)
                    } label: {
                        Label("Start Workout", systemImage: "figure.run")
                            .font(.footnote)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(scoreColor)
                } else {
                    Text("No workout synced")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .navigationTitle("Coach")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var scoreColor: Color {
        switch sessionManager.statusIndicator.lowercased() {
        case "red": return .red
        case "green": return .green
        default: return .yellow
        }
    }

    private var statusLabel: String {
        switch sessionManager.statusIndicator.lowercased() {
        case "red": return "🔴 Fatigued"
        case "green": return "🟢 Optimal"
        default: return "🟡 Medium"
        }
    }
}
