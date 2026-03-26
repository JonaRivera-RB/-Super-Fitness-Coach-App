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

    init(dayStart: Date, recoveryScore: Int, activityScore: Int) {
        self.dayStart = dayStart
        self.recoveryScore = recoveryScore
        self.activityScore = activityScore
    }
}
