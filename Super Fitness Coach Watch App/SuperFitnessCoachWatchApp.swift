//
//  SuperFitnessCoachWatchApp.swift
//  Super Fitness Coach Watch App
//

import SwiftUI

@main
struct SuperFitnessCoachWatchApp: App {
    @StateObject private var sessionManager = WatchSessionManager.shared

    var body: some Scene {
        WindowGroup {
            WatchMainView(sessionManager: sessionManager)
        }
    }
}
