//
//  DetoxView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct DetoxView: View {
    @Bindable var viewModel: DetoxViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if viewModel.isCompleted {
                        completionSection
                    } else if viewModel.isActive {
                        currentDaySection
                        dayTrackerSection
                        markTodaySection
                        pointsSection
                        deactivateSection
                    } else {
                        inactiveSection
                    }
                }
                .padding()
            }
            .navigationTitle("Detox Mode")
            .task {
                viewModel.refresh()
            }
        }
    }

    // MARK: - Current Day (prominent display)

    private var currentDaySection: some View {
        VStack(spacing: 8) {
            Text("Day \(viewModel.currentDay)")
                .font(.system(size: 72, weight: .bold, design: .rounded))
                .foregroundStyle(.purple)
                .accessibilityLabel("Day \(viewModel.currentDay) of 7")

            Text("of 7")
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.purple.opacity(0.08))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Day \(viewModel.currentDay) of 7")
    }

    // MARK: - 7-Day Progress Tracker

    private var dayTrackerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Progress", systemImage: "calendar")
                .font(.headline)

            HStack(spacing: 8) {
                ForEach(0..<7, id: \.self) { index in
                    dayCircle(index: index)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.daysCompleted) of 7 days completed")
    }

    private func dayCircle(index: Int) -> some View {
        let isMarked = viewModel.dailyLogs[index]
        let isCurrent = index == viewModel.currentDay - 1

        return VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(isMarked ? Color.purple : Color(.systemGray5))
                    .frame(width: 36, height: 36)

                if isMarked {
                    Image(systemName: "checkmark")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Text("\(index + 1)")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(isCurrent ? .purple : .secondary)
                }
            }
            .overlay(
                Circle()
                    .stroke(isCurrent ? Color.purple : Color.clear, lineWidth: 2)
                    .frame(width: 40, height: 40)
            )

            Text("D\(index + 1)")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Mark Today Button

    private var markTodaySection: some View {
        VStack(spacing: 12) {
            if viewModel.isTodayMarked {
                Label("Today marked alcohol-free", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.green)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.green.opacity(0.08))
                    )
                    .accessibilityLabel("Today marked as alcohol-free")
            } else {
                Button(action: { viewModel.markTodayAlcoholFree() }) {
                    Label("Mark Today Alcohol-Free", systemImage: "drop.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .controlSize(.large)
                .accessibilityLabel("Mark today as alcohol-free")
            }
        }
    }

    // MARK: - Points Section

    private var pointsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bonus Points", systemImage: "star.fill")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Earned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.earnedPoints)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.orange)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Available")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(viewModel.totalBonusPoints)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                }
            }

            ProgressView(value: Double(viewModel.earnedPoints), total: Double(viewModel.totalBonusPoints))
                .tint(.orange)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(viewModel.earnedPoints) of \(viewModel.totalBonusPoints) bonus points earned")
    }

    // MARK: - Deactivate

    private var deactivateSection: some View {
        Button(role: .destructive, action: { viewModel.deactivateChallenge() }) {
            Label("Cancel Challenge", systemImage: "xmark.circle")
                .font(.subheadline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .controlSize(.regular)
        .accessibilityLabel("Cancel detox challenge")
    }

    // MARK: - Inactive State

    private var inactiveSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "drop.fill")
                .font(.system(size: 64))
                .foregroundStyle(.purple)

            VStack(spacing: 8) {
                Text("7-Day Detox Challenge")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Commit to 7 alcohol-free days and earn up to \(viewModel.totalBonusPoints) bonus points.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: 8) {
                pointInfoRow(label: "Daily bonus", value: "15 pts × 7 days")
                pointInfoRow(label: "Completion bonus", value: "100 pts")
                Divider()
                pointInfoRow(label: "Total available", value: "\(viewModel.totalBonusPoints) pts")
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
            )

            Button(action: { viewModel.activateChallenge() }) {
                Label("Start Challenge", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            .accessibilityLabel("Start 7-day detox challenge")
        }
    }

    private func pointInfoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }

    // MARK: - Completion Celebration

    private var completionSection: some View {
        VStack(spacing: 24) {
            Image(systemName: "trophy.fill")
                .font(.system(size: 80))
                .foregroundStyle(.yellow)

            Text("Challenge Complete!")
                .font(.title)
                .fontWeight(.bold)

            Text("7 days alcohol-free 🎉")
                .font(.title3)
                .foregroundStyle(.secondary)

            VStack(spacing: 8) {
                Text("+\(viewModel.earnedPoints) points earned")
                    .font(.headline)
                    .foregroundStyle(.orange)

                Text("Badge: 7 days no alcohol")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.purple.opacity(0.08))
            )

            Button(action: { viewModel.activateChallenge() }) {
                Label("Start New Challenge", systemImage: "arrow.counterclockwise")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .controlSize(.large)
            .accessibilityLabel("Start a new detox challenge")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Challenge complete. 7 days alcohol-free. \(viewModel.earnedPoints) points earned.")
    }
}
