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

    // MARK: - Lifting weights (storage always kg)

    /// Formats a mass in **kg** for display in the user’s lifting unit (plates / gym).
    static func formatLiftKgForDisplay(_ kg: Double, unit: LiftingWeightUnit) -> String {
        switch unit {
        case .kilograms:
            return formatKgPlateStyle(kg)
        case .pounds:
            let lb = kgToLbs(kg)
            return formatLbPlateStyle(lb)
        }
    }

    /// Parses typed text as the user’s lifting unit → **kg**. Returns nil if empty/invalid.
    static func parseLiftInputToKg(_ text: String, unit: LiftingWeightUnit) -> Double? {
        let t = text.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: ".")
        guard !t.isEmpty, let v = Double(t), v >= 0 else { return nil }
        switch unit {
        case .kilograms: return v
        case .pounds: return lbsToKg(v)
        }
    }

    /// Mass in the **other** lifting unit only (number + symbol), using plate-style precision.
    static func formatLiftOtherUnitFromKg(_ kg: Double, displayUnit: LiftingWeightUnit) -> String {
        switch displayUnit {
        case .kilograms:
            return "\(formatLbPlateStyle(kgToLbs(kg))) lb"
        case .pounds:
            return "\(formatKgPlateStyle(kg)) kg"
        }
    }

    /// One line: equivalent in the *other* unit (e.g. user works in lb → "≈ 82.5 kg").
    static func liftEquivalentSubtitle(kg: Double, displayUnit: LiftingWeightUnit) -> String {
        "≈ \(formatLiftOtherUnitFromKg(kg, displayUnit: displayUnit))"
    }

    static func liftTargetCaption(minKg: Double, maxKg: Double?, unit: LiftingWeightUnit) -> String {
        let minS = formatLiftKgForDisplay(minKg, unit: unit)
        if let maxKg, maxKg > minKg + 0.01 {
            let maxS = formatLiftKgForDisplay(maxKg, unit: unit)
            let range = "\(minS)–\(maxS) \(unit.symbol)"
            let mid = (minKg + maxKg) / 2
            let eq = liftEquivalentSubtitle(kg: mid, displayUnit: unit)
            return "Objetivo: \(range) · \(eq)"
        }
        return "Objetivo: \(minS) \(unit.symbol) · \(liftEquivalentSubtitle(kg: minKg, displayUnit: unit))"
    }

    private static func formatKgPlateStyle(_ kg: Double) -> String {
        if abs(kg - floor(kg)) < 0.05 { return String(format: "%.0f", kg) }
        return String(format: "%.1f", kg)
    }

    private static func formatLbPlateStyle(_ lb: Double) -> String {
        if abs(lb - floor(lb)) < 0.05 { return String(format: "%.0f", lb) }
        return String(format: "%.1f", lb)
    }
}
