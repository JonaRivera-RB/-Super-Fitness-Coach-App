//
//  RoutineEditorView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData
import UIKit

struct RoutineEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query(
        filter: #Predicate<UserRoutine> { $0.isActive == true },
        sort: \UserRoutine.createdAt,
        order: .reverse
    ) private var activeRoutines: [UserRoutine]

    private var routine: UserRoutine? { activeRoutines.first }

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
            Group {
                if let routine {
                    content(routine: routine)
                } else {
                    emptyState
                }
            }
            .navigationTitle("Mi rutina")
            .navigationBarTitleDisplayMode(.inline)
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
        VStack(spacing: 12) {
            dayPicker

            if let day = selectedDay {
                dayEditor(routine: routine, day: day)
            } else {
                Text("No se encontró el día seleccionado.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var dayPicker: some View {
        let days = (1...7).map { $0 }
        return Picker("Día", selection: $selectedDayOfWeek) {
            ForEach(days, id: \.self) { d in
                Text(Self.shortWeekday(d)).tag(d)
            }
        }
        .pickerStyle(.segmented)
    }

    @ViewBuilder
    private func dayEditor(routine: UserRoutine, day: UserRoutineDay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Toggle("Día de descanso", isOn: Binding(
                    get: { day.isRestDay },
                    set: { newValue in
                        day.isRestDay = newValue
                        try? modelContext.save()
                    }
                ))
            }

            HStack {
                Button {
                    showingCopyDaySheet = true
                } label: {
                    Label("Copiar día", systemImage: "doc.on.doc")
                        .font(.subheadline)
                }
                .buttonStyle(.bordered)

                Spacer()
            }

            if day.isRestDay {
                Text("Sin ejercicios para este día.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 24)
            } else if day.exercises.isEmpty {
                VStack(spacing: 10) {
                    Text("Aún no agregas ejercicios.")
                        .font(.headline)
                    Text("Toca “+” para agregar ejercicios a este día.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
            } else {
                List {
                    ForEach(Array(day.exercises.enumerated()), id: \.element.id) { idx, ex in
                        RoutineExerciseRow(
                            exercise: ex,
                            onUpdate: { updated in
                                var copy = day.exercises
                                guard copy.indices.contains(idx) else { return }
                                copy[idx] = updated
                                day.exercises = copy
                                try? modelContext.save()
                            }
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
                }
                .listStyle(.plain)
                .scrollDismissesKeyboard(.interactively)
                .environment(\.editMode, .constant(.active)) // allow drag reorder
                .frame(minHeight: 260)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "list.clipboard")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Crea tu rutina")
                .font(.title3)
                .fontWeight(.semibold)
            Text("Estamos preparando tu rutina editable…")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
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
    var onUpdate: (PlannedExercise) -> Void

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

    init(exercise: PlannedExercise, onUpdate: @escaping (PlannedExercise) -> Void) {
        self.exercise = exercise
        self.onUpdate = onUpdate
        _sets = State(initialValue: max(1, exercise.sets))
        _reps = State(initialValue: max(1, exercise.reps))
        _restSec = State(initialValue: max(1, exercise.restBetweenSetsSeconds ?? 90))
        let per = exercise.perSetRestSeconds
        _usePerSetRest = State(initialValue: per != nil && per?.count == exercise.sets)
        _perSetRest = State(initialValue: Self.initialPerSetRest(exercise))
        _weightMinText = State(initialValue: Self.fmtWeight(exercise.suggestedWeight))
        _weightMaxText = State(initialValue: exercise.targetWeightMax.map { Self.fmtWeight($0) } ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                showingDetail = true
            } label: {
                HStack(spacing: 8) {
                    Text(exercise.name)
                        .font(.headline)
                        .lineLimit(2)
                        .foregroundStyle(.primary)
                    Spacer()
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                }
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showingDetail) {
                ExerciseDetailView(exercise: exercise)
            }

            HStack(spacing: 10) {
                Stepper("Sets \(sets)", value: $sets, in: 1...12, step: 1)
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

                Stepper("Reps \(reps)", value: $reps, in: 1...30, step: 1)
                    .onChange(of: reps) { _, newValue in
                        var updated = exercise
                        updated.reps = newValue
                        onUpdate(updated)
                    }
            }
            .font(.caption)

            HStack(spacing: 10) {
                Stepper("Descanso \(restSec)s", value: $restSec, in: 15...600, step: 15)
                    .onChange(of: restSec) { _, newValue in
                        var updated = exercise
                        updated.restBetweenSetsSeconds = newValue
                        if usePerSetRest {
                            perSetRest = Array(repeating: newValue, count: sets)
                            updated.perSetRestSeconds = perSetRest
                        }
                        onUpdate(updated)
                    }
                Toggle("Por serie", isOn: $usePerSetRest)
                    .font(.caption)
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
            .font(.caption)

            if usePerSetRest, perSetRest.count == sets {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<sets, id: \.self) { i in
                        HStack {
                            Text("Tras serie \(i + 1)")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Stepper(
                                "\(perSetRest[i])s",
                                value: Binding(
                                    get: { perSetRest[i] },
                                    set: { newVal in
                                        guard perSetRest.indices.contains(i) else { return }
                                        perSetRest[i] = newVal
                                        var updated = exercise
                                        updated.perSetRestSeconds = perSetRest
                                        onUpdate(updated)
                                    }
                                ),
                                in: 0...600,
                                step: 15
                            )
                            .font(.caption2)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                Text("Peso kg")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Mín", text: $weightMinText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 80)
                    .onChange(of: weightMinText) { _, _ in
                        pushWeightUpdate()
                    }
                Text("—")
                    .foregroundStyle(.secondary)
                TextField("Máx (opc.)", text: $weightMaxText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 100)
                    .onChange(of: weightMaxText) { _, _ in
                        pushWeightUpdate()
                    }
            }

            if let alts = exercise.alternateExerciseIds, !alts.isEmpty {
                Text("Sustitutos: \(alts.map { exerciseService.bundledExercise(withId: $0)?.name ?? $0 }.joined(separator: ", "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Button {
                showingAlternatives = true
            } label: {
                Label("Editar sustitutos", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 6)
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
            weightMinText = Self.fmtWeight(exercise.suggestedWeight)
            weightMaxText = exercise.targetWeightMax.map { Self.fmtWeight($0) } ?? ""
        }
    }

    private func pushWeightUpdate() {
        var updated = exercise
        updated.suggestedWeight = Self.parseWeight(weightMinText) ?? updated.suggestedWeight
        let maxTrim = weightMaxText.trimmingCharacters(in: .whitespacesAndNewlines)
        updated.targetWeightMax = maxTrim.isEmpty ? nil : Self.parseWeight(weightMaxText)
        onUpdate(updated)
    }

    private static func initialPerSetRest(_ ex: PlannedExercise) -> [Int] {
        if let p = ex.perSetRestSeconds, p.count == ex.sets { return p }
        let base = ex.restBetweenSetsSeconds ?? 90
        return Array(repeating: base, count: ex.sets)
    }

    private static func fmtWeight(_ w: Double) -> String {
        w == floor(w) ? String(format: "%.0f", w) : String(format: "%.1f", w)
    }

    private static func parseWeight(_ s: String) -> Double? {
        let t = s.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty else { return nil }
        return Double(t)
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

