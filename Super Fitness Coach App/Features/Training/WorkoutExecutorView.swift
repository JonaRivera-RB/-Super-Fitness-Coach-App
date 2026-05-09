//
//  WorkoutExecutorView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData
import UIKit

/// Workout execution screen inspired by Strong/Hevy:
/// - One exercise at a time with all sets visible
/// - Tap-to-log with pre-filled weights from plan
/// - Integrated rest timer
/// - Auto-advance on completion
struct WorkoutExecutorView: View {
    @Bindable var viewModel: WorkoutExecutorViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appLanguage) private var lang

    @Query(sort: \UserProfile.createdAt, order: .reverse) private var userProfiles: [UserProfile]

    private var liftingWeightUnit: LiftingWeightUnit {
        userProfiles.first?.effectiveFitnessConfig.liftingWeightUnit ?? .kilograms
    }

    var onWorkoutComplete: (([WorkoutLog]) -> Void)?

    @State private var weightInputs: [[String]] = []
    @State private var repsInputs: [[String]] = []
    @State private var showFeedback = false
    @State private var showExerciseDetail = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                exerciseProgressBar

                if !viewModel.exercises.isEmpty && !viewModel.isWorkoutComplete {
                    coachBanner
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                }

                if viewModel.isWorkoutComplete {
                    workoutCompleteScreen
                } else if viewModel.exercises.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36))
                            .foregroundStyle(.orange)
                        Text(lang.noExercisesTitle)
                            .font(.headline)
                        Text(lang.noExercisesMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    Spacer()
                } else {
                    ZStack(alignment: .bottom) {
                        ScrollView {
                            VStack(spacing: 16) {
                                exerciseHeader
                                setsTable
                            }
                            .padding()
                            // Espacio para la barra de descanso y que la última serie sea scrolleable
                            .padding(.bottom, viewModel.isRestTimerActive ? 120 : 40)
                        }
                        restTimerFloatingBar
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle(lang.workoutTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(lang.close) { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Text("\(viewModel.currentExerciseIndex + 1) / \(viewModel.exercises.count)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        ForEach(Array(viewModel.exercises.enumerated()), id: \.offset) { idx, ex in
                            Button {
                                viewModel.jumpToExercise(at: idx)
                            } label: {
                                Label {
                                    Text("\(idx + 1). \(ex.name)")
                                        .lineLimit(2)
                                } icon: {
                                    Image(systemName: idx == viewModel.currentExerciseIndex ? "checkmark.circle.fill" : "circle")
                                }
                            }
                        }
                    } label: {
                        Label(lang.workoutExercisePickerTitle, systemImage: "list.bullet")
                    }
                    .disabled(viewModel.exercises.isEmpty || viewModel.isWorkoutComplete)

                    Button {
                        viewModel.skipCurrentExercise()
                    } label: {
                        Label(lang.workoutSkipExercise, systemImage: "forward.end.fill")
                    }
                    .disabled(viewModel.exercises.isEmpty || viewModel.isWorkoutComplete)
                    .accessibilityLabel(lang.workoutSkipExercise)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button(lang.doneKeyboard) {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                viewModel.buildDailyExercises()
                // Wait for exercises to be built before initializing inputs
                if !viewModel.exercises.isEmpty {
                    buildInputs()
                }
            }
            .onChange(of: viewModel.exercises.count) { _, count in
                if count > 0 {
                    buildInputs()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    viewModel.syncRestTimerFromDeadline()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                viewModel.syncRestTimerFromDeadline()
            }
            .onDisappear {
                viewModel.stopRestTimer()
            }
            .onChange(of: viewModel.isWorkoutComplete) { _, complete in
                if complete {
                    onWorkoutComplete?(viewModel.completedLogs)
                }
            }
            .onChange(of: viewModel.currentExerciseIndex) { _, _ in
                // Scroll to top when exercise changes
            }
        }
    }

    // MARK: - Workout Complete Screen

    private var workoutCompleteScreen: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()
            Image(systemName: "trophy.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Color.reward)
            Text(lang.workoutCompleteTitle)
                .font(DesignTokens.Typography.displayTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Text("\(viewModel.exercises.count) \(lang.workoutCompleteStats) · \(viewModel.completedLogs.flatMap(\.sets).count) \(lang.workoutCompleteSets)")
                .font(.subheadline)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            Spacer()
            VStack(spacing: DesignTokens.Spacing.md) {
                Button {
                    dismiss()
                } label: {
                    Label(lang.viewSummary, systemImage: "chart.bar.fill")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(lang.close) { dismiss() }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, DesignTokens.Spacing.screenH)
            .padding(.bottom, DesignTokens.Spacing.xl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Coach (gym)

    private func coachAccessibilitySummary(exercise: PlannedExercise?) -> String {
        var parts: [String] = []
        if !viewModel.gymCoachMessage.isEmpty {
            parts.append(viewModel.gymCoachMessage)
        }
        if viewModel.isRestTimerActive, let ex = exercise {
            parts.append(GymCoach.restFocus(exercise: ex, restSecondsRemaining: viewModel.restTimerSeconds, language: lang))
        }
        return parts.joined(separator: " ")
    }

    private var coachBanner: some View {
        let idx = viewModel.currentExerciseIndex
        let exercise = viewModel.exercises.indices.contains(idx) ? viewModel.exercises[idx] : nil

        return Group {
            if !viewModel.gymCoachMessage.isEmpty || viewModel.isRestTimerActive {
                HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .font(.title3)
                        .foregroundStyle(Color(uiColor: .systemTeal))
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                        if !viewModel.gymCoachMessage.isEmpty {
                            Text(viewModel.gymCoachMessage)
                                .font(.subheadline)
                                .foregroundStyle(DesignTokens.Color.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if viewModel.isRestTimerActive, let ex = exercise {
                            Text(GymCoach.restFocus(exercise: ex, restSecondsRemaining: viewModel.restTimerSeconds, language: lang))
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Color.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(DesignTokens.Spacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                        .fill(Color(uiColor: .systemTeal).opacity(colorScheme == .dark ? 0.30 : 0.12))
                )
                .accessibilityElement(children: .combine)
                .accessibilityLabel(coachAccessibilitySummary(exercise: exercise))
            }
        }
    }

    // MARK: - Progress Bar

    private var exerciseProgressBar: some View {
        GeometryReader { geo in
            let total = max(viewModel.exercises.count, 1)
            let completed = viewModel.exercises.indices.filter { idx in
                viewModel.completedSets.indices.contains(idx) &&
                viewModel.completedSets[idx].allSatisfy { $0 }
            }.count
            let fraction = CGFloat(completed) / CGFloat(total)

            ZStack(alignment: .leading) {
                Rectangle().fill(Color(uiColor: colorScheme == .dark ? .tertiarySystemFill : .systemGray5))
                Rectangle().fill(DesignTokens.Color.positive)
                    .frame(width: geo.size.width * fraction)
                    .animation(.easeInOut(duration: 0.3), value: fraction)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Exercise Header

    private var exerciseHeader: some View {
        let exercise = viewModel.exercises[viewModel.currentExerciseIndex]

        return VStack(spacing: 8) {
            Button {
                showExerciseDetail = true
            } label: {
                VStack(spacing: 4) {
                    Text(exercise.name)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.primary)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 4) {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text(lang.seeDetail)
                            .font(.caption)
                    }
                    .foregroundStyle(DesignTokens.Color.info)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showExerciseDetail) {
                ExerciseDetailView(exercise: exercise)
            }

            if let cap = targetWeightCaption(exercise, unit: liftingWeightUnit) {
                Text(cap)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Label(exercise.muscleGroup.displayName(lang), systemImage: "figure.strengthtraining.traditional")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(colorScheme == .dark ? DesignTokens.Color.textPrimary : DesignTokens.Color.info)
                    .padding(.horizontal, DesignTokens.Spacing.sm)
                    .padding(.vertical, DesignTokens.Spacing.xs)
                    .background(Capsule().fill(DesignTokens.Color.info.opacity(colorScheme == .dark ? 0.30 : 0.12)))

                if exercise.isCompound {
                    Text(lang.labelCompound)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.caution)
                        .padding(.horizontal, DesignTokens.Spacing.sm)
                        .padding(.vertical, DesignTokens.Spacing.xs)
                        .background(Capsule().fill(DesignTokens.Color.caution.opacity(colorScheme == .dark ? 0.30 : 0.12)))
                }

                if !exercise.equipment.isEmpty {
                    Label(exercise.equipment, systemImage: "dumbbell.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Series (tarjetas grandes, fáciles de tocar)

    private var setsTable: some View {
        let exerciseIdx = viewModel.currentExerciseIndex
        let exercise = viewModel.exercises[exerciseIdx]

        return VStack(alignment: .leading, spacing: 14) {
            Text(lang.yourSets)
                .font(.title3)
                .fontWeight(.bold)

            Text(lang.setsHint(weightUnitSymbol: liftingWeightUnit.symbol))
                .font(.subheadline)
                .foregroundStyle(.secondary)

            switch viewModel.setsFooterInfo(for: exerciseIdx) {
            case .none:
                EmptyView()
            case .miRutinaNote:
                Text(lang.workoutFootnoteMiRutinaSeries)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            case .planAdjusted(let original, let adjusted):
                Text(lang.workoutFootnotePlanAdjustedSeries(original: original, adjusted: adjusted))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.caution.opacity(colorScheme == .dark ? 0.95 : 0.90))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ForEach(0..<exercise.sets, id: \.self) { setIndex in
                let done = viewModel.completedSets[safe: exerciseIdx]?[safe: setIndex] ?? false
                let pr = viewModel.prSets[safe: exerciseIdx]?[safe: setIndex] ?? false
                let prev = viewModel.previousDisplay(
                    catalogExerciseId: exercise.effectiveCatalogId,
                    setIndex: setIndex,
                    unit: liftingWeightUnit
                )
                let rawWeight = weightInputs[safe: exerciseIdx]?[safe: setIndex] ?? ""
                WorkoutSetCard(
                    setIndex: setIndex,
                    isCompleted: done,
                    isPR: pr,
                    previousLine: prev,
                    liftingUnit: liftingWeightUnit,
                    equivalentWeightLine: weightEquivalentLine(rawWeight: rawWeight),
                    weightText: weightBinding(exerciseIndex: exerciseIdx, setIndex: setIndex),
                    repsText: repsBinding(exerciseIndex: exerciseIdx, setIndex: setIndex),
                    onRegister: { completeSetAction(exerciseIndex: exerciseIdx, setIndex: setIndex) },
                    onWeightMinus: { bumpWeight(exerciseIndex: exerciseIdx, setIndex: setIndex, direction: -1) },
                    onWeightPlus: { bumpWeight(exerciseIndex: exerciseIdx, setIndex: setIndex, direction: 1) },
                    onRepsMinus: { bumpReps(exerciseIndex: exerciseIdx, setIndex: setIndex, direction: -1) },
                    onRepsPlus: { bumpReps(exerciseIndex: exerciseIdx, setIndex: setIndex, direction: 1) }
                )
            }
        }
    }

    /// Paso de peso al pulsar − / +: 2,5 kg o **1 lb** (más natural en gimnasios con placas en lb).
    private func weightStepKg() -> Double {
        switch liftingWeightUnit {
        case .kilograms: return 2.5
        case .pounds: return UnitConverter.lbsToKg(1)
        }
    }

    private func bumpWeight(exerciseIndex: Int, setIndex: Int, direction: Int) {
        guard exerciseIndex < weightInputs.count, setIndex < weightInputs[exerciseIndex].count else { return }
        let raw = weightInputs[exerciseIndex][setIndex]
        let kg = UnitConverter.parseLiftInputToKg(raw, unit: liftingWeightUnit) ?? 0
        let newKg = max(0, kg + Double(direction) * weightStepKg())
        weightInputs[exerciseIndex][setIndex] = UnitConverter.formatLiftKgForDisplay(newKg, unit: liftingWeightUnit)
    }

    private func bumpReps(exerciseIndex: Int, setIndex: Int, direction: Int) {
        guard exerciseIndex < repsInputs.count, setIndex < repsInputs[exerciseIndex].count else { return }
        let r = Int(repsInputs[exerciseIndex][setIndex].trimmingCharacters(in: .whitespaces)) ?? 0
        let newR = max(0, min(99, r + direction))
        repsInputs[exerciseIndex][setIndex] = "\(newR)"
    }

    // MARK: - Descanso (barra flotante abajo, encima del scroll)

    @ViewBuilder
    private var restTimerFloatingBar: some View {
        if viewModel.isRestTimerActive {
            HStack(spacing: DesignTokens.Spacing.md) {
                Image(systemName: "timer.circle.fill")
                    .font(.title2)
                    .foregroundStyle(DesignTokens.Color.info)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                    Text(lang.restTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text(lang.nextSet)
                        .font(DesignTokens.Typography.micro)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                Spacer(minLength: DesignTokens.Spacing.sm)
                Text("\(viewModel.restTimerSeconds)")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(DesignTokens.Color.info)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                Text(lang.secondsShort)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(DesignTokens.Color.info.opacity(0.85))
            }
            .padding(.horizontal, DesignTokens.Spacing.lg)
            .padding(.vertical, DesignTokens.Spacing.md)
            .frame(maxWidth: .infinity)
            .background {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                    .strokeBorder(DesignTokens.Color.info.opacity(0.35), lineWidth: 1)
            )
            .tokenShadow(.floating)
            .padding(.horizontal, DesignTokens.Spacing.md)
            .padding(.bottom, DesignTokens.Spacing.sm)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(lang.restAccessibility(seconds: viewModel.restTimerSeconds))
        }
    }

    private func targetWeightCaption(_ exercise: PlannedExercise, unit: LiftingWeightUnit) -> String? {
        let minW = exercise.suggestedWeight
        guard minW > 0 else { return nil }
        return UnitConverter.liftTargetCaption(minKg: minW, maxKg: exercise.targetWeightMax, unit: unit)
    }

    /// Conversión explícita a la otra unidad mientras escribes (misma fórmula que el guardado en kg).
    private func weightEquivalentLine(rawWeight: String) -> String? {
        guard let kg = UnitConverter.parseLiftInputToKg(rawWeight, unit: liftingWeightUnit), kg > 0 else { return nil }
        let other = UnitConverter.formatLiftOtherUnitFromKg(kg, displayUnit: liftingWeightUnit)
        return lang.liftWeightEquivalentLine(fullOtherUnit: other)
    }

    // MARK: - Actions

    private func completeSetAction(exerciseIndex: Int, setIndex: Int) {
        let raw = weightInputs[safe: exerciseIndex]?[safe: setIndex] ?? "0"
        let weightKg = UnitConverter.parseLiftInputToKg(raw, unit: liftingWeightUnit) ?? 0
        let reps = Int(repsInputs[safe: exerciseIndex]?[safe: setIndex] ?? "0") ?? 0
        viewModel.completeSet(exerciseIndex: exerciseIndex, setIndex: setIndex, weight: weightKg, reps: reps)
    }

    // MARK: - Input Management

    private func buildInputs() {
        weightInputs = viewModel.exercises.map { ex in
            (0..<ex.sets).map { idx in
                let kg = viewModel.defaultWeight(exercise: ex, setIndex: idx)
                return UnitConverter.formatLiftKgForDisplay(kg, unit: liftingWeightUnit)
            }
        }
        repsInputs = viewModel.exercises.map { ex in
            (0..<ex.sets).map { idx in
                "\(viewModel.defaultReps(exercise: ex, setIndex: idx))"
            }
        }
    }

    private func weightBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { weightInputs[safe: exerciseIndex]?[safe: setIndex] ?? "" },
            set: { val in
                guard exerciseIndex < weightInputs.count, setIndex < weightInputs[exerciseIndex].count else { return }
                weightInputs[exerciseIndex][setIndex] = val
            }
        )
    }

    private func repsBinding(exerciseIndex: Int, setIndex: Int) -> Binding<String> {
        Binding(
            get: { repsInputs[safe: exerciseIndex]?[safe: setIndex] ?? "" },
            set: { val in
                guard exerciseIndex < repsInputs.count, setIndex < repsInputs[exerciseIndex].count else { return }
                repsInputs[exerciseIndex][setIndex] = val
            }
        )
    }
}

// MARK: - Tarjeta de serie (UI grande y clara)

private struct WorkoutSetCard: View {
    let setIndex: Int
    let isCompleted: Bool
    let isPR: Bool
    let previousLine: String
    let liftingUnit: LiftingWeightUnit
    /// Nil si el campo está vacío / 0 o no se puede parsear.
    let equivalentWeightLine: String?
    @Binding var weightText: String
    @Binding var repsText: String
    let onRegister: () -> Void
    let onWeightMinus: () -> Void
    let onWeightPlus: () -> Void
    let onRepsMinus: () -> Void
    let onRepsPlus: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var lang

    private var setNumber: Int { setIndex + 1 }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.md) {
            header
            if previousLine != "—" { previousRow }
            inputsBlock
            if !isCompleted { registerButton }
        }
        .padding(DesignTokens.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                .strokeBorder(
                    isCompleted
                        ? DesignTokens.Color.positive.opacity(0.45)
                        : DesignTokens.Color.textPrimary.opacity(0.06),
                    lineWidth: isCompleted ? 2 : 1
                )
        )
        .tokenShadow(.card)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.sm) {
            Text(lang.setLabel(setNumber: setNumber))
                .font(DesignTokens.Typography.numberCompact)
                .foregroundStyle(isCompleted ? DesignTokens.Color.positive : DesignTokens.Color.textPrimary)
            Spacer()
            if isCompleted {
                HStack(spacing: DesignTokens.Spacing.sm) {
                    if isPR {
                        Text(lang.prBadge)
                            .font(DesignTokens.Typography.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DesignTokens.Spacing.sm)
                            .padding(.vertical, DesignTokens.Spacing.xs)
                            .background(Capsule().fill(DesignTokens.Color.restDay))
                    }
                    Label(lang.setDone, systemImage: "checkmark.circle.fill")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(DesignTokens.Color.positive)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private var previousRow: some View {
        HStack(alignment: .center, spacing: 8) {
            Image(systemName: "arrow.counterclockwise")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(lang.lastTimeLine(previousLine))
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel(lang.lastTimeLine(previousLine))
    }

    /// Peso y repeticiones en la **misma línea** (dos columnas), con controles compactos.
    private var inputsBlock: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(lang.weightAndReps)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(liftingUnit == .kilograms ? lang.stepHintKg : lang.stepHintLb)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .center, spacing: 6) {
                    Text(lang.weightFieldLabel(symbol: liftingUnit.symbol))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    quantityRow(
                        text: $weightText,
                        isDecimal: true,
                        compact: true,
                        disabled: isCompleted,
                        accessibilityLabel: "\(lang.weightFieldLabel(symbol: liftingUnit.symbol)) \(setNumber)",
                        onMinus: onWeightMinus,
                        onPlus: onWeightPlus
                    )
                    if let equivalentWeightLine {
                        Text(equivalentWeightLine)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity)

                VStack(alignment: .center, spacing: 6) {
                    Text(lang.repsShort)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    quantityRow(
                        text: $repsText,
                        isDecimal: false,
                        compact: true,
                        disabled: isCompleted,
                        accessibilityLabel: "\(lang.repsShort) \(setNumber)",
                        onMinus: onRepsMinus,
                        onPlus: onRepsPlus
                    )
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var registerButton: some View {
        Button(action: onRegister) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                Text(lang.logSetButton(setNumber: setNumber))
                    .font(DesignTokens.Typography.cardTitle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .fill(Color(uiColor: .systemTeal).opacity(colorScheme == .dark ? 0.42 : 0.20))
            )
            .foregroundStyle(colorScheme == .dark ? DesignTokens.Color.textPrimary : Color(uiColor: .systemTeal))
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.card, style: .continuous)
                    .strokeBorder(Color(uiColor: .systemTeal).opacity(colorScheme == .dark ? 0.55 : 0.45), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang.logSetButton(setNumber: setNumber))
    }

    private func quantityRow(
        text: Binding<String>,
        isDecimal: Bool,
        compact: Bool,
        disabled: Bool,
        accessibilityLabel: String,
        onMinus: @escaping () -> Void,
        onPlus: @escaping () -> Void
    ) -> some View {
        let btnSize: CGFloat = compact ? 38 : 44
        let fieldFont: CGFloat = compact ? 24 : 32
        let minH: CGFloat = compact ? 48 : 56
        let padV: CGFloat = compact ? 10 : 12

        return HStack(alignment: .center, spacing: compact ? 8 : 12) {
            Button(action: onMinus) {
                Image(systemName: "minus.circle.fill")
                    .font(.system(size: btnSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(disabled ? Color.secondary.opacity(0.35) : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .disabled(disabled)

            TextField("0", text: text)
                .keyboardType(isDecimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.center)
                .font(.system(size: fieldFont, weight: .semibold, design: .rounded))
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .frame(minHeight: minH)
                .frame(maxWidth: .infinity)
                .padding(.vertical, padV)
                .padding(.horizontal, compact ? 6 : 12)
                .background(
                    RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                        .fill(Color(.systemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: compact ? 14 : 16, style: .continuous)
                        .strokeBorder(Color(.separator), lineWidth: 1)
                )
                .disabled(disabled)
                .accessibilityLabel(accessibilityLabel)

            Button(action: onPlus) {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: btnSize))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(disabled ? Color.secondary.opacity(0.35) : Color.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .contentShape(Rectangle())
            .disabled(disabled)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Safe Array Access

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
