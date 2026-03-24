//
//  AICoach.swift
//  Super Fitness Coach App
//

import Foundation

struct AICoach {
    /// Generate a contextual recommendation message based on current state.
    /// Rules are evaluated in priority order:
    ///   1. Recovery < 40 → rest/light recommendation (with activity context)
    ///   2. Streak ≥ 3 → encouraging progress message
    ///   3. Streak == 0 && Recovery > 69 → motivational start message (with low-activity nudge)
    ///   4. Default → general encouragement
    /// All messages include the user's first name.
    static func generateMessage(
        userName: String,
        recoveryScore: Int,
        activityScore: Int,
        streakDays: Int,
        recentWorkoutCount: Int
    ) -> String {
        let firstName = extractFirstName(from: userName)

        // Rule 1: Low recovery → rest recommendation
        if recoveryScore < 40 {
            if activityScore > 70 {
                return "\(firstName), you were very active yesterday but your body needs rest today. Take it easy 💤"
            }
            return "\(firstName), your body needs rest today. Take it easy and recover well 💤"
        }

        // Rule 2: Active streak → encouraging message
        if streakDays >= 3 {
            return "\(firstName), \(streakDays) days in a row, great progress 🔥"
        }

        // Rule 3: No streak but fully recovered → motivational start
        if streakDays == 0 && recoveryScore > 69 {
            if activityScore < 30 {
                return "\(firstName), you're fully recovered and haven't moved much, let's get going 💪"
            }
            return "\(firstName), you're fully recovered, let's get moving 💪"
        }

        // Rule 4: Default encouragement
        return "\(firstName), every step counts. Keep going 🌟"
    }

    /// Extract the first name (first whitespace-delimited token) from a full name.
    private static func extractFirstName(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        return trimmed.split(separator: " ").first.map(String.init) ?? trimmed
    }
}
