//
//  ExerciseService.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os
import SwiftData
import UIKit

@Observable
final class ExerciseService {

    static let shared = ExerciseService()

    // MARK: - Private

    @ObservationIgnored private let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseService")
    @ObservationIgnored private let session: URLSession
    @ObservationIgnored private var modelContext: ModelContext?
    @ObservationIgnored private var localCatalogEnabled: Bool = false

    // MARK: - Init

    init(
        session: URLSession = .shared
    ) {
        self.session = session
    }

    /// Call once from app root where SwiftData `ModelContext` is available.
    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        self.localCatalogEnabled = true
    }

    /// One-time import entrypoint. Safe to call multiple times.
    func ensureLocalCatalogImportedIfNeeded() async {
        guard localCatalogEnabled, let ctx = modelContext else { return }
        do {
            let count = try ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())
            guard count == 0 else { return }
            // Import from the wger GitHub fixtures (stable, no dependency on wger.de uptime).
            let fixturesBase = "https://raw.githubusercontent.com/wger-project/wger/master/wger/exercises/fixtures"
            let importer = ExerciseCatalogImporter(baseURL: fixturesBase, session: session)
            var lastError: Error?
            for attempt in 1...3 {
                do {
                    try await importer.importAll(into: ctx)
                    let after = try ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())
                    logger.info("Catalog import success (attempt \(attempt)): \(after) exercises")
                    return
                } catch {
                    lastError = error
                    logger.warning("Catalog import attempt \(attempt) failed: \(error.localizedDescription)")
                    try? await Task.sleep(nanoseconds: UInt64(400_000_000 * attempt))
                }
            }
            if let lastError {
                throw lastError
            }
        } catch {
            logger.warning("ensureLocalCatalogImportedIfNeeded failed: \(error.localizedDescription)")
        }
    }

    // MARK: - Fetch Exercises

    enum CatalogError: LocalizedError {
        case notConfigured
        case emptyCatalog

        var errorDescription: String? {
            switch self {
            case .notConfigured:
                return "Exercise catalog is not configured (missing ModelContext)."
            case .emptyCatalog:
                return "El catálogo de ejercicios aún no está descargado."
            }
        }
    }

    /// Returns local exercises for the requested bodyPart (MuscleGroup.apiBodyPart compatible).
    /// If the catalog hasn't been downloaded yet, triggers import and throws if still empty.
    func fetchExercises(bodyPart: String, equipment: String?) async throws -> [Exercise] {
        guard localCatalogEnabled, let ctx = modelContext else { throw CatalogError.notConfigured }

        // If empty, try importing once.
        let count = (try? ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? 0
        if count == 0 {
            await ensureLocalCatalogImportedIfNeeded()
        }

        let after = (try? ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? 0
        guard after > 0 else { throw CatalogError.emptyCatalog }

        let mgRaw = Self.mapBodyPartToMuscleGroupRaw(bodyPart)
        let trimmedEq = equipment?.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasEq = (trimmedEq?.isEmpty == false)

        let predicate: Predicate<ExerciseCatalogEntry> = {
            if hasEq, let trimmedEq {
                return #Predicate { $0.muscleGroupRaw == mgRaw && ($0.equipmentCSV ?? "").localizedStandardContains(trimmedEq) }
            } else {
                return #Predicate { $0.muscleGroupRaw == mgRaw }
            }
        }()

        let fd = FetchDescriptor<ExerciseCatalogEntry>(predicate: predicate)
        let rows = (try? ctx.fetch(fd)) ?? []
        return rows.map { Self.rowToExercise($0) }
    }

    private static func htmlToPlainText(_ html: String) -> String {
        guard !html.isEmpty else { return "" }
        // Use HTML parsing to preserve list/newlines better than regex stripping.
        guard let data = html.data(using: .utf8) else { return "" }
        let opts: [NSAttributedString.DocumentReadingOptionKey: Any] = [
            .documentType: NSAttributedString.DocumentType.html,
            .characterEncoding: String.Encoding.utf8.rawValue
        ]
        let attributed = (try? NSAttributedString(data: data, options: opts, documentAttributes: nil))
        let raw = attributed?.string ?? html
        return raw
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    private static func plainTextToSteps(_ text: String) -> [String] {
        let lines = text
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        // Keep it readable: cap to a reasonable number of steps.
        return Array(lines.prefix(12))
    }

    // MARK: - Local catalog helpers

    func localCatalogCount() -> Int {
        guard localCatalogEnabled, let ctx = modelContext else { return 0 }
        return (try? ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? 0
    }

    @MainActor
    func searchLocalExercises(query: String, limit: Int = 50) async throws -> [Exercise] {
        guard localCatalogEnabled, let ctx = modelContext else { throw CatalogError.notConfigured }
        let count = (try? ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? 0
        if count == 0 {
            await ensureLocalCatalogImportedIfNeeded()
        }
        let after = (try? ctx.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? 0
        guard after > 0 else { throw CatalogError.emptyCatalog }

        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rows = (try? ctx.fetch(FetchDescriptor<ExerciseCatalogEntry>())) ?? []
        let filtered = q.isEmpty ? rows : rows.filter { row in
            row.nameEs.lowercased().contains(q) ||
            (row.nameEn?.lowercased().contains(q) ?? false) ||
            (row.descriptionEs?.lowercased().contains(q) ?? false) ||
            (row.descriptionEn?.lowercased().contains(q) ?? false) ||
            (row.equipmentCSV?.lowercased().contains(q) ?? false) ||
            (row.primaryMusclesCSV?.lowercased().contains(q) ?? false) ||
            (row.secondaryMusclesCSV?.lowercased().contains(q) ?? false)
        }
        return Array(filtered.prefix(limit)).map { Self.rowToExercise($0) }
    }

    func resolveLocalExerciseName(wgerUuid: String) -> String? {
        guard localCatalogEnabled, let ctx = modelContext else { return nil }
        let key = wgerUuid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        let fd = FetchDescriptor<ExerciseCatalogEntry>(predicate: #Predicate { $0.wgerUuid == key })
        let row = (try? ctx.fetch(fd))?.first
        return row?.nameEs.isEmpty == false ? row?.nameEs : row?.nameEn
    }

    private static func rowToExercise(_ row: ExerciseCatalogEntry) -> Exercise {
        let name = row.nameEs.isEmpty ? (row.nameEn ?? "Ejercicio") : row.nameEs
        let desc = row.descriptionEs ?? row.descriptionEn
        let steps = (row.instructionsEs ?? row.instructionsEn)?.split(separator: "\n").map(String.init)
        
        return Exercise(
            id: row.wgerUuid,
            name: name,
            bodyPart: MuscleGroup(rawValue: row.muscleGroupRaw)?.apiBodyPart ?? "waist",
            target: row.wgerCategoryName ?? "",
            equipment: row.equipmentCSV ?? "none",
            gifUrl: row.imageUrl,
            instructions: steps,
            description: desc,
            difficulty: nil,
            category: row.wgerCategoryName,
            secondaryMuscles: row.secondaryMusclesCSV?.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        )
    }
}

// MARK: - Static helpers (shared with importer)

extension ExerciseService {
    static func htmlToPlainTextStatic(_ html: String) -> String { htmlToPlainText(html) }
    static func plainTextToStepsStatic(_ text: String) -> [String] { plainTextToSteps(text) }

    static func mapBodyPartToMuscleGroupRaw(_ bodyPart: String) -> String {
        let b = bodyPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch b {
        case "chest": return MuscleGroup.chest.rawValue
        case "back": return MuscleGroup.back.rawValue
        case "shoulders": return MuscleGroup.shoulders.rawValue
        case "waist": return MuscleGroup.core.rawValue
        case "upper arms": return MuscleGroup.biceps.rawValue
        case "upper legs": return MuscleGroup.quads.rawValue
        case "lower legs": return MuscleGroup.calves.rawValue
        default: return MuscleGroup.core.rawValue
        }
    }
}
