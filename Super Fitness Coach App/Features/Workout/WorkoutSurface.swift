//
//  WorkoutSurface.swift
//  Super Fitness Coach App
//

import Foundation

/// Superficie del tab Entrenamiento: plan guiado vs Mi rutina (segmented control cuando ambos existen).
enum WorkoutSurface: String, CaseIterable {
    case plan
    case routine
}
