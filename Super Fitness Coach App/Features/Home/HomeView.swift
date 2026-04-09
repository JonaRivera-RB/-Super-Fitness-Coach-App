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
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var lang

    var body: some View {
        NavigationStack {
            ScrollViewReader { scroll in
                ScrollView {
                    VStack(spacing: 22) {
                        authorizationBanner
                        homeGreetingBlock
                        recoveryHeroCard
                        quickActionsRow(proxy: scroll)
                        coachSummarySection
                        actionCardSection
                        dailySummaryRow
                        recoveryScoreSection
                            .id("recovery")
                        lastNightContextSection
                            .id("sleep")
                        activityScoreSection
                            .id("activity")
                        pointsSection
                        if viewModel.detoxActive {
                            detoxProgressSection
                        }
                        startRoutineButton
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                }
                .scrollContentBackground(.hidden)
                .background(homeScreenBackground)
            }
            .refreshable {
                await viewModel.refresh()
            }
            .navigationTitle(lang.tabHome)
            .navigationBarTitleDisplayMode(.large)
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

    // MARK: - Shell (saludo, héroe, acciones)

    private var homeScreenBackground: Color {
        Color(.systemGroupedBackground)
    }

    private var greetingHeadline: String {
        let n = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if n.isEmpty { return lang.homeGreetingDefault }
        return lang.homeGreeting(name: n)
    }

    private var homeGreetingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(greetingHeadline)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundStyle(.primary)
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var recoveryHeroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(lang.homeHeroYourDay)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(lang.homeHeroRecoveryEnergy)
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Color.homeAccent.opacity(colorScheme == .dark ? 0.22 : 0.14))
                        .frame(width: 50, height: 50)
                    Image(systemName: recoveryHeroBoltIcon)
                        .font(.title2)
                        .foregroundStyle(Color.homeAccent)
                }
                .accessibilityHidden(true)
            }

            if viewModel.isLoading || viewModel.recoveryScore.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if case .available(let v) = viewModel.recoveryScore {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("\(v)%")
                            .font(.system(size: 34, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color.homeAccent)
                        Text(lang.homeWellbeingGoalLine)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                        Text("\(v)/100")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.tertiary)
                            .monospacedDigit()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(Color(.systemGray5))
                                .frame(height: 11)
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color.homeAccent.opacity(0.95), Color.homeAccent],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(10, geo.size.width * CGFloat(min(max(v, 0), 100)) / 100), height: 11)
                        }
                    }
                    .frame(height: 11)
                    if !viewModel.recoveryConfidenceLabel.isEmpty {
                        Text(viewModel.recoveryConfidenceLabel)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                Text(lang.homeNoRecoveryData)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(20)
        .modifier(SoftHomeSurface(cornerRadius: 22))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    private var recoveryHeroBoltIcon: String {
        guard case .available(let v) = viewModel.recoveryScore else { return "heart.fill" }
        if v >= 70 { return "bolt.fill" }
        if v >= 40 { return "heart.fill" }
        return "moon.zzz.fill"
    }

    private var heroAccessibilityLabel: String {
        if case .available(let v) = viewModel.recoveryScore {
            return lang.homeHeroAccessibility(score: v, confidence: viewModel.recoveryConfidenceLabel)
        }
        return lang.homeHeroLoading
    }

    private func quickActionsRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 0) {
            quickActionButton(icon: "figure.run", title: lang.homeQuickTrain, hint: lang.homeQuickTrainHint) {
                onStartRoutine()
            }
            quickActionButton(icon: "moon.zzz.fill", title: lang.homeQuickLastNight, hint: lang.homeQuickLastNightHint) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("sleep", anchor: .center)
                }
            }
            quickActionButton(icon: "bed.double.fill", title: lang.homeQuickRecoveryShort, hint: lang.homeQuickRecoveryHint) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("recovery", anchor: .top)
                }
            }
            quickActionButton(icon: "figure.walk", title: lang.homeQuickMovement, hint: lang.homeQuickMovementHint) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo("activity", anchor: .top)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func quickActionButton(icon: String, title: String, hint: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(Color(.secondarySystemGroupedBackground))
                        .frame(width: 56, height: 56)
                        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 5, y: 2)
                        .overlay {
                            Circle()
                                .strokeBorder(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.5), lineWidth: 0.5)
                        }
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(Color.primary.opacity(0.88))
                }
                Text(title)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(hint)
    }

    @ViewBuilder
    private var dailySummaryRow: some View {
        if viewModel.isLoading || viewModel.recoveryScore.isLoading {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                Text(lang.homeDailySummary)
                    .font(.headline)
                    .fontWeight(.bold)
                HStack(spacing: 12) {
                    dailyRingSummaryCard(
                        title: lang.homeLabelRecovery,
                        icon: "bed.double.fill",
                        status: viewModel.recoveryScore,
                        tint: recoveryColor
                    )
                    dailyRingSummaryCard(
                        title: lang.homeLabelActivity,
                        icon: "figure.run",
                        status: viewModel.activityScore,
                        tint: activityColor
                    )
                }
            }
            .accessibilityElement(children: .contain)
        }
    }

    @ViewBuilder
    private func dailyRingSummaryCard(
        title: String,
        icon: String,
        status: HealthDataStatus<Int>,
        tint: Color
    ) -> some View {
        let progress: Double = {
            if case .available(let v) = status { return Double(min(max(v, 0), 100)) / 100.0 }
            return 0
        }()
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5), lineWidth: 5)
                    .frame(width: 68, height: 68)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 68, height: 68)
                    .rotationEffect(.degrees(-90))
                Group {
                    switch status {
                    case .loading:
                        ProgressView()
                    case .unavailable:
                        Text("—")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    case .available(let v):
                        Text("\(v)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(tint)
                            .monospacedDigit()
                    }
                }
            }
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(title)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .modifier(SoftHomeSurface(cornerRadius: 18))
    }

    // MARK: - Authorization Banner

    @ViewBuilder
    private var authorizationBanner: some View {
        switch viewModel.authorizationStatus {
        case .denied:
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Text(lang.healthDeniedBanner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.orange.opacity(0.1)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lang.healthDeniedBannerA11y)
        case .unavailable:
            HStack(spacing: 8) {
                Image(systemName: "heart.slash")
                    .foregroundStyle(.secondary)
                Text(lang.healthUnavailableBanner)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 12).fill(Color(.systemGray5)))
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lang.healthUnavailableBanner)
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
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(coachSummaryColor.opacity(colorScheme == .dark ? 0.18 : 0.12))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(coachSummaryColor.opacity(0.2), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 10, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(viewModel.coachSummaryAccessibilityLabel)
            .accessibilityHint(lang.coachHintLongMessage)
        }
    }

    private var coachSummaryPlaceholder: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(lang.coachAnalyzing)
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
        .accessibilityLabel(lang.coachLoadingA11y)
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
                    Text("\(lang.intensityPrefix) \(viewModel.actionCardIntensity.localizedLabel(lang))")
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
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
            )
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(Color.homeAccent.opacity(0.12), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.28 : 0.07), radius: 10, y: 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.actionCardTitle), \(lang.intensityPrefix) \(viewModel.actionCardIntensity.localizedLabel(lang))")
        }
    }

    private var actionCardPlaceholder: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(lang.actionCardLoading)
                .font(.title2)
                .fontWeight(.bold)
            HStack(spacing: 8) {
                Text("\(lang.intensityPrefix) --")
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
        .accessibilityLabel(lang.actionCardLoadingA11y)
    }

    // MARK: - Recovery Score Section

    private var recoveryScoreSection: some View {
        VStack(spacing: 8) {
            Label(lang.recoverySectionTitle, systemImage: "bed.double.fill")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            compactScoreView(
                status: viewModel.recoveryScore,
                color: recoveryColor,
                label: lang.recoveryScoreLabel,
                descriptiveLabel: viewModel.recoveryLabel
            )

            if !(viewModel.isLoading || viewModel.recoveryScore.isLoading) {
                Text(lang.confidenceLine(viewModel.recoveryConfidenceLabel))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(lang.confidenceA11y(viewModel.recoveryConfidenceLabel))
            }

            if !viewModel.recoveryHistoryDays.isEmpty {
                recoveryHistoryStrip(days: viewModel.recoveryHistoryDays)
                    .padding(.top, 8)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showRecoveryBreakdown.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(lang.details)
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

    // MARK: - Last night (sleep window + vs baseline)

    @ViewBuilder
    private var lastNightContextSection: some View {
        if viewModel.isLoading || viewModel.recoveryScore.isLoading {
            EmptyView()
        } else if viewModel.lastNightSleepSummary.isEmpty,
                  viewModel.lastNightSleepWindow.isEmpty,
                  viewModel.quickMeaningLine.isEmpty,
                  viewModel.sleepConsistencyLine.isEmpty,
                  viewModel.sleepTrendLine.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 10) {
                Label(lang.lastNightSection, systemImage: "moon.zzz.fill")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(viewModel.lastNightSleepSummary)
                    .font(.body)
                    .fontWeight(.medium)

                if !viewModel.quickMeaningLine.isEmpty {
                    Text(viewModel.quickMeaningLine)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .accessibilityLabel(viewModel.quickMeaningAccessibilityLabel)
                }

                if !viewModel.lastNightSleepWindow.isEmpty {
                    Text(viewModel.lastNightSleepWindow)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.sleepConsistencyLine.isEmpty {
                    Text(viewModel.sleepConsistencyLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                if !viewModel.sleepTrendLine.isEmpty {
                    Text(viewModel.sleepTrendLine)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                DisclosureGroup(lang.sleepDetailsDisclosure) {
                    VStack(alignment: .leading, spacing: 8) {
                        if !viewModel.sleepGoalComparisonLine.isEmpty {
                            Text(viewModel.sleepGoalComparisonLine)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if !viewModel.rhrVsBaselineLine.isEmpty {
                            Text(viewModel.rhrVsBaselineLine)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }

                        if !viewModel.hrvVsBaselineLine.isEmpty {
                            Text(viewModel.hrvVsBaselineLine)
                                .font(.caption)
                                .foregroundStyle(.primary)
                        }

                        Text(lang.sleepMedicalDisclaimer)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(lang.glossaryTitle)
                                .font(.caption2)
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                            Text(lang.glossarySleep)
                            Text(lang.glossaryHRV)
                            Text(lang.glossaryRHR)
                            Text(lang.glossaryRegularity)
                        }
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.top, 2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: - Activity Score Section

    private var activityScoreSection: some View {
        VStack(spacing: 8) {
            Label(lang.homeLabelActivity, systemImage: "figure.run")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            compactScoreView(
                status: viewModel.activityScore,
                color: activityColor,
                label: lang.activityScoreLabel,
                descriptiveLabel: viewModel.activityLabel
            )

            Button {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showActivityBreakdown.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Text(lang.details)
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

            if insights.isEmpty {
                if let breakdown = breakdown, !breakdown.components.isEmpty {
                    // Fallback: show raw breakdown if no insights available
                    VStack(spacing: 10) {
                        ForEach(breakdown.components, id: \.name) { component in
                            fallbackComponentRow(component: component)
                        }
                    }
                    .padding(.horizontal)
                } else {
                    Text(lang.recoveryEmptyDetails)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 18)
                }
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
                    accessibilityLabel: lang.insightProgressA11y(metric: insight.metricName, percent: Int(min(score, 100)))
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
            Text(lang.pointsWord)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.2), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, y: 3)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.pointsA11y(viewModel.totalPoints))
    }

    // MARK: - Detox Progress

    private var detoxProgressSection: some View {
        HStack {
            Label(lang.detoxMode, systemImage: "drop.fill")
                .font(.subheadline)
                .foregroundStyle(.purple)
            Spacer()
            Text(lang.detoxDay(viewModel.detoxCurrentDay))
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.detoxA11y(day: viewModel.detoxCurrentDay))
    }

    // MARK: - Start Routine

    private var startRoutineButton: some View {
        Button(action: onStartRoutine) {
            Label(lang.goToWorkout, systemImage: "play.fill")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(Color.homeAccent)
        .controlSize(.large)
    }

    // MARK: - Recovery history strip

    @ViewBuilder
    private func recoveryHistoryStrip(days: [HomeViewModel.RecoveryHistoryDay]) -> some View {
        VStack(spacing: 10) {
            Text(lang.recoveryHistoryTitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)

            if days.count == 1, let day = days.first {
                HStack {
                    Spacer(minLength: 0)
                    recoveryHistoryChip(day: day)
                        .frame(width: 80)
                    Spacer(minLength: 0)
                }
            } else {
                HStack(spacing: 6) {
                    ForEach(days) { day in
                        recoveryHistoryChip(day: day)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 8)
    }

    private func recoveryHistoryChip(day: HomeViewModel.RecoveryHistoryDay) -> some View {
        VStack(spacing: 4) {
            Text(day.weekdayShort)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
            Text("\(day.recoveryScore)")
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 2)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.systemGray5))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.recoveryHistoryChipA11y(weekday: day.weekdayShort, score: day.recoveryScore))
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
        guard let value = viewModel.activityScore.value else { return AppSemanticPalette.systemBlue }
        if value >= 70 { return .green }
        if value >= 40 { return AppSemanticPalette.systemBlue }
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
        if normalizedScore >= 40 { return AppSemanticPalette.systemBlue }
        return .orange
    }
}

// MARK: - Home shell styling

private extension Color {
    /// Acento principal del tablero (similar a dashboards tipo “fitness” naranja).
    static let homeAccent = Color(red: 1.0, green: 122 / 255, blue: 38 / 255)
}

private struct SoftHomeSurface: ViewModifier {
    var cornerRadius: CGFloat = 20

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground))
                    .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 5)
            )
    }
}
