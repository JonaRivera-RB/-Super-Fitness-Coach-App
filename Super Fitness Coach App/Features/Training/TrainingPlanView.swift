//
//  TrainingPlanView.swift
//  Super Fitness Coach App
//

import SwiftUI
import UIKit

/// Full-screen training plan view — shows all 7 days of the current week
/// with statuses, actions, and progress. Used as a detail view when the user
/// wants to see the full week at a glance.
struct TrainingPlanView: View {
    @Bindable var viewModel: TrainingPlanViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showReEngagementAlert = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("Loading plan...")
            } else if viewModel.plan == nil {
                noPlanView
            } else {
                planContent
            }
        }
        .onChange(of: viewModel.showReEngagement) { _, show in
            if show { showReEngagementAlert = true }
        }
        .alert("Don't give up!", isPresented: $showReEngagementAlert) {
            Button("Continue", role: .cancel) { }
        } message: {
            Text("You've skipped \(viewModel.consecutiveSkipped) days in a row. Get back on track!")
        }
    }

    // MARK: - No Plan

    private var noPlanView: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No active plan")
                .font(.title3).fontWeight(.medium)
            Text("Create a training plan to get started.")
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }

    // MARK: - Plan Content

    private var planContent: some View {
        ScrollView {
            VStack(spacing: 16) {
                progressHeader
                weekDaysList
                if let error = viewModel.errorMessage {
                    Text(error).font(.caption).foregroundStyle(.red).padding(.horizontal)
                }
            }
            .padding()
        }
    }

    // MARK: - Progress Header

    private var progressHeader: some View {
        VStack(spacing: 8) {
            HStack {
                Text(viewModel.progressText)
                    .font(.title3).fontWeight(.bold)
                Spacer()
                let completed = viewModel.currentWeekDays.filter { $0.dayStatus == .completed }.count
                let training = viewModel.currentWeekDays.filter { !$0.isRestDay && $0.dayStatus != .unavailable }.count
                Text("\(completed)/\(training)")
                    .font(.headline).foregroundStyle(.green)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray4)).frame(height: 6)
                    Capsule().fill(AppSemanticPalette.systemBlue)
                        .frame(width: geo.size.width * viewModel.progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppSemanticPalette.workoutWeekProgressBlue(colorScheme)))
    }

    // MARK: - Week Days List

    private var weekDaysList: some View {
        VStack(spacing: 10) {
            ForEach(Array(viewModel.currentWeekDays.enumerated()), id: \.offset) { index, day in
                dayCard(day: day, index: index)
            }
        }
    }

    private func dayCard(day: TrainingDayPlan, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(dayName(day.dayOfWeek))
                    .font(.headline)
                    .foregroundStyle(day.dayStatus == .unavailable ? .secondary : .primary)
                Spacer()
                statusBadge(day)
            }

            if day.dayStatus == .unavailable {
                Text("Not available")
                    .font(.caption).foregroundStyle(.secondary)
            } else if day.isRestDay {
                HStack(spacing: 6) {
                    Image(systemName: "moon.zzz.fill").foregroundStyle(.purple)
                    Text("Rest Day").font(.subheadline).foregroundStyle(.secondary)
                }
            } else {
                Text(day.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: ", "))
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if !day.isRestDay && day.dayStatus == .pending {
                dayActions(index: index)
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(cardColor(day))
        )
        .opacity(day.dayStatus == .unavailable ? 0.5 : 1.0)
    }

    private func statusBadge(_ day: TrainingDayPlan) -> some View {
        let (icon, color) = statusStyle(day)
        return HStack(spacing: 4) {
            Text(icon).font(.caption)
            Text(day.dayStatus.rawValue.capitalized)
                .font(.caption).fontWeight(.medium)
        }
        .padding(.horizontal, 8).padding(.vertical, 3)
        .background(Capsule().fill(color.opacity(0.15)))
        .foregroundStyle(color)
    }

    private func dayActions(index: Int) -> some View {
        HStack(spacing: 10) {
            Button {
                viewModel.completeDay(at: index)
            } label: {
                Label("Complete", systemImage: "checkmark.circle.fill")
                    .font(.caption).fontWeight(.medium)
            }
            .buttonStyle(.borderedProminent).tint(.green).controlSize(.mini)

            Button {
                viewModel.skipDay(at: index)
            } label: {
                Label("Skip", systemImage: "forward.fill")
                    .font(.caption).fontWeight(.medium)
            }
            .buttonStyle(.bordered).tint(.orange).controlSize(.mini)

            if viewModel.canReschedule(at: index) {
                Button {
                    viewModel.rescheduleDay(at: index)
                } label: {
                    Label("Reschedule", systemImage: "arrow.uturn.right")
                        .font(.caption).fontWeight(.medium)
                }
                .buttonStyle(.bordered).tint(AppSemanticPalette.systemBlue).controlSize(.mini)
            }
        }
    }

    // MARK: - Helpers

    private func dayName(_ dow: Int) -> String {
        ["Monday","Tuesday","Wednesday","Thursday","Friday","Saturday","Sunday"][safe: dow - 1] ?? "Day \(dow)"
    }

    private func statusStyle(_ day: TrainingDayPlan) -> (String, Color) {
        if day.isRestDay { return ("🌙", .purple) }
        switch day.dayStatus {
        case .pending:     return ("⏳", .gray)
        case .completed:   return ("✓", .green)
        case .skipped:     return ("⏭", .orange)
        case .rescheduled: return ("🔄", AppSemanticPalette.systemBlue)
        case .unavailable: return ("—", .gray)
        }
    }

    private func cardColor(_ day: TrainingDayPlan) -> Color {
        if day.dayStatus == .unavailable { return Color(.systemGray6).opacity(0.5) }
        if day.isRestDay { return Color.purple.opacity(0.06) }
        switch day.dayStatus {
        case .completed:   return Color.green.opacity(0.08)
        case .skipped:     return Color.orange.opacity(0.08)
        case .rescheduled: return AppSemanticPalette.tintedFill(.systemBlue, colorScheme, light: 0.08, dark: 0.24)
        default:           return Color(.systemGray6)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
