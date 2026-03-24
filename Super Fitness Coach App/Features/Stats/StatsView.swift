//
//  StatsView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct StatsView: View {
    @Bindable var viewModel: StatsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    levelSection
                    streakSection
                    badgesSection
                }
                .padding()
            }
            .navigationTitle("Stats")
            .task {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Level & Points

    private var levelSection: some View {
        VStack(spacing: 12) {
            Text("Level \(viewModel.currentLevel)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .accessibilityLabel("Level \(viewModel.currentLevel)")

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.totalPoints) points")
                    .fontWeight(.medium)
            }
            .font(.title3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.totalPoints) points")
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
                title: "Current Streak",
                value: viewModel.currentStreak,
                icon: "flame.fill",
                color: .red
            )
            streakCard(
                title: "Personal Best",
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
        .accessibilityLabel("\(title): \(value) days")
    }

    // MARK: - Badges

    private var badgesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Badges", systemImage: "medal.fill")
                .font(.headline)

            if viewModel.badges.isEmpty {
                Text("No badges earned yet. Keep going!")
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
        .accessibilityLabel("Badge: \(badge.name)")
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
