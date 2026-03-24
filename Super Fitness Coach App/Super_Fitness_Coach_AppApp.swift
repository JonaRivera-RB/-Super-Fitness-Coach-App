//
//  Super_Fitness_Coach_AppApp.swift
//  Super Fitness Coach App
//
//  Created by Jonathan Rivera on 22/03/26.
//

import SwiftUI
import SwiftData

@main
struct Super_Fitness_Coach_AppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            UserProfile.self,
            WeeklyPlan.self,
            WorkoutSession.self,
            GamificationState.self,
            DetoxProgress.self
        ])
    }
}
