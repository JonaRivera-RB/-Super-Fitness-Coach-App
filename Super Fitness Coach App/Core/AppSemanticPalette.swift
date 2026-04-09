//
//  AppSemanticPalette.swift
//  Super Fitness Coach App
//

import SwiftUI
import UIKit

/// Colores legibles en claro y oscuro: evita `Color.teal`/`Color.blue` fijos y opacidades demasiado bajas en dark.
enum AppSemanticPalette {

    // MARK: - Colores de sistema (se adaptan al appearance)

    /// `UIColor.systemBlue` — en modo oscuro evita el azul marino denso de `Color.blue` / `.blue` en SwiftUI.
    static var systemBlue: Color { Color(uiColor: .systemBlue) }
    static var systemTeal: Color { Color(uiColor: .systemTeal) }
    static var systemGreen: Color { Color(uiColor: .systemGreen) }
    static var systemOrange: Color { Color(uiColor: .systemOrange) }
    static var systemPurple: Color { Color(uiColor: .systemPurple) }
    static var systemYellow: Color { Color(uiColor: .systemYellow) }
    static var systemRed: Color { Color(uiColor: .systemRed) }

    // MARK: - Fondos tintados (en oscuro subimos opacidad para que el texto y bordes se lean bien)

    /// Relleno semitransparente sobre `UIColor` adaptativo.
    static func tintedFill(_ uiColor: UIColor, _ scheme: ColorScheme, light: CGFloat, dark: CGFloat) -> Color {
        Color(uiColor: uiColor).opacity(scheme == .dark ? dark : light)
    }

    static func coachBannerFill(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.12, dark: 0.30)
    }

    static func muscleTagBackground(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.12, dark: 0.30)
    }

    static func compoundTagBackground(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.12, dark: 0.30)
    }

    static func registerSetButtonFill(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.20, dark: 0.42)
    }

    static func registerSetButtonForeground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? Color(uiColor: .label) : systemTeal
    }

    static func restBarAccent(_ scheme: ColorScheme) -> Color {
        Color(uiColor: .systemBlue)
    }

    static func progressTrack(_ scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? .tertiarySystemFill : .systemGray5)
    }

    static func progressFill(_ scheme: ColorScheme) -> Color {
        Color(uiColor: .systemGreen)
    }

    /// Texto o icono sobre chip/banner tintado: en oscuro priorizamos `label` para contraste.
    static func accentOrPrimaryLabel(_ accent: UIColor, _ scheme: ColorScheme) -> Color {
        Color(uiColor: scheme == .dark ? .label : accent)
    }

    // MARK: - Superficies con nombre (Entrenamiento / Inicio)

    static func workoutBannerTeal(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.08, dark: 0.28)
    }

    static func workoutBannerBlue(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.08, dark: 0.28)
    }

    static func workoutRoutineHeader(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutCardGreenTint(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemGreen, scheme, light: 0.08, dark: 0.26)
    }

    static func workoutCardTealTint(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.06, dark: 0.26)
    }

    static func workoutChipTealFill(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.15, dark: 0.32)
    }

    static func workoutChipBlueFill(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.12, dark: 0.30)
    }

    static func workoutWeekProgressBlue(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutRestCardPurple(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemPurple, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutInfoCardBlue(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutLockedOrange(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutWeekCompleteYellow(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemYellow, scheme, light: 0.07, dark: 0.22)
    }

    static func workoutWeekCompleteOrange(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.07, dark: 0.26)
    }

    static func workoutDayPillTodayTeal(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemTeal, scheme, light: 0.12, dark: 0.28)
    }

    static func workoutDayPillTodayBlue(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemBlue, scheme, light: 0.10, dark: 0.26)
    }

    static func homeHealthDeniedBanner(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.10, dark: 0.28)
    }

    static func homePointsCardStroke(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.20, dark: 0.42)
    }

    static func homeDetoxPurple(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemPurple, scheme, light: 0.08, dark: 0.26)
    }

    static func statsLevelOrange(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemOrange, scheme, light: 0.08, dark: 0.24)
    }

    static func statsBadgePurple(_ scheme: ColorScheme) -> Color {
        tintedFill(.systemPurple, scheme, light: 0.08, dark: 0.26)
    }

    /// Bordes sobre superficies tintadas.
    static func strokeMuted(_ uiColor: UIColor, _ scheme: ColorScheme) -> Color {
        Color(uiColor: uiColor).opacity(scheme == .dark ? 0.50 : 0.30)
    }

    /// Fondo degradado para **Nuevo plan** / **Mi rutina** en modo oscuro: evita el azul marino (B > R/G en el gradiente anterior).
    static func planRoutineDarkGradientColors() -> [Color] {
        [
            Color(red: 0.12, green: 0.12, blue: 0.11),
            Color(red: 0.06, green: 0.06, blue: 0.06)
        ]
    }

    /// Círculos de estado en la fila semanal (entreno completado, descanso, etc.).
    static func workoutPillCircle(
        doneThisWeek: Bool,
        isRest: Bool,
        hasExercises: Bool,
        scheme: ColorScheme
    ) -> Color {
        if doneThisWeek {
            return tintedFill(.systemGreen, scheme, light: 0.55, dark: 0.62)
        }
        if isRest {
            return tintedFill(.systemPurple, scheme, light: 0.45, dark: 0.55)
        }
        if hasExercises {
            return tintedFill(.systemTeal, scheme, light: 0.45, dark: 0.55)
        }
        return Color(uiColor: .systemGray).opacity(scheme == .dark ? 0.35 : 0.28)
    }
}
