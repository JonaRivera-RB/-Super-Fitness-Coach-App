//
//  WatchModels.swift
//  Super Fitness Coach App
//

import Foundation

struct WatchContext: Codable {
    var recoveryScore: Int
    var statusIndicator: String
    var exercises: [WatchExercise]
}

struct WatchExercise: Codable, Identifiable {
    var id: String
    var name: String
    var sets: Int
    var reps: Int
    var isCompleted: Bool
}

struct WatchCompletionUpdate: Codable {
    var exerciseId: String
    var sessionId: String
    var completedAt: Date
}
