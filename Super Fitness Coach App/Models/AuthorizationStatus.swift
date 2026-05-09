//
//  AuthorizationStatus.swift
//  Super Fitness Coach App
//

import Foundation

/// Real HealthKit authorization state, verified via test query.
enum AuthorizationStatus: String, Codable {
    case notDetermined
    case authorized
    case denied
    case unavailable
}
