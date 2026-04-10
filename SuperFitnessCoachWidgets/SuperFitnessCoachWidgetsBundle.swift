//
//  SuperFitnessCoachWidgetsBundle.swift
//  SuperFitnessCoachWidgets
//
//  Created by Jonathan Rivera on 09/04/26.
//

import WidgetKit
import SwiftUI

@main
struct SuperFitnessCoachWidgetsBundle: WidgetBundle {
    var body: some Widget {
        // Live Activity disabled for now (Plan B: local notification).
        // Keep a basic widget so the extension target still builds.
        SuperFitnessCoachWidgets()
    }
}
