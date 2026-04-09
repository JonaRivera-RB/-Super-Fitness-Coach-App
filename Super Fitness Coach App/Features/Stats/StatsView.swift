//
//  StatsView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: StatsViewModel
    @Environment(\.appLanguage) private var lang

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    levelSection
                    streakSection
                    prSection
                    historySection
                    badgesSection
                }
                .padding()
            }
            .navigationTitle(lang.statsNavTitle)
            .refreshable {
                viewModel.refresh()
            }
            .task {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Level & Points

    private var levelSection: some View {
        VStack(spacing: 12) {
            Text(lang.statsLevel(viewModel.currentLevel))
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .accessibilityLabel(lang.statsLevel(viewModel.currentLevel))

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.totalPoints) \(lang.pointsWord)")
                    .fontWeight(.medium)
            }
            .font(.title3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lang.pointsA11y(viewModel.totalPoints))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.orange.opacity(0.08))
        )
    }

    // MARK: - Streaks

    private var streakSection: some View {
        HStack(spacing: 16) {
            streakCard(
                title: lang.statsStreakCurrent,
                value: viewModel.currentStreak,
                icon: "flame.fill",
                color: .red
            )
            streakCard(
                title: lang.statsStreakBest,
                value: viewModel.personalBestStreak,
                icon: "trophy.fill",
                color: .yellow
            )
        }
    }

    private func streakCard(title: String, value: Int, icon: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)")
                .font(.system(size: 32, weight: .bold, design: .rounded))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.statsStreakA11y(title: title, value: value))
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.statsPRSection, systemImage: "crown.fill")
                .font(.headline)

            if viewModel.prRecords.isEmpty {
                Text(lang.statsPREmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.prRecords) { pr in
                        NavigationLink {
                            PRRecordDetailView(record: pr)
                        } label: {
                            prRow(pr)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func prRow(_ pr: PRRecordRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(pr.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(pr.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(pr.headline)
                .font(.caption)
                .foregroundStyle(.primary)
            Text(pr.subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - History

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.statsHistorySection, systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if viewModel.recentHistory.isEmpty {
                Text(lang.statsHistoryEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(viewModel.recentHistory) { row in
                        NavigationLink {
                            WorkoutSessionDetailView(row: row)
                        } label: {
                            historyRow(row)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func historyRow(_ row: WorkoutHistoryRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.exerciseName)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                Spacer()
                Text(row.date, format: .dateTime.day().month(.abbreviated).hour().minute())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(lang.statsSetsVolumeLine(sets: row.setsCount, volume: row.volumeText))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Divider()
        }
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(lang.statsBadges, systemImage: "medal.fill")
                .font(.headline)

            if viewModel.badges.isEmpty {
                Text(lang.statsBadgesEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(viewModel.badges) { badge in
                        badgeCard(badge)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }

    private func badgeCard(_ badge: Badge) -> some View {
        VStack(spacing: 6) {
            Image(systemName: badgeIcon(for: badge.id))
                .font(.title2)
                .foregroundStyle(.purple)
            Text(badge.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(lang.badgeA11y(badge.name))
    }

    private func badgeIcon(for milestoneId: String) -> String {
        switch milestoneId {
        case BadgeMilestone.sevenDaysNoAlcohol.rawValue: return "drop.fill"
        case BadgeMilestone.fiveConsecutiveWorkouts.rawValue: return "figure.run"
        case BadgeMilestone.firstWorkout.rawValue: return "checkmark.seal.fill"
        case BadgeMilestone.levelTenReached.rawValue: return "star.circle.fill"
        case BadgeMilestone.thirtyDayStreak.rawValue: return "flame.fill"
        default: return "medal.fill"
        }
    }
}

// MARK: - Detail views

private struct WorkoutSessionDetailView: View {
    let row: WorkoutHistoryRow
    @State private var showVolumeInfo = false
    @Environment(\.appLanguage) private var lang

    var body: some View {
        List {
            Section {
                LabeledContent(lang.sessionExercise, value: row.exerciseName)
                LabeledContent(lang.sessionDate) {
                    Text(row.date, format: .dateTime.day().month(.wide).year().hour().minute())
                }
            }
            Section(lang.sessionSetsSection) {
                ForEach(Array(row.log.sets.enumerated()), id: \.offset) { index, s in
                    HStack {
                        Text(lang.sessionSetRow(index + 1))
                        Spacer()
                        Text(String(format: "%.1f kg × %d", s.weight, s.reps))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                HStack {
                    Text(row.volumeText)
                    Spacer()
                    Button {
                        showVolumeInfo = true
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(lang.volumeInfoA11y)
                }
                Text(row.bestSetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(lang.sessionDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(lang.volumeInfoTitle, isPresented: $showVolumeInfo) {
            Button(lang.ok, role: .cancel) {}
        } message: {
            Text(lang.volumeInfoBody)
        }
    }
}

private struct PRRecordDetailView: View {
    let record: PRRecordRow
    @Environment(\.appLanguage) private var lang

    var body: some View {
        List {
            Section {
                LabeledContent(lang.sessionExercise, value: record.exerciseName)
                LabeledContent(lang.sessionDate) {
                    Text(record.date, format: .dateTime.day().month(.wide).year().hour().minute())
                }
            }
            Section(lang.prFeaturedSet) {
                Text(record.headline)
                Text(record.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle(lang.prDetailTitle)
        .navigationBarTitleDisplayMode(.inline)
    }
}
