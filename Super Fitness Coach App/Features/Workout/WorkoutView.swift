//
//  WorkoutView.swift
//  Super Fitness Coach App
//

import SwiftUI
import SwiftData

/// Entrenamiento unificado: **plan guiado** (metas, semanas, fases) y **mi rutina** (misma capa visual).
struct WorkoutView: View {
    @Environment(\.appLanguage) private var lang
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext

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
                        Picker(lang.workoutSurfacePicker, selection: $storedSurface) {
                            Text(lang.workoutSurfacePlan).tag(WorkoutSurface.plan.rawValue)
                            Text(lang.workoutSurfaceRoutine).tag(WorkoutSurface.routine.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .accessibilityLabel(lang.workoutSurfacePickerA11y)
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
            .navigationTitle(lang.workoutNavTitle)
            .navigationBarTitleDisplayMode(.large)
            .task {
                try? UserRoutineRepository(context: modelContext).getOrCreateActiveDefault()
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 12) {
                        Button {
                            onEditRoutine?()
                        } label: {
                            Label(hasRoutine ? lang.workoutEditRoutine : lang.workoutCreateRoutine, systemImage: "slider.horizontal.3")
                        }
                        Menu {
                            Button { onNewTrainingPlan?() } label: {
                                Label(lang.workoutNewPlan, systemImage: "plus.circle")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .accessibilityLabel(lang.moreOptions)
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
            Text(lang.workoutEmptyTitle)
                .font(.headline)
            Text(lang.workoutEmptySubtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if onEditRoutine != nil {
                Button {
                    onEditRoutine?()
                } label: {
                    Label(lang.workoutCreateMyRoutine, systemImage: "list.clipboard")
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .padding(.top, 4)
            }
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
                    .foregroundStyle(AppSemanticPalette.systemTeal)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.workoutBannerAlsoRoutineTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(lang.workoutBannerAlsoRoutineBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppSemanticPalette.workoutBannerTeal(colorScheme)))
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
                    .foregroundStyle(AppSemanticPalette.systemBlue)
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.workoutBannerBackToPlanTitle)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(lang.workoutBannerBackToPlanBody)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14).fill(AppSemanticPalette.workoutBannerBlue(colorScheme)))
        }
        .buttonStyle(.plain)
    }

    // MARK: - No Plan Banner

    private var noPlanBanner: some View {
        VStack(spacing: 14) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 36)).foregroundStyle(AppSemanticPalette.systemBlue)
            Text(lang.workoutOptionalPlanTitle).font(.headline)
            Text(lang.workoutOptionalPlanBody)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            Button { onNewTrainingPlan?() } label: {
                Label(lang.workoutCreateTrainingPlan, systemImage: "plus")
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
            weekOverview(days: currentWeekDays)
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

    /// Descanso solo si no hay ejercicios; si hay ejercicios, es día de entreno aunque `isRestDay` quedara mal guardado.
    private func routineDayIsEffectiveRest(_ day: UserRoutineDay) -> Bool {
        day.isRestDay && day.exercises.isEmpty
    }

    private func routineWeekHeader(routine: UserRoutine, days: [UserRoutineDay]) -> some View {
        let trainingDayCount = days.filter { !routineDayIsEffectiveRest($0) }.count
        let totalMoves = days.reduce(0) { $0 + $1.exercises.count }
        let fraction = min(1.0, Double(trainingDayCount) / 7.0)

        return VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(lang.workoutMyRoutineHeader)
                        .font(.title3).fontWeight(.bold)
                    Text(lang.workoutRoutineWeekSummary(days: trainingDayCount, exercises: totalMoves))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(AppSemanticPalette.systemTeal)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill)).frame(height: 6)
                    Capsule().fill(AppSemanticPalette.systemTeal)
                        .frame(width: geo.size.width * fraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppSemanticPalette.workoutRoutineHeader(colorScheme)))
    }

    @ViewBuilder
    private func routineTodayCard(days: [UserRoutineDay]) -> some View {
        let today = todayDayOfWeek
        if let day = days.first(where: { $0.dayOfWeek == today }) {
            if routineDayCompletedToday(day) {
                routineDayCompletedCard(day: day)
            } else if routineDayIsEffectiveRest(day) {
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

    /// Último entreno de este día de rutina cayó en la **misma semana calendario** que hoy (para la fila «Esta semana»).
    private func routineDayCompletedThisCalendarWeek(_ day: UserRoutineDay) -> Bool {
        guard let at = day.lastRoutineWorkoutCompletedAt else { return false }
        let cal = Calendar.current
        return cal.component(.yearForWeekOfYear, from: at) == cal.component(.yearForWeekOfYear, from: Date())
            && cal.component(.weekOfYear, from: at) == cal.component(.weekOfYear, from: Date())
    }

    private func routineDayCompletedCard(day: UserRoutineDay) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(AppSemanticPalette.systemGreen)
            Text(lang.workoutRoutineDoneTitle)
                .font(.headline)
            Text(lang.workoutRoutineDoneBody)
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
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutCardGreenTint(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppSemanticPalette.strokeMuted(.systemGreen, colorScheme), lineWidth: 1))
    }

    private var routineEmptyDayCard: some View {
        VStack(spacing: 10) {
            Text(lang.workoutRoutineDayMissing)
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
                .foregroundStyle(AppSemanticPalette.systemTeal)
            Text(lang.workoutTodayTrainTitle)
                .font(.headline)
            Text(lang.workoutTodayTrainBody)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { onEditRoutine?() } label: {
                Label(lang.workoutAddExercises, systemImage: "pencil")
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppSemanticPalette.systemTeal)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutCardTealTint(colorScheme)))
    }

    private func routineWorkoutHeroCard(day: UserRoutineDay) -> some View {
        let groups = uniqueMuscleLabels(from: day.exercises)

        return VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.workoutTodayInRoutine)
                        .font(.headline)
                    if !groups.isEmpty {
                        HStack(spacing: 6) {
                            ForEach(groups.prefix(4), id: \.self) { g in
                                Text(g)
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 8).padding(.vertical, 3)
                                    .background(Capsule().fill(AppSemanticPalette.workoutChipTealFill(colorScheme)))
                                    .foregroundStyle(AppSemanticPalette.accentOrPrimaryLabel(.systemTeal, colorScheme))
                            }
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)").font(.title2).fontWeight(.bold)
                    Text(lang.workoutExercisesWord).font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? AppSemanticPalette.systemOrange : AppSemanticPalette.tintedFill(.systemTeal, colorScheme, light: 0.5, dark: 0.55))
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
                    Text(lang.workoutMoreExercises(day.exercises.count - 4))
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }

            Button {
                onStartRoutineWorkout?(day.exercises, day.dayOfWeek)
            } label: {
                Label(lang.workoutStart, systemImage: "play.fill")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(AppSemanticPalette.systemGreen)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: AppSemanticPalette.systemGreen.opacity(colorScheme == .dark ? 0.22 : 0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppSemanticPalette.strokeMuted(.systemGreen, colorScheme), lineWidth: 1))
    }

    private func uniqueMuscleLabels(from exercises: [PlannedExercise]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for ex in exercises {
            let label = ex.muscleGroup.displayName(lang)
            if !seen.contains(label) {
                seen.insert(label)
                out.append(label)
            }
        }
        return out
    }

    private func routineWeekOverview(days: [UserRoutineDay]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(lang.workoutThisWeek)
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
        let isRest = routineDayIsEffectiveRest(day)
        let n = day.exercises.count
        let doneThisWeek = routineDayCompletedThisCalendarWeek(day)

        return VStack(spacing: 4) {
            Text(lang.shortWeekday(day.dayOfWeek))
                .font(.system(size: 9)).fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(AppSemanticPalette.workoutPillCircle(doneThisWeek: doneThisWeek, isRest: isRest, hasExercises: n > 0, scheme: colorScheme))
                    .frame(width: 32, height: 32)
                if doneThisWeek {
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

            if !isRest && n > 0 && !doneThisWeek {
                Text("+\(n)")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(isToday ? AppSemanticPalette.workoutDayPillTodayTeal(colorScheme) : Color.clear))
    }

    // MARK: - Week Progress Header (plan)

    private func weekProgressHeader(plan: TrainingPlan, days: [TrainingDayPlan]) -> some View {
        let completed = days.filter { !$0.isRestDay && $0.dayStatus == .completed }.count
        let training = days.filter { !$0.isRestDay }.count
        let totalWeeks = plan.preferences.planDurationWeeks
        let currentWeek = plan.currentWeek
        let progressText = totalWeeks > 0 ? lang.weekProgressText(current: currentWeek, total: totalWeeks) : ""
        let progressFraction = totalWeeks > 0 ? Double(currentWeek) / Double(totalWeeks) : 0
        let p = WeeklyProgressionEngine.progression(for: currentWeek)
        let phaseLabel: String
        switch p.weekInCycle {
        case 1: phaseLabel = lang.phaseBase
        case 2: phaseLabel = lang.phaseWeight5
        case 3: phaseLabel = lang.phaseVolume10
        case 4: phaseLabel = lang.phaseDeload
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
                    .font(.title2).fontWeight(.bold).foregroundStyle(AppSemanticPalette.systemGreen)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .tertiarySystemFill)).frame(height: 6)
                    Capsule().fill(AppSemanticPalette.systemBlue)
                        .frame(width: geo.size.width * progressFraction, height: 6)
                }
            }
            .frame(height: 6)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(AppSemanticPalette.workoutWeekProgressBlue(colorScheme)))
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
                    Text(isActuallyToday ? lang.workoutTodayCard : lang.workoutNextDay(lang.shortWeekday(day.dayOfWeek)))
                        .font(.headline)
                    HStack(spacing: 6) {
                        ForEach(day.muscleGroups, id: \.self) { group in
                            Text(group.displayName(lang))
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(Capsule().fill(AppSemanticPalette.workoutChipBlueFill(colorScheme)))
                                .foregroundStyle(AppSemanticPalette.accentOrPrimaryLabel(.systemBlue, colorScheme))
                        }
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(day.exercises.count)").font(.title2).fontWeight(.bold)
                    Text(lang.workoutExercisesWord).font(.caption2).foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 0) {
                ForEach(Array(day.exercises.prefix(4).enumerated()), id: \.offset) { _, exercise in
                    HStack {
                        Circle()
                            .fill(exercise.isCompound ? AppSemanticPalette.systemOrange : AppSemanticPalette.tintedFill(.systemBlue, colorScheme, light: 0.5, dark: 0.55))
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
                    Text(lang.workoutMoreExercises(day.exercises.count - 4))
                        .font(.caption).foregroundStyle(.secondary).padding(.top, 4)
                }
            }

            Button { onStartTrainingWorkout?(dayIndex) } label: {
                Label(lang.workoutStart, systemImage: "play.fill")
                    .fontWeight(.semibold).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).controlSize(.large).tint(AppSemanticPalette.systemGreen)

            if isActuallyToday {
                HStack(spacing: 12) {
                    Button { trainingPlanVM?.skipDay(at: dayIndex) } label: {
                        Label(lang.workoutSkipToday, systemImage: "forward.fill").font(.subheadline)
                    }
                    .buttonStyle(.bordered).tint(AppSemanticPalette.systemOrange).controlSize(.small)

                    if trainingPlanVM?.canReschedule(at: dayIndex) == true {
                        Button { trainingPlanVM?.rescheduleDay(at: dayIndex) } label: {
                            Label(lang.workoutReschedule, systemImage: "arrow.uturn.right").font(.subheadline)
                        }
                        .buttonStyle(.bordered).tint(AppSemanticPalette.systemBlue).controlSize(.small)
                    }
                    Spacer()
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.systemBackground))
            .shadow(color: AppSemanticPalette.systemGreen.opacity(colorScheme == .dark ? 0.22 : 0.15), radius: 8))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppSemanticPalette.strokeMuted(.systemGreen, colorScheme), lineWidth: 1))
    }

    private var restDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "moon.zzz.fill").font(.system(size: 36)).foregroundStyle(AppSemanticPalette.systemPurple)
            Text(lang.workoutRestDayTitle).font(.title3).fontWeight(.bold)
            Text(lang.workoutRestDayBody)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutRestCardPurple(colorScheme)))
    }

    private func dayCompletedCard(day: TrainingDayPlan) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill").font(.system(size: 36)).foregroundStyle(AppSemanticPalette.systemGreen)
            Text(lang.workoutTodayDoneTitle).font(.headline)
            Text(day.muscleGroups.map { $0.displayName(lang) }.joined(separator: " · "))
                .font(.subheadline).foregroundStyle(.secondary)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutCardGreenTint(colorScheme)))
    }

    private var noWorkoutTodayCard: some View {
        VStack(spacing: 10) {
            Image(systemName: "calendar").font(.system(size: 36)).foregroundStyle(AppSemanticPalette.systemBlue)
            Text(lang.workoutNoTrainingTodayTitle).font(.headline)
            Text(lang.workoutNoTrainingTodayBody)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutInfoCardBlue(colorScheme)))
    }

    private var skippedDayCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "lock.fill").font(.system(size: 36)).foregroundStyle(AppSemanticPalette.systemOrange)
            Text(lang.workoutLockedTitle).font(.title3).fontWeight(.bold)
            Text(lang.workoutLockedBody)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16).fill(AppSemanticPalette.workoutLockedOrange(colorScheme)))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppSemanticPalette.strokeMuted(.systemOrange, colorScheme), lineWidth: 1))
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
                .foregroundStyle(allCompleted ? AppSemanticPalette.systemYellow : AppSemanticPalette.systemOrange)
            Text(allCompleted ? lang.workoutWeekCompleteCelebration : lang.workoutWeekNoMore)
                .font(.headline)
            Text(allCompleted
                 ? lang.workoutWeekCompleteBody
                 : lang.workoutWeekNoMoreBody)
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .padding(20).frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(allCompleted ? AppSemanticPalette.workoutWeekCompleteYellow(colorScheme) : AppSemanticPalette.workoutWeekCompleteOrange(colorScheme))))
    }

    // MARK: - Week Overview (plan)

    private func weekOverview(days: [TrainingDayPlan]) -> some View {
        let training = days.filter { !$0.isRestDay }
        let weekAllTrainingDone = !training.isEmpty && training.allSatisfy { $0.dayStatus == .completed }
        return VStack(alignment: .leading, spacing: 10) {
            Text(lang.workoutThisWeek).font(.headline)
            HStack(spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    dayPill(day: day, maskFutureCompleted: !weekAllTrainingDone)
                }
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.systemGray6)))
    }

    private func dayPill(day: TrainingDayPlan, maskFutureCompleted: Bool) -> some View {
        let today = todayDayOfWeek
        let rawStatus = day.dayStatus
        // Si la semana aún no está toda hecha, no mostrar como completados días futuros (datos viejos / plan sin avanzar).
        let status: DayStatus = (maskFutureCompleted && !day.isRestDay && rawStatus == .completed && day.dayOfWeek > today)
            ? .pending
            : rawStatus
        let isPast = day.dayOfWeek < today && status == .pending
        let isToday = day.dayOfWeek == today

        return VStack(spacing: 4) {
            Text(lang.shortWeekday(day.dayOfWeek))
                .font(.system(size: 9)).fontWeight(.medium)
                .foregroundStyle(isToday ? .primary : .secondary)

            ZStack {
                Circle()
                    .fill(isPast ? Color(uiColor: .tertiarySystemFill) : pillColor(status: status, isRestDay: day.isRestDay))
                    .frame(width: 32, height: 32)
                pillIcon(status: status, isRestDay: day.isRestDay, isPast: isPast)
            }

            if !day.isRestDay && !day.muscleGroups.isEmpty && !isPast {
                Text(day.muscleGroups.first.map { String($0.displayName(lang).prefix(3)) } ?? "")
                    .font(.system(size: 8)).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 8).fill(isToday ? AppSemanticPalette.workoutDayPillTodayBlue(colorScheme) : Color.clear))
        .opacity(isPast ? 0.45 : 1.0)
    }

    @ViewBuilder
    private func pillIcon(status: DayStatus, isRestDay: Bool, isPast: Bool) -> some View {
        if isRestDay {
            Image(systemName: "moon.fill").font(.caption2).foregroundStyle(.white.opacity(0.8))
        } else if isPast {
            Image(systemName: "minus").font(.system(size: 8)).foregroundStyle(.secondary)
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
        if isRestDay {
            return AppSemanticPalette.tintedFill(.systemPurple, colorScheme, light: 0.5, dark: 0.55)
        }
        switch status {
        case .completed:   return AppSemanticPalette.systemGreen
        case .skipped:     return AppSemanticPalette.systemOrange
        case .rescheduled: return AppSemanticPalette.systemBlue
        case .pending, .unavailable:
            return Color(uiColor: .systemGray).opacity(colorScheme == .dark ? 0.38 : 0.4)
        }
    }

    // MARK: - Helpers

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
