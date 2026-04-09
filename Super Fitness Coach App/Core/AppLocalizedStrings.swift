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

    func recoveryHistoryChipA11y(weekday: String, score: Int) -> String {
        switch self {
        case .spanish: return "\(weekday), recuperación \(score)"
        case .english: return "\(weekday), recovery \(score)"
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
