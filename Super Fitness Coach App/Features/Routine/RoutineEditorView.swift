//
//  RoutineEditorView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData
import UIKit

/// Espaciado y radios compartidos (cuadrícula 8 pt) para lista y tarjetas de «Mi rutina».
private enum RoutineEditorLayout {
    static let hInset: CGFloat = 16
    static let cardInset: CGFloat = 8
    static let radiusS: CGFloat = 14
    static let radiusM: CGFloat = 16
    static let radiusL: CGFloat = 18
    static let dayChip: CGFloat = 40
    static let dayChipGap: CGFloat = 6
    static let blockGap: CGFloat = 12
    static let sectionGap: CGFloat = 18
    static let rowVPadding: CGFloat = 8
}

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(
        filter: #Predicate<UserRoutine> { $0.isActive == true },
        sort: \UserRoutine.createdAt,
        order: .reverse
    ) private var activeRoutines: [UserRoutine]

    @Query(sort: \UserProfile.createdAt, order: .reverse) private var userProfiles: [UserProfile]

    private var routine: UserRoutine? { activeRoutines.first }

    private var profileLiftingUnit: LiftingWeightUnit {
        userProfiles.first?.effectiveFitnessConfig.liftingWeightUnit ?? .kilograms
    }

    @State private var selectedDayOfWeek: Int = 1
    @State private var showingExercisePicker = false
    @State private var replacingExerciseIndex: Int? = nil
    @State private var showingCopyDaySheet = false
    @State private var clipboardExercise: PlannedExercise?

    private var selectedDay: UserRoutineDay? {
        routine?.days.first(where: { $0.dayOfWeek == selectedDayOfWeek })
    }

    var body: some View {
        NavigationStack {
            ZStack {
                routineThemeBackground
                Group {
                    if let routine {
                        content(routine: routine)
                    } else {
                        emptyState
                    }
                }
            }
            .navigationTitle("Mi rutina")
            .navigationBarTitleDisplayMode(.inline)
            .tint(RoutineTheme.accent)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Listo") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cerrar") { dismiss() }
                }
                if routine != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 16) {
                            if clipboardExercise != nil {
                                Button {
                                    if let r = routine {
                                        pasteClipboard(into: r)
                                    }
                                } label: {
                                    Label("Pegar", systemImage: "doc.on.clipboard")
                                }
                            }
                            Button {
                                showingExercisePicker = true
                            } label: {
                                Image(systemName: "plus")
                                    .accessibilityLabel("Agregar ejercicio")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingExercisePicker) {
                if let routine {
                    ExercisePickerSheet(
                        dayOfWeek: selectedDayOfWeek,
                        onPick: { planned in
                            if let idx = replacingExerciseIndex {
                                replaceExercise(at: idx, with: planned, in: routine, dayOfWeek: selectedDayOfWeek)
                                replacingExerciseIndex = nil
                            } else {
                                addExercise(planned, to: routine, dayOfWeek: selectedDayOfWeek)
                            }
                        }
                    )
                }
            }
            .sheet(isPresented: $showingCopyDaySheet) {
                if let routine {
                    CopyDaySheet(
                        routine: routine,
                        targetDayOfWeek: selectedDayOfWeek,
                        onApply: { sourceDay, mode in
                            applyCopy(from: sourceDay, mode: mode, to: routine, targetDayOfWeek: selectedDayOfWeek)
                        }
                    )
                }
            }
        }
        .task {
            ensureRoutineExists()
        }
    }

    @ViewBuilder
    private func content(routine: UserRoutine) -> some View {
        List {
            Section {
                routineHeroHeader
                dayOfWeekChips
            }
            .listRowInsets(EdgeInsets(top: 16, leading: RoutineEditorLayout.hInset, bottom: 12, trailing: RoutineEditorLayout.hInset))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)

            if let day = selectedDay {
                dayEditor(routine: routine, day: day)
            } else {
                Section {
                    Text("No se encontró el día seleccionado.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .listRowInsets(EdgeInsets(top: 12, leading: RoutineEditorLayout.hInset, bottom: 12, trailing: RoutineEditorLayout.hInset))
                .listRowBackground(RoutineTheme.cardFill(for: colorScheme))
            }
        }
        .listStyle(.plain)
        .listSectionSpacing(RoutineEditorLayout.sectionGap)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .environment(\.editMode, .constant(.active))
    }

    private var routineThemeBackground: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(red: 0.12, green: 0.12, blue: 0.11), Color(red: 0.06, green: 0.06, blue: 0.06)]
                : [RoutineTheme.mintTop, RoutineTheme.mintBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }

    private var routineHeroHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tu semana, a tu ritmo")
                .font(.system(size: 24, weight: .bold, design: .serif))
                .foregroundStyle(RoutineTheme.titleColor(for: colorScheme))
            Text("Elige el día y arma ejercicios, series y descansos.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var dayOfWeekChips: some View {
        VStack(alignment: .leading, spacing: RoutineEditorLayout.blockGap) {
            Text("Día")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.85))
                .textCase(.uppercase)
                .tracking(0.6)
            HStack(spacing: RoutineEditorLayout.dayChipGap) {
                ForEach(1...7, id: \.self) { d in
                    let on = selectedDayOfWeek == d
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedDayOfWeek = d
                        }
                    } label: {
                        Text(Self.shortWeekday(d))
                            .font(.caption)
                            .fontWeight(.bold)
                            .frame(width: RoutineEditorLayout.dayChip, height: RoutineEditorLayout.dayChip)
                            .background(
                                Circle()
                                    .fill(on ? RoutineTheme.accent : RoutineTheme.cardFill(for: colorScheme))
                            )
                            .foregroundStyle(on ? Color.white : Color.primary)
                            .overlay {
                                Circle()
                                    .strokeBorder(Color.primary.opacity(on ? 0 : 0.08), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.07), radius: on ? 0 : 3, y: 2)
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel("Día \(Self.weekdayAccessibility(d))")
                }
            }
        }
    }

    private static func weekdayAccessibility(_ day: Int) -> String {
        switch day {
        case 1: return "lunes"
        case 2: return "martes"
        case 3: return "miércoles"
        case 4: return "jueves"
        case 5: return "viernes"
        case 6: return "sábado"
        default: return "domingo"
        }
    }

    @ViewBuilder
    private func dayEditor(routine: UserRoutine, day: UserRoutineDay) -> some View {
        Section {
            VStack(alignment: .leading, spacing: RoutineEditorLayout.blockGap) {
                Toggle("Día de descanso", isOn: Binding(
                    get: { day.isRestDay },
                    set: { newValue in
                        if newValue {
                            day.exercises = []
                            day.isRestDay = true
                        } else {
                            day.isRestDay = false
                        }
                        try? modelContext.save()
                    }
                ))
                .tint(RoutineTheme.accent)

                Button {
                    showingCopyDaySheet = true
                } label: {
                    Label("Copiar desde otro día", systemImage: "doc.on.doc")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 13)
                        .background(
                            RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                                .fill(RoutineTheme.cardFill(for: colorScheme))
                        )
                        .overlay {
                            RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                                .strokeBorder(RoutineTheme.accent.opacity(0.22), lineWidth: 1)
                        }
                }
                .buttonStyle(.plain)
                .foregroundStyle(RoutineTheme.accent)
            }
            .padding(.vertical, 4)
        }
        .listRowInsets(EdgeInsets(top: 10, leading: RoutineEditorLayout.hInset, bottom: 8, trailing: RoutineEditorLayout.hInset))
        .listRowBackground(
            RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusL, style: .continuous)
                .fill(RoutineTheme.cardFill(for: colorScheme))
                .padding(.horizontal, RoutineEditorLayout.cardInset)
                .padding(.vertical, 4)
        )

        if day.isRestDay {
            Section {
                Text("Sin ejercicios este día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 28)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusL, style: .continuous)
                    .fill(RoutineTheme.cardFill(for: colorScheme))
                    .padding(.horizontal, RoutineEditorLayout.cardInset)
            )
        } else if day.exercises.isEmpty {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(RoutineTheme.accent.opacity(0.85))
                    Text("Aún no hay ejercicios")
                        .font(.headline)
                    Text("Toca + arriba para añadir el primero.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
            }
            .listRowBackground(
                RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusL, style: .continuous)
                    .fill(RoutineTheme.cardFill(for: colorScheme))
                    .padding(.horizontal, RoutineEditorLayout.cardInset)
            )
        } else {
            Section {
                ForEach(Array(day.exercises.enumerated()), id: \.element.id) { idx, ex in
                    RoutineExerciseRow(
                        exercise: ex,
                        liftingUnit: profileLiftingUnit,
                        onUpdate: { updated in
                            var copy = day.exercises
                            guard copy.indices.contains(idx) else { return }
                            copy[idx] = updated
                            day.exercises = copy
                            try? modelContext.save()
                        }
                    )
                    .listRowInsets(EdgeInsets(
                        top: RoutineEditorLayout.rowVPadding,
                        leading: RoutineEditorLayout.hInset,
                        bottom: RoutineEditorLayout.rowVPadding,
                        trailing: RoutineEditorLayout.hInset
                    ))
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                            .fill(RoutineTheme.cardFill(for: colorScheme))
                            .padding(.horizontal, RoutineEditorLayout.cardInset)
                            .padding(.vertical, 4)
                    )
                    .contextMenu {
                        Button {
                            duplicateExercise(at: idx, day: day)
                        } label: {
                            Label("Duplicar", systemImage: "plus.square.on.square")
                        }
                        Button {
                            clipboardExercise = day.exercises[idx]
                        } label: {
                            Label("Copiar", systemImage: "doc.on.doc")
                        }
                        Button {
                            pasteClipboard(into: routine, afterIndex: idx)
                        } label: {
                            Label("Pegar debajo", systemImage: "arrow.down.doc")
                        }
                        .disabled(clipboardExercise == nil)
                        Button {
                            replacingExerciseIndex = idx
                            showingExercisePicker = true
                        } label: {
                            Label("Sustituir…", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .onDelete { offsets in
                    var copy = day.exercises
                    copy.remove(atOffsets: offsets)
                    day.exercises = copy
                    try? modelContext.save()
                }
                .onMove { from, to in
                    var copy = day.exercises
                    copy.move(fromOffsets: from, toOffset: to)
                    day.exercises = copy
                    try? modelContext.save()
                }
            } header: {
                Text("Ejercicios del día")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.82))
                    .textCase(.uppercase)
                    .tracking(0.55)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "list.clipboard.fill")
                .font(.system(size: 48))
                .foregroundStyle(RoutineTheme.accent.opacity(0.9))
            Text("Preparando tu rutina")
                .font(.system(size: 22, weight: .bold, design: .serif))
                .foregroundStyle(RoutineTheme.titleColor(for: colorScheme))
            Text("En un momento podrás editar tus días y ejercicios.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(RoutineEditorLayout.hInset)
    }

    private func ensureRoutineExists() {
        do {
            let repo = UserRoutineRepository(context: modelContext)
            _ = try repo.getOrCreateActiveDefault()
        } catch {
            // no-op
        }
    }

    private func addExercise(_ planned: PlannedExercise, to routine: UserRoutine, dayOfWeek: Int) {
        guard let day = routine.days.first(where: { $0.dayOfWeek == dayOfWeek }) else { return }
        if day.isRestDay { day.isRestDay = false }
        var copy = day.exercises
        copy.append(planned)
        day.exercises = copy
        try? modelContext.save()
    }

    private func replaceExercise(at index: Int, with planned: PlannedExercise, in routine: UserRoutine, dayOfWeek: Int) {
        guard let day = routine.days.first(where: { $0.dayOfWeek == dayOfWeek }) else { return }
        var copy = day.exercises
        guard copy.indices.contains(index) else { return }
        copy[index] = planned
        day.exercises = copy
        try? modelContext.save()
    }

    private func applyCopy(from sourceDay: Int, mode: CopyDaySheet.CopyMode, to routine: UserRoutine, targetDayOfWeek: Int) {
        guard let source = routine.days.first(where: { $0.dayOfWeek == sourceDay }) else { return }
        guard let target = routine.days.first(where: { $0.dayOfWeek == targetDayOfWeek }) else { return }

        if target.isRestDay { target.isRestDay = false }
        switch mode {
        case .replace:
            target.exercises = source.exercises
        case .append:
            var copy = target.exercises
            copy.append(contentsOf: source.exercises)
            target.exercises = copy
        }
        try? modelContext.save()
    }

    private func duplicateExercise(at index: Int, day: UserRoutineDay) {
        var copy = day.exercises
        guard copy.indices.contains(index) else { return }
        let dup = copy[index].duplicatedInstance()
        copy.insert(dup, at: index + 1)
        day.exercises = copy
        try? modelContext.save()
    }

    /// Pega el ejercicio copiado al final del día o justo debajo de `afterIndex`.
    private func pasteClipboard(into routine: UserRoutine, afterIndex: Int? = nil) {
        guard let clip = clipboardExercise else { return }
        guard let day = routine.days.first(where: { $0.dayOfWeek == selectedDayOfWeek }) else { return }
        if day.isRestDay { day.isRestDay = false }
        var exercises = day.exercises
        let toInsert = clip.duplicatedInstance()
        if let after = afterIndex, exercises.indices.contains(after) {
            exercises.insert(toInsert, at: after + 1)
        } else {
            exercises.append(toInsert)
        }
        day.exercises = exercises
        try? modelContext.save()
    }

    private static func shortWeekday(_ day: Int) -> String {
        // 1...7 (Mon..Sun)
        switch day {
        case 1: return "L"
        case 2: return "M"
        case 3: return "X"
        case 4: return "J"
        case 5: return "V"
        case 6: return "S"
        default: return "D"
        }
    }
}

private struct RoutineExerciseRow: View {
    let exercise: PlannedExercise
    let liftingUnit: LiftingWeightUnit
    var onUpdate: (PlannedExercise) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.appLanguage) private var lang

    @State private var sets: Int
    @State private var reps: Int
    @State private var restSec: Int
    @State private var usePerSetRest: Bool
    @State private var perSetRest: [Int]
    @State private var weightMinText: String
    @State private var weightMaxText: String
    @State private var showingAlternatives = false
    @State private var showingDetail = false

    private let exerciseService = ExerciseService()

    init(exercise: PlannedExercise, liftingUnit: LiftingWeightUnit, onUpdate: @escaping (PlannedExercise) -> Void) {
        self.exercise = exercise
        self.liftingUnit = liftingUnit
        self.onUpdate = onUpdate
        _sets = State(initialValue: max(1, exercise.sets))
        _reps = State(initialValue: max(1, exercise.reps))
        _restSec = State(initialValue: max(1, exercise.restBetweenSetsSeconds ?? 90))
        let per = exercise.perSetRestSeconds
        _usePerSetRest = State(initialValue: per != nil && per?.count == exercise.sets)
        _perSetRest = State(initialValue: Self.initialPerSetRest(exercise))
        _weightMinText = State(initialValue: UnitConverter.formatLiftKgForDisplay(exercise.suggestedWeight, unit: liftingUnit))
        _weightMaxText = State(initialValue: exercise.targetWeightMax.map { UnitConverter.formatLiftKgForDisplay($0, unit: liftingUnit) } ?? "")
    }

    private var exerciseHeader: some View {
        Button {
            showingDetail = true
        } label: {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [RoutineTheme.accent.opacity(0.35), RoutineTheme.accent.opacity(0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 46, height: 46)
                    Image(systemName: "dumbbell.fill")
                        .font(.title3)
                        .foregroundStyle(RoutineTheme.accent)
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.system(.headline, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(RoutineTheme.titleColor(for: colorScheme))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                    Text(exercise.isCompound ? "Compuesto" : "Aislamiento")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundStyle(RoutineTheme.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(RoutineTheme.accent.opacity(0.14)))
                }
                Spacer(minLength: 8)
                Image(systemName: "info.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(RoutineTheme.accent)
            }
            .padding(RoutineEditorLayout.hInset)
            .background(
                RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                    .fill(RoutineTheme.accent.opacity(colorScheme == .dark ? 0.1 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                    .strokeBorder(RoutineTheme.accent.opacity(0.2), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showingDetail) {
            ExerciseDetailView(exercise: exercise)
        }
    }

    private func routineConfigSectionTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.55))
            .tracking(0.55)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: RoutineEditorLayout.sectionGap) {
            exerciseHeader

            routineConfigSectionTitle("Volumen")
            HStack(alignment: .top, spacing: RoutineEditorLayout.blockGap) {
                RoutineConfigMetricTile(
                    title: "Series",
                    subtitle: nil,
                    value: $sets,
                    range: 1...12,
                    step: 1,
                    unitSuffix: ""
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: sets) { _, newValue in
                    var updated = exercise
                    updated.sets = newValue
                    if usePerSetRest {
                        if perSetRest.count < newValue {
                            perSetRest.append(contentsOf: Array(repeating: restSec, count: newValue - perSetRest.count))
                        } else if perSetRest.count > newValue {
                            perSetRest = Array(perSetRest.prefix(newValue))
                        }
                        updated.perSetRestSeconds = perSetRest
                    }
                    onUpdate(updated)
                }

                RoutineConfigMetricTile(
                    title: "Reps",
                    subtitle: nil,
                    value: $reps,
                    range: 1...30,
                    step: 1,
                    unitSuffix: ""
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: reps) { _, newValue in
                    var updated = exercise
                    updated.reps = newValue
                    onUpdate(updated)
                }
            }

            routineConfigSectionTitle("Descanso")
            VStack(alignment: .leading, spacing: RoutineEditorLayout.blockGap) {
                HStack(alignment: .top, spacing: RoutineEditorLayout.blockGap) {
                    RoutineConfigMetricTile(
                        title: "Entre series",
                        subtitle: usePerSetRest ? "base" : nil,
                        value: $restSec,
                        range: 15...600,
                        step: 15,
                        unitSuffix: "s"
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onChange(of: restSec) { _, newValue in
                        var updated = exercise
                        updated.restBetweenSetsSeconds = newValue
                        if usePerSetRest {
                            perSetRest = Array(repeating: newValue, count: sets)
                            updated.perSetRestSeconds = perSetRest
                        }
                        onUpdate(updated)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Por serie")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.85))
                        Toggle("", isOn: $usePerSetRest)
                            .labelsHidden()
                            .tint(RoutineTheme.accent)
                            .onChange(of: usePerSetRest) { _, on in
                                var updated = exercise
                                if on {
                                    perSetRest = Array(repeating: restSec, count: sets)
                                    updated.perSetRestSeconds = perSetRest
                                } else {
                                    updated.perSetRestSeconds = nil
                                }
                                onUpdate(updated)
                            }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(RoutineEditorLayout.blockGap)
                    .background(
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                            .fill(RoutineTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                            .strokeBorder(RoutineTheme.accent.opacity(0.2), lineWidth: 1)
                    )
                }

                if usePerSetRest, perSetRest.count == sets {
                    routineConfigSectionTitle("Tras cada serie")
                    VStack(spacing: 8) {
                        ForEach(0..<sets, id: \.self) { i in
                            HStack {
                                Label("Serie \(i + 1)", systemImage: "timer")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.9))
                                Spacer()
                                RoutineCompactRestStepper(
                                    seconds: Binding(
                                        get: { perSetRest[i] },
                                        set: { newVal in
                                            guard perSetRest.indices.contains(i) else { return }
                                            perSetRest[i] = newVal
                                            var updated = exercise
                                            updated.perSetRestSeconds = perSetRest
                                            onUpdate(updated)
                                        }
                                    )
                                )
                            }
                            .padding(.horizontal, RoutineEditorLayout.blockGap)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                                    .fill(RoutineTheme.mintBottom.opacity(colorScheme == .dark ? 0.15 : 0.35))
                            )
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                routineConfigSectionTitle("Peso (\(liftingUnit.symbol))")
                Text("Equivalente en la otra unidad debajo de cada campo.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .top, spacing: RoutineEditorLayout.blockGap) {
                RoutineWeightField(
                    label: "Objetivo",
                    placeholder: liftingUnit == .kilograms ? "12.5" : "135",
                    text: $weightMinText,
                    equivalentSubtitle: weightMinEquivalent,
                    onEdit: { pushWeightUpdate() }
                )
                RoutineWeightField(
                    label: "Techo (opc.)",
                    placeholder: "—",
                    text: $weightMaxText,
                    equivalentSubtitle: weightMaxEquivalent,
                    onEdit: { pushWeightUpdate() }
                )
            }

            if let alts = exercise.alternateExerciseIds, !alts.isEmpty {
                Text(alts.map { exerciseService.bundledExercise(withId: $0)?.name ?? $0 }.joined(separator: " · "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .padding(RoutineEditorLayout.blockGap)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                            .fill(Color.primary.opacity(0.04))
                    )
            }

            Button {
                showingAlternatives = true
            } label: {
                Label("Sustitutos", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                            .fill(RoutineTheme.cardFill(for: colorScheme))
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusM, style: .continuous)
                            .strokeBorder(RoutineTheme.accent.opacity(0.26), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .foregroundStyle(RoutineTheme.accent)
        }
        .padding(.vertical, 2)
        .sheet(isPresented: $showingAlternatives) {
            AlternativesEditorSheet(
                exercise: exercise,
                onSave: { updated in
                    onUpdate(updated)
                }
            )
        }
        .onChange(of: exercise.id) { _, _ in
            sets = max(1, exercise.sets)
            reps = max(1, exercise.reps)
            restSec = max(1, exercise.restBetweenSetsSeconds ?? 90)
            usePerSetRest = exercise.perSetRestSeconds != nil && exercise.perSetRestSeconds?.count == exercise.sets
            perSetRest = Self.initialPerSetRest(exercise)
            weightMinText = UnitConverter.formatLiftKgForDisplay(exercise.suggestedWeight, unit: liftingUnit)
            weightMaxText = exercise.targetWeightMax.map { UnitConverter.formatLiftKgForDisplay($0, unit: liftingUnit) } ?? ""
        }
    }

    private var weightMinEquivalent: String {
        let kg = UnitConverter.parseLiftInputToKg(weightMinText, unit: liftingUnit) ?? exercise.suggestedWeight
        return lang.liftWeightEquivalentLine(fullOtherUnit: UnitConverter.formatLiftOtherUnitFromKg(kg, displayUnit: liftingUnit))
    }

    private var weightMaxEquivalent: String? {
        let t = weightMaxText.trimmingCharacters(in: .whitespacesAndNewlines)
        if t.isEmpty { return nil }
        guard let kg = UnitConverter.parseLiftInputToKg(weightMaxText, unit: liftingUnit) else { return nil }
        return lang.liftWeightEquivalentLine(fullOtherUnit: UnitConverter.formatLiftOtherUnitFromKg(kg, displayUnit: liftingUnit))
    }

    private func pushWeightUpdate() {
        var updated = exercise
        updated.suggestedWeight = UnitConverter.parseLiftInputToKg(weightMinText, unit: liftingUnit) ?? updated.suggestedWeight
        let maxTrim = weightMaxText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.targetWeightMax = maxTrim.isEmpty ? nil : UnitConverter.parseLiftInputToKg(weightMaxText, unit: liftingUnit)
        onUpdate(updated)
    }

    private static func initialPerSetRest(_ ex: PlannedExercise) -> [Int] {
        if let p = ex.perSetRestSeconds, p.count == ex.sets { return p }
        let base = ex.restBetweenSetsSeconds ?? 90
        return Array(repeating: base, count: ex.sets)
    }

}

// MARK: - Routine exercise row — métricas

private struct RoutineConfigMetricTile: View {
    let title: String
    let subtitle: String?
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int
    let unitSuffix: String

    @Environment(\.colorScheme) private var colorScheme

    private func bump(_ delta: Int) {
        let next = value + delta * step
        value = min(max(next, range.lowerBound), range.upperBound)
    }

    private var displayValue: String {
        if unitSuffix.isEmpty { return "\(value)" }
        return "\(value)\(unitSuffix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.9))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            HStack(spacing: 8) {
                Button {
                    bump(-1)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RoutineTheme.accent)
                .disabled(value <= range.lowerBound)

                Text(displayValue)
                    .font(.system(.title3, design: .rounded))
                    .fontWeight(.semibold)
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                    .frame(minWidth: 44)

                Button {
                    bump(1)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                }
                .buttonStyle(.plain)
                .foregroundStyle(RoutineTheme.accent)
                .disabled(value >= range.upperBound)
            }
        }
        .padding(RoutineEditorLayout.blockGap)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                .fill(RoutineTheme.accent.opacity(colorScheme == .dark ? 0.12 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                .strokeBorder(RoutineTheme.accent.opacity(0.2), lineWidth: 1)
        )
    }
}

private struct RoutineCompactRestStepper: View {
    @Binding var seconds: Int

    private let range = 0...600
    private let step = 15

    private func bump(_ delta: Int) {
        let next = seconds + delta * step
        seconds = min(max(next, range.lowerBound), range.upperBound)
    }

    var body: some View {
        HStack(spacing: 6) {
            Button {
                bump(-1)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RoutineTheme.accent)
            .disabled(seconds <= range.lowerBound)

            Text("\(seconds)s")
                .font(.caption)
                .fontWeight(.bold)
                .monospacedDigit()
                .frame(minWidth: 40)

            Button {
                bump(1)
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.body)
            }
            .buttonStyle(.plain)
            .foregroundStyle(RoutineTheme.accent)
            .disabled(seconds >= range.upperBound)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule(style: .continuous)
                .fill(RoutineTheme.accent.opacity(0.12))
        )
    }
}

private struct RoutineWeightField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var equivalentSubtitle: String?
    var onEdit: () -> Void

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(RoutineTheme.titleColor(for: colorScheme, opacity: 0.85))
            TextField(placeholder, text: $text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.body)
                .fontWeight(.semibold)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                        .fill(RoutineTheme.cardFill(for: colorScheme))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: RoutineEditorLayout.radiusS, style: .continuous)
                        .strokeBorder(RoutineTheme.accent.opacity(0.22), lineWidth: 1)
                )
                .onChange(of: text) { _, _ in
                    onEdit()
                }
            if let equivalentSubtitle {
                Text(equivalentSubtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AlternativesEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    let exercise: PlannedExercise
    let onSave: (PlannedExercise) -> Void

    @State private var ids: [String]
    @State private var query: String = ""
    @State private var results: [Exercise] = []

    private let exerciseService = ExerciseService()

    init(exercise: PlannedExercise, onSave: @escaping (PlannedExercise) -> Void) {
        self.exercise = exercise
        self.onSave = onSave
        _ids = State(initialValue: exercise.alternateExerciseIds ?? [])
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Buscar ejercicio sustituto", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: query) { _, _ in
                            refreshResults()
                        }
                }

                if !ids.isEmpty {
                    Section("Guardados (\(ids.count))") {
                        ForEach(ids, id: \.self) { id in
                            HStack {
                                Text(exerciseService.bundledExercise(withId: id)?.name ?? id)
                                Spacer()
                                Button(role: .destructive) {
                                    ids.removeAll { $0 == id }
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }

                Section("Añadir desde el catálogo") {
                    let available = results.filter { $0.id != exercise.effectiveCatalogId && !ids.contains($0.id) }
                    if available.isEmpty {
                        Text(ids.isEmpty ? "Busca arriba o elige un resultado para añadir." : "No hay más resultados que añadir.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(available, id: \.id) { ex in
                        Button {
                            guard !ids.contains(ex.id) else { return }
                            withAnimation {
                                ids = ids + [ex.id]
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ex.name)
                                Text("\(ex.bodyPart) · \(ex.equipment)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sustitutos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Guardar") {
                        var updated = exercise
                        updated.alternateExerciseIds = ids.isEmpty ? nil : ids
                        onSave(updated)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            ids = exercise.alternateExerciseIds ?? []
            refreshResults()
        }
    }

    private func refreshResults() {
        results = exerciseService.searchBundledExercises(query: query, limit: 40)
    }
}

private struct ExercisePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query: String = ""
    @State private var results: [Exercise] = []
    @State private var selectedEquipment: String = "Todos"
    @State private var selectedBodyPart: String = "Todos"
    @State private var isLoading: Bool = false
    @State private var lastLoadedKey: String = ""
    @State private var cachedPool: [Exercise] = []
    // Wrapper for sheet(item:) since Exercise isn't Identifiable in this context
    struct PreviewItem: Identifiable {
        let id = UUID()
        let exercise: Exercise
    }
    @State private var previewItem: PreviewItem? = nil

    let dayOfWeek: Int
    let onPick: (PlannedExercise) -> Void

    private let exerciseService = ExerciseService.shared // shared cache across openings
    // Keep these bodyPart keys aligned with the rest of the app (MuscleGroup.apiBodyPart).
    private let bodyPartOptions: [String] = ["Todos", "chest", "back", "shoulders", "upper arms", "waist", "upper legs", "lower legs"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Buscar ejercicio (ej. press, squat, curl)", text: $query)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    HStack {
                        Menu {
                            Picker("Equipo", selection: $selectedEquipment) {
                                ForEach(["Todos", "none (bodyweight exercise)", "barbell", "dumbbell", "machine", "cable"], id: \.self) { e in
                                    Text(e).tag(e)
                                }
                            }
                        } label: {
                            Label(selectedEquipment, systemImage: "dumbbell.fill")
                                .font(.caption)
                        }

                        Spacer()

                        Menu {
                            Picker("Zona", selection: $selectedBodyPart) {
                                ForEach(bodyPartOptions, id: \.self) { b in
                                    Text(b).tag(b)
                                }
                            }
                        } label: {
                            Label(selectedBodyPart, systemImage: "target")
                                .font(.caption)
                        }
                    }
                }

                Section("Resultados") {
                    if isLoading {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                    ForEach(results, id: \.id) { ex in
                        HStack(spacing: 10) {
                            Button {
                                onPick(Self.toPlannedExercise(ex))
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(ex.name)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                    Text("\(ex.bodyPart) · \(ex.equipment)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Button {
                                previewItem = PreviewItem(exercise: ex)
                            } label: {
                                Image(systemName: "info.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Ver detalle")
                        }
                    }
                }
            }
            .navigationTitle("Agregar ejercicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onAppear {
            refreshResults()
        }
        .onChange(of: query) { _, newValue in
            _ = newValue
            refreshResults()
        }
        .onChange(of: selectedEquipment) { _, _ in
            refreshResults()
        }
        .onChange(of: selectedBodyPart) { _, _ in
            refreshResults()
        }
        .sheet(item: $previewItem) { item in
            ExerciseDetailView(exercise: Self.toPlannedExercise(item.exercise))
        }
    }

    private func refreshResults() {
        let key = "\(selectedBodyPart)|\(selectedEquipment)"
        if key != lastLoadedKey {
            lastLoadedKey = key
            cachedPool = []
            isLoading = true

            Task { @MainActor in
                var pool: [Exercise] = []
                if selectedBodyPart == "Todos" {
                    // Load a reasonable cross-section (keeps UI fast).
                    async let chest = try? await exerciseService.fetchExercises(bodyPart: "chest", equipment: nil)
                    async let back = try? await exerciseService.fetchExercises(bodyPart: "back", equipment: nil)
                    async let legs = try? await exerciseService.fetchExercises(bodyPart: "upper legs", equipment: nil)
                    async let shoulders = try? await exerciseService.fetchExercises(bodyPart: "shoulders", equipment: nil)
                    async let core = try? await exerciseService.fetchExercises(bodyPart: "waist", equipment: nil)
                    let lists = [await chest, await back, await legs, await shoulders, await core].compactMap { $0 }
                    pool = Array(lists.flatMap { $0 }.prefix(400))
                } else {
                    pool = (try? await exerciseService.fetchExercises(bodyPart: selectedBodyPart, equipment: nil)) ?? []
                }

                cachedPool = pool
                isLoading = false
                applyFilters()
            }
            return
        }

        applyFilters()
    }

    private func applyFilters() {
        var items = cachedPool
        if selectedEquipment != "Todos" {
            items = items.filter { $0.equipment.localizedCaseInsensitiveContains(selectedEquipment) }
        }
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !q.isEmpty {
            items = items.filter { ex in
                ex.name.lowercased().contains(q) ||
                ex.bodyPart.lowercased().contains(q) ||
                ex.target.lowercased().contains(q) ||
                ex.equipment.lowercased().contains(q) ||
                (ex.description?.lowercased().contains(q) ?? false)
            }
        }
        // Show more than 20; keep it performant.
        results = Array(items.prefix(200))
    }

    private static func toPlannedExercise(_ ex: Exercise) -> PlannedExercise {
        PlannedExercise(
            id: ex.id,
            catalogExerciseId: nil,
            name: ex.name,
            muscleGroup: mapToMuscleGroup(ex.bodyPart),
            isCompound: false,
            sets: 3,
            reps: 10,
            suggestedWeight: defaultTargetWeight(for: ex),
            targetWeightMax: nil,
            equipment: ex.equipment,
            gifUrl: ex.gifUrl,
            instructions: ex.instructions ?? []
        )
    }

    private static func defaultTargetWeight(for ex: Exercise) -> Double {
        let e = ex.equipment.lowercased()
        if e.contains("body weight") { return 0 }
        if e.contains("barbell") { return 20 }
        if e.contains("dumbbell") { return 10 }
        if e.contains("machine") || e.contains("cable") { return 15 }
        return 12.5
    }

    private static func mapToMuscleGroup(_ bodyPart: String) -> MuscleGroup {
        switch bodyPart.lowercased() {
        case "chest": return .chest
        case "back": return .back
        case "shoulders": return .shoulders
        case "upper arms": return .biceps
        case "upper legs": return .quads
        case "lower legs": return .calves
        case "waist": return .core
        default: return .core
        }
    }
}

private struct CopyDaySheet: View {
    enum CopyMode: String, CaseIterable {
        case replace = "Reemplazar"
        case append = "Agregar"
    }

    @Environment(\.dismiss) private var dismiss
    let routine: UserRoutine
    let targetDayOfWeek: Int
    let onApply: (_ sourceDay: Int, _ mode: CopyMode) -> Void

    @State private var sourceDay: Int = 1
    @State private var mode: CopyMode = .replace

    var body: some View {
        NavigationStack {
            Form {
                Section("Copiar desde") {
                    Picker("Día", selection: $sourceDay) {
                        ForEach(1...7, id: \.self) { d in
                            Text(Self.shortWeekday(d)).tag(d)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Acción") {
                    Picker("Modo", selection: $mode) {
                        ForEach(CopyMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    Button("Aplicar") {
                        onApply(sourceDay, mode)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(sourceDay == targetDayOfWeek)
                } footer: {
                    Text("Reemplazar borra los ejercicios actuales del día. Agregar los concatena al final.")
                }
            }
            .navigationTitle("Copiar día")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
        .onAppear {
            // default: pick any day other than target
            if sourceDay == targetDayOfWeek {
                sourceDay = targetDayOfWeek == 1 ? 2 : 1
            }
        }
    }

    private static func shortWeekday(_ day: Int) -> String {
        switch day {
        case 1: return "L"
        case 2: return "M"
        case 3: return "X"
        case 4: return "J"
        case 5: return "V"
        case 6: return "S"
        default: return "D"
        }
    }
}

// MARK: - Palette (alineado con Crear plan / Home)

private enum RoutineTheme {
    static let accent = Color(red: 1.0, green: 122 / 255, blue: 38 / 255)
    static let mintTop = Color(red: 0.86, green: 0.96, blue: 0.91)
    static let mintBottom = Color(red: 0.78, green: 0.93, blue: 0.88)
    /// Solo modo claro: en oscuro `titleColor(for:opacity:)` usa `primary` (el tono fijo tiraba a violeta‑azulado).
    static let title = Color(red: 0.22, green: 0.1, blue: 0.26)

    static func titleColor(for scheme: ColorScheme, opacity: Double = 1.0) -> Color {
        if scheme == .dark {
            return Color.primary.opacity(opacity)
        }
        return RoutineTheme.title.opacity(opacity)
    }

    static func cardFill(for scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(.secondarySystemGroupedBackground) : Color.white
    }
}

