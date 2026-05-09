//
//  DetoxProgress.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

@Model
final class DetoxProgress {
    @Attribute(.unique) var id: UUID
    var startDate: Date
    var currentDay: Int
    var dailyLogs: [Bool]
    var isActive: Bool
    var isCompleted: Bool

    init(startDate: Date) {
        self.id = UUID()
        self.startDate = startDate
        self.currentDay = 1
        self.dailyLogs = Array(repeating: false, count: 7)
        self.isActive = true
        self.isCompleted = false
    }
}
