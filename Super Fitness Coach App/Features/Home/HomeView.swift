//
//  HomeView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct HomeView: View {
    var viewModel: HomeViewModel
    var onStartRoutine: () -> Void
    @State private var showRecoveryBreakdown = false
    @State private var showActivityBreakdown = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    authorizationBanner
                    recoveryScoreSection
                    activityScoreSection
                    recommendationSection
                    pointsSection
                    if viewModel.detoxActive {
                        detoxProgressSection
                    }
                    startRoutineButton
                }
                .padding()
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle("Dashboard")
            .task {
                await viewModel.onAppear()
            }
        }
    }

    // MARK: - Authorization Banner

    @ViewBuilder
    private var authorizationBanner: some View {
        switch viewModel.authorizationStatus {
        case .denied:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text("Health data access denied. Open Settings to grant permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Health data access denied. Open Settings to grant permission.")
        case .unavailable:
            HStack(spacing: 8) {
                Image(systemName: "heart.slash")
                    .foregroundStyle(.secondary)
                Text("Health data is not available on this device.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Health data is not available on this device.")
        default:
            EmptyView()
        }
    }

    // MARK: - Recovery Score Section

    private var recoveryScoreSection: some View {
        VStack(spacing: 8) {
            Label("Recovery", systemImage: "bed.double.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            healthDataScoreView(
                status: viewModel.recoveryScore,
                color: recoveryColor,
                label: "Recovery score"
            )

            if viewModel.recoveryScore.isAvailable {
                HStack(spacing: 6) {
                    Text(viewModel.statusIndicator.emoji)
                    Text(viewModel.statusIndicator.label)
                        .font(.title3)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Status: \(viewModel.statusIndicator.label)")
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRecoveryBreakdown.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Details")
                        .font(.subheadline)
                    Image(systemName: showRecoveryBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if showRecoveryBreakdown, let breakdown = viewModel.recoveryBreakdown {
                breakdownView(breakdown: breakdown)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(recoveryColor.opacity(0.08))
        )
    }

    // MARK: - Activity Score Section

    private var activityScoreSection: some View {
        VStack(spacing: 8) {
            Label("Activity", systemImage: "figure.run")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            healthDataScoreView(
                status: viewModel.activityScore,
                color: activityColor,
                label: "Activity score"
            )

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showActivityBreakdown.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text("Details")
                        .font(.subheadline)
                    Image(systemName: showActivityBreakdown ? "chevron.up" : "chevron.down")
                        .font(.caption)
                }
                .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            if showActivityBreakdown, let breakdown = viewModel.activityBreakdown {
                breakdownView(breakdown: breakdown)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(activityColor.opacity(0.08))
        )
    }

    // MARK: - HealthDataStatus Score View

    @ViewBuilder
    private func healthDataScoreView(status: HealthDataStatus<Int>, color: Color, label: String) -> some View {
        switch status {
        case .loading:
            ProgressView()
                .frame(height: 80)
                .accessibilityLabel("\(label) loading")
        case .unavailable:
            Text("--")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.secondary)
                .accessibilityLabel("\(label) unavailable")
        case .available(let value):
            Text("\(value)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .accessibilityLabel("\(label) \(value)")
        }
    }

    // MARK: - Score Breakdown

    private func breakdownView(breakdown: ScoreBreakdown) -> some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            VStack(spacing: 10) {
                ForEach(breakdown.components, id: \.name) { component in
                    breakdownComponentRow(component: component)
                }
            }
            .padding(.horizontal)
        }
        .padding(.top, 8)
    }

    private func breakdownComponentRow(component: ScoreBreakdown.ScoreComponent) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Circle()
                    .fill(statusColor(for: component.status))
                    .frame(width: 8, height: 8)
                Text(component.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Text("\(String(format: "%.1f", component.rawValue)) \(component.rawUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("(\(String(format: "%.0f", component.weight * 100))%)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            ProgressView(value: component.normalizedScore, total: 100)
                .tint(statusColor(for: component.status))
            Text(component.description)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(component.name): \(String(format: "%.1f", component.rawValue)) \(component.rawUnit), score \(Int(component.normalizedScore)) out of 100")
    }

    private func statusColor(for status: ScoreBreakdown.ComponentStatus) -> Color {
        switch status {
        case .warning: return .red
        case .good: return .green
        case .normal: return .orange
        }
    }

    // MARK: - Recommendation

    private var recommendationSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Today's Plan", systemImage: "sparkles")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Text(viewModel.recommendationText)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(viewModel.todayWorkoutType.rawValue.capitalized)
                .font(.headline)
                .foregroundStyle(recoveryColor)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    // MARK: - Points

    private var pointsSection: some View {
        HStack {
            Label("\(viewModel.totalPoints)", systemImage: "star.fill")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
            Text("points")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.totalPoints) points")
    }

    // MARK: - Detox Progress

    private var detoxProgressSection: some View {
        HStack {
            Label("Detox Mode", systemImage: "drop.fill")
                .font(.subheadline)
                .foregroundStyle(.purple)
            Spacer()
            Text("Day \(viewModel.detoxCurrentDay) of 7")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Detox mode, day \(viewModel.detoxCurrentDay) of 7")
    }

    // MARK: - Start Routine

    private var startRoutineButton: some View {
        Button(action: onStartRoutine) {
            Label("Start Routine", systemImage: "play.fill")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
    }

    // MARK: - Helpers

    private var recoveryColor: Color {
        switch viewModel.statusIndicator {
        case .red: return .red
        case .yellow: return .orange
        case .green: return .green
        }
    }

    private var activityColor: Color {
        guard let value = viewModel.activityScore.value else { return .blue }
        if value >= 70 { return .green }
        if value >= 40 { return .blue }
        return .orange
    }
}
