//  RecoverySnapshot.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

/// Una fila por día calendario (inicio del día local) con puntuaciones guardadas al refrescar Home.
@Model
final class RecoverySnapshot {
    @Attribute(.unique) var dayStart: Date
    var recoveryScore: Int
    var activityScore: Int
    var sleepScore: Int?
    var sleepHours: Double?
    var deepSleepHours: Double?
    var remSleepHours: Double?
    var sleepConsistencyScore: Int?
    var sleepSessionStart: Date?
    var sleepSessionEnd: Date?
    var restingHR: Double?
    var hrv: Double?
    var recoveryConfidenceRaw: String?

    init(
        dayStart: Date,
        recoveryScore: Int,
        activityScore: Int,
        sleepScore: Int? = nil,
        sleepHours: Double? = nil,
        deepSleepHours: Double? = nil,
        remSleepHours: Double? = nil,
        sleepConsistencyScore: Int? = nil,
        sleepSessionStart: Date? = nil,
        sleepSessionEnd: Date? = nil,
        restingHR: Double? = nil,
        hrv: Double? = nil,
        recoveryConfidenceRaw: String? = nil
    ) {
        self.dayStart = dayStart
        self.recoveryScore = recoveryScore
        self.activityScore = activityScore
        self.sleepScore = sleepScore
        self.sleepHours = sleepHours
        self.deepSleepHours = deepSleepHours
        self.remSleepHours = remSleepHours
        self.sleepConsistencyScore = sleepConsistencyScore
        self.sleepSessionStart = sleepSessionStart
        self.sleepSessionEnd = sleepSessionEnd
        self.restingHR = restingHR
        self.hrv = hrv
        self.recoveryConfidenceRaw = recoveryConfidenceRaw
    }
}
