//
//  AppLanguage.swift
//  Super Fitness Coach App
//

import SwiftUI

/// Idioma de la interfaz elegido en Perfil (independiente del idioma del sistema).
enum AppLanguage: String, CaseIterable, Sendable {
    case spanish = "es"
    case english = "en"

    /// Nombre del idioma para el selector (siempre reconocible).
    var nativePickerLabel: String {
        switch self {
        case .spanish: return "Español"
        case .english: return "English"
        }
    }

    /// Clave en `UserDefaults` / `@AppStorage` (debe coincidir en toda la app).
    static let storageKey = "app.preference.language"

    /// Valor persistido o español por defecto.
    static var current: AppLanguage {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let value = AppLanguage(rawValue: raw) {
            return value
        }
        return .spanish
    }
}

// MARK: - SwiftUI Environment

private enum AppLanguageKey: EnvironmentKey {
    static let defaultValue: AppLanguage = .current
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}
