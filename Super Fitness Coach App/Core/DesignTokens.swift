//
//  DesignTokens.swift
//  Super Fitness Coach App
//
//  Single source of truth for all visual decisions.
//
//  iOS 26+  → Liquid Glass (.glassEffect, floating tab bar, glass materials)
//  iOS 18+  → System materials (.regularMaterial, adaptive fills, native shadows)
//
//  Usage:
//    .padding(DesignTokens.Spacing.md)
//    .cornerRadius(DesignTokens.Radius.card)
//    .tokenCard()                          ← ViewModifier, glass on iOS 26
//    .tokenShadow(.elevated)               ← semantic shadow level
//    DesignTokens.Color.recoveryAccent(score: 72)
//

import SwiftUI

// MARK: - Design Tokens

enum DesignTokens {

    // ─────────────────────────────────────────────
    // MARK: Color
    // ─────────────────────────────────────────────

    enum Color {

        // MARK: Recovery accent (responde al score del usuario)
        //
        // score >= 70  →  verde sistema   (energético, listo)
        // score 40–69  →  ámbar sistema   (moderado, precaución)
        // score < 40   →  slate/gris      (descanso, NO rojo — rojo causa ansiedad)

        static func recoveryAccent(score: Int) -> SwiftUI.Color {
            if score >= 70 { return .init(uiColor: .systemGreen) }
            if score >= 40 { return .init(uiColor: .systemOrange) }
            return .init(uiColor: .systemGray)
        }

        /// Retorna el nivel semántico de recuperación (para lógica de color).
        static func recoveryLevel(score: Int) -> RecoveryLevel {
            if score >= 70 { return .high }
            if score >= 40 { return .medium }
            return .low
        }

        enum RecoveryLevel {
            case high, medium, low

            var accent: SwiftUI.Color {
                switch self {
                case .high:   return .init(uiColor: .systemGreen)
                case .medium: return .init(uiColor: .systemOrange)
                case .low:    return .init(uiColor: .systemGray)
                }
            }

            var fillOpacity: Double { 0.10 }

            var fill: SwiftUI.Color { accent.opacity(fillOpacity) }

            /// Label legible en español para el nivel.
            var label: String {
                switch self {
                case .high:   return "Alta"
                case .medium: return "Media"
                case .low:    return "Baja"
                }
            }
        }

        // MARK: Surfaces (usan UIColor semánticos — se adaptan a light/dark automáticamente)

        /// Fondo base de la app (equivale a systemGroupedBackground).
        static var backgroundPrimary: SwiftUI.Color { .init(.systemGroupedBackground) }
        /// Superficie de cards y celdas.
        static var surfaceCard: SwiftUI.Color { .init(.secondarySystemGroupedBackground) }
        /// Superficie elevada (dentro de cards, inputs).
        static var surfaceElevated: SwiftUI.Color { .init(.tertiarySystemGroupedBackground) }
        /// Superficie de sheets y modales.
        static var surfaceSheet: SwiftUI.Color { .init(.systemBackground) }

        // MARK: Text

        static var textPrimary: SwiftUI.Color   { .primary }
        static var textSecondary: SwiftUI.Color { .secondary }
        static var textTertiary: SwiftUI.Color  { .init(.tertiaryLabel) }
        static var textQuaternary: SwiftUI.Color { .init(.quaternaryLabel) }

        // MARK: Semantic states

        /// Positivo / completado / buena recuperación.
        static var positive: SwiftUI.Color    { .init(uiColor: .systemGreen) }
        /// Precaución / moderado / ámbar.
        static var caution: SwiftUI.Color     { .init(uiColor: .systemOrange) }
        /// Descanso / datos insuficientes / neutral.
        static var rest: SwiftUI.Color        { .init(uiColor: .systemGray) }
        /// Informativo / links / HealthKit.
        static var info: SwiftUI.Color        { .init(uiColor: .systemBlue) }
        /// Destructivo / errores.
        static var destructive: SwiftUI.Color { .init(uiColor: .systemRed) }
        /// Gamificación / puntos / logros.
        static var reward: SwiftUI.Color      { .init(uiColor: .systemYellow) }
        /// Días de descanso / modo detox.
        static var restDay: SwiftUI.Color     { .init(uiColor: .systemPurple) }

        // MARK: Borders / Strokes

        /// Borde sutil sobre superficies (adapta opacity a dark/light).
        static func stroke(_ scheme: ColorScheme) -> SwiftUI.Color {
            scheme == .dark
                ? .white.opacity(0.10)
                : .black.opacity(0.06)
        }

        /// Borde de acento suave (recuperación moderada, warning).
        static func accentStroke(_ accent: SwiftUI.Color, _ scheme: ColorScheme) -> SwiftUI.Color {
            accent.opacity(scheme == .dark ? 0.40 : 0.20)
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Spacing  (grid de 4pt)
    // ─────────────────────────────────────────────

    enum Spacing {
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 8
        static let md: CGFloat  = 16
        static let lg: CGFloat  = 24
        static let xl: CGFloat  = 32
        static let xxl: CGFloat = 48

        /// Padding horizontal estándar de pantalla.
        static let screenH: CGFloat = 20
        /// Padding vertical de secciones en scroll.
        static let screenV: CGFloat = 12
        /// Spacing interno de un card estándar.
        static let cardInner: CGFloat = md
        /// Spacing interno de un card héroe.
        static let heroInner: CGFloat = lg
    }

    // ─────────────────────────────────────────────
    // MARK: Radius
    // ─────────────────────────────────────────────

    enum Radius {
        /// Tags, chips, badges pequeñas.
        static let chip: CGFloat    = 10
        /// Cards estándar (métricas, secciones).
        static let card: CGFloat    = 16
        /// Cards grandes / hero cards.
        static let hero: CGFloat    = 22
        /// Sheets, modales, bottom sheets.
        static let sheet: CGFloat   = 32
        /// Botones tipo pill (CTA principal).
        static let pill: CGFloat    = 9999
    }

    // ─────────────────────────────────────────────
    // MARK: Shadow
    // ─────────────────────────────────────────────

    struct ShadowStyle {
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        /// Sutil: separación mínima del fondo. Para chips, tags.
        static func subtle(_ scheme: ColorScheme) -> ShadowStyle {
            .init(
                color: .black.opacity(scheme == .dark ? 0.20 : 0.06),
                radius: 4, x: 0, y: 1
            )
        }
        /// Card: elevación estándar de una tarjeta.
        static func card(_ scheme: ColorScheme) -> ShadowStyle {
            .init(
                color: .black.opacity(scheme == .dark ? 0.28 : 0.09),
                radius: 12, x: 0, y: 4
            )
        }
        /// Elevated: hero cards, secciones destacadas.
        static func elevated(_ scheme: ColorScheme) -> ShadowStyle {
            .init(
                color: .black.opacity(scheme == .dark ? 0.35 : 0.12),
                radius: 24, x: 0, y: 8
            )
        }
        /// Floating: timers, overlays, floating buttons.
        static func floating(_ scheme: ColorScheme) -> ShadowStyle {
            .init(
                color: .black.opacity(scheme == .dark ? 0.45 : 0.16),
                radius: 40, x: 0, y: 16
            )
        }
        /// Acento de color (sombra tintada con el accent del recovey).
        static func accent(_ color: SwiftUI.Color, _ scheme: ColorScheme) -> ShadowStyle {
            .init(
                color: color.opacity(scheme == .dark ? 0.30 : 0.18),
                radius: 16, x: 0, y: 6
            )
        }
    }

    // ─────────────────────────────────────────────
    // MARK: Typography
    // ─────────────────────────────────────────────
    //
    //  Usa fuentes del sistema (SF Pro / SF Rounded) para:
    //  - Integración nativa con Dynamic Type automáticamente
    //  - Compatibilidad sin assets externos
    //  - Coherencia con el estilo iOS Liquid Glass
    //
    //  Si en el futuro se adopta una fuente custom, solo
    //  cambiar aquí y se propaga a toda la app.

    enum Typography {
        /// Número del recovery score — protagonista de pantalla. (56pt heavy rounded)
        static let scoreHero = Font.system(size: 56, weight: .heavy, design: .rounded)
        /// Número grande en estadísticas. (48pt bold rounded)
        static let numberLarge = Font.system(size: 48, weight: .bold, design: .rounded)
        /// Número mediano en cards de métricas. (34pt bold rounded)
        static let numberMedium = Font.system(size: 34, weight: .bold, design: .rounded)
        /// Número compacto (dentro de chips, progress). (28pt semibold rounded)
        static let numberCompact = Font.system(size: 28, weight: .semibold, design: .rounded)

        /// Título de pantalla / saludo. (28pt bold)
        static let displayTitle = Font.system(size: 28, weight: .bold)
        /// Título de sección dentro de una pantalla. (20pt semibold)
        static let sectionTitle = Font.system(size: 20, weight: .semibold)
        /// Título de card. (17pt semibold)
        static let cardTitle = Font.system(size: 17, weight: .semibold)

        /// Cuerpo principal. (16pt regular)
        static let body = Font.system(size: 16, weight: .regular)
        /// Cuerpo con énfasis. (16pt medium)
        static let bodyMedium = Font.system(size: 16, weight: .medium)

        /// Etiquetas, captions. (13pt medium)
        static let caption = Font.system(size: 13, weight: .medium)
        /// Caption regular. (13pt regular)
        static let captionRegular = Font.system(size: 13, weight: .regular)

        /// Labels muy pequeños, disclaimers. (11pt regular)
        static let micro = Font.system(size: 11, weight: .regular)
        /// Micro con énfasis. (11pt medium)
        static let microMedium = Font.system(size: 11, weight: .medium)
    }

    // ─────────────────────────────────────────────
    // MARK: Motion / Animation
    // ─────────────────────────────────────────────

    enum Motion {
        /// Micro-interacciones rápidas (toggle, tap feedback). 0.20s
        static let quick = Animation.easeOut(duration: 0.20)
        /// Transiciones estándar (expand/collapse, fade). 0.30s
        static let standard = Animation.easeInOut(duration: 0.30)
        /// Spring crisp para elementos que "caen en su lugar".
        static let springSnappy = Animation.spring(response: 0.35, dampingFraction: 0.82)
        /// Spring con rebote para celebraciones (PR, badge).
        static let springBouncy = Animation.spring(response: 0.50, dampingFraction: 0.68)
        /// Slow fade para textos y placeholders.
        static let fadeIn = Animation.easeIn(duration: 0.45)
    }
}

// MARK: - ViewModifiers que usan los tokens

// ─────────────────────────────────────────────
// MARK: TokenCard
// ─────────────────────────────────────────────
//
//  iOS 26+  → Liquid Glass (.glassEffect)
//  iOS 18+  → surfaceCard fill + shadow semántico

struct TokenCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = DesignTokens.Spacing.cardInner
    var cornerRadius: CGFloat = DesignTokens.Radius.card

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                cardBackground(radius: cornerRadius)
            }
    }

    @ViewBuilder
    private func cardBackground(radius: CGFloat) -> some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(.regularMaterial)
                // .glassEffect() — activar cuando el proyecto tenga iOS 26 SDK
        } else {
            let shadow = DesignTokens.Shadow.card(scheme)
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: TokenHeroCard
// ─────────────────────────────────────────────

struct TokenHeroCard: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var padding: CGFloat = DesignTokens.Spacing.heroInner
    var accentColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                heroBackground
            }
    }

    @ViewBuilder
    private var heroBackground: some View {
        if #available(iOS 26, *) {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                .fill(.regularMaterial)
                // .glassEffect() — activar con iOS 26 SDK
        } else {
            let shadow = DesignTokens.Shadow.elevated(scheme)
            RoundedRectangle(cornerRadius: DesignTokens.Radius.hero, style: .continuous)
                .fill(DesignTokens.Color.surfaceCard)
                .shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: TokenShadow
// ─────────────────────────────────────────────

enum TokenShadowLevel { case subtle, card, elevated, floating }

struct TokenShadowModifier: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    let level: TokenShadowLevel

    func body(content: Content) -> some View {
        let s = shadow(for: level)
        content.shadow(color: s.color, radius: s.radius, x: s.x, y: s.y)
    }

    private func shadow(for level: TokenShadowLevel) -> DesignTokens.ShadowStyle {
        switch level {
        case .subtle:   return DesignTokens.Shadow.subtle(scheme)
        case .card:     return DesignTokens.Shadow.card(scheme)
        case .elevated: return DesignTokens.Shadow.elevated(scheme)
        case .floating: return DesignTokens.Shadow.floating(scheme)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: TokenStroke
// ─────────────────────────────────────────────

struct TokenStroke: ViewModifier {
    @Environment(\.colorScheme) private var scheme
    var cornerRadius: CGFloat = DesignTokens.Radius.card
    var lineWidth: CGFloat = 1

    func body(content: Content) -> some View {
        content.overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(DesignTokens.Color.stroke(scheme), lineWidth: lineWidth)
        }
    }
}

// ─────────────────────────────────────────────
// MARK: View extensions (API limpia para llamar desde las vistas)
// ─────────────────────────────────────────────

extension View {

    /// Card estándar con glass en iOS 26 y material nativo en iOS 18.
    func tokenCard(
        padding: CGFloat = DesignTokens.Spacing.cardInner,
        radius: CGFloat = DesignTokens.Radius.card
    ) -> some View {
        modifier(TokenCard(padding: padding, cornerRadius: radius))
    }

    /// Hero card — radio y sombra mayores. Para el score principal y secciones protagonistas.
    func tokenHeroCard(
        padding: CGFloat = DesignTokens.Spacing.heroInner,
        accentColor: Color? = nil
    ) -> some View {
        modifier(TokenHeroCard(padding: padding, accentColor: accentColor))
    }

    /// Sombra semántica por nivel de elevación.
    func tokenShadow(_ level: TokenShadowLevel = .card) -> some View {
        modifier(TokenShadowModifier(level: level))
    }

    /// Borde sutil usando el token de stroke.
    func tokenStroke(
        radius: CGFloat = DesignTokens.Radius.card,
        lineWidth: CGFloat = 1
    ) -> some View {
        modifier(TokenStroke(cornerRadius: radius, lineWidth: lineWidth))
    }

    /// Chip / badge compacto (fondo tintado, esquinas pequeñas).
    func tokenChip(color: Color, scheme: ColorScheme) -> some View {
        self
            .padding(.horizontal, DesignTokens.Spacing.sm)
            .padding(.vertical, DesignTokens.Spacing.xs)
            .background(
                Capsule()
                    .fill(color.opacity(scheme == .dark ? 0.22 : 0.12))
            )
    }
}

// MARK: - Compatibilidad con código existente
// AppSemanticPalette sigue funcionando pero está deprecated.
// Migrar usages a DesignTokens gradualmente.
