//
//  HomeView.swift
//  Super Fitness Coach App
//
//  Rediseño con DesignTokens.
//  iOS 26+: Liquid Glass en cards y nav bar (glass material).
//  iOS 18+: system materials, adaptive fills, native shadows.
//
//  Layout en 3 zonas:
//  ① Hero (sin scroll) — score + chips + coach + CTA
//  ② Detalles (scroll)  — breakdown colapsable por sección
//  ③ Contextual         — detox banner, historial 7 días
//

import SwiftUI

struct HomeView: View {

    // MARK: - Input

    var viewModel: HomeViewModel
    var onStartRoutine: () -> Void

    // MARK: - State

    @State private var showRecoveryBreakdown  = false
    @State private var showActivityBreakdown  = false
    @State private var showHowWeScore         = false

    // MARK: - Environment

    @Environment(\.scenePhase)   private var scenePhase
    @Environment(\.colorScheme)  private var colorScheme
    @Environment(\.appLanguage)  private var lang

    // MARK: - Computed helpers

    private var recoveryScore: Int { viewModel.recoveryScore.value ?? 0 }
    private var recoveryLevel: DesignTokens.Color.RecoveryLevel {
        DesignTokens.Color.recoveryLevel(score: recoveryScore)
    }
    private var accent: Color { recoveryLevel.accent }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {

                    // ── Zona 1: siempre visible ──────────────
                    authorizationBanner
                    greetingSection
                    heroRecoveryCard
                    metricChipsRow
                    coachInsightSection
                    ctaSection

                    // ── Separador hacia detalles ─────────────
                    detailsDivider

                    // ── Zona 2: detalles bajo demanda ────────
                    recoveryDetailSection
                        .id("recovery")
                    sleepDetailSection
                        .id("sleep")
                    activityDetailSection
                        .id("activity")

                    // ── Zona 3: contextual ───────────────────
                    if !viewModel.recoveryHistoryDays.isEmpty {
                        historyStripSection
                    }
                    if viewModel.detoxActive {
                        detoxBanner
                    }

                    Spacer(minLength: DesignTokens.Spacing.xxl)
                }
                .padding(.horizontal, DesignTokens.Spacing.screenH)
                .padding(.top, DesignTokens.Spacing.sm)
            }
            .scrollContentBackground(.hidden)
            .background(Color(.systemGroupedBackground))
            .refreshable { await viewModel.refresh() }
            .navigationTitle(lang.tabHome)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    infoButton
                }
            }
        }
        .task { await viewModel.onAppear() }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showHowWeScore) {
            HowWeScoreSheet()
        }
    }

    // MARK: - Toolbar

    private var infoButton: some View {
        Button { showHowWeScore = true } label: {
            Image(systemName: "info.circle")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .accessibilityLabel("Cómo medimos tu recuperación")
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Zona 1 — Hero
    // ─────────────────────────────────────────────────────────

    // MARK: Authorization banner

    @ViewBuilder
    private var authorizationBanner: some View {
        switch viewModel.authorizationStatus {
        case .denied:
            bannerRow(
                icon: "exclamationmark.triangle.fill",
                iconColor: DesignTokens.Color.caution,
                text: lang.healthDeniedBanner,
                background: DesignTokens.Color.caution.opacity(colorScheme == .dark ? 0.20 : 0.10)
            )
            .accessibilityLabel(lang.healthDeniedBannerA11y)

        case .unavailable:
            bannerRow(
                icon: "heart.slash",
                iconColor: DesignTokens.Color.textTertiary,
                text: lang.healthUnavailableBanner,
                background: Color(.systemGray5)
            )

        default:
            EmptyView()
        }
    }

    private func bannerRow(icon: String, iconColor: Color, text: String, background: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(iconColor)
            Text(text)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .padding(DesignTokens.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous).fill(background))
    }

    // MARK: Greeting

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            let name = viewModel.userName.trimmingCharacters(in: .whitespacesAndNewlines)
            Text(name.isEmpty ? lang.homeGreetingDefault : lang.homeGreeting(name: name))
                .font(DesignTokens.Typography.displayTitle)
                .fontWeight(.bold)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text(Date.now, format: .dateTime.weekday(.wide).day().month(.wide))
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: Hero recovery card

    private var heroRecoveryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {

            // Label
            Text(lang.homeHeroRecoveryEnergy)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .textCase(.uppercase)
                .tracking(0.5)

            if viewModel.isLoading || viewModel.recoveryScore.isLoading {
                heroLoadingState
            } else if case .available(let score) = viewModel.recoveryScore {
                heroScoreContent(score: score)
            } else {
                Text(lang.homeNoRecoveryData)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.heroInner)
        .background(heroCardBackground)
        .tokenStroke(radius: DesignTokens.Radius.hero)
        .tokenShadow(.elevated)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(heroAccessibilityLabel)
    }

    @ViewBuilder
    private var heroCardBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                .fill(.regularMaterial)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
                // Tinte sutil del color de recuperación sobre la card
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                        .fill(accent.opacity(colorScheme == .dark ? 0.08 : 0.05))
                }
        }
    }

    private var heroLoadingState: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: 56)
            Text(lang.coachAnalyzing)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textTertiary)
        }
    }

    private func heroScoreContent(score: Int) -> some View {
        let level = DesignTokens.Color.recoveryLevel(score: score)
        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {

            // Número + badge de estado
            HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.sm) {
                Text("\(score)")
                    .font(DesignTokens.Typography.scoreHero)
                    .foregroundStyle(level.accent)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    recoveryStatusBadge(level: level)
                    Text("de 100")
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                Spacer(minLength: 0)
            }

            // Barra de progreso fina
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(.systemGray5))
                        .frame(height: 6)
                    Capsule()
                        .fill(level.accent)
                        .frame(width: max(6, geo.size.width * CGFloat(min(score, 100)) / 100), height: 6)
                        .animation(DesignTokens.Motion.springSnappy, value: score)
                }
            }
            .frame(height: 6)

            // Confianza
            if !viewModel.recoveryConfidenceLabel.isEmpty {
                Text(viewModel.recoveryConfidenceLabel)
                    .font(DesignTokens.Typography.micro)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
        }
    }

    private func recoveryStatusBadge(level: DesignTokens.Color.RecoveryLevel) -> some View {
        Text(viewModel.recoveryLabel.isEmpty ? level.label : viewModel.recoveryLabel)
            .font(DesignTokens.Typography.microMedium)
            .foregroundStyle(level.accent)
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, 3)
            .background(
                Capsule().fill(level.accent.opacity(colorScheme == .dark ? 0.20 : 0.12))
            )
    }

    private var heroAccessibilityLabel: String {
        if case .available(let v) = viewModel.recoveryScore {
            return lang.homeHeroAccessibility(score: v, confidence: viewModel.recoveryConfidenceLabel)
        }
        return lang.homeHeroLoading
    }

    // MARK: Metric chips (sueño + hoy)

    private var metricChipsRow: some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            sleepMetricChip
            todayWorkoutChip
        }
    }

    private var sleepMetricChip: some View {
        metricChip(
            icon: "moon.zzz.fill",
            iconColor: DesignTokens.Color.info,
            label: lang.homeQuickLastNight,
            value: sleepChipValue
        )
    }

    private var sleepChipValue: String {
        if viewModel.lastNightSleepSummary.isEmpty { return "—" }
        // Extraer solo el número de horas del string "Dormiste ~7.4 h"
        let s = viewModel.lastNightSleepSummary
        if let range = s.range(of: #"[\d.]+\s*h"#, options: .regularExpression) {
            return String(s[range])
        }
        return viewModel.lastNightSleepSummary
    }

    private var todayWorkoutChip: some View {
        metricChip(
            icon: "figure.run",
            iconColor: accent,
            label: lang.homeQuickTrain,
            value: viewModel.todayMuscleLabel
        )
    }

    private func metricChip(icon: String, iconColor: Color, label: String, value: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(DesignTokens.Typography.micro)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                Text(value)
                    .font(DesignTokens.Typography.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(maxWidth: .infinity)
        .background(chipBackground)
        .tokenStroke(radius: DesignTokens.Radius.card)
    }

    @ViewBuilder
    private var chipBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(.regularMaterial)
        } else {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
                .shadow(
                    color: DesignTokens.Shadow.subtle(colorScheme).color,
                    radius: DesignTokens.Shadow.subtle(colorScheme).radius,
                    x: 0, y: DesignTokens.Shadow.subtle(colorScheme).y
                )
        }
    }

    // MARK: Coach insight

    @ViewBuilder
    private var coachInsightSection: some View {
        if !viewModel.coachSummary.isEmpty && !viewModel.isLoading {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                // Barra de color izquierda (reemplaza el emoji grande)
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3)
                    .padding(.vertical, 2)

                Text(viewModel.coachSummary)
                    .font(DesignTokens.Typography.body)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(viewModel.coachSummaryAccessibilityLabel)
            }
            .padding(.horizontal, DesignTokens.Spacing.sm)
        }
    }

    // MARK: CTA

    private var ctaSection: some View {
        Button(action: onStartRoutine) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text(viewModel.actionCardTitle.isEmpty ? lang.goToWorkout : viewModel.actionCardTitle)
                    .font(DesignTokens.Typography.bodyMedium)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.md)
        }
        .buttonStyle(.borderedProminent)
        .tint(accent)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.pill, style: .continuous))
        .shadow(
            color: accent.opacity(colorScheme == .dark ? 0.35 : 0.25),
            radius: 12, x: 0, y: 4
        )
        .accessibilityLabel(lang.goToWorkout)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Separador "Detalles"
    // ─────────────────────────────────────────────────────────

    private var detailsDivider: some View {
        HStack {
            Rectangle().fill(Color(.systemGray5)).frame(height: 1)
            Text(lang.details)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .fixedSize()
            Rectangle().fill(Color(.systemGray5)).frame(height: 1)
        }
        .padding(.vertical, DesignTokens.Spacing.xs)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Zona 2 — Detalles colapsables
    // ─────────────────────────────────────────────────────────

    // MARK: Recovery detail

    @ViewBuilder
    private var recoveryDetailSection: some View {
        if !viewModel.isLoading {
            DisclosureGroup(
                isExpanded: $showRecoveryBreakdown,
                content: { recoveryBreakdownContent },
                label: {
                    disclosureLabel(
                        icon: "bed.double.fill",
                        title: lang.recoverySectionTitle,
                        value: viewModel.recoveryScore.value.map { "\($0)/100" } ?? "—",
                        accent: accent
                    )
                }
            )
            .tokenCard(padding: DesignTokens.Spacing.md)
            .animation(DesignTokens.Motion.standard, value: showRecoveryBreakdown)
        }
    }

    private var recoveryBreakdownContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Divider()
            if viewModel.recoveryInsights.isEmpty {
                if let bd = viewModel.recoveryBreakdown, !bd.components.isEmpty {
                    ForEach(bd.components, id: \.name) { component in
                        metricRow(
                            name: component.name,
                            value: String(format: "%.1f %@", component.rawValue, component.rawUnit),
                            status: component.status
                        )
                    }
                } else {
                    Text(lang.recoveryEmptyDetails)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
            } else {
                ForEach(Array(viewModel.recoveryInsights.enumerated()), id: \.offset) { _, insight in
                    insightRow(insight: insight)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    // MARK: Sleep detail

    @ViewBuilder
    private var sleepDetailSection: some View {
        let hasSleepData = !viewModel.lastNightSleepSummary.isEmpty
            || !viewModel.quickMeaningLine.isEmpty
            || !viewModel.sleepTrendLine.isEmpty

        if !viewModel.isLoading, hasSleepData {
            DisclosureGroup(
                content: { sleepBreakdownContent },
                label: {
                    disclosureLabel(
                        icon: "moon.zzz.fill",
                        title: lang.lastNightSection,
                        value: sleepChipValue,
                        accent: DesignTokens.Color.info
                    )
                }
            )
            .tokenCard(padding: DesignTokens.Spacing.md)
        }
    }

    private var sleepBreakdownContent: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Divider()

            if !viewModel.lastNightSleepSummary.isEmpty {
                Text(viewModel.lastNightSleepSummary)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
            }
            if !viewModel.lastNightSleepWindow.isEmpty {
                labeledRow(label: "Ventana", value: viewModel.lastNightSleepWindow)
            }
            if !viewModel.quickMeaningLine.isEmpty {
                Text(viewModel.quickMeaningLine)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !viewModel.sleepTrendLine.isEmpty {
                Text(viewModel.sleepTrendLine)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !viewModel.sleepConsistencyLine.isEmpty {
                Text(viewModel.sleepConsistencyLine)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
            if !viewModel.hrvVsBaselineLine.isEmpty || !viewModel.rhrVsBaselineLine.isEmpty {
                Divider()
                if !viewModel.hrvVsBaselineLine.isEmpty {
                    Text(viewModel.hrvVsBaselineLine)
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                if !viewModel.rhrVsBaselineLine.isEmpty {
                    Text(viewModel.rhrVsBaselineLine)
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
            }
            Text(lang.sleepMedicalDisclaimer)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textQuaternary)
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    // MARK: Activity detail

    @ViewBuilder
    private var activityDetailSection: some View {
        if !viewModel.isLoading {
            DisclosureGroup(
                isExpanded: $showActivityBreakdown,
                content: { activityBreakdownContent },
                label: {
                    disclosureLabel(
                        icon: "figure.run",
                        title: lang.homeLabelActivity,
                        value: viewModel.activityScore.value.map { "\($0)/100" } ?? "—",
                        accent: activityAccent
                    )
                }
            )
            .tokenCard(padding: DesignTokens.Spacing.md)
            .animation(DesignTokens.Motion.standard, value: showActivityBreakdown)
        }
    }

    private var activityAccent: Color {
        guard let v = viewModel.activityScore.value else { return DesignTokens.Color.info }
        if v >= 70 { return DesignTokens.Color.positive }
        if v >= 40 { return DesignTokens.Color.info }
        return DesignTokens.Color.caution
    }

    private var activityBreakdownContent: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            Divider()
            if viewModel.activityInsights.isEmpty {
                if let bd = viewModel.activityBreakdown, !bd.components.isEmpty {
                    ForEach(bd.components, id: \.name) { comp in
                        metricRow(
                            name: comp.name,
                            value: String(format: "%.1f %@", comp.rawValue, comp.rawUnit),
                            status: comp.status
                        )
                    }
                } else {
                    Text(lang.recoveryEmptyDetails)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.vertical, DesignTokens.Spacing.sm)
                }
            } else {
                ForEach(Array(viewModel.activityInsights.enumerated()), id: \.offset) { _, insight in
                    insightRow(insight: insight)
                }
            }
        }
        .padding(.top, DesignTokens.Spacing.xs)
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Zona 3 — Contextual
    // ─────────────────────────────────────────────────────────

    // MARK: History strip (7 días)

    private var historyStripSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(lang.recoveryHistoryTitle)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            HStack(spacing: DesignTokens.Spacing.xs) {
                ForEach(viewModel.recoveryHistoryDays) { day in
                    historyBar(day: day)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .tokenCard()
    }

    private func historyBar(day: HomeViewModel.RecoveryHistoryDay) -> some View {
        let level = DesignTokens.Color.recoveryLevel(score: day.recoveryScore)
        return VStack(spacing: DesignTokens.Spacing.xs) {
            Text("\(day.recoveryScore)")
                .font(DesignTokens.Typography.microMedium)
                .foregroundStyle(level.accent)
                .monospacedDigit()
            RoundedRectangle(cornerRadius: 3)
                .fill(level.accent.opacity(colorScheme == .dark ? 0.70 : 0.55))
                .frame(height: max(4, CGFloat(day.recoveryScore) / 100 * 40))
            Text(day.weekdayShort)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.recoveryHistoryChipA11y(weekday: day.weekdayShort, score: day.recoveryScore))
    }

    // MARK: Detox banner

    private var detoxBanner: some View {
        HStack {
            Label(lang.detoxMode, systemImage: "drop.fill")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.restDay)
            Spacer()
            Text(lang.detoxDay(viewModel.detoxCurrentDay))
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.restDay)
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(DesignTokens.Color.restDay.opacity(colorScheme == .dark ? 0.15 : 0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.detoxA11y(day: viewModel.detoxCurrentDay))
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Sub-components reutilizables
    // ─────────────────────────────────────────────────────────

    private func disclosureLabel(icon: String, title: String, value: String, accent: Color) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(accent)
                .frame(width: 20)
            Text(title)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(accent)
                .monospacedDigit()
        }
    }

    private func metricRow(name: String, value: String, status: ScoreBreakdown.ComponentStatus) -> some View {
        HStack {
            Circle()
                .fill(statusColor(status))
                .frame(width: 7, height: 7)
            Text(name)
                .font(DesignTokens.Typography.captionRegular)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name): \(value)")
    }

    private func insightRow(insight: MetricInsight) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Circle()
                    .fill(statusColor(for: insight.status))
                    .frame(width: 7, height: 7)
                    .padding(.top, 5)
                Text(insight.message)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let score = insight.normalizedScore {
                insightProgressBar(score: score, insight: insight)
                    .padding(.leading, DesignTokens.Spacing.md)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(insight.metricName): \(insight.message)")
    }

    private func insightProgressBar(score: Double, insight: MetricInsight) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color(.systemGray5)).frame(height: 5)
                Capsule()
                    .fill(progressBarColor(for: score))
                    .frame(width: geo.size.width * min(max(score / 100, 0), 1), height: 5)
            }
        }
        .frame(height: 5)
        .accessibilityElement()
        .accessibilityLabel(lang.insightProgressA11y(metric: insight.metricName, percent: Int(min(score, 100))))
    }

    private func labeledRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textTertiary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.micro)
                .fontWeight(.medium)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
    }

    // MARK: Colors helpers

    private func statusColor(_ status: ScoreBreakdown.ComponentStatus) -> Color {
        switch status {
        case .warning: return DesignTokens.Color.destructive
        case .good:    return DesignTokens.Color.positive
        case .normal:  return DesignTokens.Color.caution
        }
    }

    private func statusColor(for status: ScoreBreakdown.ComponentStatus) -> Color {
        statusColor(status)
    }

    private func progressBarColor(for score: Double) -> Color {
        if score >= 100 { return DesignTokens.Color.positive }
        if score >= 40  { return DesignTokens.Color.info }
        return DesignTokens.Color.caution
    }
}

// ─────────────────────────────────────────────────────────
// MARK: - HowWeScoreSheet
// ─────────────────────────────────────────────────────────

private struct HowWeScoreSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {

                    Text("Tu puntuación de recuperación diaria se calcula combinando señales de Apple Health.")
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .padding(.top, DesignTokens.Spacing.sm)

                    howWeScoreItem(
                        icon: "moon.zzz.fill",
                        iconColor: DesignTokens.Color.info,
                        title: "Sueño",
                        description: "Duración y calidad del sueño principal de la noche anterior. Base del score diario."
                    )
                    howWeScoreItem(
                        icon: "waveform.path.ecg",
                        iconColor: DesignTokens.Color.positive,
                        title: "HRV (Variabilidad cardíaca)",
                        description: "Variación entre latidos. Un HRV más alto respecto a tu media de 14 días indica mejor recuperación del sistema nervioso."
                    )
                    howWeScoreItem(
                        icon: "heart.fill",
                        iconColor: DesignTokens.Color.destructive,
                        title: "FC en reposo",
                        description: "Frecuencia cardíaca en reposo del día. Valores más bajos que tu media generalmente indican mejor recuperación."
                    )
                    howWeScoreItem(
                        icon: "chart.bar.fill",
                        iconColor: DesignTokens.Color.caution,
                        title: "Confianza del dato",
                        description: "Indica cuántas señales estuvieron disponibles. Con más datos (especialmente sueño y HRV), la puntuación es más fiable."
                    )

                    Divider()

                    Text("Todos los valores se comparan con tu historial personal de los últimos 14 días, no con promedios generales.")
                        .font(DesignTokens.Typography.captionRegular)
                        .foregroundStyle(DesignTokens.Color.textTertiary)

                    Text("Esta información es orientativa y no sustituye consejo médico profesional.")
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textQuaternary)
                        .padding(.bottom, DesignTokens.Spacing.lg)
                }
                .padding(.horizontal, DesignTokens.Spacing.screenH)
            }
            .navigationTitle("Cómo medimos tu recuperación")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cerrar") { dismiss() }
                        .font(DesignTokens.Typography.bodyMedium)
                }
            }
        }
    }

    private func howWeScoreItem(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.chip, style: .continuous)
                    .fill(iconColor.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(iconColor)
            }

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(title)
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Text(description)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
