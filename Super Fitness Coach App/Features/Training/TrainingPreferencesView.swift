//
//  TrainingPreferencesView.swift
//  Super Fitness Coach App
//

import SwiftUI

struct TrainingPreferencesView: View {
    @Bindable var viewModel: TrainingPreferencesViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// Orden visual del grid: dos arriba, “salud” abajo a ancho completo.
    private let goalGridOrder: [FitnessGoal] = [.gainMuscle, .loseWeight, .beHealthy]

    var body: some View {
        NavigationStack {
            ZStack {
                planBackground
                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        headerCopy

                        goalGridSection

                        experienceChipsSection

                        restDaysStyledSection

                        muscleGridSection

                        cardioStyledSection

                        durationStyledSection

                        generateButtonBlock
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 8)
                    .padding(.bottom, 36)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .principal) {
                    Text("Nuevo plan")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .onChange(of: viewModel.didGenerate) { _, generated in
                if generated { dismiss() }
            }
        }
    }

    // MARK: - Background

    private var planBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.12, green: 0.12, blue: 0.11), Color(red: 0.06, green: 0.06, blue: 0.06)]
                : [Color.planMintTop, Color.planMintBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tu reto empieza aquí")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color.planTitleForeground(for: colorScheme))
            Text("Elige objetivo y detalles; generamos semanas de entreno con tu estilo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Goal grid (referencia: tarjetas blancas / selección naranja)

    private var goalGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Objetivo principal")

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: 14),
                    GridItem(.flexible(), spacing: 14)
                ],
                spacing: 14
            ) {
                ForEach(goalGridOrder, id: \.self) { goal in
                    goalCard(goal)
                        .gridCellColumns(goal == .beHealthy ? 2 : 1)
                }
            }
        }
    }

    private func goalCard(_ goal: FitnessGoal) -> some View {
        let selected = viewModel.goal == goal
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                viewModel.goal = goal
            }
        } label: {
            VStack(spacing: 12) {
                Image(systemName: goalIcon(goal))
                    .font(.system(size: 30, weight: .medium))
                    .symbolRenderingMode(.hierarchical)
                Text(goalDisplayName(goal))
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(selected ? Color.planAccent : cardFill)
            )
            .foregroundStyle(selected ? Color.white : Color.primary)
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .strokeBorder(selected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.08), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(goalDisplayName(goal))\(selected ? ", seleccionado" : "")")
    }

    private var cardFill: Color {
        colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color.white
    }

    // MARK: - Experience

    private var experienceChipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Nivel")
            HStack(spacing: 10) {
                ForEach(FitnessLevel.allCases, id: \.self) { level in
                    let on = viewModel.experienceLevel == level
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.experienceLevel = level
                        }
                    } label: {
                        Text(levelDisplayName(level))
                            .font(.caption)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(on ? Color.planAccent : cardFill)
                            )
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .overlay {
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(on ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 6, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Weekly schedule

    private let dayNames = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]

    private var restDaysStyledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Semana tipo")
            Text("Toca un día para alternar entreno o descanso (mín. 3 entrenos).")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                ForEach(1...7, id: \.self) { day in
                    let isTraining = !viewModel.restDays.contains(day)
                    Button {
                        if isTraining {
                            if viewModel.trainingDaysPerWeek > 3 {
                                viewModel.restDays.insert(day)
                                viewModel.trainingDaysPerWeek -= 1
                            }
                        } else {
                            if viewModel.trainingDaysPerWeek < 6 {
                                viewModel.restDays.remove(day)
                                viewModel.trainingDaysPerWeek += 1
                            }
                        }
                    } label: {
                        VStack(spacing: 6) {
                            Text(dayNames[day - 1])
                                .font(.caption2)
                                .fontWeight(.bold)
                            ZStack {
                                Circle()
                                    .fill(isTraining ? Color.planAccent : Color.primary.opacity(0.12))
                                    .frame(width: 36, height: 36)
                                Image(systemName: isTraining ? "dumbbell.fill" : "moon.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(isTraining ? .white : .secondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(14)
            .background(roundedCard)

            HStack {
                Label("\(viewModel.trainingDaysPerWeek) entrenos", systemImage: "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(Color.planAccent)
                Spacer()
                Label("\(7 - viewModel.trainingDaysPerWeek) descanso", systemImage: "moon.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Muscles

    private var muscleGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Prioridad muscular (máx. 2)")
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                spacing: 10
            ) {
                ForEach(MuscleGroup.allCases) { muscle in
                    let on = viewModel.priorityMuscles.contains(muscle)
                    Button {
                        viewModel.toggleMuscle(muscle)
                    } label: {
                        HStack(spacing: 8) {
                            Text(muscle.rawValue.capitalized)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(on ? Color.white : Color.primary)
                            Spacer(minLength: 0)
                            if on {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(on ? Color.white : Color.planAccent)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(on ? Color.planAccent : cardFill)
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .strokeBorder(on ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            if viewModel.priorityMuscles.count >= 2 {
                Text("Ya elegiste 2 grupos prioritarios.")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }
        }
    }

    // MARK: - Cardio & duration

    private var cardioStyledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Cardio")
            HStack {
                Label("Incluir cardio en el plan", systemImage: "heart.circle.fill")
                    .font(.subheadline)
                    .fontWeight(.medium)
                Spacer()
                Toggle("", isOn: $viewModel.wantsCardio)
                    .labelsHidden()
                    .tint(Color.planAccent)
            }
            .padding(16)
            .background(roundedCard)
        }
    }

    private var durationStyledSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("Duración del plan")
            VStack(spacing: 0) {
                Picker("Semanas", selection: $viewModel.planDurationWeeks) {
                    Text("4 semanas").tag(4)
                    Text("6 semanas").tag(6)
                    Text("8 semanas").tag(8)
                }
                .pickerStyle(.segmented)
                .tint(Color.planAccent)
            }
            .padding(12)
            .background(roundedCard)
        }
    }

    // MARK: - Generate

    private var generateButtonBlock: some View {
        VStack(spacing: 12) {
            Button {
                Task { await viewModel.generatePlan() }
            } label: {
                HStack(spacing: 10) {
                    if viewModel.isGenerating {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isGenerating ? "Generando tu plan…" : "Generar mi plan")
                        .font(.headline)
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 18)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(Color.planAccent)
                )
                .foregroundStyle(.white)
                .shadow(color: Color.planAccent.opacity(0.45), radius: 12, y: 6)
            }
            .disabled(viewModel.isGenerating)
            .accessibilityLabel(viewModel.isGenerating ? "Generando plan" : "Generar plan de entrenamiento")

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: - Pieces

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .fontWeight(.bold)
            .foregroundStyle(Color.planSectionTitleForeground(for: colorScheme))
            .textCase(.uppercase)
            .tracking(0.6)
    }

    private var roundedCard: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(cardFill)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.25 : 0.06), radius: 8, y: 3)
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.05), lineWidth: 1)
            }
    }

    private func goalDisplayName(_ goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "Perder peso"
        case .gainMuscle: return "Ganar músculo"
        case .beHealthy: return "Salud y energía"
        }
    }

    private func goalIcon(_ goal: FitnessGoal) -> String {
        switch goal {
        case .loseWeight: return "flame.fill"
        case .gainMuscle: return "dumbbell.fill"
        case .beHealthy: return "heart.circle.fill"
        }
    }

    private func levelDisplayName(_ level: FitnessLevel) -> String {
        switch level {
        case .beginner: return "Principiante"
        case .intermediate: return "Intermedio"
        case .advanced: return "Avanzado"
        }
    }
}

// MARK: - Palette (alineado con Home)

private extension Color {
    static let planAccent = Color(red: 1.0, green: 122 / 255, blue: 38 / 255)
    static let planMintTop = Color(red: 0.86, green: 0.96, blue: 0.91)
    static let planMintBottom = Color(red: 0.78, green: 0.93, blue: 0.88)
    /// Solo claro: en oscuro `planTitleForeground` usa `primary` (el violeta‑azulado fijo no contrasta).
    static let planTitle = Color(red: 0.22, green: 0.1, blue: 0.26)

    static func planTitleForeground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary : Color.planTitle
    }

    static func planSectionTitleForeground(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color.primary : Color.planTitle.opacity(0.92)
    }
}
