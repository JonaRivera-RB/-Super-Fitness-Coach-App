//
//  HealthDataStatus.swift
//  Super Fitness Coach App
//

import Foundation

/// Represents the state of a health metric read from HealthKit.
/// Eliminates the use of default values that mask absent data.
enum HealthDataStatus<T> {
    case available(T)
    case unavailable
    case loading

    var value: T? {
        if case .available(let v) = self { return v }
        return nil
    }

    var isAvailable: Bool {
        if case .available = self { return true }
        return false
    }

    var isLoading: Bool {
        if case .loading = self { return true }
        return false
    }
}
