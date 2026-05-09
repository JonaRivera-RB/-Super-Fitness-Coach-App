//
//  SleepDetailScreen.swift
//  Super Fitness Coach App
//

import SwiftUI

struct SleepDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HomeViewModel

    @State private var segmentIndex: Int = 0
    @State private var activeSheet: SleepDetailSheetKind?

    private var dayLabel: String {
        viewModel.isShowingYesterdaySleep ? lang.homeRingYesterday : lang.homeRingToday
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.lg) {
                    SleepDetailSegmentedHeader(selected: $segmentIndex)
                    if viewModel.isShowingYesterdaySleep {
                        yesterdayContextBanner
                    }
                    dateRow
                    headlineBlock
                    summaryCard
                    contributorsSection
                    if let p = phaseFractions {
                        phasesCard(p)
                    }
                    #if DEBUG
                    sleepScoringDebugSection
                    #endif
                    Text(lang.homeDataSourceAppleHealthSleep)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, DesignTokens.Spacing.screenH)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Color.surfaceSheet)
            .navigationTitle(viewModel.isShowingYesterdaySleep ? lang.sleepDetailNavTitleYesterday : lang.homeTodayUpper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
            .sheet(item: $activeSheet) { kind in
                SleepDetailMetricSheet(kind: kind, scoreForScale: scoreForSheet(kind))
            }
        }
    }

    /// Fecha de referencia en pantalla: ayer si el placeholder es “noche anterior”; hoy si ya hay datos del día.
    private var referenceDateForHeader: Date {
        if viewModel.isShowingYesterdaySleep {
            Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        } else {
            Date()
        }
    }

    private var yesterdayContextBanner: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.title2)
                .foregroundStyle(DesignTokens.Color.caution)
                .accessibilityHidden(true)
            Text(lang.sleepDetailTodayDataLoadingLegend)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(DesignTokens.Color.caution.opacity(colorScheme == .dark ? 0.18 : 0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .stroke(DesignTokens.Color.caution.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.sleepDetailTodayDataLoadingLegend)
    }

    private var dateRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Text(
                    viewModel.isShowingYesterdaySleep
                        ? lang.homeRingYesterday.uppercased()
                        : lang.homeRingToday.uppercased()
                )
                .font(DesignTokens.Typography.microMedium)
                .foregroundStyle(DesignTokens.Color.caution)
                .accessibilityHidden(true)
                Text(referenceDateForHeader, format: .dateTime.day().month(.wide).year())
                    .font(DesignTokens.Typography.bodyMedium)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
            Spacer()
        }
    }

    private var headlineBlock: some View {
        let s = viewModel.sleepScore.value ?? 0
        return Text(s < 50 ? lang.sleepDetailHeadlineWhenLow : lang.sleepDetailHeadlineWhenOK)
            .font(DesignTokens.Typography.displayTitle)
            .fontWeight(.bold)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var summaryCard: some View {
        let g = viewModel.profileSleepGoalHours
        let t = viewModel.sleepHours.value
        let met = (g > 0 && t != nil) ? (t! + 0.02 >= g) : false

        return VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "moon.fill")
                            .foregroundStyle(DesignTokens.Color.info)
                        Text(lang.sleepDetailDuration)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                    Text(formatHMHours(t))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .monospacedDigit()
                    if g > 0 {
                        HStack(spacing: 8) {
                            Text("/\(Int(round(g)))h")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Color.textSecondary)
                            if let t, !met {
                                Text(lang.sleepDetailGoalNotReached)
                                    .font(DesignTokens.Typography.microMedium)
                                    .foregroundStyle(DesignTokens.Color.caution)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(DesignTokens.Color.caution.opacity(0.15)))
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    HStack {
                        Text(lang.sleepDetailQuality)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                        Image(systemName: "info.circle")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                    if let s = viewModel.sleepScore.value {
                        Text(SleepDetailPresentationBand.fromScore(s).statusLabel(lang))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(SleepDetailPresentationBand.fromScore(s).color(colorScheme))
                    } else {
                        Text("—")
                            .font(.title2)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                    if let s = viewModel.sleepScore.value {
                        Text("\(s)")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                }
            }
        }
        .tokenCard()
    }

    private var contributorsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(lang.sleepDetailContributorsTitle)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
            contributorRow(
                kind: .total,
                icon: "moon.fill",
                title: lang.sleepDetailRowTotal,
                band: SleepDetailPresentationBand.fromScore(viewModel.sleepScore.value ?? 0),
                subtitle: totalSubtitle
            ) {
                let g = viewModel.profileSleepGoalHours
                let t = viewModel.sleepHours.value ?? 0
                let p = g > 0 ? min(1, t / g) : 0
                SleepDetailProgressBar(progress: CGFloat(p), tint: DesignTokens.Color.info)
            }
            contributorRow(
                kind: .restorative,
                icon: "heart.fill",
                title: lang.sleepDetailRowRestorative,
                band: SleepDetailPresentationBand.fromScore(restorativeScore),
                subtitle: restorativeSubtitle
            ) {
                SleepDetailProgressBar(progress: CGFloat(restorativeShare), tint: DesignTokens.Color.info)
            }
            contributorRow(
                kind: .continuity,
                icon: "circle.dotted",
                title: lang.sleepDetailRowContinuity,
                band: SleepDetailPresentationBand.fromScore(viewModel.sleepContinuitySubscore ?? 0),
                subtitle: continuitySubtitle
            ) {
                let v = Double(viewModel.sleepContinuitySubscore ?? 0) / 100
                SleepDetailProgressBar(progress: CGFloat(v), tint: DesignTokens.Color.info)
            }
            contributorRow(
                kind: .efficiency,
                icon: "clock.fill",
                title: lang.sleepDetailRowEfficiency,
                band: SleepDetailPresentationBand.fromScore(efficiencyScore),
                subtitle: efficiencySubtitle
            ) {
                SleepDetailProgressBar(progress: CGFloat(efficiencyRatio), tint: DesignTokens.Color.info)
            }
            contributorRow(
                kind: .regularity,
                icon: "target",
                title: lang.sleepDetailRowRegularity,
                band: SleepDetailPresentationBand.fromScore(viewModel.sleepConsistencyScore),
                subtitle: regularitySubtitle
            ) {
                let v = Double(viewModel.sleepConsistencyScore) / 100
                SleepDetailProgressBar(progress: CGFloat(v), tint: DesignTokens.Color.info)
            }
        }
        .tokenCard()
    }

    private func phasesCard(_ p: (aw: Double, re: Double, co: Double, de: Double)) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            Text(lang.sleepDetailPhasesTitle)
                .font(DesignTokens.Typography.body)
                .fontWeight(.semibold)
            SleepDetailPhaseStrip(awake: p.aw, rem: p.re, core: p.co, deep: p.de)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tokenCard()
    }

    private func contributorRow(
        kind: SleepDetailSheetKind,
        icon: String,
        title: String,
        band: SleepDetailPresentationBand,
        subtitle: String,
        @ViewBuilder bar: @escaping () -> some View
    ) -> some View {
        Button { activeSheet = kind } label: {
            HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
                Image(systemName: icon)
                    .foregroundStyle(DesignTokens.Color.info)
                    .frame(width: 24)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(title)
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                        Spacer()
                        Text(band.statusLabel(lang))
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(band.color(colorScheme))
                    }
                    Text(subtitle)
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .lineLimit(2)
                    bar()
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    #if DEBUG
    @ViewBuilder
    private var sleepScoringDebugSection: some View {
        if let s = viewModel.sleepQualityDebugSnapshot {
            VStack(alignment: .leading, spacing: 8) {
                Text("DEBUG · SleepQualityScoring (último refresh HK)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Color.caution)
                Group {
                    debugLine("TST (h)", String(format: "%.3f", s.totalSleepHours))
                    debugLine("goalHoursUsed", String(format: "%.3f", s.goalHoursUsed))
                    debugLine("sleepConfidence", String(format: "%.3f", s.sleepConfidence))
                    debugLine("durationSubscore", String(format: "%.2f", s.durationSubscore))
                    debugLine("rawWeightedComposite", String(format: "%.2f", s.rawWeightedComposite))
                    debugLine("scoreAfterDurationHourCap", String(format: "%.2f", s.scoreAfterDurationHourCap))
                    debugLine("continuity / rem / deep", String(format: "%.1f / %.1f / %.1f", s.continuitySubscore, s.remSubscore, s.deepSubscore))
                    debugLine("displayScore / forRecovery", "\(s.displayScore) / \(String(format: "%.2f", s.sleepQualityForRecovery))")
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignTokens.Color.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .stroke(DesignTokens.Color.caution.opacity(0.4), lineWidth: 1)
            )
        } else {
            Text("DEBUG: sin desglose (vista AYER con snapshot, o sin TST en el refresh).")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(DesignTokens.Color.textTertiary)
        }
    }

    private func debugLine(_ k: String, _ v: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(k)
                .frame(width: 200, alignment: .leading)
            Text(v)
                .lineLimit(2)
        }
    }
    #endif

    // MARK: - Derived

    private var totalSubtitle: String {
        if viewModel.sleepScore.value == nil { return dayLabel }
        return "\(dayLabel) · \(lang.homeMetricSleepScore)"
    }

    private var restorativeScore: Int {
        let t = viewModel.sleepHours.value ?? 0
        let d = viewModel.deepSleepHours.value ?? 0
        let r = viewModel.remSleepHours.value ?? 0
        guard t > 0.01 else { return 0 }
        return Int(max(0, min(100, (d + r) / t * 100)))
    }

    private var restorativeShare: Double {
        let t = viewModel.sleepHours.value ?? 0
        let d = viewModel.deepSleepHours.value ?? 0
        let r = viewModel.remSleepHours.value ?? 0
        guard t > 0.01 else { return 0 }
        return min(1, (d + r) / t)
    }

    private var restorativeSubtitle: String {
        let d = viewModel.deepSleepHours.value ?? 0
        let r = viewModel.remSleepHours.value ?? 0
        return "\(formatHMHours(d + r)) · \(lang.sleepDetailProportion): \(Int(restorativeShare * 100))%"
    }

    private var continuitySubtitle: String {
        let c = viewModel.sleepAwakeEpisodeCount
        if let s = viewModel.sleepAwakeSecondsDuringSession {
            let m = max(0, Int(s / 60))
            return "\(c)× · \(m)m"
        }
        if c > 0 { return "\(c)×" }
        return "—"
    }

    private var efficiencyRatio: Double {
        guard let w = viewModel.sleepSessionWallDuration, w > 0,
              let t = viewModel.sleepHours.value, t > 0 else { return 0 }
        return min(1, (t * 3600) / w)
    }

    private var efficiencyScore: Int { Int(efficiencyRatio * 100) }

    private var efficiencySubtitle: String {
        guard let w = viewModel.sleepSessionWallDuration, w > 0,
              let t = viewModel.sleepHours.value else { return "—" }
        return "\(formatHMHours(t)) / \(formatHMHours(w / 3600))"
    }

    private var regularitySubtitle: String {
        if !viewModel.lastNightSleepWindow.isEmpty { return viewModel.lastNightSleepWindow }
        if let a = viewModel.sleepSessionStart, let b = viewModel.sleepSessionEnd {
            return "\(formatTime(a)) – \(formatTime(b))"
        }
        return "—"
    }

    private var phaseFractions: (aw: Double, re: Double, co: Double, de: Double)? {
        guard let w = viewModel.sleepSessionWallDuration, w > 0 else { return nil }
        let wallH = w / 3600
        let awH = (viewModel.sleepAwakeSecondsDuringSession ?? 0) / 3600
        let t = viewModel.sleepHours.value ?? 0
        let d = viewModel.deepSleepHours.value ?? 0
        let r = viewModel.remSleepHours.value ?? 0
        let c = max(0, t - d - r)
        return (awH, r, c, d)
    }

    private func scoreForSheet(_ k: SleepDetailSheetKind) -> Int {
        switch k {
        case .total: return viewModel.sleepScore.value ?? 0
        case .restorative: return restorativeScore
        case .continuity: return viewModel.sleepContinuitySubscore ?? 0
        case .efficiency: return efficiencyScore
        case .regularity: return viewModel.sleepConsistencyScore
        }
    }

    private func formatHMHours(_ h: Double?) -> String {
        guard let h, h > 0 else { return "—" }
        let m = Int((h * 60).rounded())
        if m < 60 { return "\(m)m" }
        return String(format: "%dh %dm", m / 60, m % 60)
    }

    private func formatTime(_ d: Date) -> String {
        d.formatted(date: .omitted, time: .shortened)
    }
}
