import Foundation
import HealthKit

struct SleepDetectionResult: Equatable {
    let sleepDetected: Bool
    let sessionStart: Date?
    let sessionEnd: Date?
    let totalSleepHours: Double?
    let deepSleepHours: Double?
    let remSleepHours: Double?
    let sleepConfidence: Double        // [0.0, 1.0]
    let sleepConsistencyScore: Int     // [0, 100] — regularidad vs horario meta (independiente del score de calidad)
    /// Duración reloj de la sesión elegida (fin − inicio del intervalo `best`), para relación con vigilia.
    let sessionWallDuration: TimeInterval?
    /// Suma de tramos `awake` de HealthKit recortados a la sesión (fragmentación nocturna).
    let awakeSecondsDuringSession: TimeInterval?
    /// Número de bloques de vigilia fusionados (pausas) dentro de la sesión.
    let awakeEpisodeCount: Int
    let rawSampleCount: Int
    let mergedSessionCount: Int
}

struct SleepSessionFilter {
    private struct Interval: Equatable {
        let start: Date
        let end: Date

        var duration: TimeInterval { end.timeIntervalSince(start) }
    }

    static func process(
        samples: [HKCategorySample],
        window: SleepWindowBuilder.ExpectedSleepWindow,
        goal: SleepGoal?,
        calendar: Calendar = .current
    ) -> SleepDetectionResult {
        let rawCount = samples.count

        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ]

        let asleepSamples = samples.filter { asleepValues.contains($0.value) }
        if asleepSamples.isEmpty {
            return noSleepResult(window: window, rawSampleCount: rawCount, mergedSessionCount: 0)
        }

        let sorted = asleepSamples.sorted { $0.startDate < $1.startDate }
        let intervals = sorted.map { Interval(start: $0.startDate, end: $0.endDate) }

        let merged = merge(intervals: intervals, adjacencyGapSeconds: 10 * 60)
        let mergedCount = merged.count

        // Debe alinearse con el fin de la query de HealthKit (mediodía del día de levantar);
        // si usamos solo adjustedEnd (~meta+buffer), se descartan tramos matinales aunque el fetch tenga datos.
        let fetchQueryEnd = SleepWindowBuilder.sleepFetchQueryEnd(window: window, calendar: calendar)
        let nightlyFetch = Interval(start: window.adjustedStart, end: fetchQueryEnd)
        var overlapping = merged.filter { overlaps($0, nightlyFetch) }

        let strictExpected = Interval(start: window.expectedStart, end: window.expectedEnd)
        // Nap exclusion and late-start allowance.
        overlapping = overlapping.filter { session in
            let sessionDuration = session.duration
            if sessionDuration < 90 * 60 { return false } // < 90 minutes

            let overlapStrict = overlapSeconds(session, strictExpected)
            let overlapLoose = overlapSeconds(session, nightlyFetch)
            let bestOverlap = max(overlapStrict, overlapLoose)
            let overlapFraction = sessionDuration > 0 ? bestOverlap / sessionDuration : 0

            if overlapFraction < 0.20 { return false }

            // Heurística: sieta ~10:00–15:00 sin tocar el bloque estricto de "anoche" (meta) ≈ 0, descartar.
            if overlapStrict < sessionDuration * 0.10 {
                let h = calendar.component(.hour, from: session.start)
                if h >= 10 && h < 15 { return false }
            }

            // Allow sessions that start after expectedStart if overlap is strong.
            if session.start > window.expectedStart && overlapFraction <= 0.50 { return false }

            return true
        }

        guard !overlapping.isEmpty else {
            return noSleepResult(window: window, rawSampleCount: rawCount, mergedSessionCount: mergedCount)
        }

        // Unir tramos de la misma noche (vigila larga entre segmentos "asleep") y luego pico por más tiempo sumando etapas.
        let nightClusters = clusterByGap(overlapping, maxInterSegmentGap: 3 * 60 * 60)
        guard
            let bestCluster = nightClusters.max(by: { clusterAsleepSum($0, samples: asleepSamples) < clusterAsleepSum($1, samples: asleepSamples) }),
            let best = envelope(of: bestCluster)
        else {
            return noSleepResult(window: window, rawSampleCount: rawCount, mergedSessionCount: mergedCount)
        }

        let expected = Interval(start: window.expectedStart, end: window.expectedEnd)

        let totalSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue
        ])
        let deepSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue
        ])
        let remSeconds = stageSeconds(in: best, samples: asleepSamples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])

        let totalHours = totalSeconds > 0 ? totalSeconds / 3600.0 : nil
        let deepHours = deepSeconds > 0 ? deepSeconds / 3600.0 : nil
        let remHours = remSeconds > 0 ? remSeconds / 3600.0 : nil

        // Apple suele alargar "En la cama" tras el último "asleep"; sin esto, el fin de ventana
        // queda en el último tramo de sueño (p. ej. 4:44) aunque Suelo muestre despertar 6:49.
        let displayEnd = displayEndByExtendingSleepTail(
            best: best,
            allSamples: samples,
            capEnd: fetchQueryEnd
        )
        let displayForWall = Interval(start: best.start, end: displayEnd)
        let confidence = computeConfidence(session: displayForWall, expected: expected, isFallback: window.isFallback)

        let consistency = computeConsistencyScore(
            goal: goal,
            expectedStart: window.expectedStart,
            expectedEnd: window.expectedEnd,
            actualStart: best.start,
            actualEnd: displayEnd,
            calendar: calendar
        )

        let wall = displayForWall.duration
        let (awakeSec, awakeEpisodes) = awakeSecondsAndEpisodes(in: displayForWall, samples: samples)
        let hasAwakeStaging = samples.contains { $0.value == HKCategoryValueSleepAnalysis.awake.rawValue }
        // nil = dispositivo no aporta etapas "awake"; el scoring usa continuidad neutral.
        let awakeForScoring: TimeInterval? = hasAwakeStaging ? awakeSec : nil

        return SleepDetectionResult(
            sleepDetected: true,
            sessionStart: best.start,
            sessionEnd: displayEnd,
            totalSleepHours: totalHours,
            deepSleepHours: deepHours,
            remSleepHours: remHours,
            sleepConfidence: confidence,
            sleepConsistencyScore: consistency,
            sessionWallDuration: wall,
            awakeSecondsDuringSession: awakeForScoring,
            awakeEpisodeCount: awakeEpisodes,
            rawSampleCount: rawCount,
            mergedSessionCount: mergedCount
        )
    }

    /// Tras el último tramo *asleep* unido, alinear con la app Salud/otros: usar **“en la cama”** cuando exista y encadenar
    /// fases hacia el despertar sin enganchar siestas muchas horas después (horizonte 3 h, no 6 h).
    private static func displayEndByExtendingSleepTail(
        best: Interval,
        allSamples: [HKCategorySample],
        capEnd: Date
    ) -> Date {
        let inBedValue = HKCategoryValueSleepAnalysis.inBed.rawValue
        var end = best.end

        // 1) Un único *in bed* nocturno que envuelve el bloque asleep (típico Apple Watch) → fin = fin de inBed (~despertar).
        for s in allSamples {
            guard s.value == inBedValue, s.endDate <= capEnd else { continue }
            if s.startDate <= best.start && s.endDate >= best.end {
                end = max(end, s.endDate)
            }
        }

        // 2) *in bed* cuya cola continúa tras el último asleep (o empieza en el límite); incluye inBed partido en segmentos.
        for s in allSamples {
            guard s.value == inBedValue, s.endDate > end, s.endDate <= capEnd else { continue }
            if s.startDate <= best.end && s.endDate > best.end {
                end = max(end, s.endDate)
            }
        }

        // 3) Compat: straddle con regla anterior (s.start estrictamente antes de best.end) por si faltó (2).
        for s in allSamples {
            guard s.value == inBedValue else { continue }
            guard s.endDate > best.end, s.endDate <= capEnd, s.startDate < best.end else { continue }
            end = max(end, s.endDate)
        }

        // 4) Cadena inBed/awake/asleep: horizonte 3 h para unir vigilia en cama al último core/REM, sin atrapar siesta ~10:00.
        let linkHorizon: TimeInterval = 3 * 60 * 60
        var grew = true
        while grew {
            grew = false
            let mark = end
            for s in allSamples {
                guard s.endDate > end, s.endDate <= capEnd else { continue }
                if s.startDate < end + linkHorizon {
                    end = max(end, s.endDate)
                }
            }
            if end > mark { grew = true }
        }

        return min(end, capEnd)
    }

    // MARK: - Confidence & consistency

    private static func computeConfidence(session: Interval, expected: Interval, isFallback: Bool) -> Double {
        let overlap = overlapSeconds(session, expected)
        let frac = session.duration > 0 ? overlap / session.duration : 0
        let clamped = max(0.0, min(1.0, frac))
        let capped = isFallback ? min(0.8, clamped) : clamped
        // Full overlap -> 1.0
        if session.start >= expected.start && session.end <= expected.end {
            return isFallback ? 0.8 : 1.0
        }
        return capped
    }

    private static func computeConsistencyScore(
        goal: SleepGoal?,
        expectedStart: Date,
        expectedEnd: Date,
        actualStart: Date,
        actualEnd: Date,
        calendar: Calendar
    ) -> Int {
        guard goal != nil else { return 0 }

        let startDeviation = abs(minutesBetween(expectedStart, actualStart, calendar: calendar))
        let endDeviation = abs(minutesBetween(expectedEnd, actualEnd, calendar: calendar))
        let deviationMinutes = Double(startDeviation + endDeviation) / 2.0

        let score = 100.0 - min(100.0, deviationMinutes / 120.0 * 100.0)
        return Int(max(0, min(100, round(score))))
    }

    private static func minutesBetween(_ a: Date, _ b: Date, calendar: Calendar) -> Int {
        let comps = calendar.dateComponents([.minute], from: a, to: b)
        return comps.minute ?? Int((b.timeIntervalSince(a) / 60.0).rounded())
    }

    // MARK: - Helpers

    private static func noSleepResult(
        window: SleepWindowBuilder.ExpectedSleepWindow,
        rawSampleCount: Int,
        mergedSessionCount: Int
    ) -> SleepDetectionResult {
        SleepDetectionResult(
            sleepDetected: false,
            sessionStart: nil,
            sessionEnd: nil,
            totalSleepHours: nil,
            deepSleepHours: nil,
            remSleepHours: nil,
            sleepConfidence: 0.2,
            sleepConsistencyScore: 0,
            sessionWallDuration: nil,
            awakeSecondsDuringSession: nil,
            awakeEpisodeCount: 0,
            rawSampleCount: rawSampleCount,
            mergedSessionCount: mergedSessionCount
        )
    }

    /// Vigilia recortada al intervalo de sesión; episodios = tramos `awake` fusionados (gap 0).
    private static func awakeSecondsAndEpisodes(
        in session: Interval,
        samples: [HKCategorySample]
    ) -> (TimeInterval, Int) {
        let awakeVal = HKCategoryValueSleepAnalysis.awake.rawValue
        let stageIntervals: [Interval] = samples
            .filter { $0.value == awakeVal }
            .compactMap { sample in
                let clippedStart = max(sample.startDate, session.start)
                let clippedEnd = min(sample.endDate, session.end)
                guard clippedStart < clippedEnd else { return nil }
                return Interval(start: clippedStart, end: clippedEnd)
            }
        let merged = merge(intervals: stageIntervals, adjacencyGapSeconds: 0)
        let total = merged.reduce(0.0) { $0 + $1.duration }
        return (total, merged.count)
    }

    private static func overlaps(_ a: Interval, _ b: Interval) -> Bool {
        a.start < b.end && a.end > b.start
    }

    private static func overlapSeconds(_ a: Interval, _ b: Interval) -> TimeInterval {
        let start = max(a.start, b.start)
        let end = min(a.end, b.end)
        return max(0, end.timeIntervalSince(start))
    }

    /// Varios tramos "asleep" con vigilia intermedia (p. ej. >10 min) quedan en `merged` separados; se agrupan si el hueco es ≤3 h (misma noche).
    private static func clusterByGap(_ intervals: [Interval], maxInterSegmentGap: TimeInterval) -> [[Interval]] {
        let sorted = intervals.sorted { $0.start < $1.start }
        guard !sorted.isEmpty else { return [] }
        var clusters: [[Interval]] = []
        var current: [Interval] = [sorted[0]]
        for iv in sorted.dropFirst() {
            if iv.start.timeIntervalSince(current.last!.end) <= maxInterSegmentGap {
                current.append(iv)
            } else {
                clusters.append(current)
                current = [iv]
            }
        }
        clusters.append(current)
        return clusters
    }

    private static func envelope(of intervals: [Interval]) -> Interval? {
        guard let first = intervals.first else { return nil }
        let s = intervals.map { $0.start }.min() ?? first.start
        let e = intervals.map { $0.end }.max() ?? first.end
        return Interval(start: s, end: e)
    }

    private static func clusterAsleepSum(_ cluster: [Interval], samples: [HKCategorySample]) -> TimeInterval {
        guard let env = envelope(of: cluster) else { return 0 }
        return asleepSeconds(in: env, samples: samples)
    }

    private static func merge(intervals: [Interval], adjacencyGapSeconds: TimeInterval) -> [Interval] {
        guard !intervals.isEmpty else { return [] }
        let sorted = intervals.sorted { $0.start < $1.start }
        var merged: [Interval] = [sorted[0]]

        for interval in sorted.dropFirst() {
            let last = merged[merged.count - 1]
            let gap = interval.start.timeIntervalSince(last.end)
            if interval.start <= last.end || gap <= adjacencyGapSeconds {
                merged[merged.count - 1] = Interval(start: last.start, end: max(last.end, interval.end))
            } else {
                merged.append(interval)
            }
        }
        return merged
    }

    private static func asleepSeconds(in session: Interval, samples: [HKCategorySample]) -> TimeInterval {
        stageSeconds(in: session, samples: samples, allowedValues: [
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue
        ])
    }

    private static func stageSeconds(
        in session: Interval,
        samples: [HKCategorySample],
        allowedValues: Set<Int>
    ) -> TimeInterval {
        let stageIntervals: [Interval] = samples
            .filter { allowedValues.contains($0.value) }
            .compactMap { sample in
                let clippedStart = max(sample.startDate, session.start)
                let clippedEnd = min(sample.endDate, session.end)
                guard clippedStart < clippedEnd else { return nil }
                return Interval(start: clippedStart, end: clippedEnd)
            }

        return merge(intervals: stageIntervals, adjacencyGapSeconds: 0).reduce(0.0) { $0 + $1.duration }
    }
}

