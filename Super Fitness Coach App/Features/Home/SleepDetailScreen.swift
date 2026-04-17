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

    @State private var showWhatItMeans = true

    private var dayLabel: String {
        viewModel.isShowingYesterdaySleep ? lang.homeRingYesterday : lang.homeRingToday
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    header
                    bigRing(
                        title: lang.homeRingSleepTitle,
                        value: viewModel.sleepScore.value,
                        tint: DesignTokens.Color.info
                    )
                    metricList
                    whatItMeansSection
                    footerText(lang.homeSleepFooter)
                }
                .padding(.horizontal, DesignTokens.Spacing.screenH)
                .padding(.vertical, DesignTokens.Spacing.md)
            }
            .background(DesignTokens.Color.surfaceSheet)
            .navigationTitle(lang.homeTodayUpper)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { dismiss() } label: { Image(systemName: "chevron.left") }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Text(lang.homeSleepTitle)
                    .font(DesignTokens.Typography.displayTitle)
                    .fontWeight(.bold)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Text(dayLabel.uppercased())
                    .font(DesignTokens.Typography.microMedium)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        Capsule().fill(DesignTokens.Color.textSecondary.opacity(colorScheme == .dark ? 0.18 : 0.10))
                    )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(lang.homeSleepSubtitle)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            metricRow(icon: "moon.zzz.fill", title: lang.homeMetricSleepTotal, value: formatHours(viewModel.sleepHours.value))
            metricRow(icon: "bed.double.fill", title: lang.homeMetricSleepDeep, value: formatHours(viewModel.deepSleepHours.value))
            metricRow(icon: "sparkles", title: lang.homeMetricSleepREM, value: formatHours(viewModel.remSleepHours.value))
            metricRow(icon: "clock.fill", title: lang.homeMetricSleepRegularity, value: formatPercent(viewModel.sleepConsistencyScore))
            if let start = viewModel.sleepSessionStart, let end = viewModel.sleepSessionEnd {
                metricRow(icon: "calendar", title: lang.homeMetricSleepWindow, value: "\(formatTime(start)) → \(formatTime(end))")
            }
        }
        .tokenCard()
    }

    private var whatItMeansSection: some View {
        DisclosureGroup(isExpanded: $showWhatItMeans) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(lang.homeSleepWhatItMeansIntro)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                definitionRow(title: lang.homeDefinitionSleepTotalTitle, body: lang.homeDefinitionSleepTotalBody)
                definitionRow(title: lang.homeDefinitionSleepDeepTitle, body: lang.homeDefinitionSleepDeepBody)
                definitionRow(title: lang.homeDefinitionSleepREMTitle, body: lang.homeDefinitionSleepREMBody)
                definitionRow(title: lang.homeDefinitionSleepRegularityTitle, body: lang.homeDefinitionSleepRegularityBody)

                Divider()

                Text(lang.homeDataSourceAppleHealthSleep)
                    .font(DesignTokens.Typography.micro)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, DesignTokens.Spacing.sm)
        } label: {
            Text(lang.homeWhatItMeans)
                .font(DesignTokens.Typography.bodyMedium)
                .foregroundStyle(DesignTokens.Color.textPrimary)
        }
        .tokenCard(padding: DesignTokens.Spacing.md)
    }

    private func definitionRow(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text(body)
                .font(DesignTokens.Typography.captionRegular)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func metricRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .frame(width: 22)
            Text(title)
                .font(DesignTokens.Typography.captionRegular)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer()
            Text(value)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private func bigRing(title: String, value: Int?, tint: Color) -> some View {
        let v = value ?? 0
        let progress = min(max(Double(v) / 100.0, 0), 1)
        return VStack(spacing: DesignTokens.Spacing.sm) {
            ZStack {
                Circle()
                    .stroke(Color(.systemGray5).opacity(colorScheme == .dark ? 0.55 : 1), lineWidth: 14)
                    .frame(width: 170, height: 170)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(tint, style: .init(lineWidth: 14, lineCap: .round))
                    .frame(width: 170, height: 170)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 2) {
                    Text(value.map(String.init) ?? "—")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .monospacedDigit()
                    Text(lang.homeOutOf100)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
            Text(title)
                .font(DesignTokens.Typography.microMedium)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .textCase(.uppercase)
                .tracking(0.6)
        }
        .padding(.vertical, DesignTokens.Spacing.sm)
    }

    private func footerText(_ text: String) -> some View {
        Text(text)
            .font(DesignTokens.Typography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.sm)
    }

    private func formatHours(_ hours: Double?) -> String {
        guard let hours else { return "—" }
        return String(format: "%.1f h", hours)
    }

    private func formatPercent(_ v: Int) -> String {
        "\(max(0, min(100, v)))%"
    }

    private func formatTime(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

