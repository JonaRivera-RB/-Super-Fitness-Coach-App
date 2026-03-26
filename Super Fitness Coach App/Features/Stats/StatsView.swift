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
                    prSection
                    historySection
                    badgesSection
                }
                .padding()
            }
            .navigationTitle("Estadísticas")
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
            Text("Nivel \(viewModel.currentLevel)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .accessibilityLabel("Nivel \(viewModel.currentLevel)")

            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .foregroundStyle(.orange)
                Text("\(viewModel.totalPoints) puntos")
                    .fontWeight(.medium)
            }
            .font(.title3)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(viewModel.totalPoints) puntos")
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
                title: "Racha actual",
                value: viewModel.currentStreak,
                icon: "flame.fill",
                color: .red
            )
            streakCard(
                title: "Mejor racha",
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
        .accessibilityLabel("\(title): \(value) días")
    }

    // MARK: - PRs

    private var prSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Récords personales (PR)", systemImage: "crown.fill")
                .font(.headline)

            if viewModel.prRecords.isEmpty {
                Text("Cuando mejores tu mejor e1RM estimado en un ejercicio, aparecerá aquí.")
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
            Label("Historial de sesiones", systemImage: "clock.arrow.circlepath")
                .font(.headline)

            if viewModel.recentHistory.isEmpty {
                Text("Aún no hay entrenos registrados. Completa series desde Entrenamiento.")
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
            Text("\(row.setsCount) series · \(row.volumeText)")
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
            Label("Insignias", systemImage: "medal.fill")
                .font(.headline)

            if viewModel.badges.isEmpty {
                Text("Aún no tienes insignias. ¡Sigue entrenando!")
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

// MARK: - Detail views

private struct WorkoutSessionDetailView: View {
    let row: WorkoutHistoryRow

    var body: some View {
        List {
            Section {
                LabeledContent("Ejercicio", value: row.exerciseName)
                LabeledContent("Fecha") {
                    Text(row.date, format: .dateTime.day().month(.wide).year().hour().minute())
                }
            }
            Section("Series") {
                ForEach(Array(row.log.sets.enumerated()), id: \.offset) { index, s in
                    HStack {
                        Text("Serie \(index + 1)")
                        Spacer()
                        Text(String(format: "%.1f kg × %d", s.weight, s.reps))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Section {
                Text(row.volumeText)
                Text(row.bestSetText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Detalle")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct PRRecordDetailView: View {
    let record: PRRecordRow

    var body: some View {
        List {
            Section {
                LabeledContent("Ejercicio", value: record.exerciseName)
                LabeledContent("Fecha") {
                    Text(record.date, format: .dateTime.day().month(.wide).year().hour().minute())
                }
            }
            Section("Serie destacada") {
                Text(record.headline)
                Text(record.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("PR")
        .navigationBarTitleDisplayMode(.inline)
    }
}
