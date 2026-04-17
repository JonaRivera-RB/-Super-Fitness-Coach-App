//
//  RecoveryDetailScreen.swift
//  Super Fitness Coach App
//

import SwiftUI

struct RecoveryDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HomeViewModel
    @State private var showWhatItMeans = true

    private var tint: Color {
        let score = viewModel.recoveryScore.value ?? 0
        return DesignTokens.Color.recoveryLevel(score: score).accent
    }

    private var dayLabel: String {
        viewModel.isShowingYesterdayRecovery ? lang.homeRingYesterday : lang.homeRingToday
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    header
                    bigRing(
                        title: lang.homeRingRecoveryTitle,
                        value: viewModel.recoveryScore.value,
                        tint: tint
                    )
                    metricList
                    whatItMeansSection
                    footerText(lang.homeRecoveryFooter)
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
                Text(lang.homeRecoveryTitle)
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

            Text(lang.homeRecoverySubtitle)
                .font(DesignTokens.Typography.displayTitle)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            metricRow(icon: "waveform.path.ecg", title: lang.homeMetricHRV, value: formatMs(viewModel.hrv.value))
            metricRow(icon: "heart.fill", title: lang.homeMetricRHR, value: formatBpm(viewModel.restingHR.value))
            metricRow(icon: "moon.zzz.fill", title: lang.homeMetricSleepScore, value: formatScore(viewModel.sleepScore.value))
            metricRow(icon: "chart.line.uptrend.xyaxis", title: lang.homeMetricConfidence, value: viewModel.recoveryConfidenceLabel)
        }
        .tokenCard()
    }

    private var whatItMeansSection: some View {
        DisclosureGroup(isExpanded: $showWhatItMeans) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(lang.homeRecoveryWhatItMeansIntro)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                definitionRow(title: lang.homeDefinitionHRVTitle, body: lang.homeDefinitionHRVBody)
                definitionRow(title: lang.homeDefinitionRHRTitle, body: lang.homeDefinitionRHRBody)
                definitionRow(title: lang.homeDefinitionSleepScoreTitle, body: lang.homeDefinitionSleepScoreBody)
                definitionRow(title: lang.homeDefinitionConfidenceTitle, body: lang.homeDefinitionConfidenceBody)

                Divider()

                Text(lang.homeDataSourceAppleHealth)
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

    private func formatMs(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(round(v))) ms"
    }

    private func formatBpm(_ v: Double?) -> String {
        guard let v else { return "—" }
        return "\(Int(round(v))) lpm"
    }

    private func formatScore(_ v: Int?) -> String {
        guard let v else { return "—" }
        return "\(v)/100"
    }
}

