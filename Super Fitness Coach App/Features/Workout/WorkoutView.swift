//
//  WorkoutView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData

/// Entrenamiento unificado: **plan guiado** (metas, semanas, fases) y **mi rutina** (misma capa visual).
struct WorkoutView: View {
    var trainingPlanVM: TrainingPlanViewModel?
    var onNewTrainingPlan: (() -> Void)?
    var onStartTrainingWorkout: ((Int) -> Void)?
    var onEditRoutine: (() -> Void)?
    /// Ejercicios del día y día de la semana (1...7) para marcar completado al cerrar el entreno.
    var onStartRoutineWorkout: (([PlannedExercise], Int) -> Void)?

    @AppStorage("workoutHomeSurface") private var storedSurface: String = WorkoutSurface.plan.rawValue

    @Query(
        filter: #Predicate<TrainingPlan> { $0.planStatusRaw == "active" },
        sort: \TrainingPlan.createdAt,
        order: .reverse
    ) private var activePlans: [TrainingPlan]

    private var activePlan: TrainingPlan? { activePlans.first }

    @Query(
        filter: #Predicate<UserRoutine> { $0.isActive == true },
        sort: \UserRoutine.createdAt,
        order: .reverse
    ) private var activeRoutines: [UserRoutine]
    private var activeRoutine: UserRoutine? { activeRoutines.first }

    private var hasPlan: Bool { activePlan != nil }
    private var hasRoutine: Bool { activeRoutine != nil }

    private var surface: WorkoutSurface {
        if hasPlan && !hasRoutine { return .plan }
        if hasRoutine && !hasPlan { return .routine }
        if hasPlan && hasRoutine {
            return WorkoutSurface(rawValue: storedSurface) ?? .plan
        }
        return .plan
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if hasPlan && hasRoutine {
                        Picker("Vista", selection: $storedSurface) {
                            Text("Plan guiado").tag(WorkoutSurface.plan.rawValue)
                            Text("Mi rutina").tag(WorkoutSurface.routine.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel("Elegir entre plan guiado o mi rutina")
                    }

                    Group {
                        switch surface {
                        case .plan:
                            if let plan = activePlan {
                                trainingPlanSection(plan: plan)
                            } else if let routine = activeRoutine {
                                routineSection(routine: routine)
                            } else {
                                emptyTrainingState
                            }
                        case .routine:
                            if let routine = activeRoutine {
                                routineSection(routine: routine)
                            } else if let plan = activePlan {
                                trainingPlanSection(plan: plan)
                            } else {
                                emptyTrainingState
                            }
                        }
                    }

                    if surface == .plan, hasRoutine {
                        routineHintBanner
                    } else if surface == .routine, hasPlan {
                        planHintBanner
                    }

                    if !hasPlan {
                        noPlanBanner
                    }
                }
                .padding()
            }
            .navigationTitle("Entrenamiento")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        if hasRoutine {
                            Button {
                                onEditRoutine?()
                            } label: {
                                Label("Editar rutina", systemImage: "slider.horizontal.3")
                            }
                        }
                        Menu {
                            Button { onNewTrainingPlan?() } label: {
                                Label("Nuevo plan", systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel("Más opciones")
                        }
                    }
                }
            }
        }
    }

    // MARK: - Empty

    private var emptyTrainingState: some View {
        VStack(spacing: 12) {
            Image(systemName: "figure.run.circle")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            Text("Sin contenido")
                .font(.headline)
            Text("Crea un plan o configura tu rutina.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Cross-hints (fusion UX)

    private var routineHintBanner: some View {
        Button {
            storedSurface = WorkoutSurface.routine.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.swap")
                    .font(.title3)
                    .foregroundStyle(.teal)
                VStack(alignment: .leading, spacing: 4) {
                    Text("También tienes Mi rutina")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Ejercicios, descansos y sustitutos bajo tu control.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.teal.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    private var planHintBanner: some View {
        Button {
            storedSurface = WorkoutSurface.plan.rawValue
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "calendar.badge.clock")
                    .font(.title3)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Volver al plan guiado")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Semanas, fases y días bloqueados como antes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.08)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Plan Banner

    private var noPlanBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36)).foregroundStyle(.blue)
            Text("Plan opcional").font(.headline)
            Text("Metas, prioridades y duración en semanas. Puedes entrenar solo con Mi rutina o combinar ambos.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { onNewTrainingPlan?() } label: {
                Label("Crear plan de entrenamiento", systemImage: "plus")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }

    // MARK: - Training Plan Section

    private func trainingPlanSection(plan: TrainingPlan) -> some View {
        let weekIndex = plan.currentWeek - 1
        let currentWeekDays: [TrainingDayPlan] = weekIndex >= 0 && weekIndex < plan.weeks.count
            ? plan.weeks[weekIndex].days.sorted { $0.dayOfWeek < $1.dayOfWeek }
            : []

        return VStack(spacing: 14) {
            weekProgressHeader(plan: plan, days: currentWeekDays)
            todayCard(plan: plan, days: currentWeekDays)
            weekOverview(plan: plan, days: currentWeekDays)
        }
        .id("\(plan.id)-\(currentWeekDays.map(\.dayStatusRaw).joined())")
    }

    // MARK: - Routine Section (misma jerarquía que el plan)

    private func routineSection(routine: UserRoutine) -> some View {
        let days = routine.days.sorted { $0.dayOfWeek < $1.dayOfWeek }

        return VStack(spacing: 14) {
            routineWeekHeader(routine: routine, days: days)
            routineTodayCard(days: days)
            routineWeekOverview(days: days)
        }
        .id(routine.id)
    }

    private func routineWeekHeader(routine: UserRoutine, days: [UserRoutineDay]) -> some View {
        let trainingDayCount = days.filter { !$0.isRestDay }.count
        let totalMoves = days.reduce(0) { $0 + $1.exercises.count }
        let fraction = min(1.0, Double(trainingDayCount) / 7.0)

        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Mi rutina")
                        .font(.title3).fontWeight(.bold)
                    Text("\(trainingDayCount) días de entreno · \(totalMoves) ejercicios en la semana")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.teal)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray4)).frame(height: 6)
                    Capsule().fill(Color.teal)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.teal.opacity(0.07)))
    }

    @ViewBuilder
    private func routineTodayCard(days: [UserRoutineDay]) -> some View {
        let today = todayDayOfWeek
        if let day = days.first(where: { $0.dayOfWeek == today }) {
            if routineDayCompletedToday(day) {
                routineDayCompletedCard(day: day)
            } else if day.isRestDay {
                restDayCard
            } else if day.exercises.isEmpty {
                routineEmptyExercisesCard
            } else {
                routineWorkoutHeroCard(day: day)
            }
        } else {
            routineEmptyDayCard
        }
    }

    /// Ya hiciste Mi rutina hoy: no mostrar de nuevo el botón principal hasta mañana.
    private func routineDayCompletedToday(_ day: UserRoutineDay) -> Bool {
        guard let at = day.lastRoutineWorkoutCompletedAt else { return false }
        return Calendar.current.isDate(at, inSameDayAs: Date())
    }

    private func routineDayCompletedCard(day: UserRoutineDay) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Entreno de Mi rutina hecho")
                .font(.headline)
            Text("Hoy ya registraste este día. Mañana podrás volver a empezarlo.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let at = day.lastRoutineWorkoutCompletedAt {
                Text(at, format: .dateTime.hour().minute())
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.08)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.25), lineWidth: 1))
    }

    private var routineEmptyDayCard: some View {
        VStack(spacing: 10) {
            Text("No se encontró el día en la rutina.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemGray6)))
    }

    private var routineEmptyExercisesCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "plus.circle.fill")
                .font(.system(size: 36))
                .foregroundStyle(.teal)
            Text("Hoy toca entrenar")
                .font(.headline)
            Text("Este día no tiene ejercicios. Añádelos desde Editar rutina.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { onEditRoutine?() } label: {
                Label("Añadir ejercicios", systemImage: "pencil")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.teal.opacity(0.06)))
    }

    private func routineWorkoutHeroCard(day: UserRoutineDay) -> some View {
        let groups = uniqueMuscleLabels(from: day.exercises)

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hoy en tu rutina")
                        .font(.headline)
                    if !groups.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(groups.prefix(4), id: \.self) { g in
                                Text(g)
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(Color.teal.opacity(0.15)))
                                    .foregroundStyle(.teal)
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)").font(.title2).fontWeight(.bold)
                    Text("ejercicios").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? Color.orange : Color.teal.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(exercise.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets)×\(exercise.reps)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    if exercise.id != day.exercises.prefix(4).last?.id { Divider() }
                }
                if day.exercises.count > 4 {
                    Text("+\(day.exercises.count - 4) más")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }

            Button {
                onStartRoutineWorkout?(day.exercises, day.dayOfWeek)
            } label: {
                Label("Empezar entreno", systemImage: "play.fill")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(.green)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: .green.opacity(0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

    private func uniqueMuscleLabels(from exercises: [PlannedExercise]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for ex in exercises {
            let label = ex.muscleGroup.rawValue.capitalized
            if !seen.contains(label) {
                seen.insert(label)
                out.append(label)
            }
        }
        return out
    }

    private func routineWeekOverview(days: [UserRoutineDay]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Esta semana")
                .font(.headline)
            HStack(spacing: 4) {
                ForEach(days, id: \.dayOfWeek) { day in
                    routineDayPill(day: day)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func routineDayPill(day: UserRoutineDay) -> some View {
        let today = todayDayOfWeek
        let isToday = day.dayOfWeek == today
        let isRest = day.isRestDay
        let n = day.exercises.count
        let doneToday = routineDayCompletedToday(day)

        return VStack(spacing: 4) {
            Text(shortDayLabelEs(day.dayOfWeek))
                .font(.system(size: 9)).fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(doneToday ? Color.green.opacity(0.55) : (isRest ? Color.purple.opacity(0.45) : (n > 0 ? Color.teal.opacity(0.45) : Color.gray.opacity(0.25))))
                    .frame(width: 32, height: 32)
                if doneToday {
                    Image(systemName: "checkmark").font(.caption).fontWeight(.bold).foregroundStyle(.white)
                } else if isRest {
                    Image(systemName: "moon.fill").font(.caption2).foregroundStyle(.white.opacity(0.9))
                } else if n > 0 {
                    Text("\(min(n, 9))")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                } else {
                    Image(systemName: "ellipsis").font(.caption2).foregroundStyle(.white.opacity(0.8))
                }
            }

            if !isRest && n > 0 && !doneToday {
                Text("+\(n)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(isToday ? Color.teal.opacity(0.12) : Color.clear))
    }

    // MARK: - Week Progress Header (plan)

    private func weekProgressHeader(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        let completed = days.filter { !$0.isRestDay && $0.dayStatus == .completed }.count
        let training = days.filter { !$0.isRestDay }.count
        let totalWeeks = plan.preferences.planDurationWeeks
        let currentWeek = plan.currentWeek
        let progressText = totalWeeks > 0 ? "Semana \(currentWeek) / \(totalWeeks)" : ""
        let progressFraction = totalWeeks > 0 ? Double(currentWeek) / Double(totalWeeks) : 0
        let p = WeeklyProgressionEngine.progression(for: currentWeek)
        let phaseLabel: String
        switch p.weekInCycle {
        case 1: phaseLabel = "Semana base"
        case 2: phaseLabel = "+5% peso"
        case 3: phaseLabel = "+10% volumen"
        case 4: phaseLabel = "Semana descarga"
        default: phaseLabel = ""
        }

        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(progressText).font(.title3).fontWeight(.bold)
                    Text(phaseLabel).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(completed)/\(training)")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.green)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(.systemGray4)).frame(height: 6)
                    Capsule().fill(Color.blue)
                        .frame(width: geo.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.blue.opacity(0.07)))
    }

    // MARK: - Today Card (plan)

    @ViewBuilder
    private func todayCard(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        let today = todayDayOfWeek
        let todayPlanIndex = days.firstIndex(where: { $0.dayOfWeek == today })
        let todayStatus: DayStatus? = todayPlanIndex.map { days[$0].dayStatus }

        if todayStatus == .skipped {
            skippedDayCard
        } else if todayStatus == .completed {
            dayCompletedCard(day: days[todayPlanIndex!])
        } else {
            let displayIndex = resolveDisplayIndex(days: days, todayPlanIndex: todayPlanIndex, today: today)
            if let idx = displayIndex {
                let day = days[idx]
                if day.isRestDay {
                    restDayCard
                } else if day.dayStatus == .completed {
                    dayCompletedCard(day: day)
                } else {
                    todayWorkoutCard(day: day, dayIndex: idx, isActuallyToday: day.dayOfWeek == today)
                }
            } else if days.contains(where: { !$0.isRestDay && $0.dayStatus == .pending }) {
                noWorkoutTodayCard
            } else {
                weekCompleteCard(days: days)
            }
        }
    }

    private var todayDayOfWeek: Int {
        let weekday = Calendar.current.component(.weekday, from: Date())
        return weekday == 1 ? 7 : weekday - 1
    }

    private func resolveDisplayIndex(days: [TrainingDayPlan], todayPlanIndex: Int?, today: Int) -> Int? {
        if let idx = todayPlanIndex {
            let day = days[idx]
            if day.isRestDay { return idx }
            if day.dayStatus == .pending { return idx }
            if day.dayStatus == .completed { return idx }
        }
        return days.indices.first { i in
            !days[i].isRestDay && days[i].dayStatus == .pending && days[i].dayOfWeek > today
        }
    }

    private func todayWorkoutCard(day: TrainingDayPlan, dayIndex: Int, isActuallyToday: Bool) -> some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isActuallyToday ? "Entreno de hoy" : "Siguiente — \(shortDayLabelEs(day.dayOfWeek))")
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(day.muscleGroups, id: \.self) { group in
                            Text(group.rawValue.capitalized)
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(Color.blue.opacity(0.12)))
                                .foregroundStyle(.blue)
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)").font(.title2).fontWeight(.bold)
                    Text("ejercicios").font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? Color.orange : Color.blue.opacity(0.5))
                            .frame(width: 6, height: 6)
                        Text(exercise.name).font(.subheadline).lineLimit(1)
                        Spacer()
                        Text("\(exercise.sets)×\(exercise.reps)")
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.vertical, 6)
                    if exercise.id != day.exercises.prefix(4).last?.id { Divider() }
                }
                if day.exercises.count > 4 {
                    Text("+\(day.exercises.count - 4) más")
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }

            Button { onStartTrainingWorkout?(dayIndex) } label: {
                Label("Empezar entreno", systemImage: "play.fill")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(.green)

            if isActuallyToday {
                HStack(spacing: 12) {
                    Button { trainingPlanVM?.skipDay(at: dayIndex) } label: {
                        Label("Saltar hoy", systemImage: "forward.fill").font(.subheadline)
                    }
                    .buttonStyle(.bordered).tint(.orange).controlSize(.small)

                    if trainingPlanVM?.canReschedule(at: dayIndex) == true {
                        Button { trainingPlanVM?.rescheduleDay(at: dayIndex) } label: {
                            Label("Reprogramar", systemImage: "arrow.uturn.right").font(.subheadline)
                        }
                        .buttonStyle(.bordered).tint(.blue).controlSize(.small)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: .green.opacity(0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.green.opacity(0.3), lineWidth: 1))
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 36)).foregroundStyle(.purple)
            Text("Día de descanso").font(.title3).fontWeight(.bold)
            Text("Recupera bien; el crecimiento ocurre también fuera del gimnasio.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.purple.opacity(0.07)))
    }

    private func dayCompletedCard(day: TrainingDayPlan) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(.green)
            Text("Entreno de hoy hecho").font(.headline)
            Text(day.muscleGroups.map { $0.rawValue.capitalized }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.green.opacity(0.07)))
    }

    private var noWorkoutTodayCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 36)).foregroundStyle(.blue)
            Text("Hoy no toca entreno").font(.headline)
            Text("El siguiente día de entreno aparece abajo en la semana.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.blue.opacity(0.07)))
    }

    private var skippedDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 36)).foregroundStyle(.orange)
            Text("Entreno bloqueado").font(.title3).fontWeight(.bold)
            Text("Saltaste el entreno de hoy. Mañana podrás seguir con el plan.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.orange.opacity(0.07)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.orange.opacity(0.25), lineWidth: 1))
    }

    private func weekCompleteCard(days: [TrainingDayPlan]) -> some View {
        let trainingDays = days.filter { !$0.isRestDay }
        guard !trainingDays.isEmpty else {
            return AnyView(noWorkoutTodayCard)
        }
        let allCompleted = trainingDays.allSatisfy { $0.dayStatus == .completed }

        return AnyView(VStack(spacing: 10) {
            Image(systemName: allCompleted ? "trophy.fill" : "checkmark.circle")
                .font(.system(size: 36))
                .foregroundStyle(allCompleted ? .yellow : .orange)
            Text(allCompleted ? "¡Semana completada!" : "No quedan entrenos esta semana")
                .font(.headline)
            Text(allCompleted
                 ? "Buen trabajo con el plan."
                 : "Aún puedes revisar la semana que viene.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(allCompleted ? Color.yellow.opacity(0.07) : Color.orange.opacity(0.07))))
    }

    // MARK: - Week Overview (plan)

    private func weekOverview(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Esta semana").font(.headline)
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayPill(day: day)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func dayPill(day: TrainingDayPlan) -> some View {
        let today = todayDayOfWeek
        let status = day.dayStatus
        let isPast = day.dayOfWeek < today && status == .pending
        let isToday = day.dayOfWeek == today

        return VStack(spacing: 4) {
            Text(shortDayLabelEs(day.dayOfWeek))
                .font(.system(size: 9)).fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(isPast ? Color.gray.opacity(0.2) : pillColor(status: status, isRestDay: day.isRestDay))
                    .frame(width: 32, height: 32)
                pillIcon(status: status, isRestDay: day.isRestDay, isPast: isPast)
            }

            if !day.isRestDay && !day.muscleGroups.isEmpty && !isPast {
                Text(day.muscleGroups.first?.rawValue.prefix(3).capitalized ?? "")
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(isToday ? Color.blue.opacity(0.1) : Color.clear))
        .opacity(isPast ? 0.45 : 1.0)
    }

    @ViewBuilder
    private func pillIcon(status: DayStatus, isRestDay: Bool, isPast: Bool) -> some View {
        if isRestDay {
            Image(systemName: "moon.fill").font(.caption2).foregroundStyle(.white.opacity(0.8))
        } else if isPast {
            Image(systemName: "minus").font(.system(size: 8)).foregroundStyle(.gray)
        } else {
            switch status {
            case .completed:
                Image(systemName: "checkmark").font(.caption).fontWeight(.bold).foregroundStyle(.white)
            case .skipped:
                Image(systemName: "forward.fill").font(.system(size: 8)).foregroundStyle(.white)
            case .rescheduled:
                Image(systemName: "arrow.uturn.right").font(.system(size: 8)).foregroundStyle(.white)
            case .pending, .unavailable:
                EmptyView()
            }
        }
    }

    private func pillColor(status: DayStatus, isRestDay: Bool) -> Color {
        if isRestDay { return .purple.opacity(0.5) }
        switch status {
        case .completed:   return .green
        case .skipped:     return .orange
        case .rescheduled: return .blue
        case .pending, .unavailable: return .gray.opacity(0.4)
        }
    }

    // MARK: - Helpers

    private func shortDayLabelEs(_ dayOfWeek: Int) -> String {
        ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"][safe: dayOfWeek - 1] ?? "?"
    }
}

// MARK: - Surface

private enum WorkoutSurface: String {
    case plan
    case routine
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
