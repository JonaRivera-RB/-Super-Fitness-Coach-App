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
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    authorizationBanner
                    coachSummarySection
                    actionCardSection
                    recoveryScoreSection
                    activityScoreSection
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
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    Task { await viewModel.refresh() }
                }
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

    // MARK: - Coach Summary Section

    @ViewBuilder
    private var coachSummarySection: some View {
        if viewModel.isLoading || viewModel.recoveryScore.isLoading {
            coachSummaryPlaceholder
        } else {
            VStack(spacing: 12) {
                Text(viewModel.coachEmoji)
                    .font(.system(size: 40))

                Text(viewModel.coachSummary)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(.vertical, 20)
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(coachSummaryColor.opacity(0.12))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coach summary: \(viewModel.coachSummary)")
        }
    }

    private var coachSummaryPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Analizando tus datos...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(.systemGray5))
        )
        .redacted(reason: .placeholder)
        .accessibilityLabel("Coach summary loading")
    }

    // MARK: - Action Card Section

    @ViewBuilder
    private var actionCardSection: some View {
        if viewModel.isLoading || viewModel.recoveryScore.isLoading {
            actionCardPlaceholder
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(viewModel.actionCardTitle)
                    .font(.title2)
                    .fontWeight(.bold)

                HStack(spacing: 8) {
                    Text("Intensidad: \(viewModel.actionCardIntensity.label)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray4))
                                .frame(height: 8)
                            Capsule()
                                .fill(intensityColor)
                                .frame(width: geo.size.width * intensityFraction, height: 8)
                        }
                    }
                    .frame(height: 8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.actionCardTitle), intensidad \(viewModel.actionCardIntensity.label)")
        }
    }

    private var actionCardPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cargando plan del día...")
                .font(.title2)
                .fontWeight(.bold)
            HStack(spacing: 8) {
                Text("Intensidad: --")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: 8)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .redacted(reason: .placeholder)
        .accessibilityLabel("Action card loading")
    }

    // MARK: - Recovery Score Section

    private var recoveryScoreSection: some View {
        VStack(spacing: 8) {
            Label("Recovery", systemImage: "bed.double.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            compactScoreView(
                status: viewModel.recoveryScore,
                color: recoveryColor,
                label: "Recovery score",
                descriptiveLabel: viewModel.recoveryLabel
            )

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

            if showRecoveryBreakdown {
                insightsBreakdownView(insights: viewModel.recoveryInsights, breakdown: viewModel.recoveryBreakdown)
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

            compactScoreView(
                status: viewModel.activityScore,
                color: activityColor,
                label: "Activity score",
                descriptiveLabel: viewModel.activityLabel
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

            if showActivityBreakdown {
                insightsBreakdownView(insights: viewModel.activityInsights, breakdown: viewModel.activityBreakdown)
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

    // MARK: - Compact Score View

    @ViewBuilder
    private func compactScoreView(
        status: HealthDataStatus<Int>,
        color: Color,
        label: String,
        descriptiveLabel: String
    ) -> some View {
        switch status {
        case .loading:
            ProgressView()
                .frame(height: 56)
                .accessibilityLabel("\(label) loading")
        case .unavailable:
            HStack(spacing: 12) {
                Text("--")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            .accessibilityLabel("\(label) unavailable")
        case .available(let value):
            HStack(spacing: 12) {
                Text("\(value)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(color)

                Text(descriptiveLabel)
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)

                Circle()
                    .fill(color)
                    .frame(width: 10, height: 10)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(label) \(value), \(descriptiveLabel)")
        }
    }

    // MARK: - Insights Breakdown View

    private func insightsBreakdownView(insights: [MetricInsight], breakdown: ScoreBreakdown?) -> some View {
        VStack(spacing: 12) {
            Divider()
                .padding(.horizontal)

            if insights.isEmpty, let breakdown = breakdown {
                // Fallback: show raw breakdown if no insights available
                VStack(spacing: 10) {
                    ForEach(breakdown.components, id: \.name) { component in
                        fallbackComponentRow(component: component)
                    }
                }
                .padding(.horizontal)
            } else {
                VStack(spacing: 10) {
                    ForEach(Array(insights.enumerated()), id: \.offset) { _, insight in
                        insightRow(insight: insight, normalizedScore: insight.normalizedScore)
                    }
                }
                .padding(.horizontal)
            }
        }
        .padding(.top, 8)
    }

    private func insightRow(insight: MetricInsight, normalizedScore: Double? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                Circle()
                    .fill(statusColor(for: insight.status))
                    .frame(width: 8, height: 8)
                    .padding(.top, 6)
                Text(insight.message)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            if let score = normalizedScore {
                activityProgressBar(
                    progress: score / 100.0,
                    normalizedScore: score,
                    accessibilityLabel: "Progreso de \(insight.metricName): \(Int(min(score, 100))) por ciento"
                )
                .padding(.leading, 16)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.metricName): \(insight.message)")
    }

    private func fallbackComponentRow(component: ScoreBreakdown.ScoreComponent) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Circle()
                .fill(statusColor(for: component.status))
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(component.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("\(String(format: "%.1f", component.rawValue)) \(component.rawUnit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(component.name): \(String(format: "%.1f", component.rawValue)) \(component.rawUnit)")
    }

    private func statusColor(for status: ScoreBreakdown.ComponentStatus) -> Color {
        switch status {
        case .warning: return .red
        case .good: return .green
        case .normal: return .orange
        }
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

    private var coachSummaryColor: Color {
        switch viewModel.coachEmoji {
        case "🔴": return .red
        case "🟢": return .green
        default: return .orange
        }
    }

    private var intensityColor: Color {
        switch viewModel.actionCardIntensity {
        case .low: return .red
        case .medium: return .orange
        case .high: return .green
        }
    }

    private var intensityFraction: CGFloat {
        switch viewModel.actionCardIntensity {
        case .low: return 0.33
        case .medium: return 0.66
        case .high: return 1.0
        }
    }

    // MARK: - Activity Progress Bar

    /// Barra de progreso para métricas de actividad.
    private func activityProgressBar(
        progress: Double,
        normalizedScore: Double,
        accessibilityLabel: String
    ) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color(.systemGray4))
                    .frame(height: 6)
                Capsule()
                    .fill(progressBarColor(for: normalizedScore))
                    .frame(width: geo.size.width * min(max(progress, 0), 1), height: 6)
            }
        }
        .frame(height: 6)
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
    }

    private func progressBarColor(for normalizedScore: Double) -> Color {
        if normalizedScore >= 100 { return .green }
        if normalizedScore >= 40 { return .blue }
        return .orange
    }
}
