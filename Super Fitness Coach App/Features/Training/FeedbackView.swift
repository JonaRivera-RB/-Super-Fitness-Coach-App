//
//  FeedbackView.swift
//  Super Fitness Coach App
//

import SwiftUI

/// Vista de feedback post-entrenamiento.
/// Muestra mejoras de peso por ejercicio, días consecutivos, indicador 🔼
/// y mensaje de bienvenida si es el primer entrenamiento.
/// Validates: Requirements 12.1, 12.2, 12.3, 12.4
struct FeedbackView: View {
    @Bindable var viewModel: FeedbackViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if viewModel.isFirstWorkout {
                        welcomeSection
                    } else {
                        improvingIndicator
                        weightImprovementsSection
                    }
                    consecutiveDaysSection
                }
                .padding()
            }
            .navigationTitle("Resumen del entreno")
            .onAppear {
                viewModel.loadFeedback()
            }
        }
    }

    // MARK: - Welcome Section (Req 12.4)

    private var welcomeSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(.system(size: 48))
                .foregroundStyle(.yellow)

            Text("Welcome to your first workout!")
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)

            Text("Great job completing your first session. Keep it up and you'll start seeing your progress here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome to your first workout. Great job completing your first session.")
    }

    // MARK: - Improving Indicator (Req 12.3)

    @ViewBuilder
    private var improvingIndicator: some View {
        if viewModel.hasImproving {
            HStack(spacing: 8) {
                Text("🔼")
                    .font(.title2)
                Text("You're improving!")
                    .font(.headline)
                    .foregroundStyle(.green)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.green.opacity(0.08))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You are improving")
        }
    }

    // MARK: - Weight Improvements (Req 12.1)

    private var weightImprovementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Progreso de peso (máx. por ejercicio)")
                .font(.headline)
                .accessibilityAddTraits(.isHeader)

            Text("Comparado con tu último día de entreno anterior para ese mismo movimiento (no es el volumen total).")
                .font(.caption)
                .foregroundStyle(.secondary)

            if viewModel.weightImprovements.isEmpty {
                Text("No hay datos de ejercicios.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(viewModel.weightImprovements.enumerated()), id: \.offset) { _, improvement in
                    improvementRow(exerciseName: improvement.exerciseName, delta: improvement.delta)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func improvementRow(exerciseName: String, delta: Double) -> some View {
        HStack {
            Text(exerciseName)
                .font(.subheadline)
                .lineLimit(1)

            Spacer()

            Text(deltaText(delta))
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(deltaColor(delta))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(exerciseName), \(deltaAccessibilityLabel(delta))")
    }

    // MARK: - Consecutive Days (Req 12.2)

    private var consecutiveDaysSection: some View {
        HStack(spacing: 12) {
            Image(systemName: "flame.fill")
                .font(.title2)
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(viewModel.consecutiveDays)")
                    .font(.title)
                    .fontWeight(.bold)
                Text("consecutive days")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.consecutiveDays) consecutive training days")
    }

    // MARK: - Helpers

    private func deltaText(_ delta: Double) -> String {
        if delta > 0 {
            return String(format: "+%.1f kg (máx.)", delta)
        } else if delta < 0 {
            return String(format: "%.1f kg (máx.)", delta)
        } else {
            return "Sin cambio (máx.)"
        }
    }

    private func deltaColor(_ delta: Double) -> Color {
        if delta > 0 { return .green }
        if delta < 0 { return .red }
        return .secondary
    }

    private func deltaAccessibilityLabel(_ delta: Double) -> String {
        if delta > 0 {
            return "increased by \(String(format: "%.1f", delta)) kilograms"
        } else if delta < 0 {
            return "decreased by \(String(format: "%.1f", abs(delta))) kilograms"
        } else {
            return "no change"
        }
    }
}
