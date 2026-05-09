//
//  ActivityDetailScreen.swift
//  Super Fitness Coach App
//

import SwiftUI

struct ActivityDetailScreen: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang
    @Environment(\.locale) private var locale
    @Environment(\.colorScheme) private var colorScheme

    let viewModel: HomeViewModel

    @State private var showWhatItMeans = true

    private var integerFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = locale
        f.maximumFractionDigits = 0
        return f
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DesignTokens.Spacing.lg) {
                    header
                    bigRing(
                        title: lang.homeRingActivityTitle,
                        value: viewModel.activityScore.value,
                        tint: DesignTokens.Color.reward
                    )
                    metricList
                    whatItMeansSection
                    footerText(lang.homeActivityFooter)
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
            Text(lang.homeActivityTitle)
                .font(DesignTokens.Typography.displayTitle)
                .fontWeight(.bold)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text(lang.homeActivitySubtitle)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var metricList: some View {
        VStack(spacing: DesignTokens.Spacing.sm) {
            activityMetricRow(
                icon: "figure.walk",
                title: lang.homeMetricSteps,
                current: viewModel.stepCount.value,
                goal: viewModel.stepsGoal
            )
            activityMetricRow(
                icon: "flame.fill",
                title: lang.homeMetricActiveCalories,
                current: viewModel.activeEnergy.value,
                goal: viewModel.calorieGoal,
                suffixKcal: true
            )
        }
        .tokenCard()
    }

    private func activityMetricRow(
        icon: String,
        title: String,
        current: Double?,
        goal: Double,
        suffixKcal: Bool = false
    ) -> some View {
        let goalStr = formatIntForDisplay(goal)
        let currentStr: String = {
            guard let current else { return "—" }
            let s = formatIntForDisplay(current)
            return suffixKcal ? "\(s) kcal" : s
        }()
        return HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .frame(width: 22)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Text("\(lang.homeActivityGoalShort): \(goalStr)\(suffixKcal ? " kcal" : "")")
                    .font(DesignTokens.Typography.micro)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
            Spacer(minLength: DesignTokens.Spacing.sm)
            Text(currentStr)
                .font(DesignTokens.Typography.caption)
                .fontWeight(.semibold)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
        }
        .padding(.vertical, 6)
    }

    private func formatIntForDisplay(_ value: Double) -> String {
        let n = NSNumber(value: round(value))
        return integerFormatter.string(from: n) ?? String(Int(round(value)))
    }

    private var whatItMeansSection: some View {
        DisclosureGroup(isExpanded: $showWhatItMeans) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(lang.homeActivityWhatItMeansIntro)
                    .font(DesignTokens.Typography.captionRegular)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                definitionRow(title: lang.homeDefinitionStepsTitle, body: lang.homeDefinitionStepsBody)
                definitionRow(title: lang.homeDefinitionActiveCaloriesTitle, body: lang.homeDefinitionActiveCaloriesBody)

                Divider()

                Text(lang.homeDataSourceAppleHealthActivity)
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

}

