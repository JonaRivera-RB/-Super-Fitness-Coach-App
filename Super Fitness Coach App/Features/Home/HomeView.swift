//
//  HomeView.swift
//  Super Fitness Coach App
//
//  Rediseño con DesignTokens.
//  iOS 26+: Liquid Glass en cards y nav bar (glass material).
//  iOS 18+: system materials, adaptive fills, native shadows.
//
//  Layout en 2 zonas:
//  ① Hero (scroll) — score + chips + coach + CTA
//  ② Contextual — detox banner, historial 7 días
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct HomeView: View {

    // MARK: - Input

    var viewModel: HomeViewModel
    var onStartRoutine: () -> Void

    // MARK: - State

    @State private var showHowWeScore         = false
    @State private var homeContentVisible     = false
    @State private var presentedRing: HomeRingDetail? = nil
    @State private var selectedHistoryDayId: Date? = nil

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

    private enum HomeRingDetail: Identifiable {
        case sleep
        case recovery
        case activity
        var id: String {
            switch self {
            case .sleep: return "sleep"
            case .recovery: return "recovery"
            case .activity: return "activity"
            }
        }
    }

    // MARK: - Ambiente & momentum (refuerzo positivo, estilo “super app”)

    private var ambientBackdrop: some View {
        VStack(spacing: 0) {
            LinearGradient(
                colors: [
                    accent.opacity(colorScheme == .dark ? 0.26 : 0.16),
                    DesignTokens.Color.info.opacity(colorScheme == .dark ? 0.10 : 0.06),
                    Color(.systemGroupedBackground)
                ],
                startPoint: .topLeading,
                endPoint: .bottom
            )
            .frame(height: 320)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemGroupedBackground))
        .allowsHitTesting(false)
        .ignoresSafeArea(edges: .top)
    }

    private var momentumStrip: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            Text(lang.homeMomentumTitle)
                .font(DesignTokens.Typography.microMedium)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(spacing: DesignTokens.Spacing.sm) {
                momentumPill(
                    icon: "flame.fill",
                    tint: DesignTokens.Color.caution,
                    value: "\(viewModel.trainingStreakDays)",
                    caption: lang.homeMomentumStreak(days: viewModel.trainingStreakDays)
                )
                momentumPill(
                    icon: "star.fill",
                    tint: DesignTokens.Color.reward,
                    value: "\(viewModel.totalPoints)",
                    caption: lang.pointsWord
                )
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func momentumPill(icon: String, tint: Color, value: String, caption: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(tint.opacity(colorScheme == .dark ? 0.22 : 0.12))
                    .frame(width: 44, height: 44)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(tint)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(DesignTokens.Typography.numberCompact)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(caption)
                    .font(DesignTokens.Typography.micro)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
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

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                ambientBackdrop
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {

                    // ── Zona 1: siempre visible ──────────────
                    authorizationBanner
                    greetingSection
                        .opacity(homeContentVisible ? 1 : 0)
                        .offset(y: homeContentVisible ? 0 : 10)
                        .animation(DesignTokens.Motion.springSnappy.delay(0.02), value: homeContentVisible)
                    momentumStrip
                        .opacity(homeContentVisible ? 1 : 0)
                        .offset(y: homeContentVisible ? 0 : 14)
                        .animation(DesignTokens.Motion.springSnappy.delay(0.08), value: homeContentVisible)
                    homeRingsPyramid
                        .opacity(homeContentVisible ? 1 : 0)
                        .offset(y: homeContentVisible ? 0 : 18)
                        .animation(DesignTokens.Motion.springSnappy.delay(0.14), value: homeContentVisible)
                    coachInsightSection
                        .opacity(homeContentVisible ? 1 : 0)
                        .offset(y: homeContentVisible ? 0 : 10)
                        .animation(DesignTokens.Motion.springSnappy.delay(0.26), value: homeContentVisible)

                    // ── Contextual ───────────────────
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
            .background(Color.clear)
            .refreshable { await viewModel.refresh() }
            }
            .navigationTitle(lang.tabHome)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    infoButton
                }
            }
        }
        .task { await viewModel.onAppear() }
        .onAppear {
            homeContentVisible = true
            viewModel.syncStreakFromEngine()
            selectedHistoryDayId = viewModel.recoveryHistoryDays.last(where: { $0.isToday })?.id
                ?? viewModel.recoveryHistoryDays.last?.id
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await viewModel.refresh() }
            }
        }
        .sheet(isPresented: $showHowWeScore) {
            HowWeScoreSheet()
        }
        .sheet(item: $presentedRing) { ring in
            switch ring {
            case .sleep:
                SleepDetailScreen(viewModel: viewModel)
            case .recovery:
                RecoveryDetailScreen(viewModel: viewModel)
            case .activity:
                ActivityDetailScreen(viewModel: viewModel)
            }
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

    // MARK: Home rings (pyramid)

    private var homeRingsPyramid: some View {
        VStack(spacing: DesignTokens.Spacing.md) {
            Button { presentedRing = .recovery } label: {
                HomeRingCard(
                    title: lang.homeRingRecoveryTitle,
                    subtitle: viewModel.isShowingYesterdayRecovery ? lang.homeRingYesterday : lang.homeRingToday,
                    value: viewModel.recoveryScore.value,
                    tint: accent,
                    size: .large,
                    message: viewModel.heroRecoveryMessage
                )
            }
            .buttonStyle(.plain)

            HStack(spacing: DesignTokens.Spacing.md) {
                Button { presentedRing = .sleep } label: {
                    HomeRingCard(
                        title: lang.homeRingSleepTitle,
                        subtitle: viewModel.isShowingYesterdaySleep ? lang.homeRingYesterday : lang.homeRingToday,
                        value: viewModel.sleepScore.value,
                        tint: DesignTokens.Color.info,
                        size: .small,
                        message: nil
                    )
                }
                .buttonStyle(.plain)

                Button { presentedRing = .activity } label: {
                    HomeRingCard(
                        title: lang.homeRingActivityTitle,
                        subtitle: lang.homeRingToday,
                        value: viewModel.activityScore.value,
                        tint: DesignTokens.Color.reward,
                        size: .small,
                        message: nil
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .accessibilityElement(children: .contain)
    }

    private enum HomeRingSize {
        case small
        case large

        var diameter: CGFloat { self == .large ? 132 : 104 }
        var stroke: CGFloat { self == .large ? 12 : 10 }
    }

    private struct HomeRingCard: View {
        let title: String
        let subtitle: String
        let value: Int?
        let tint: Color
        let size: HomeRingSize
        let message: String?

        @Environment(\.colorScheme) private var colorScheme
        @Environment(\.appLanguage) private var lang

        private var progress: Double {
            guard let value else { return 0 }
            return min(max(Double(value) / 100.0, 0), 1)
        }

        var body: some View {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title)
                            .font(DesignTokens.Typography.microMedium)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .textCase(.uppercase)
                            .tracking(0.6)
                        Text(subtitle)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                    Spacer()
                }

                HStack(spacing: DesignTokens.Spacing.md) {
                    ZStack {
                        Circle()
                            .stroke(Color(.systemGray5).opacity(colorScheme == .dark ? 0.55 : 1), lineWidth: size.stroke)
                            .frame(width: size.diameter, height: size.diameter)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(tint, style: .init(lineWidth: size.stroke, lineCap: .round))
                            .frame(width: size.diameter, height: size.diameter)
                            .rotationEffect(.degrees(-90))
                            .animation(DesignTokens.Motion.springSnappy, value: progress)

                        if let v = value {
                            Text("\(v)")
                                .font(size == .large ? DesignTokens.Typography.displayTitle : DesignTokens.Typography.numberCompact)
                                .fontWeight(.bold)
                                .foregroundStyle(DesignTokens.Color.textPrimary)
                                .monospacedDigit()
                        } else {
                            Text("—")
                                .font(DesignTokens.Typography.displayTitle)
                                .fontWeight(.bold)
                                .foregroundStyle(DesignTokens.Color.textTertiary)
                        }
                    }

                    if size == .large {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(lang.homeRingOutOf100)
                                .font(DesignTokens.Typography.micro)
                                .foregroundStyle(DesignTokens.Color.textSecondary)
                            if let message, !message.isEmpty {
                                Text(message)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Color.textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Text(lang.homeRingTapForDetails)
                                    .font(DesignTokens.Typography.caption)
                                    .foregroundStyle(DesignTokens.Color.textSecondary)
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(DesignTokens.Spacing.heroInner)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .tokenStroke(radius: DesignTokens.Radius.hero)
            .tokenShadow(.elevated)
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                tint.opacity(colorScheme == .dark ? 0.38 : 0.22),
                                tint.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
        }

        @ViewBuilder
        private var cardBackground: some View {
            if #available(iOS 26, *) {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                    .fill(.regularMaterial)
            } else {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                    .fill(DesignTokens.Color.surfaceCard)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                            .fill(tint.opacity(colorScheme == .dark ? 0.08 : 0.05))
                    }
            }
        }
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
        let ringSize: CGFloat = 132
        let lineWidth: CGFloat = 10

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.md) {
                ZStack {
                    Circle()
                        .stroke(Color(.systemGray5).opacity(colorScheme == .dark ? 0.55 : 1), lineWidth: lineWidth)
                        .frame(width: ringSize, height: ringSize)
                    Circle()
                        .trim(from: 0, to: CGFloat(min(score, 100)) / 100)
                        .stroke(
                            level.accent,
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .frame(width: ringSize, height: ringSize)
                        .rotationEffect(.degrees(-90))
                        .animation(DesignTokens.Motion.springSnappy, value: score)
                    Text("\(score)")
                        .font(.system(size: 40, weight: .heavy, design: .rounded))
                        .foregroundStyle(level.accent)
                        .monospacedDigit()
                        .contentTransition(.numericText())
                }
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    recoveryStatusBadge(level: level)
                    Text("de 100")
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                    if !viewModel.recoveryConfidenceLabel.isEmpty {
                        Text(viewModel.recoveryConfidenceLabel)
                            .font(DesignTokens.Typography.micro)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                }
                Spacer(minLength: 0)
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

    // MARK: Coach insight

    @ViewBuilder
    private var coachInsightSection: some View {
        if !viewModel.coachSummary.isEmpty && !viewModel.isLoading {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
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
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(.regularMaterial)
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                            .stroke(
                                LinearGradient(
                                    colors: [accent.opacity(0.35), accent.opacity(0.06)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    }
            )
            .tokenShadow(.card)
        }
    }

    // ─────────────────────────────────────────────────────────
    // MARK: Contextual — historial 7 días
    // ─────────────────────────────────────────────────────────

    @ViewBuilder
    private var historyStripSection: some View {
        let days = viewModel.rollingRecoveryDays
        let isCollectingToday = (days.last?.isToday == true) && (days.last?.percent == nil)
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                Text(lang.homeRecoveryWeeklyProgressTitle)
                    .font(DesignTokens.Typography.body)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Spacer(minLength: DesignTokens.Spacing.sm)
                Text(lang.homeRecoveryLast7Days)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.md) {
                yAxis
                HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
                    ForEach(days) { d in
                        weeklyProgressBar(day: d)
                    }
                }
            }
            .frame(maxWidth: .infinity)

            if isCollectingToday {
                HStack(spacing: DesignTokens.Spacing.xs) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                    Text(lang.homeRecoveryCollectingOvernight)
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(lang.homeRecoveryCollectingOvernight)
            }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .stroke(Color(.separator).opacity(0.35), lineWidth: 1)
        }
        .tokenShadow(.card)
    }

    private var yAxis: some View {
        VStack {
            Text("100")
            Spacer()
            Text("50")
            Spacer()
            Text("0")
        }
        .font(DesignTokens.Typography.micro)
        .foregroundStyle(DesignTokens.Color.textTertiary)
        .frame(width: 24, height: 120)
    }

    private func weeklyProgressBar(day: HomeViewModel.RollingRecoveryDay) -> some View {
        let maxBar: CGFloat = 92
        let percent = day.percent ?? 0
        let ratio = CGFloat(min(100, max(0, percent))) / 100.0
        let barH = max(minBar, min(ratio * maxBar, maxBar))
        let track = LinearGradient(
            colors: [
                Color(.systemGray4).opacity(colorScheme == .dark ? 0.38 : 0.28),
                Color(.systemGray4).opacity(0.10)
            ],
            startPoint: .bottom,
            endPoint: .top
        )
        let fill = LinearGradient(
            colors: [
                Color(uiColor: .systemOrange),
                Color(uiColor: .systemOrange).opacity(0.75)
            ],
            startPoint: .bottom,
            endPoint: .top
        )

        return VStack(spacing: 8) {
            ZStack {
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(track)
                        .frame(height: maxBar)
                    if day.percent != nil {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(fill)
                            .frame(height: barH)
                    }
                }
                .overlay {
                    Text("\(percent)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(day.percent != nil ? Color.white.opacity(0.92) : DesignTokens.Color.textTertiary)
                        .monospacedDigit()
                }
                .overlay {
                    if day.isToday && day.percent == nil {
                        Image(systemName: "info.circle")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .padding(6)
                            .background(Circle().fill(.ultraThinMaterial))
                            .accessibilityLabel(lang.homeRecoveryCollectingOvernight)
                    }
                }
            }

            Text(lang.shortWeekday(day.dayOfWeek))
                .font(DesignTokens.Typography.micro)
                .foregroundStyle(DesignTokens.Color.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(lang.shortWeekday(day.dayOfWeek)), \(day.percent.map(String.init) ?? "—") de 100")
    }

    private let minBar: CGFloat = 6

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
