//
//  UnitConverter.swift
//  Super Fitness Coach App
//

import Foundation

struct UnitConverter {
    // MARK: - Weight

    static func kgToLbs(_ kg: Double) -> Double {
        kg * 2.20462
    }

    static func lbsToKg(_ lbs: Double) -> Double {
        lbs / 2.20462
    }

    // MARK: - Height

    static func cmToFeetInches(_ cm: Double) -> (feet: Int, inches: Double) {
        let totalInches = cm / 2.54
        let feet = Int(totalInches) / 12
        let inches = totalInches - Double(feet * 12)
        return (feet, inches)
    }

    static func feetInchesToCm(feet: Int, inches: Double) -> Double {
        (Double(feet) * 12.0 + inches) * 2.54
    }

    // MARK: - Locale Detection

    static func defaultPreference(for locale: Locale = .current) -> UnitPreference {
        locale.measurementSystem == .us ? .imperial : .metric
    }
}
