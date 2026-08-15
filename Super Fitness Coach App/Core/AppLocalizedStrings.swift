//
//  AppLocalizedStrings.swift
//  Super Fitness Coach App
//

import Foundation

// MARK: - AppLanguage UI strings

extension AppLanguage {

    // MARK: Tabs

    var tabHome: String {
        switch self {
        case .spanish: return "Inicio"
        case .english: return "Home"
        }
    }

    var tabWorkout: String {
        switch self {
        case .spanish: return "Entrenamiento"
        case .english: return "Workout"
        }
    }

    var tabStats: String {
        switch self {
        case .spanish: return "Estadísticas"
        case .english: return "Stats"
        }
    }

    var tabProfile: String {
        switch self {
        case .spanish: return "Perfil"
        case .english: return "Profile"
        }
    }

    // MARK: Profile — navigation & language

    var profileTitle: String {
        switch self {
        case .spanish: return "Perfil"
        case .english: return "Profile"
        }
    }

    var sectionLanguage: String {
        switch self {
        case .spanish: return "Idioma"
        case .english: return "Language"
        }
    }

    // MARK: Profile — alerts

    var alertPlanUpdatedTitle: String {
        switch self {
        case .spanish: return "Plan actualizado"
        case .english: return "Plan updated"
        }
    }

    var alertPlanUpdatedMessage: String {
        switch self {
        case .spanish: return "Tu plan semanal se ha regenerado."
        case .english: return "Your weekly plan has been regenerated."
        }
    }

    var ok: String {
        switch self {
        case .spanish: return "Aceptar"
        case .english: return "OK"
        }
    }

    // MARK: Profile — fitness goal section

    var sectionFitnessGoal: String {
        switch self {
        case .spanish: return "Objetivo"
        case .english: return "Fitness goal"
        }
    }

    // MARK: Profile — Apple Health

    var sectionAppleHealth: String {
        switch self {
        case .spanish: return "Apple Health"
        case .english: return "Apple Health"
        }
    }

    var labelHealthKit: String {
        switch self {
        case .spanish: return "HealthKit"
        case .english: return "HealthKit"
        }
    }

    var healthConnected: String {
        switch self {
        case .spanish: return "Conectado"
        case .english: return "Connected"
        }
    }

    var healthDenied: String {
        switch self {
        case .spanish: return "Denegado"
        case .english: return "Denied"
        }
    }

    var healthUnavailable: String {
        switch self {
        case .spanish: return "No disponible"
        case .english: return "Unavailable"
        }
    }

    var healthConnect: String {
        switch self {
        case .spanish: return "Conectar"
        case .english: return "Connect"
        }
    }

    // MARK: Profile — notifications

    var sectionNotifications: String {
        switch self {
        case .spanish: return "Notificaciones"
        case .english: return "Notifications"
        }
    }

    var labelDailyReminder: String {
        switch self {
        case .spanish: return "Recordatorio diario"
        case .english: return "Daily reminder"
        }
    }

    /// Push local: datos de recuperación del día ya listos (cuando hay sueño sincronizado + confianza).
    var notificationRecoveryDataReadyTitle: String {
        switch self {
        case .spanish: return "Tu coach"
        case .english: return "Your coach"
        }
    }

    func notificationRecoveryDataReadyBody(score: Int, emoji: String, tip: String) -> String {
        switch self {
        case .spanish:
            return "Tu recuperación de hoy ya está lista: \(score) \(emoji). \(tip)"
        case .english:
            return "Today’s recovery data is ready: \(score) \(emoji). \(tip)"
        }
    }

    var notificationsOn: String {
        switch self {
        case .spanish: return "Activadas"
        case .english: return "On"
        }
    }

    var notificationsEnable: String {
        switch self {
        case .spanish: return "Activar"
        case .english: return "Enable"
        }
    }

    // MARK: Profile — body metrics

    var sectionBodyMetrics: String {
        switch self {
        case .spanish: return "Medidas corporales"
        case .english: return "Body metrics"
        }
    }

    var unitsLabel: String {
        switch self {
        case .spanish: return "Unidades"
        case .english: return "Units"
        }
    }

    var unitMetric: String {
        switch self {
        case .spanish: return "Métrico"
        case .english: return "Metric"
        }
    }

    var unitImperial: String {
        switch self {
        case .spanish: return "Imperial"
        case .english: return "Imperial"
        }
    }

    var labelWeight: String {
        switch self {
        case .spanish: return "Peso"
        case .english: return "Weight"
        }
    }

    var labelHeight: String {
        switch self {
        case .spanish: return "Altura"
        case .english: return "Height"
        }
    }

    var notSet: String {
        switch self {
        case .spanish: return "Sin definir"
        case .english: return "Not set"
        }
    }

    var edit: String {
        switch self {
        case .spanish: return "Editar"
        case .english: return "Edit"
        }
    }

    var cancel: String {
        switch self {
        case .spanish: return "Cancelar"
        case .english: return "Cancel"
        }
    }

    var save: String {
        switch self {
        case .spanish: return "Guardar"
        case .english: return "Save"
        }
    }

    // MARK: Profile — fitness goals (config)

    var sectionFitnessGoals: String {
        switch self {
        case .spanish: return "Objetivos de salud"
        case .english: return "Health goals"
        }
    }

    var labelSleepGoal: String {
        switch self {
        case .spanish: return "Sueño"
        case .english: return "Sleep goal"
        }
    }

    var labelStepsGoal: String {
        switch self {
        case .spanish: return "Pasos"
        case .english: return "Steps goal"
        }
    }

    var labelCalorieGoal: String {
        switch self {
        case .spanish: return "Calorías"
        case .english: return "Calorie goal"
        }
    }

    var labelBaselineHR: String {
        switch self {
        case .spanish: return "FC en reposo"
        case .english: return "Baseline HR"
        }
    }

    var labelFitnessLevel: String {
        switch self {
        case .spanish: return "Nivel"
        case .english: return "Fitness level"
        }
    }

    var labelGymWeightUnit: String {
        switch self {
        case .spanish: return "Peso (gimnasio)"
        case .english: return "Gym weight"
        }
    }

    var liftingUnitKilograms: String {
        switch self {
        case .spanish: return "Kilogramos (kg)"
        case .english: return "Kilograms (kg)"
        }
    }

    var liftingUnitPounds: String {
        switch self {
        case .spanish: return "Libras (lb)"
        case .english: return "Pounds (lb)"
        }
    }

    var labelBedtime: String {
        switch self {
        case .spanish: return "Hora de dormir"
        case .english: return "Bedtime"
        }
    }

    var labelWake: String {
        switch self {
        case .spanish: return "Despertar"
        case .english: return "Wake"
        }
    }

    var labelBuffer: String {
        switch self {
        case .spanish: return "Margen"
        case .english: return "Buffer"
        }
    }

    var labelSleepSchedule: String {
        switch self {
        case .spanish: return "Horario de sueño"
        case .english: return "Sleep schedule"
        }
    }

    var editSleepSchedule: String {
        switch self {
        case .spanish: return "Editar horario de sueño"
        case .english: return "Edit sleep schedule"
        }
    }

    var minutesShort: String {
        switch self {
        case .spanish: return "min"
        case .english: return "min"
        }
    }

    var sleepScheduleNotSet: String {
        switch self {
        case .spanish: return "Sin definir"
        case .english: return "Not set"
        }
    }

    var hoursSuffix: String { "h" }

    var pickerFitnessLevel: String {
        switch self {
        case .spanish: return "Nivel de forma"
        case .english: return "Fitness level"
        }
    }

    var gymWeightSectionTitle: String {
        switch self {
        case .spanish: return "Peso en el gimnasio"
        case .english: return "Gym weight entry"
        }
    }

    var gymWeightPickerAccessibility: String {
        switch self {
        case .spanish: return "Unidad de pesas"
        case .english: return "Weight unit"
        }
    }

    var gymWeightFooter: String {
        switch self {
        case .spanish:
            return "Introduces el peso en esa unidad; debajo de cada campo verás el equivalente exacto en la otra unidad (1 lb = 0,453592 kg)."
        case .english:
            return "Log weight in that unit; under each field you’ll see the exact conversion to the other unit (1 lb = 0.453592 kg)."
        }
    }

    /// Debajo del campo de peso en entreno / editor de rutina.
    func liftWeightEquivalentLine(fullOtherUnit: String) -> String {
        switch self {
        case .spanish: return "Equivale a \(fullOtherUnit)"
        case .english: return "Equivalent to \(fullOtherUnit)"
        }
    }

    // MARK: Validation (ProfileViewModel)

    var validationWeightKg: String {
        switch self {
        case .spanish: return "Introduce un peso válido en kg."
        case .english: return "Please enter a valid weight in kg."
        }
    }

    var validationHeightCm: String {
        switch self {
        case .spanish: return "Introduce una altura válida en cm."
        case .english: return "Please enter a valid height in cm."
        }
    }

    var validationWeightLbs: String {
        switch self {
        case .spanish: return "Introduce un peso válido en lb."
        case .english: return "Please enter a valid weight in lbs."
        }
    }

    var validationHeightImperial: String {
        switch self {
        case .spanish: return "Introduce una altura válida en pies/pulgadas."
        case .english: return "Please enter a valid height in feet/inches."
        }
    }

    var validationSaveFailed: String {
        switch self {
        case .spanish: return "No se pudo guardar. Inténtalo de nuevo."
        case .english: return "Failed to save. Please try again."
        }
    }

    var validationFitnessNumbers: String {
        switch self {
        case .spanish: return "Introduce números válidos en todos los campos."
        case .english: return "Please enter valid numbers for all fields."
        }
    }

    var validationFitnessRanges: String {
        switch self {
        case .spanish:
            return "Revisa los valores: sueño 4–12 h, pasos 1k–50k, calorías 100–2000, FC en reposo 35–120 lpm."
        case .english:
            return "Please check your values: sleep 4–12h, steps 1k–50k, calories 100–2000, resting HR 35–120 bpm."
        }
    }

    var validationBedtimeWakeSame: String {
        switch self {
        case .spanish: return "La hora de dormir y la de despertar no pueden coincidir."
        case .english: return "Bedtime and wake time cannot be the same."
        }
    }

    var validationSleepWindowShort: String {
        switch self {
        case .spanish: return "La ventana de sueño debe ser de al menos 4 horas."
        case .english: return "Sleep window must be at least 4 hours."
        }
    }

    // MARK: Workout executor

    var workoutTitle: String {
        switch self {
        case .spanish: return "Entreno"
        case .english: return "Workout"
        }
    }

    var close: String {
        switch self {
        case .spanish: return "Cerrar"
        case .english: return "Close"
        }
    }

    /// Saltar al siguiente ejercicio sin completar el actual (toolbar del entreno).
    var workoutSkipExercise: String {
        switch self {
        case .spanish: return "Siguiente"
        case .english: return "Next"
        }
    }

    /// Menú para elegir el ejercicio activo (orden libre).
    var workoutExercisePickerTitle: String {
        switch self {
        case .spanish: return "Ir a…"
        case .english: return "Go to…"
        }
    }

    /// Pie de texto: Mi rutina respeta las series del editor.
    var workoutFootnoteMiRutinaSeries: String {
        switch self {
        case .spanish:
            return "Mi rutina: las series son las que definiste aquí. No se aplica el ajuste por fase del plan ni por recuperación del día."
        case .english:
            return "Your routine: set counts are the ones you set in the editor. Plan-phase and daily recovery adjustments don’t apply."
        }
    }

    /// Pie de texto: plan guiado puede cambiar el número de series respecto al día del plan.
    func workoutFootnotePlanAdjustedSeries(original: Int, adjusted: Int) -> String {
        switch self {
        case .spanish:
            return "Plan guiado: hoy \(adjusted) series (en tu día del plan: \(original)). Puede variar por la fase de la semana (p. ej. descarga) o por tu recuperación."
        case .english:
            return "Guided plan: \(adjusted) sets today (your plan day had \(original)). This can change with the weekly phase (e.g. deload) or your recovery."
        }
    }

    var doneKeyboard: String {
        switch self {
        case .spanish: return "Listo"
        case .english: return "Done"
        }
    }

    var noExercisesTitle: String {
        switch self {
        case .spanish: return "No hay ejercicios"
        case .english: return "No exercises"
        }
    }

    var noExercisesMessage: String {
        switch self {
        case .spanish:
            return "No se pudieron cargar ejercicios para hoy. Revisa tu plan o rutina."
        case .english:
            return "Couldn’t load exercises for today. Check your plan or routine."
        }
    }

    var workoutCompleteTitle: String {
        switch self {
        case .spanish: return "¡Entreno completado!"
        case .english: return "Workout complete!"
        }
    }

    var workoutCompleteStats: String {
        switch self {
        case .spanish: return "ejercicios"
        case .english: return "exercises"
        }
    }

    var workoutCompleteSets: String {
        switch self {
        case .spanish: return "series"
        case .english: return "sets"
        }
    }

    var viewSummary: String {
        switch self {
        case .spanish: return "Ver resumen"
        case .english: return "View summary"
        }
    }

    var seeDetail: String {
        switch self {
        case .spanish: return "Ver detalle"
        case .english: return "See details"
        }
    }

    var labelCompound: String {
        switch self {
        case .spanish: return "Compuesto"
        case .english: return "Compound"
        }
    }

    var yourSets: String {
        switch self {
        case .spanish: return "Tus series"
        case .english: return "Your sets"
        }
    }

    func setsHint(weightUnitSymbol: String) -> String {
        switch self {
        case .spanish:
            return "Toca − y + para ajustar, o escribe el valor. El peso va en \(weightUnitSymbol), como en tu gimnasio."
        case .english:
            return "Tap − and + to adjust, or type values. Weight is in \(weightUnitSymbol), like at your gym."
        }
    }

    var restTitle: String {
        switch self {
        case .spanish: return "Descanso"
        case .english: return "Rest"
        }
    }

    var nextSet: String {
        switch self {
        case .spanish: return "Siguiente serie"
        case .english: return "Next set"
        }
    }

    var secondsShort: String {
        switch self {
        case .spanish: return "s"
        case .english: return "s"
        }
    }

    func restAccessibility(seconds: Int) -> String {
        switch self {
        case .spanish: return "Descanso, \(seconds) segundos"
        case .english: return "Rest, \(seconds) seconds"
        }
    }

    func setLabel(setNumber n: Int) -> String {
        switch self {
        case .spanish: return "Serie \(n)"
        case .english: return "Set \(n)"
        }
    }

    var setDone: String {
        switch self {
        case .spanish: return "Hecha"
        case .english: return "Done"
        }
    }

    var prBadge: String { "PR" }

    func lastTimeLine(_ line: String) -> String {
        switch self {
        case .spanish: return "Última vez: \(line)"
        case .english: return "Last time: \(line)"
        }
    }

    var weightAndReps: String {
        switch self {
        case .spanish: return "Peso y repeticiones"
        case .english: return "Weight & reps"
        }
    }

    func weightFieldLabel(symbol: String) -> String {
        switch self {
        case .spanish: return "Peso (\(symbol))"
        case .english: return "Weight (\(symbol))"
        }
    }

    var repsShort: String {
        switch self {
        case .spanish: return "Reps"
        case .english: return "Reps"
        }
    }

    func logSetButton(setNumber: Int) -> String {
        switch self {
        case .spanish: return "Registrar serie \(setNumber)"
        case .english: return "Log set \(setNumber)"
        }
    }

    var stepHintKg: String {
        switch self {
        case .spanish: return "±2,5 kg · ±1 rep"
        case .english: return "±2.5 kg · ±1 rep"
        }
    }

    var stepHintLb: String {
        switch self {
        case .spanish: return "±1 lb · ±1 rep"
        case .english: return "±1 lb · ±1 rep"
        }
    }

    // MARK: - Home

    var homeGreetingDefault: String {
        switch self {
        case .spanish: return "Vamos con todo"
        case .english: return "Let’s go"
        }
    }

    func homeGreeting(name: String) -> String {
        switch self {
        case .spanish: return "Hola, \(name)"
        case .english: return "Hi, \(name)"
        }
    }

    var homeHeroYourDay: String {
        switch self {
        case .spanish: return "Tu día"
        case .english: return "Your day"
        }
    }

    var homeHeroRecoveryEnergy: String {
        switch self {
        case .spanish: return "Recuperación y energía"
        case .english: return "Recovery & energy"
        }
    }

    var homeHeroRecoveryEnergyYesterday: String {
        switch self {
        case .spanish: return "Recuperación (ayer)"
        case .english: return "Recovery (yesterday)"
        }
    }

    var homeRecoveryCollectingOvernight: String {
        switch self {
        case .spanish: return "Estamos recopilando tu descanso… vuelve más tarde cuando se sincronicen tus datos."
        case .english: return "We’re collecting your sleep… check back later once your data syncs."
        }
    }

    var homeRecoveryNotCollectedByNoon: String {
        switch self {
        case .spanish: return "Hoy no se ha logrado recopilar información suficiente para calcular tu recuperación."
        case .english: return "We couldn’t collect enough data today to calculate your recovery."
        }
    }

    var homeWellbeingGoalLine: String {
        switch self {
        case .spanish: return "de tu objetivo de bienestar hoy"
        case .english: return "of your wellbeing goal today"
        }
    }

    var homeNoRecoveryData: String {
        switch self {
        case .spanish: return "Sin datos de recuperación todavía"
        case .english: return "No recovery data yet"
        }
    }

    // MARK: Home — rings (Sueño / Recuperación / Actividad)

    var homeRingRecoveryTitle: String {
        switch self {
        case .spanish: return "Recuperación"
        case .english: return "Recovery"
        }
    }

    var homeRingSleepTitle: String {
        switch self {
        case .spanish: return "Sueño"
        case .english: return "Sleep"
        }
    }

    var homeRingActivityTitle: String {
        switch self {
        case .spanish: return "Actividad"
        case .english: return "Activity"
        }
    }

    var homeRingToday: String {
        switch self {
        case .spanish: return "Hoy"
        case .english: return "Today"
        }
    }

    var homeRingYesterday: String {
        switch self {
        case .spanish: return "Ayer"
        case .english: return "Yesterday"
        }
    }

    var homeRingOutOf100: String {
        switch self {
        case .spanish: return "de 100"
        case .english: return "out of 100"
        }
    }

    var homeRingTapForDetails: String {
        switch self {
        case .spanish: return "Toca para ver detalles"
        case .english: return "Tap to see details"
        }
    }

    var homeTodayUpper: String {
        switch self {
        case .spanish: return "HOY"
        case .english: return "TODAY"
        }
    }

    var homeOutOf100: String {
        switch self {
        case .spanish: return "de 100"
        case .english: return "out of 100"
        }
    }

    // MARK: Home — detail screens copy

    var homeSleepTitle: String {
        switch self {
        case .spanish: return "Sueño"
        case .english: return "Sleep"
        }
    }

    var homeSleepSubtitle: String {
        switch self {
        case .spanish: return "Cómo dormiste y qué tan constante fue tu horario."
        case .english: return "How you slept and how consistent your schedule was."
        }
    }

    var homeRecoveryTitle: String {
        switch self {
        case .spanish: return "Recuperación"
        case .english: return "Recovery"
        }
    }

    var homeRecoverySubtitle: String {
        switch self {
        case .spanish: return "Qué tan listo está tu cuerpo para entrenar hoy."
        case .english: return "How ready your body is to train today."
        }
    }

    var homeActivityTitle: String {
        switch self {
        case .spanish: return "Actividad"
        case .english: return "Activity"
        }
    }

    var homeActivitySubtitle: String {
        switch self {
        case .spanish: return "Tu movimiento del día: pasos y calorías activas."
        case .english: return "Your daily movement: steps and active calories."
        }
    }

    var homeSleepInfo: String {
        switch self {
        case .spanish:
            return "El score de Sueño (0–100) resume cuánto dormiste y la calidad de tu descanso. Si falta información, verás “—”."
        case .english:
            return "The Sleep score (0–100) summarizes how much you slept and your sleep quality. If data is missing, you’ll see “—”."
        }
    }

    var homeRecoveryInfo: String {
        switch self {
        case .spanish:
            return "El score de Recuperación (0–100) combina tu descanso y señales del cuerpo (como FC en reposo y HRV). Entre más alto, mejor para entrenar fuerte."
        case .english:
            return "The Recovery score (0–100) combines your sleep and body signals (like resting HR and HRV). Higher usually means you can push harder."
        }
    }

    var homeActivityInfo: String {
        switch self {
        case .spanish:
            return "El score de Actividad (0–100) resume tu movimiento del día. Sube con más pasos y calorías activas."
        case .english:
            return "The Activity score (0–100) summarizes your daily movement. It goes up with more steps and active calories."
        }
    }

    var homeSleepFooter: String {
        switch self {
        case .spanish: return "Tip: intenta dormir y despertar a horas parecidas para mejorar la regularidad."
        case .english: return "Tip: go to sleep and wake up around the same time to improve regularity."
        }
    }

    var homeRecoveryFooter: String {
        switch self {
        case .spanish: return "Tip: tu recuperación mejora con buen sueño, descanso y menos estrés."
        case .english: return "Tip: recovery improves with good sleep, rest, and lower stress."
        }
    }

    var homeActivityFooter: String {
        switch self {
        case .spanish: return "Tip: una caminata corta puede subir tu actividad sin cansarte."
        case .english: return "Tip: a short walk can boost activity without draining you."
        }
    }

    // MARK: Home — metrics labels

    var homeMetricSleepTotal: String {
        switch self {
        case .spanish: return "Horas dormidas"
        case .english: return "Sleep hours"
        }
    }

    var homeMetricSleepDeep: String {
        switch self {
        case .spanish: return "Sueño profundo"
        case .english: return "Deep sleep"
        }
    }

    var homeMetricSleepREM: String {
        switch self {
        case .spanish: return "Sueño REM"
        case .english: return "REM sleep"
        }
    }

    var homeMetricSleepRegularity: String {
        switch self {
        case .spanish: return "Regularidad"
        case .english: return "Regularity"
        }
    }

    var homeMetricSleepContinuity: String {
        switch self {
        case .spanish: return "Continuidad (menos interrupciones)"
        case .english: return "Continuity (fewer wake-ups)"
        }
    }

    var homeMetricSleepWindow: String {
        switch self {
        case .spanish: return "Ventana detectada"
        case .english: return "Detected window"
        }
    }

    // MARK: Sleep detail (MVP)

    /// Barra de navegación del detalle de sueño cuando los datos son del día anterior (placeholder).
    var sleepDetailNavTitleYesterday: String {
        switch self {
        case .spanish: return "AYER"
        case .english: return "YESTERDAY"
        }
    }

    /// Leyenda explícita: el usuario ve datos de ayer mientras hoy sigue cargando.
    var sleepDetailTodayDataLoadingLegend: String {
        switch self {
        case .spanish:
            return "Los datos del día de hoy aún se están cargando. La información que ves corresponde a ayer."
        case .english:
            return "Today’s data is still loading. What you’re seeing is from yesterday."
        }
    }

    var sleepDetailSegmentDay: String {
        switch self {
        case .spanish: return "Día"
        case .english: return "Day"
        }
    }

    var sleepDetailSegmentWeek: String {
        switch self {
        case .spanish: return "Sem"
        case .english: return "Wk"
        }
    }

    var sleepDetailSegmentMonth: String {
        switch self {
        case .spanish: return "Mes"
        case .english: return "Mo"
        }
    }

    var sleepDetailTabSoon: String {
        switch self {
        case .spanish: return "Próximamente"
        case .english: return "Coming soon"
        }
    }

    var sleepDetailContributorsTitle: String {
        switch self {
        case .spanish: return "Contribuyentes a la calidad del sueño"
        case .english: return "Sleep quality contributors"
        }
    }

    var sleepDetailPhasesTitle: String {
        switch self {
        case .spanish: return "Fases"
        case .english: return "Stages"
        }
    }

    var sleepDetailDuration: String {
        switch self {
        case .spanish: return "Duración"
        case .english: return "Duration"
        }
    }

    var sleepDetailQuality: String {
        switch self {
        case .spanish: return "Calidad"
        case .english: return "Quality"
        }
    }

    var sleepDetailGoalNotReached: String {
        switch self {
        case .spanish: return "No alcanzado"
        case .english: return "Not reached"
        }
    }

    var sleepDetailHeadlineWhenLow: String {
        switch self {
        case .spanish: return "Es hora de priorizar el sueño"
        case .english: return "It’s time to prioritize sleep"
        }
    }

    var sleepDetailHeadlineWhenOK: String {
        switch self {
        case .spanish: return "Buen equilibrio en tus métricas de descanso"
        case .english: return "You’re in a good range for rest metrics"
        }
    }

    var sleepDetailRowTotal: String {
        switch self {
        case .spanish: return "Sueño total"
        case .english: return "Total sleep"
        }
    }

    var sleepDetailRowRestorative: String {
        switch self {
        case .spanish: return "Sueño reparador"
        case .english: return "Restorative sleep"
        }
    }

    var sleepDetailRowContinuity: String {
        switch self {
        case .spanish: return "Continuidad"
        case .english: return "Continuity"
        }
    }

    var sleepDetailRowEfficiency: String {
        switch self {
        case .spanish: return "Eficiencia"
        case .english: return "Efficiency"
        }
    }

    var sleepDetailRowRegularity: String {
        switch self {
        case .spanish: return "Regularidad"
        case .english: return "Regularity"
        }
    }

    var sleepDetailStatusAttention: String {
        switch self {
        case .spanish: return "Atención"
        case .english: return "Attention"
        }
    }

    var sleepDetailStatusNormal: String {
        switch self {
        case .spanish: return "Normal"
        case .english: return "OK"
        }
    }

    var sleepDetailStatusExcellent: String {
        switch self {
        case .spanish: return "Excelente"
        case .english: return "Great"
        }
    }

    var sleepDetailScaleAttention: String {
        switch self {
        case .spanish: return "<60"
        case .english: return "<60"
        }
    }

    var sleepDetailScaleNormal: String {
        switch self {
        case .spanish: return "60–85"
        case .english: return "60–85"
        }
    }

    var sleepDetailScaleExcellent: String {
        switch self {
        case .spanish: return ">85"
        case .english: return ">85"
        }
    }

    var sleepDetailPhaseAwake: String {
        switch self {
        case .spanish: return "Vigilia"
        case .english: return "Awake"
        }
    }

    var sleepDetailPhaseREM: String {
        switch self { case .spanish: return "REM"; case .english: return "REM" }
    }

    var sleepDetailPhaseCore: String {
        switch self {
        case .spanish: return "Esencial"
        case .english: return "Core"
        }
    }

    var sleepDetailPhaseDeep: String {
        switch self {
        case .spanish: return "Profundo"
        case .english: return "Deep"
        }
    }

    var sleepDetailProportion: String {
        switch self {
        case .spanish: return "Proporción"
        case .english: return "Share"
        }
    }

    var sleepDetailMetaGoalHours: String {
        switch self {
        case .spanish: return "Meta"
        case .english: return "Goal"
        }
    }

    // MARK: Sleep detail — sheets (copy)

    var sleepDetailSheetTotalTitle: String {
        switch self { case .spanish: return "Sueño total"; case .english: return "Total sleep" }
    }

    var sleepDetailSheetTotalBody: String {
        switch self {
        case .spanish:
            return "El sueño total es la base de la calidad. Incluye las fases que Apple Health registro como profundo, REM y ligero. Para adultos suele recomendarse alrededor de 7 a 9 h; dormir poco afecta la recuperación y el rendimiento."
        case .english:
            return "Total sleep is the foundation. It’s the sum of the stages Health recorded as deep, REM, and light. Most adults are advised to aim for roughly 7–9 hours. Too little sleep can hurt recovery and performance."
        }
    }

    var sleepDetailSheetRestorativeTitle: String {
        switch self { case .spanish: return "Sueño reparador"; case .english: return "Restorative sleep" }
    }

    var sleepDetailSheetRestorativeBody: String {
        switch self {
        case .spanish:
            return "Suma el sueño profundo y REM dentro de la ventana. Son las fases más vinculadas a recuperación física y memoria. El porcentaje se calcula sobre el tiempo total de sueño detectado."
        case .english:
            return "This adds deep and REM time within the session—stages most tied to physical recovery and memory. The share is the fraction of your detected total sleep time."
        }
    }

    var sleepDetailSheetContinuityTitle: String {
        switch self { case .spanish: return "Continuidad"; case .english: return "Continuity" }
    }

    var sleepDetailSheetContinuityBody: String {
        switch self {
        case .spanish:
            return "La continuidad mide interrupciones: más vigilia en la noche y más episodios suelen bajar el score. Cuartos frescos y rutinas fijas al acostarse ayudan; evita mucha cafeína o pantallas cerca de dormir."
        case .english:
            return "Continuity looks at how fragmented the night is—more time awake and more episodes usually lower the score. A cool, dark room and a steady wind‑down help; go easy on caffeine and screens before bed."
        }
    }

    var sleepDetailSheetEfficiencyTitle: String {
        switch self { case .spanish: return "Eficiencia"; case .english: return "Efficiency" }
    }

    var sleepDetailSheetEfficiencyBody: String {
        switch self {
        case .spanish:
            return "Eficiencia = tiempo de sueño detectado / tiempo en cama aprox. (duración reloj de la sesión en HealthKit). Si el dispositivo no informa fases, puede mostrarse “—”."
        case .english:
            return "Efficiency is detected sleep time divided by approximate time in bed (clock time of the session from HealthKit). If staging is missing, you may see “—”."
        }
    }

    var sleepDetailSheetRegularityTitle: String {
        switch self { case .spanish: return "Regularidad"; case .english: return "Regularity" }
    }

    var sleepDetailSheetRegularityBody: String {
        switch self {
        case .spanish:
            return "Mide qué tan cerca te acercas al horario de cama y de despertar en tu perfil. Más fiel al horario, mejor la puntuación. Es independiente de la “calidad de sueño” de las fases."
        case .english:
            return "This is how close your actual sleep times are to the sleep and wake times in your profile. Sticking to a regular schedule usually raises the score, separate from the stage‑based sleep quality."
        }
    }

    var sleepDetailMoreInfo: String {
        switch self { case .spanish: return "Más información"; case .english: return "More info" }
    }

    var homeMetricHRV: String {
        switch self {
        case .spanish: return "HRV"
        case .english: return "HRV"
        }
    }

    var homeMetricRHR: String {
        switch self {
        case .spanish: return "FC reposo"
        case .english: return "Resting HR"
        }
    }

    var homeMetricSleepScore: String {
        switch self {
        case .spanish: return "Score de sueño"
        case .english: return "Sleep score"
        }
    }

    var homeMetricConfidence: String {
        switch self {
        case .spanish: return "Confianza"
        case .english: return "Confidence"
        }
    }

    var homeMetricSteps: String {
        switch self {
        case .spanish: return "Pasos"
        case .english: return "Steps"
        }
    }

    var homeMetricActiveCalories: String {
        switch self {
        case .spanish: return "Calorías activas"
        case .english: return "Active calories"
        }
    }

    /// Etiqueta corta antes del valor objetivo (pasos/kcal) en el detalle de actividad.
    var homeActivityGoalShort: String {
        switch self {
        case .spanish: return "Meta"
        case .english: return "Goal"
        }
    }

    // MARK: Home — transparency / definitions (inline)

    var homeWhatItMeans: String {
        switch self {
        case .spanish: return "Qué significa"
        case .english: return "What it means"
        }
    }

    // Recovery definitions
    var homeRecoveryWhatItMeansIntro: String {
        switch self {
        case .spanish: return "Esto es lo que usamos para estimar tu recuperación. Si algo sale como “—”, es porque Apple Health no registró suficiente información."
        case .english: return "These are the signals we use to estimate recovery. If you see “—”, it means Apple Health didn’t record enough data."
        }
    }

    var homeDefinitionHRVTitle: String {
        switch self {
        case .spanish: return "HRV"
        case .english: return "HRV"
        }
    }

    var homeDefinitionHRVBody: String {
        switch self {
        case .spanish: return "Variabilidad de la frecuencia cardiaca: cambios entre latidos. En general, más alto puede indicar mejor recuperación (pero varía por persona)."
        case .english: return "Heart rate variability: changes between heart beats. Higher can suggest better recovery (but it’s personal)."
        }
    }

    var homeDefinitionRHRTitle: String {
        switch self {
        case .spanish: return "FC en reposo"
        case .english: return "Resting HR"
        }
    }

    var homeDefinitionRHRBody: String {
        switch self {
        case .spanish: return "Tu frecuencia cardiaca cuando estás en reposo. Si sube más de lo normal, a veces es señal de fatiga, estrés o poco descanso."
        case .english: return "Your heart rate at rest. If it’s higher than your usual, it can signal fatigue, stress, or poor sleep."
        }
    }

    var homeDefinitionSleepScoreTitle: String {
        switch self {
        case .spanish: return "Score de sueño"
        case .english: return "Sleep score"
        }
    }

    var homeDefinitionSleepScoreBody: String {
        switch self {
        case .spanish: return "Un resumen (0–100) de cuánto y qué tan bien dormiste. Lo calculamos con tus fases/horas de sueño registradas."
        case .english: return "A 0–100 summary of how much and how well you slept, based on sleep hours/stages recorded."
        }
    }

    var homeDefinitionConfidenceTitle: String {
        switch self {
        case .spanish: return "Confianza"
        case .english: return "Confidence"
        }
    }

    var homeDefinitionConfidenceBody: String {
        switch self {
        case .spanish: return "Qué tan segura es la app de que los datos son completos. Si hay poca señal (por ejemplo, falta sueño o HRV), la confianza baja."
        case .english: return "How sure we are the data is complete. If signals are missing (like sleep or HRV), confidence goes down."
        }
    }

    var homeDataSourceAppleHealth: String {
        switch self {
        case .spanish: return "Fuente: Apple Health (HealthKit). Esta app solo lee tus datos con permiso; no inventa valores."
        case .english: return "Source: Apple Health (HealthKit). This app only reads your data with permission; it doesn’t make values up."
        }
    }

    // Sleep definitions
    var homeSleepWhatItMeansIntro: String {
        switch self {
        case .spanish: return "Estas métricas vienen de tu sueño registrado. Si duermes sin el iPhone/Watch cerca, puede faltar información."
        case .english: return "These metrics come from your recorded sleep. If you sleep without your iPhone/Watch nearby, data may be missing."
        }
    }

    var homeDefinitionSleepTotalTitle: String {
        switch self {
        case .spanish: return "Horas dormidas"
        case .english: return "Sleep hours"
        }
    }

    var homeDefinitionSleepTotalBody: String {
        switch self {
        case .spanish: return "Tiempo total que Apple Health detectó como sueño."
        case .english: return "Total time Apple Health detected as sleep."
        }
    }

    var homeDefinitionSleepDeepTitle: String {
        switch self {
        case .spanish: return "Sueño profundo"
        case .english: return "Deep sleep"
        }
    }

    var homeDefinitionSleepDeepBody: String {
        switch self {
        case .spanish: return "Fase de sueño más reparadora para el cuerpo. No siempre se detecta en todos los dispositivos."
        case .english: return "A restorative sleep stage for the body. It may not be detected on every device."
        }
    }

    var homeDefinitionSleepREMTitle: String {
        switch self {
        case .spanish: return "Sueño REM"
        case .english: return "REM sleep"
        }
    }

    var homeDefinitionSleepREMBody: String {
        switch self {
        case .spanish: return "Fase relacionada con memoria y aprendizaje. Puede variar mucho noche a noche."
        case .english: return "A stage linked to memory and learning. It can vary a lot night to night."
        }
    }

    var homeDefinitionSleepRegularityTitle: String {
        switch self {
        case .spanish: return "Regularidad"
        case .english: return "Regularity"
        }
    }

    var homeDefinitionSleepRegularityBody: String {
        switch self {
        case .spanish: return "Qué tan parecidos fueron tus horarios de dormir/despertar comparado con tus últimos días."
        case .english: return "How consistent your sleep/wake times were compared with recent days."
        }
    }

    var homeDataSourceAppleHealthSleep: String {
        switch self {
        case .spanish: return "Fuente: sueño detectado en Apple Health (HealthKit)."
        case .english: return "Source: sleep detected in Apple Health (HealthKit)."
        }
    }

    // Activity definitions
    var homeActivityWhatItMeansIntro: String {
        switch self {
        case .spanish: return "Actividad resume tu movimiento del día. Si ves “—”, es porque no hay datos suficientes en Apple Health."
        case .english: return "Activity summarizes your daily movement. If you see “—”, Apple Health didn’t have enough data."
        }
    }

    var homeDefinitionStepsTitle: String {
        switch self {
        case .spanish: return "Pasos"
        case .english: return "Steps"
        }
    }

    var homeDefinitionStepsBody: String {
        switch self {
        case .spanish: return "Conteo de pasos detectado por tu iPhone/Watch durante el día."
        case .english: return "Step count detected by your iPhone/Watch during the day."
        }
    }

    var homeDefinitionActiveCaloriesTitle: String {
        switch self {
        case .spanish: return "Calorías activas"
        case .english: return "Active calories"
        }
    }

    var homeDefinitionActiveCaloriesBody: String {
        switch self {
        case .spanish: return "Energía estimada que gastaste al moverte (no incluye lo que gastas en reposo)."
        case .english: return "Estimated energy you burned from movement (not including resting energy)."
        }
    }

    var homeDataSourceAppleHealthActivity: String {
        switch self {
        case .spanish: return "Fuente: pasos y energía activa en Apple Health (HealthKit)."
        case .english: return "Source: steps and active energy in Apple Health (HealthKit)."
        }
    }

    func homeHeroAccessibility(score: Int, confidence: String) -> String {
        switch self {
        case .spanish: return "Recuperación \(score) de 100. \(confidence)"
        case .english: return "Recovery \(score) of 100. \(confidence)"
        }
    }

    var homeHeroLoading: String {
        switch self {
        case .spanish: return "Cargando recuperación"
        case .english: return "Loading recovery"
        }
    }

    /// Racha + puntos en Home (refuerzo tipo apps premium).
    var homeMomentumTitle: String {
        switch self {
        case .spanish: return "Tu momentum"
        case .english: return "Your momentum"
        }
    }

    func homeMomentumStreak(days: Int) -> String {
        switch self {
        case .spanish:
            if days <= 0 { return "Sin racha aún" }
            return days == 1 ? "1 día seguido" : "\(days) días seguidos"
        case .english:
            if days <= 0 { return "No streak yet" }
            return days == 1 ? "1 day streak" : "\(days)-day streak"
        }
    }

    // MARK: Sleep outlook (Home — datos locales + opcional Foundation Models)

    var sleepOutlookCardTitle: String {
        switch self {
        case .spanish: return "Perspectiva de sueño"
        case .english: return "Sleep outlook"
        }
    }

    var sleepOutlookDisclaimer: String {
        switch self {
        case .spanish:
            return "Orientación general de bienestar basada en tu historial en la app; no es consejo médico."
        case .english:
            return "General wellness guidance from your in-app history; not medical advice."
        }
    }

    var sleepOutlookAppleBadge: String {
        switch self {
        case .spanish: return "Texto asistido por Apple Intelligence"
        case .english: return "Text refined with Apple Intelligence"
        }
    }

    var sleepOutlookRefiningAccessibility: String {
        switch self {
        case .spanish: return "Refinando texto con Apple Intelligence"
        case .english: return "Refining text with Apple Intelligence"
        }
    }

    var sleepOutlookFoundationInstructions: String {
        switch self {
        case .spanish:
            return """
            Eres coach de bienestar en una app de fitness. Escribe 2–4 frases cortas en español de tono cercano y práctico.
            No des diagnósticos médicos ni menciones medicaciones. No inventes números que no aparezcan en el bloque de métricas.
            Si la banda es strained, sugiere priorizar descanso sin alarmar. Si es favorable, refuerza lo positivo sin exagerar.
            """
        case .english:
            return """
            You are a wellness coach in a fitness app. Write 2–4 short sentences in English in a friendly, practical tone.
            Do not give medical diagnoses or mention medications. Do not invent numbers absent from the metrics block.
            If the band is strained, suggest prioritizing rest without alarming. If favorable, reinforce positives without exaggerating.
            """
        }
    }

    func sleepOutlookFoundationUserPrompt(metricsBlock: String) -> String {
        switch self {
        case .spanish:
            return """
            Resume solo con estas etiquetas agregadas (no añadas cifras nuevas):
            \(metricsBlock)
            """
        case .english:
            return """
            Summarize using ONLY these aggregated tags (do not add new numbers):
            \(metricsBlock)
            """
        }
    }

    func sleepOutlookComposeTemplate(_ snapshot: SleepOutlookSnapshot) -> String {
        var parts: [String] = snapshot.facts.map { sleepOutlookSentence(for: $0) }
        parts.append(sleepOutlookBandClosing(snapshot.band))
        return parts.joined(separator: " ")
    }

    private func sleepOutlookSentence(for fact: SleepOutlookFact) -> String {
        switch self {
        case .spanish:
            switch fact {
            case .insufficientHistory(let days):
                return "Aún hay pocas noches con datos de sueño en la app (\(days) día(s)); cuando lleves más días veremos mejor las tendencias."
            case .nightsBelowGoalLast7(let count, let goal):
                if count == 0 {
                    return "En los últimos 7 días tus horas de sueño coinciden bastante con tu meta de \(Self.formatHours(goal))."
                }
                let threshold = max(5.5, goal * 0.85)
                return "\(count) de las últimas 7 noches estuvieron por debajo de \(Self.formatHours(threshold)) (menos de lo recomendado vs tu meta)."
            case .sleepHoursTrend(let diff):
                if diff >= 0.35 {
                    return "La última semana dormiste algo más de media que la semana anterior (≈+\(Self.formatHours(abs(diff))) h entre semanas)."
                }
                return "La última semana dormiste algo menos de media que la anterior (≈−\(Self.formatHours(abs(diff))) h entre semanas)."
            case .recoveryGapShortSleepVersusRested(let delta):
                return "En tu historial reciente, tras noches más cortas tu recuperación fue ~\(delta) puntos menor de media que tras noches con mejor sueño."
            case .fragmentedSleep(let score):
                return "La continuidad del sueño última fue baja (\(score)/100), lo que suele acompañar sensación de sueño menos reparador."
            }
        case .english:
            switch fact {
            case .insufficientHistory(let days):
                return "There are still few nights with sleep data in the app (\(days) day(s)); trends will be clearer as you log more."
            case .nightsBelowGoalLast7(let count, let goal):
                if count == 0 {
                    return "Over the last 7 days your sleep duration mostly aligns with your \(Self.formatHours(goal)) goal."
                }
                let threshold = max(5.5, goal * 0.85)
                return "\(count) of the last 7 nights were under \(Self.formatHours(threshold)), below what fits your goal."
            case .sleepHoursTrend(let diff):
                if diff >= 0.35 {
                    return "You slept a bit more on average last week than the prior week (≈+\(Self.formatHours(abs(diff))) h between weeks)."
                }
                return "You slept a bit less on average last week than the prior week (≈−\(Self.formatHours(abs(diff))) h between weeks)."
            case .recoveryGapShortSleepVersusRested(let delta):
                return "In recent history, recovery averaged ~\(delta) points lower after shorter nights than after better sleep nights."
            case .fragmentedSleep(let score):
                return "Last night's sleep continuity was low (\(score)/100), which often pairs with less restorative sleep."
            }
        }
    }

    private func sleepOutlookBandClosing(_ band: SleepOutlookBand) -> String {
        switch self {
        case .spanish:
            switch band {
            case .strained:
                return "Si mantienes este patrón, es probable que la recuperación siga floja; intenta proteger una noche más larga cuando puedas."
            case .neutral:
                return "Sigue observando tu sueño; pequeños ajustes de horario suelen notarse en cómo te sientes al entrenar."
            case .favorable:
                return "Con este ritmo de sueño tienes buena base para recuperarte bien; mantén la constancia."
            }
        case .english:
            switch band {
            case .strained:
                return "If this pattern continues, recovery may stay muted—try to protect a longer night when you can."
            case .neutral:
                return "Keep observing sleep patterns; small schedule tweaks often show up in how training feels."
            case .favorable:
                return "This sleep pattern supports recovery well—consistency is doing you favors."
            }
        }
    }

    private static func formatHours(_ value: Double) -> String {
        String(format: "%.1f", value)
    }

    var homeQuickTrain: String {
        switch self {
        case .spanish: return "Entrenar"
        case .english: return "Train"
        }
    }

    var homeQuickTrainHint: String {
        switch self {
        case .spanish: return "Abre la pestaña Entrenamiento"
        case .english: return "Opens the Workout tab"
        }
    }

    var homeQuickLastNight: String {
        switch self {
        case .spanish: return "Anoche"
        case .english: return "Last night"
        }
    }

    var homeQuickLastNightHint: String {
        switch self {
        case .spanish: return "Ir a sueño y contexto de anoche"
        case .english: return "Go to sleep context"
        }
    }

    var homeQuickRecoveryShort: String {
        switch self {
        case .spanish: return "Recup."
        case .english: return "Recovery"
        }
    }

    var homeQuickRecoveryHint: String {
        switch self {
        case .spanish: return "Ir a recuperación"
        case .english: return "Go to recovery"
        }
    }

    var homeQuickMovement: String {
        switch self {
        case .spanish: return "Movimiento"
        case .english: return "Activity"
        }
    }

    var homeQuickMovementHint: String {
        switch self {
        case .spanish: return "Ir a actividad"
        case .english: return "Go to activity"
        }
    }

    var homeDailySummary: String {
        switch self {
        case .spanish: return "Resumen del día"
        case .english: return "Daily summary"
        }
    }

    var homeLabelRecovery: String {
        switch self {
        case .spanish: return "Recuperación"
        case .english: return "Recovery"
        }
    }

    var homeLabelActivity: String {
        switch self {
        case .spanish: return "Actividad"
        case .english: return "Activity"
        }
    }

    var healthDeniedBanner: String {
        switch self {
        case .spanish:
            return "Salud no compartió datos. Abre Configuración → Privacidad y seguridad → Salud para permitirlo."
        case .english:
            return "Health didn’t share data. Open Settings → Privacy & Security → Health to allow access."
        }
    }

    var healthDeniedBannerA11y: String {
        switch self {
        case .spanish:
            return "Salud no compartió datos. Abre Configuración, Privacidad y seguridad, Salud, para permitir el acceso."
        case .english:
            return "Health did not share data. Open Settings, Privacy & Security, Health, to allow access."
        }
    }

    var healthUnavailableBanner: String {
        switch self {
        case .spanish: return "Salud no está disponible en este dispositivo."
        case .english: return "Health isn’t available on this device."
        }
    }

    var coachAnalyzing: String {
        switch self {
        case .spanish: return "Analizando tus datos..."
        case .english: return "Analyzing your data..."
        }
    }

    var coachLoadingA11y: String {
        switch self {
        case .spanish: return "Cargando resumen del coach"
        case .english: return "Loading coach summary"
        }
    }

    var coachHintLongMessage: String {
        switch self {
        case .spanish: return "Mensaje largo en pantalla; usa el rotor para leer línea por línea si lo necesitas."
        case .english: return "Long message on screen; use the rotor to read line by line if needed."
        }
    }

    var intensityPrefix: String {
        switch self {
        case .spanish: return "Intensidad:"
        case .english: return "Intensity:"
        }
    }

    var actionCardLoading: String {
        switch self {
        case .spanish: return "Cargando plan del día..."
        case .english: return "Loading today’s plan..."
        }
    }

    var actionCardLoadingA11y: String {
        switch self {
        case .spanish: return "Cargando tarjeta de acción"
        case .english: return "Loading action card"
        }
    }

    var recoverySectionTitle: String {
        switch self {
        case .spanish: return "Recovery"
        case .english: return "Recovery"
        }
    }

    var recoveryScoreLabel: String {
        switch self {
        case .spanish: return "Puntuación de recuperación"
        case .english: return "Recovery score"
        }
    }

    var activityScoreLabel: String {
        switch self {
        case .spanish: return "Puntuación de actividad"
        case .english: return "Activity score"
        }
    }

    func confidenceLine(_ label: String) -> String {
        switch self {
        case .spanish: return "Confianza: \(label)"
        case .english: return "Confidence: \(label)"
        }
    }

    func confidenceA11y(_ label: String) -> String {
        switch self {
        case .spanish: return "Confianza del recovery: \(label)"
        case .english: return "Recovery confidence: \(label)"
        }
    }

    var details: String {
        switch self {
        case .spanish: return "Detalles"
        case .english: return "Details"
        }
    }

    var lastNightSection: String {
        switch self {
        case .spanish: return "Anoche"
        case .english: return "Last night"
        }
    }

    var sleepDetailsDisclosure: String {
        switch self {
        case .spanish: return "Ver detalles (Apple Health)"
        case .english: return "See details (Apple Health)"
        }
    }

    var sleepMedicalDisclaimer: String {
        switch self {
        case .spanish:
            return "La FC y el HRV se comparan con tu media de 14 días. No sustituye consejo médico."
        case .english:
            return "RHR and HRV are compared to your 14‑day average. Not medical advice."
        }
    }

    var glossaryTitle: String {
        switch self {
        case .spanish: return "Glosario rápido"
        case .english: return "Quick glossary"
        }
    }

    var glossarySleep: String {
        switch self {
        case .spanish:
            return "Sueño (intervalo): tramo fusionado de Apple Health; puede no coincidir con tu hora de acostarte."
        case .english:
            return "Sleep (interval): merged window from Apple Health; may not match when you went to bed."
        }
    }

    var glossaryHRV: String {
        switch self {
        case .spanish: return "HRV: variabilidad entre latidos; suele subir con mejor recuperación."
        case .english: return "HRV: beat‑to‑beat variability; often higher with better recovery."
        }
    }

    var glossaryRHR: String {
        switch self {
        case .spanish:
            return "FC en reposo: valor del día; a veces se alinea con una ventana algo más amplia que el sueño."
        case .english:
            return "Resting HR: daily value; sometimes aligned to a slightly wider window than sleep."
        }
    }

    var glossaryRegularity: String {
        switch self {
        case .spanish:
            return "Regularidad: qué tan cerca quedaron el inicio y el fin de tu sueño del horario guardado en Perfil (promedio de desviación vs acostarte/despertar)."
        case .english:
            return "Regularity: how close sleep start/end were to the schedule saved in Profile (avg. deviation vs bedtime/wake)."
        }
    }

    var recoveryEmptyDetails: String {
        switch self {
        case .spanish:
            return "Aún no hay detalles disponibles para Recovery. Con más datos (especialmente sueño) esta sección se completa automáticamente."
        case .english:
            return "No recovery details yet. With more data (especially sleep) this section fills in automatically."
        }
    }

    func insightProgressA11y(metric: String, percent: Int) -> String {
        switch self {
        case .spanish: return "Progreso de \(metric): \(percent) por ciento"
        case .english: return "\(metric) progress: \(percent) percent"
        }
    }

    var pointsWord: String {
        switch self {
        case .spanish: return "puntos"
        case .english: return "points"
        }
    }

    func pointsA11y(_ n: Int) -> String {
        switch self {
        case .spanish: return "\(n) puntos"
        case .english: return "\(n) points"
        }
    }

    var detoxMode: String {
        switch self {
        case .spanish: return "Modo detox"
        case .english: return "Detox mode"
        }
    }

    func detoxDay(_ day: Int) -> String {
        switch self {
        case .spanish: return "Día \(day) de 7"
        case .english: return "Day \(day) of 7"
        }
    }

    func detoxA11y(day: Int) -> String {
        switch self {
        case .spanish: return "Modo detox, día \(day) de 7"
        case .english: return "Detox mode, day \(day) of 7"
        }
    }

    var goToWorkout: String {
        switch self {
        case .spanish: return "Ir a entrenar"
        case .english: return "Go to workout"
        }
    }

    var recoveryHistoryTitle: String {
        switch self {
        case .spanish: return "Historial reciente (recuperación)"
        case .english: return "Recent recovery"
        }
    }

    /// Título de la tarjeta de barras (estilo progreso semanal).
    var homeRecoveryWeeklyProgressTitle: String {
        switch self {
        case .spanish: return "Progreso semanal"
        case .english: return "Weekly progress"
        }
    }

    var homeRecoveryLast7Days: String {
        switch self {
        case .spanish: return "Últimos 7 días"
        case .english: return "Last 7 days"
        }
    }

    func recoveryHistoryChipA11y(weekday: String, score: Int) -> String {
        switch self {
        case .spanish: return "\(weekday), recuperación \(score)"
        case .english: return "\(weekday), recovery \(score)"
        }
    }

    func recoveryHistoryBarA11y(weekday: String, score: Int, isToday: Bool, hasData: Bool) -> String {
        switch self {
        case .spanish:
            let dayTag = isToday ? "Hoy" : weekday
            if hasData {
                return "\(dayTag), recuperación \(score) de 100"
            }
            return "\(dayTag), sin datos de recuperación guardados"
        case .english:
            let dayTag = isToday ? "Today" : weekday
            if hasData {
                return "\(dayTag), recovery \(score) out of 100"
            }
            return "\(dayTag), no saved recovery data"
        }
    }

    // MARK: - Workout tab

    var workoutNavTitle: String {
        switch self {
        case .spanish: return "Entrenamiento"
        case .english: return "Workout"
        }
    }

    var workoutSurfacePicker: String {
        switch self {
        case .spanish: return "Vista"
        case .english: return "View"
        }
    }

    var workoutSurfacePlan: String {
        switch self {
        case .spanish: return "Plan guiado"
        case .english: return "Guided plan"
        }
    }

    var workoutSurfaceRoutine: String {
        switch self {
        case .spanish: return "Mi rutina"
        case .english: return "My routine"
        }
    }

    var workoutSurfacePickerA11y: String {
        switch self {
        case .spanish: return "Elegir entre plan guiado o mi rutina"
        case .english: return "Choose guided plan or my routine"
        }
    }

    // MARK: Workout dashboard (rings + chart)

    var workoutRingWeek: String {
        switch self {
        case .spanish: return "Semana"
        case .english: return "Week"
        }
    }

    var workoutRingWeekSubtitle: String {
        switch self {
        case .spanish: return "Días del plan hechos"
        case .english: return "Plan days done"
        }
    }

    var workoutRingWeekInfo: String {
        switch self {
        case .spanish:
            return "Cuenta cuántos días del plan guiado ya completaste esta semana del plan. Ejemplo: 1/4 significa “ya hice 1 de 4 días de entreno”."
        case .english:
            return "Counts how many guided plan days you’ve completed in the plan’s current week. Example: 1/4 means “I’ve done 1 of 4 training days”."
        }
    }

    var workoutRingRoutine: String {
        switch self {
        case .spanish: return "Rutina"
        case .english: return "Routine"
        }
    }

    var workoutRingRoutineSubtitle: String {
        switch self {
        case .spanish: return "Días de rutina hechos"
        case .english: return "Routine days done"
        }
    }

    var workoutRingRoutineInfo: String {
        switch self {
        case .spanish:
            return "Cuenta cuántos días de «Mi rutina» completaste esta semana. Ejemplo: 2/5 significa “hice 2 de 5 días de rutina”."
        case .english:
            return "Counts how many “My routine” days you completed this week. Example: 2/5 means “I did 2 of 5 routine days”."
        }
    }

    var workoutRingVolume: String {
        switch self {
        case .spanish: return "Volumen"
        case .english: return "Volume"
        }
    }

    var workoutRingVolumeSubtitle: String {
        switch self {
        case .spanish: return "Series esta semana"
        case .english: return "Sets this week"
        }
    }

    var workoutRingVolumeInfo: String {
        switch self {
        case .spanish:
            return "Series que ya registraste esta semana / series que el plan esperaba para esta semana. (Una serie = un set)."
        case .english:
            return "Sets you logged this week / sets your plan expected for this week. (A set = one set)."
        }
    }

    var workoutRingToday: String {
        switch self {
        case .spanish: return "Hoy"
        case .english: return "Today"
        }
    }

    var workoutRingTodaySubtitle: String {
        switch self {
        case .spanish: return "Series hoy"
        case .english: return "Sets today"
        }
    }

    var workoutRingTodayInfo: String {
        switch self {
        case .spanish:
            return "Series que ya llevas hoy / series que el plan esperaba para hoy. (Una serie = un set)."
        case .english:
            return "Sets you’ve logged today / sets your plan expected for today. (A set = one set)."
        }
    }

    var workoutVolumeTrendTitle: String {
        switch self {
        case .spanish: return "Volumen (semanal)"
        case .english: return "Volume (weekly)"
        }
    }

    /// Bajo el título de la gráfica cuando la superficie es Mi rutina (el tonelaje sigue siendo global).
    var workoutVolumeTrendRoutineSubtitle: String {
        switch self {
        case .spanish: return "Incluye entrenos del plan guiado y de Mi rutina (todos tus registros)."
        case .english: return "Includes guided plan and My routine workouts (all your logs)."
        }
    }

    var workoutVolumeTrendEmpty: String {
        switch self {
        case .spanish: return "Completa entrenos para ver tu progreso aquí."
        case .english: return "Complete workouts to see your progress here."
        }
    }

    var workoutVolumeInfoTitle: String {
        switch self {
        case .spanish: return "¿Qué es Volumen?"
        case .english: return "What is Volume?"
        }
    }

    var workoutVolumeInfoBody: String {
        switch self {
        case .spanish:
            return "Volumen aquí significa trabajo total (tonnage): suma de (peso en kg × repeticiones) de todas tus series registradas.\\n\\nEjemplo: 60 kg × 10 reps × 4 series = 2400.\\n\\nEsta gráfica es semanal y combina tanto el Plan guiado como Mi rutina porque se calcula desde tus registros (WorkoutLog)."
        case .english:
            return "Volume here means total work (tonnage): sum of (weight in kg × reps) for all your logged sets.\\n\\nExample: 60 kg × 10 reps × 4 sets = 2400.\\n\\nThis chart is weekly and includes both the guided plan and your routine because it is calculated from your logs (WorkoutLog)."
        }
    }

    var workoutEditRoutine: String {
        switch self {
        case .spanish: return "Editar rutina"
        case .english: return "Edit routine"
        }
    }

    var workoutCreateRoutine: String {
        switch self {
        case .spanish: return "Crear rutina"
        case .english: return "Create routine"
        }
    }

    var workoutNewPlan: String {
        switch self {
        case .spanish: return "Nuevo plan"
        case .english: return "New plan"
        }
    }

    var moreOptions: String {
        switch self {
        case .spanish: return "Más opciones"
        case .english: return "More options"
        }
    }

    var workoutEmptyTitle: String {
        switch self {
        case .spanish: return "Sin contenido"
        case .english: return "No content"
        }
    }

    var workoutEmptySubtitle: String {
        switch self {
        case .spanish: return "Crea un plan o configura tu rutina."
        case .english: return "Create a plan or set up your routine."
        }
    }

    var workoutCreateMyRoutine: String {
        switch self {
        case .spanish: return "Crear Mi rutina"
        case .english: return "Create My routine"
        }
    }

    var workoutBannerAlsoRoutineTitle: String {
        switch self {
        case .spanish: return "También tienes Mi rutina"
        case .english: return "You also have My routine"
        }
    }

    var workoutBannerAlsoRoutineBody: String {
        switch self {
        case .spanish: return "Ejercicios, descansos y sustitutos bajo tu control."
        case .english: return "Exercises, rest, and swaps under your control."
        }
    }

    var workoutBannerBackToPlanTitle: String {
        switch self {
        case .spanish: return "Volver al plan guiado"
        case .english: return "Back to guided plan"
        }
    }

    var workoutBannerBackToPlanBody: String {
        switch self {
        case .spanish: return "Semanas, fases y días bloqueados como antes."
        case .english: return "Weeks, phases, and scheduled days as before."
        }
    }

    var workoutOptionalPlanTitle: String {
        switch self {
        case .spanish: return "Plan opcional"
        case .english: return "Optional plan"
        }
    }

    var workoutOptionalPlanBody: String {
        switch self {
        case .spanish:
            return "Metas, prioridades y duración en semanas. Puedes entrenar solo con Mi rutina o combinar ambos."
        case .english:
            return "Goals, priorities, and length in weeks. Train with My routine only or combine both."
        }
    }

    var workoutCreateTrainingPlan: String {
        switch self {
        case .spanish: return "Crear plan de entrenamiento"
        case .english: return "Create training plan"
        }
    }

    var workoutMyRoutineHeader: String {
        switch self {
        case .spanish: return "Mi rutina"
        case .english: return "My routine"
        }
    }

    func workoutRoutineWeekSummary(days: Int, exercises: Int) -> String {
        switch self {
        case .spanish:
            return "\(days) días de entreno · \(exercises) ejercicios en la semana"
        case .english:
            return "\(days) training days · \(exercises) exercises this week"
        }
    }

    var workoutRoutineDoneTitle: String {
        switch self {
        case .spanish: return "Entreno de Mi rutina hecho"
        case .english: return "My routine workout done"
        }
    }

    var workoutRoutineDoneBody: String {
        switch self {
        case .spanish: return "Hoy ya registraste este día. Mañana podrás volver a empezarlo."
        case .english: return "You already logged this day today. You can start it again tomorrow."
        }
    }

    var workoutRoutineDayMissing: String {
        switch self {
        case .spanish: return "No se encontró el día en la rutina."
        case .english: return "Routine day not found."
        }
    }

    var workoutTodayTrainTitle: String {
        switch self {
        case .spanish: return "Hoy toca entrenar"
        case .english: return "Train today"
        }
    }

    var workoutTodayTrainBody: String {
        switch self {
        case .spanish: return "Este día no tiene ejercicios. Añádelos desde Editar rutina."
        case .english: return "This day has no exercises. Add them from Edit routine."
        }
    }

    var workoutAddExercises: String {
        switch self {
        case .spanish: return "Añadir ejercicios"
        case .english: return "Add exercises"
        }
    }

    var workoutTodayInRoutine: String {
        switch self {
        case .spanish: return "Hoy en tu rutina"
        case .english: return "Today in your routine"
        }
    }

    var workoutExercisesWord: String {
        switch self {
        case .spanish: return "ejercicios"
        case .english: return "exercises"
        }
    }

    func workoutMoreExercises(_ n: Int) -> String {
        switch self {
        case .spanish: return "+\(n) más"
        case .english: return "+\(n) more"
        }
    }

    var workoutStart: String {
        switch self {
        case .spanish: return "Empezar entreno"
        case .english: return "Start workout"
        }
    }

    var workoutThisWeek: String {
        switch self {
        case .spanish: return "Esta semana"
        case .english: return "This week"
        }
    }

    func weekProgressText(current: Int, total: Int) -> String {
        switch self {
        case .spanish: return "Semana \(current) / \(total)"
        case .english: return "Week \(current) / \(total)"
        }
    }

    var phaseBase: String {
        switch self {
        case .spanish: return "Semana base"
        case .english: return "Base week"
        }
    }

    var phaseWeight5: String {
        switch self {
        case .spanish: return "+5% peso"
        case .english: return "+5% weight"
        }
    }

    var phaseVolume10: String {
        switch self {
        case .spanish: return "+10% volumen"
        case .english: return "+10% volume"
        }
    }

    var phaseDeload: String {
        switch self {
        case .spanish: return "Semana descarga"
        case .english: return "Deload week"
        }
    }

    var workoutTodayCard: String {
        switch self {
        case .spanish: return "Entreno de hoy"
        case .english: return "Today’s workout"
        }
    }

    func workoutNextDay(_ weekday: String) -> String {
        switch self {
        case .spanish: return "Siguiente — \(weekday)"
        case .english: return "Next — \(weekday)"
        }
    }

    var workoutSkipToday: String {
        switch self {
        case .spanish: return "Saltar hoy"
        case .english: return "Skip today"
        }
    }

    var workoutReschedule: String {
        switch self {
        case .spanish: return "Reprogramar"
        case .english: return "Reschedule"
        }
    }

    var workoutRestDayTitle: String {
        switch self {
        case .spanish: return "Día de descanso"
        case .english: return "Rest day"
        }
    }

    var workoutRestDayBody: String {
        switch self {
        case .spanish: return "Recupera bien; el crecimiento ocurre también fuera del gimnasio."
        case .english: return "Recover well—growth happens outside the gym too."
        }
    }

    var workoutTodayDoneTitle: String {
        switch self {
        case .spanish: return "Entreno de hoy hecho"
        case .english: return "Today’s workout done"
        }
    }

    var workoutNoTrainingTodayTitle: String {
        switch self {
        case .spanish: return "Hoy no toca entreno"
        case .english: return "No workout today"
        }
    }

    var workoutNoTrainingTodayBody: String {
        switch self {
        case .spanish: return "El siguiente día de entreno aparece abajo en la semana."
        case .english: return "Your next training day is shown below in the week."
        }
    }

    var workoutLockedTitle: String {
        switch self {
        case .spanish: return "Entreno bloqueado"
        case .english: return "Workout locked"
        }
    }

    var workoutLockedBody: String {
        switch self {
        case .spanish: return "Saltaste el entreno de hoy. Mañana podrás seguir con el plan."
        case .english: return "You skipped today’s workout. You can continue the plan tomorrow."
        }
    }

    var workoutWeekCompleteCelebration: String {
        switch self {
        case .spanish: return "¡Semana completada!"
        case .english: return "Week complete!"
        }
    }

    var workoutWeekNoMore: String {
        switch self {
        case .spanish: return "No quedan entrenos esta semana"
        case .english: return "No more workouts this week"
        }
    }

    var workoutWeekCompleteBody: String {
        switch self {
        case .spanish: return "Buen trabajo con el plan."
        case .english: return "Nice work on the plan."
        }
    }

    var workoutWeekNoMoreBody: String {
        switch self {
        case .spanish: return "Aún puedes revisar la semana que viene."
        case .english: return "You can still review next week."
        }
    }

    /// Abreviatura de día 1...7 (Lun–Dom / Mon–Sun).
    func shortWeekday(_ dayOfWeek: Int) -> String {
        let labels: [String]
        switch self {
        case .spanish:
            labels = ["Lun", "Mar", "Mié", "Jue", "Vie", "Sáb", "Dom"]
        case .english:
            labels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        }
        guard dayOfWeek >= 1, dayOfWeek <= 7 else { return "?" }
        return labels[dayOfWeek - 1]
    }

    // MARK: - Stats

    var statsNavTitle: String {
        switch self {
        case .spanish: return "Estadísticas"
        case .english: return "Statistics"
        }
    }

    func statsLevel(_ n: Int) -> String {
        switch self {
        case .spanish: return "Nivel \(n)"
        case .english: return "Level \(n)"
        }
    }

    var statsPRSection: String {
        switch self {
        case .spanish: return "Récords personales (PR)"
        case .english: return "Personal records (PR)"
        }
    }

    var statsPREmpty: String {
        switch self {
        case .spanish:
            return "Cuando mejores tu mejor e1RM estimado en un ejercicio, aparecerá aquí."
        case .english:
            return "When you beat your best estimated 1RM on an exercise, it will show up here."
        }
    }

    var statsHistorySection: String {
        switch self {
        case .spanish: return "Historial de sesiones"
        case .english: return "Session history"
        }
    }

    var statsHistoryEmpty: String {
        switch self {
        case .spanish:
            return "Aún no hay entrenos registrados. Completa series desde Entrenamiento."
        case .english:
            return "No workouts logged yet. Complete sets from the Workout tab."
        }
    }

    func statsSetsVolumeLine(sets: Int, volume: String) -> String {
        switch self {
        case .spanish: return "\(sets) series · \(volume)"
        case .english: return "\(sets) sets · \(volume)"
        }
    }

    var statsBadges: String {
        switch self {
        case .spanish: return "Insignias"
        case .english: return "Badges"
        }
    }

    var statsBadgesEmpty: String {
        switch self {
        case .spanish: return "Aún no tienes insignias. ¡Sigue entrenando!"
        case .english: return "No badges yet—keep training!"
        }
    }

    var statsStreakCurrent: String {
        switch self {
        case .spanish: return "Racha actual"
        case .english: return "Current streak"
        }
    }

    var statsStreakBest: String {
        switch self {
        case .spanish: return "Mejor racha"
        case .english: return "Best streak"
        }
    }

    func statsStreakA11y(title: String, value: Int) -> String {
        switch self {
        case .spanish: return "\(title): \(value) días"
        case .english: return "\(title): \(value) days"
        }
    }

    var sessionDetailTitle: String {
        switch self {
        case .spanish: return "Detalle"
        case .english: return "Detail"
        }
    }

    var sessionExercise: String {
        switch self {
        case .spanish: return "Ejercicio"
        case .english: return "Exercise"
        }
    }

    var sessionDate: String {
        switch self {
        case .spanish: return "Fecha"
        case .english: return "Date"
        }
    }

    var sessionSetsSection: String {
        switch self {
        case .spanish: return "Series"
        case .english: return "Sets"
        }
    }

    func sessionSetRow(_ n: Int) -> String {
        switch self {
        case .spanish: return "Serie \(n)"
        case .english: return "Set \(n)"
        }
    }

    var volumeInfoA11y: String {
        switch self {
        case .spanish: return "¿Qué significa carga total?"
        case .english: return "What is total load?"
        }
    }

    var volumeInfoTitle: String {
        switch self {
        case .spanish: return "¿Qué es “carga total”?"
        case .english: return "What is “total load”?"
        }
    }

    var volumeInfoBody: String {
        switch self {
        case .spanish:
            return "Es la suma de (kg × reps) de cada serie.\n\nEjemplo: 20×10 + 20×8 = 360.\n\nSirve para comparar el volumen de trabajo entre sesiones."
        case .english:
            return "It’s the sum of (kg × reps) for each set.\n\nExample: 20×10 + 20×8 = 360.\n\nUse it to compare training volume between sessions."
        }
    }

    var prDetailTitle: String {
        switch self {
        case .spanish: return "PR"
        case .english: return "PR"
        }
    }

    var prFeaturedSet: String {
        switch self {
        case .spanish: return "Serie destacada"
        case .english: return "Featured set"
        }
    }

    func badgeA11y(_ name: String) -> String {
        switch self {
        case .spanish: return "Insignia: \(name)"
        case .english: return "Badge: \(name)"
        }
    }
}

// MARK: - Onboarding (3 pasos)

extension AppLanguage {

    // MARK: Onboarding — común

    func onboardingStepCaption(_ step: Int) -> String {
        switch self {
        case .spanish: return "Paso \(step) de 3"
        case .english: return "Step \(step) of 3"
        }
    }

    var onboardingContinue: String {
        switch self {
        case .spanish: return "Continuar"
        case .english: return "Continue"
        }
    }

    var onboardingBack: String {
        switch self {
        case .spanish: return "Atrás"
        case .english: return "Back"
        }
    }

    var onboardingKeyboardDone: String {
        switch self {
        case .spanish: return "Hecho"
        case .english: return "Done"
        }
    }

    var onboardingSaveFailed: String {
        switch self {
        case .spanish: return "No se pudo guardar tu perfil. Intenta de nuevo."
        case .english: return "We couldn't save your profile. Please try again."
        }
    }

    // MARK: Onboarding — paso 1 «Tú»

    var onboardingYouTitle: String {
        switch self {
        case .spanish: return "Empecemos\npor ti"
        case .english: return "Let's start\nwith you"
        }
    }

    var onboardingNameCaption: String {
        switch self {
        case .spanish: return "Cómo te llamas"
        case .english: return "Your name"
        }
    }

    var onboardingNamePlaceholder: String {
        switch self {
        case .spanish: return "Tu nombre"
        case .english: return "Your name"
        }
    }

    var onboardingGoalCaption: String {
        switch self {
        case .spanish: return "Qué buscas"
        case .english: return "What you're after"
        }
    }

    // MARK: Onboarding — paso 2 «Tu cuerpo»

    var onboardingBodyTitle: String {
        switch self {
        case .spanish: return "Tu cuerpo"
        case .english: return "Your body"
        }
    }

    var onboardingBodySubtitle: String {
        switch self {
        case .spanish:
            return "Peso y altura ajustan la intensidad. Apple Health también nos da sueño y pulso para tu score de recuperación."
        case .english:
            return "Weight and height tune your intensity. Apple Health also gives us sleep and heart rate for your recovery score."
        }
    }

    var onboardingHealthCardTitle: String {
        switch self {
        case .spanish: return "Conectar Apple Health"
        case .english: return "Connect Apple Health"
        }
    }

    var onboardingHealthCardSubtitle: String {
        switch self {
        case .spanish: return "Rellena peso y altura al instante"
        case .english: return "Fills in weight and height instantly"
        }
    }

    var onboardingHealthConnect: String {
        switch self {
        case .spanish: return "Conectar"
        case .english: return "Connect"
        }
    }

    var onboardingHealthConnected: String {
        switch self {
        case .spanish: return "Apple Health conectado"
        case .english: return "Apple Health connected"
        }
    }

    var onboardingHealthNotConnected: String {
        switch self {
        case .spanish: return "Apple Health sin conectar"
        case .english: return "Apple Health not connected"
        }
    }

    var onboardingHealthImported: String {
        switch self {
        case .spanish: return "Importado de Apple Health"
        case .english: return "Imported from Apple Health"
        }
    }

    var onboardingOrTypeIt: String {
        switch self {
        case .spanish: return "o escríbelo"
        case .english: return "or type it"
        }
    }

    var onboardingWeightCaption: String {
        switch self {
        case .spanish: return "Peso"
        case .english: return "Weight"
        }
    }

    var onboardingHeightCaption: String {
        switch self {
        case .spanish: return "Altura"
        case .english: return "Height"
        }
    }

    var onboardingLater: String {
        switch self {
        case .spanish: return "Prefiero hacerlo después"
        case .english: return "I'd rather do it later"
        }
    }

    // MARK: Onboarding — paso 3 «Listo»

    func onboardingDoneTitle(_ name: String) -> String {
        switch self {
        case .spanish: return "Listo, \(name)"
        case .english: return "All set, \(name)"
        }
    }

    var onboardingDoneSubtitle: String {
        switch self {
        case .spanish: return "Tu plan de fuerza empieza hoy. Puedes cambiar todo esto en Ajustes."
        case .english: return "Your strength plan starts today. You can change all of this in Settings."
        }
    }

    var onboardingChange: String {
        switch self {
        case .spanish: return "Cambiar"
        case .english: return "Change"
        }
    }

    var onboardingNoMetrics: String {
        switch self {
        case .spanish: return "Sin peso ni altura"
        case .english: return "No weight or height"
        }
    }

    var onboardingSleepTitle: String {
        switch self {
        case .spanish: return "Horario de sueño"
        case .english: return "Sleep schedule"
        }
    }

    var onboardingSleepAccuracy: String {
        switch self {
        case .spanish: return "mejora la precisión del score"
        case .english: return "improves score accuracy"
        }
    }

    var onboardingSleepNote: String {
        switch self {
        case .spanish: return "Si lo activas usamos esas horas por defecto; puedes afinarlas más tarde."
        case .english: return "If you turn it on we'll use those hours by default; you can fine-tune them later."
        }
    }

    var onboardingStart: String {
        switch self {
        case .spanish: return "Empezar a entrenar"
        case .english: return "Start training"
        }
    }
}

// MARK: - FitnessGoal display (rawValue stays English for persistence)

extension FitnessGoal {
    func displayName(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.loseWeight, .spanish): return "Perder peso"
        case (.loseWeight, .english): return "Lose weight"
        case (.gainMuscle, .spanish): return "Ganar músculo"
        case (.gainMuscle, .english): return "Gain muscle"
        case (.beHealthy, .spanish): return "Salud"
        case (.beHealthy, .english): return "Be healthy"
        }
    }

    /// Copy del onboarding, más concreta que `displayName` («Perder grasa» en
    /// lugar de «Perder peso»). Solo presentación: el `rawValue` no cambia.
    func onboardingLabel(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.loseWeight, .spanish): return "Perder grasa"
        case (.loseWeight, .english): return "Lose fat"
        case (.gainMuscle, .spanish): return "Ganar músculo"
        case (.gainMuscle, .english): return "Gain muscle"
        case (.beHealthy, .spanish): return "Estar sano"
        case (.beHealthy, .english): return "Stay healthy"
        }
    }
}

// MARK: - FitnessLevel

extension FitnessLevel {
    func displayName(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.beginner, .spanish): return "Principiante"
        case (.beginner, .english): return "Beginner"
        case (.intermediate, .spanish): return "Intermedio"
        case (.intermediate, .english): return "Intermediate"
        case (.advanced, .spanish): return "Avanzado"
        case (.advanced, .english): return "Advanced"
        }
    }
}

// MARK: - MuscleGroup

extension MuscleGroup {
    func displayName(_ language: AppLanguage) -> String {
        switch (self, language) {
        case (.chest, .spanish): return "Pecho"
        case (.chest, .english): return "Chest"
        case (.back, .spanish): return "Espalda"
        case (.back, .english): return "Back"
        case (.shoulders, .spanish): return "Hombros"
        case (.shoulders, .english): return "Shoulders"
        case (.biceps, .spanish): return "Bíceps"
        case (.biceps, .english): return "Biceps"
        case (.triceps, .spanish): return "Tríceps"
        case (.triceps, .english): return "Triceps"
        case (.quads, .spanish): return "Cuádriceps"
        case (.quads, .english): return "Quads"
        case (.hamstrings, .spanish): return "Isquiotibiales"
        case (.hamstrings, .english): return "Hamstrings"
        case (.glutes, .spanish): return "Glúteos"
        case (.glutes, .english): return "Glutes"
        case (.calves, .spanish): return "Gemelos"
        case (.calves, .english): return "Calves"
        case (.core, .spanish): return "Core"
        case (.core, .english): return "Core"
        }
    }
}
