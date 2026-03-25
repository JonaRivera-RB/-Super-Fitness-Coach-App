//
//  TrainingPlanView.swift
//  Super Fitness Coach App
//

import SwiftUI

/// Vista del plan semanal de entrenamiento.
/// Muestra progreso del plan, días de la semana actual con estados,
/// acciones por día (completar, saltar, reprogramar) y alerta de re-engagement.
/// Validates: Requirements 14.1, 14.2, 14.3, 14.4, 10.1
struct TrainingPlanView: View {
    @Bindable var viewModel: TrainingPlanViewModel
    @State private var showReEngagementAlert = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Cargando plan...")
                        .accessibilityLabel("Loading training plan")
                } else if viewModel.plan == nil {
                    noPlanView
                } else {
                    planContent
                }
            }
            .navigationTitle("Training Plan")
            .onAppear {
                viewModel.loadPlan()
            }
            .onChange(of: viewModel.showReEngagement) { _, show in
                if show {
                    showReEngagementAlert = true
                }
            }
            .alert("¡No te rindas!", isPresented: $showReEngagementAlert) {
                Button("Continuar", role: .cancel) { }
            } message: {
                Text("Llevas \(viewModel.consecutiveSkipped) días sin entrenar. ¡Vuelve al plan y sigue avanzando!")
            }
        }
    }

    // MARK: - No Plan View

    private var noPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No active plan")
                .font(.title3)
                .fontWeight(.medium)
            Text("Generate a training plan to get started.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("No active training plan. Generate a plan to get started.")
    }

    // MARK: - Plan Content

    private var planContent: some View {
        ScrollView {
            VStack(spacing: 20) {
                progressHeader
                weekDaysList

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                        .accessibilityLabel("Error: \(error)")
                }
            }
            .padding()
        }
    }

    // MARK: - Progress Header (Req 14.4)

    private var progressHeader: some View {
        VStack(spacing: 10) {
            Text(viewModel.progressText)
                .font(.title2)
                .fontWeight(.bold)
                .accessibilityLabel("Week \(viewModel.currentWeek) of \(viewModel.totalWeeks)")

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray4))
                        .frame(height: 8)
                    Capsule()
                        .fill(Color.blue)
                        .frame(width: geo.size.width * viewModel.progressFraction, height: 8)
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel("Plan progress \(Int(viewModel.progressFraction * 100)) percent")
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.08))
        )
    }

    // MARK: - Week Days List (Req 14.2, 14.3)

    private var weekDaysList: some View {
        VStack(spacing: 12) {
            ForEach(Array(viewModel.currentWeekDays.enumerated()), id: \.offset) { index, day in
                dayCard(day: day, index: index)
            }
        }
    }

    // MARK: - Day Card

    private func dayCard(day: TrainingDayPlan, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayOfWeekLabel(day.dayOfWeek))
                    .font(.headline)

                Spacer()

                statusBadge(day.dayStatus)
            }

            if day.isRestDay {
                restDayIndicator
            } else {
                muscleGroupsLabel(day.muscleGroups)
            }

            if !day.isRestDay && day.dayStatus == .pending {
                dayActions(index: index)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(dayBackgroundColor(day))
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(dayAccessibilityLabel(day: day, index: index))
    }

    // MARK: - Status Badge (Req 14.2)

    private func statusBadge(_ status: DayStatus) -> some View {
        HStack(spacing: 4) {
            Text(statusIcon(status))
            Text(status.rawValue.capitalized)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor(status).opacity(0.15))
        )
        .foregroundStyle(statusColor(status))
        .accessibilityLabel("Status: \(status.rawValue)")
    }

    // MARK: - Rest Day Indicator (Req 14.3)

    private var restDayIndicator: some View {
        HStack(spacing: 6) {
            Image(systemName: "moon.zzz.fill")
                .foregroundStyle(.purple)
            Text("Rest Day")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Rest day")
    }

    // MARK: - Muscle Groups Label

    private func muscleGroupsLabel(_ groups: [MuscleGroup]) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.strengthtraining.traditional")
                .foregroundStyle(.blue)
                .font(.subheadline)
            Text(groups.map { $0.rawValue.capitalized }.joined(separator: ", "))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("Muscle groups: \(groups.map { $0.rawValue }.joined(separator: ", "))")
    }

    // MARK: - Day Actions (Req 10.1)

    private func dayActions(index: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                viewModel.completeDay(at: index)
            } label: {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)
            .controlSize(.small)
            .accessibilityLabel("Complete day")

            Button {
                viewModel.skipDay(at: index)
            } label: {
                Label("Skip", systemImage: "forward.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .controlSize(.small)
            .accessibilityLabel("Skip day")

            if viewModel.canReschedule(at: index) {
                Button {
                    viewModel.rescheduleDay(at: index)
                } label: {
                    Label("Reschedule", systemImage: "arrow.uturn.right")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .buttonStyle(.bordered)
                .tint(.blue)
                .controlSize(.small)
                .accessibilityLabel("Reschedule day")
            }
        }
        .padding(.top, 4)
    }

    // MARK: - Helpers

    private func dayOfWeekLabel(_ dayOfWeek: Int) -> String {
        switch dayOfWeek {
        case 1: return "Monday"
        case 2: return "Tuesday"
        case 3: return "Wednesday"
        case 4: return "Thursday"
        case 5: return "Friday"
        case 6: return "Saturday"
        case 7: return "Sunday"
        default: return "Day \(dayOfWeek)"
        }
    }

    private func statusIcon(_ status: DayStatus) -> String {
        switch status {
        case .pending: return "⏳"
        case .completed: return "✓"
        case .skipped: return "⏭"
        case .rescheduled: return "🔄"
        }
    }

    private func statusColor(_ status: DayStatus) -> Color {
        switch status {
        case .pending: return .gray
        case .completed: return .green
        case .skipped: return .orange
        case .rescheduled: return .blue
        }
    }

    private func dayBackgroundColor(_ day: TrainingDayPlan) -> Color {
        if day.isRestDay {
            return Color.purple.opacity(0.06)
        }
        switch day.dayStatus {
        case .completed: return Color.green.opacity(0.08)
        case .skipped: return Color.orange.opacity(0.08)
        case .rescheduled: return Color.blue.opacity(0.08)
        case .pending: return Color(.systemGray6)
        }
    }

    private func dayAccessibilityLabel(day: TrainingDayPlan, index: Int) -> String {
        let dayName = dayOfWeekLabel(day.dayOfWeek)
        if day.isRestDay {
            return "\(dayName), rest day, status \(day.dayStatus.rawValue)"
        }
        let muscles = day.muscleGroups.map { $0.rawValue }.joined(separator: " and ")
        return "\(dayName), \(muscles), status \(day.dayStatus.rawValue)"
    }
}
