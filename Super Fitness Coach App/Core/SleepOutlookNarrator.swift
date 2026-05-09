//
//  SleepOutlookNarrator.swift
//  Super Fitness Coach App
//
//  Plantillas locales + opcional Apple Foundation Models (session-per-call).
//

import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

enum SleepOutlookNarrator {

    /// Párrafo determinista (siempre disponible).
    static func templateParagraph(snapshot: SleepOutlookSnapshot, language: AppLanguage) -> String {
        language.sleepOutlookComposeTemplate(snapshot)
    }

    /// Intenta enriquecer el texto con el modelo del sistema; siempre tiene fallback equivalente en datos.
    static func narrate(snapshot: SleepOutlookSnapshot, language: AppLanguage) async -> (text: String, usedAppleModel: Bool) {
        let fallback = templateParagraph(snapshot: snapshot, language: language)

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                return (fallback, false)
            }

            let session = LanguageModelSession(instructions: language.sleepOutlookFoundationInstructions)

            let metricsBlock = snapshot.structuredPromptLines.joined(separator: "\n")
            let promptText = language.sleepOutlookFoundationUserPrompt(metricsBlock: metricsBlock)

            do {
                let response = try await session.respond(to: Prompt { promptText })
                let raw = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                if raw.count < 24 {
                    return (fallback, false)
                }
                return (raw, true)
            } catch {
                return (fallback, false)
            }
        }
        #endif

        return (fallback, false)
    }
}
