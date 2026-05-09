//
//  ExerciseCatalogImporter.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData
import os

/// Imports wger exercises into the local SwiftData catalog.
///
/// Designed for:
/// - Offline-first usage (query local DB)
/// - Future Firebase mirroring (own UUID + keep wgerUuid)
final class ExerciseCatalogImporter {

    private let baseURL: String
    private let session: URLSession
    private let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseCatalogImporter")

    init(baseURL: String = "https://wger.de/api/v2", session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    // MARK: - Public

    /// Imports the whole catalog (paged) into SwiftData.
    /// Safe to call multiple times: it upserts by `wgerUuid`.
    func importAll(
        into context: ModelContext,
        preferredLanguageId: Int = 4, // ES
        fallbackLanguageId: Int = 2,  // EN (commonly 2 in wger instances, but we treat it as optional)
        limitPerPage: Int = 200,
        maxPages: Int = 200,
        wipeExisting: Bool = false
    ) async throws {
        if wipeExisting {
            let existing = (try? context.fetch(FetchDescriptor<ExerciseCatalogEntry>())) ?? []
            for row in existing { context.delete(row) }
            try context.save()
        }

        // Primary strategy (stable): import from the wger GitHub fixtures (no dependency on wger.de uptime).
        // Fallback strategy: attempt live API if desired (baseURL points to /api/v2).
        if baseURL.contains("raw.githubusercontent.com") {
            try await importFromGitFixtures(into: context, preferredLanguageId: preferredLanguageId, fallbackLanguageId: fallbackLanguageId)
        } else {
            // If wger.de is down, this will fail; callers should prefer the Git fixtures base URL.
            try await importFromLiveAPI(into: context, preferredLanguageId: preferredLanguageId, fallbackLanguageId: fallbackLanguageId, limitPerPage: limitPerPage, maxPages: maxPages)
        }
    }

    // MARK: - Git fixtures import (recommended)

    /// Imports from the wger repo fixtures:
    /// - `exercise-base-data.json` (exercise uuids, category ids, muscles, equipment)
    /// - `translations.json` (names + descriptions by language)
    /// - `categories.json`, `equipment.json`, `muscles.json` (lookup tables)
    private func importFromGitFixtures(
        into context: ModelContext,
        preferredLanguageId: Int,
        fallbackLanguageId: Int
    ) async throws {
        let fixtures = baseURL.trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        func u(_ name: String) -> URL {
            URL(string: "\(fixtures)/\(name)")!
        }

        async let baseData = fetch(url: u("exercise-base-data.json"), retries: 3)
        async let translationsData = fetch(url: u("translations.json"), retries: 3)
        async let categoriesData = fetch(url: u("categories.json"), retries: 3)
        async let equipmentData = fetch(url: u("equipment.json"), retries: 3)
        async let musclesData = fetch(url: u("muscles.json"), retries: 3)

        let decoder = JSONDecoder()

        // NOTE: exercise-base-data.json and translations.json contain multiple models with different field sets.
        // Decoding them as a single typed fixture fails with “missing data” for the other models.
        let baseAny = try Self.parseFixtureJSONArray(try await baseData)
        let translationsAny = try Self.parseFixtureJSONArray(try await translationsData)

        let categories = try decoder.decode([Fixture<CategoryFields>].self, from: try await categoriesData)
        let equipment = try decoder.decode([Fixture<EquipmentFields>].self, from: try await equipmentData)
        let muscles = try decoder.decode([Fixture<MuscleFields>].self, from: try await musclesData)

        let categoryById: [Int: String] = Dictionary(uniqueKeysWithValues: categories.map { ($0.pk, $0.fields.name) })
        let equipmentById: [Int: String] = Dictionary(uniqueKeysWithValues: equipment.map { ($0.pk, $0.fields.name) })
        let muscleById: [Int: String] = Dictionary(uniqueKeysWithValues: muscles.map { ($0.pk, $0.fields.nameEn.isEmpty ? $0.fields.name : $0.fields.nameEn) })

        // Build translation index for ES + EN.
        var transEs: [Int: (name: String, description: String)] = [:]
        var transEn: [Int: (name: String, description: String)] = [:]
        for item in translationsAny where item.model == "exercises.translation" {
            guard
                let exercisePk = item.fields["exercise"] as? Int,
                let lang = item.fields["language"] as? Int,
                let name = item.fields["name"] as? String,
                let description = item.fields["description"] as? String
            else { continue }
            if lang == preferredLanguageId {
                transEs[exercisePk] = (name: name, description: description)
            } else if lang == fallbackLanguageId {
                transEn[exercisePk] = (name: name, description: description)
            }
        }

        // Import all exercises that have at least EN translation.
        let expected = baseAny
            .filter { $0.model == "exercises.exercise" }
            .compactMap { $0.pk }
            .filter { transEn[$0] != nil || transEs[$0] != nil }
            .count
        var insertedOrUpdated = 0

        for ex in baseAny where ex.model == "exercises.exercise" {
            guard let pk = ex.pk else { continue }
            guard let uuidRaw = ex.fields["uuid"] as? String else { continue }
            let uuid = uuidRaw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !uuid.isEmpty else { continue }

            // Prefer ES; fallback to EN for catalog completeness.
            let esT = transEs[pk]
            let enT = transEn[pk]
            guard esT != nil || enT != nil else { continue }

            let nameEs = esT?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let descEsPlain = esT.map { ExerciseService.htmlToPlainTextStatic($0.description) } ?? ""
            let stepsEs = ExerciseService.plainTextToStepsStatic(descEsPlain)
            let instructionsEs = stepsEs.isEmpty ? nil : stepsEs.joined(separator: "\n")

            let nameEn = enT?.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let descEnPlain = enT.map { ExerciseService.htmlToPlainTextStatic($0.description) }
            let stepsEn = descEnPlain.map { ExerciseService.plainTextToStepsStatic($0) } ?? []
            let instructionsEn = stepsEn.isEmpty ? nil : stepsEn.joined(separator: "\n")

            let needsEs = (nameEs?.isEmpty != false) && (nameEn?.isEmpty == false)

            let equipmentIds = (ex.fields["equipment"] as? [Int]) ?? []
            let equipmentNames = equipmentIds.compactMap { equipmentById[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let equipmentCSV = equipmentNames.isEmpty ? nil : equipmentNames.joined(separator: ", ")

            let primaryIds = (ex.fields["muscles"] as? [Int]) ?? []
            let secondaryIds = (ex.fields["muscles_secondary"] as? [Int]) ?? []
            let primaryNames = primaryIds.compactMap { muscleById[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
            let secondaryNames = secondaryIds.compactMap { muscleById[$0]?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }

            let categoryId = (ex.fields["category"] as? Int) ?? 0
            let categoryName = categoryById[categoryId]?.trimmingCharacters(in: .whitespacesAndNewlines)
            let muscleGroupRaw = Self.mapToAppMuscleGroupRaw(primary: primaryNames, secondary: secondaryNames, categoryName: categoryName)

            let fetch = FetchDescriptor<ExerciseCatalogEntry>(predicate: #Predicate { $0.wgerUuid == uuid })
            let existing = (try? context.fetch(fetch))?.first

            if let row = existing {
                row.muscleGroupRaw = muscleGroupRaw
                // If ES is missing, keep ES fields empty so UI falls back to EN without showing "Ejercicio".
                row.nameEs = (nameEs?.isEmpty == false ? nameEs! : "")
                row.descriptionEs = descEsPlain.isEmpty ? nil : descEsPlain
                row.instructionsEs = instructionsEs
                row.nameEn = (nameEn?.isEmpty == false ? nameEn : nil)
                row.descriptionEn = (descEnPlain?.isEmpty == false ? descEnPlain : nil)
                row.instructionsEn = instructionsEn
                row.wgerCategoryId = categoryId
                row.wgerCategoryName = categoryName
                row.equipmentCSV = equipmentCSV
                row.primaryMusclesCSV = primaryNames.isEmpty ? nil : primaryNames.joined(separator: ", ")
                row.secondaryMusclesCSV = secondaryNames.isEmpty ? nil : secondaryNames.joined(separator: ", ")
                row.imageUrl = nil
                row.needsEsTranslation = needsEs
                row.updatedAt = Date()
            } else {
                let row = ExerciseCatalogEntry(
                    wgerUuid: uuid,
                    muscleGroupRaw: muscleGroupRaw,
                    nameEs: (nameEs?.isEmpty == false ? nameEs! : ""),
                    descriptionEs: descEsPlain.isEmpty ? nil : descEsPlain,
                    instructionsEs: instructionsEs,
                    nameEn: (nameEn?.isEmpty == false ? nameEn : nil),
                    descriptionEn: (descEnPlain?.isEmpty == false ? descEnPlain : nil),
                    instructionsEn: instructionsEn,
                    wgerCategoryId: categoryId,
                    wgerCategoryName: categoryName,
                    equipmentCSV: equipmentCSV,
                    primaryMusclesCSV: primaryNames.isEmpty ? nil : primaryNames.joined(separator: ", "),
                    secondaryMusclesCSV: secondaryNames.isEmpty ? nil : secondaryNames.joined(separator: ", "),
                    imageUrl: nil,
                    videoUrl: nil,
                    needsEsTranslation: needsEs,
                    translationRequestedAt: nil
                )
                context.insert(row)
            }

            insertedOrUpdated += 1
        }

        try context.save()
        let actual = (try? context.fetchCount(FetchDescriptor<ExerciseCatalogEntry>())) ?? -1
        if actual >= 0, actual < expected {
            logger.error("importFromGitFixtures incomplete: expected=\(expected), actual=\(actual), upserted=\(insertedOrUpdated)")
            throw NSError(
                domain: "ExerciseCatalogImporter",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Import incompleto: expected=\(expected) actual=\(actual)"]
            )
        }
        logger.info("importFromGitFixtures done: expected=\(expected), actual=\(actual), upserted=\(insertedOrUpdated)")
    }

    // MARK: - Fixture parsing (loose)

    private struct AnyFixture {
        let model: String
        let pk: Int?
        let fields: [String: Any]
    }

    private static func parseFixtureJSONArray(_ data: Data) throws -> [AnyFixture] {
        let obj = try JSONSerialization.jsonObject(with: data, options: [])
        guard let arr = obj as? [[String: Any]] else {
            throw NSError(domain: "ExerciseCatalogImporter", code: 2, userInfo: [NSLocalizedDescriptionKey: "Fixture JSON is not an array"])
        }
        return arr.map { dict in
            AnyFixture(
                model: dict["model"] as? String ?? "",
                pk: dict["pk"] as? Int,
                fields: dict["fields"] as? [String: Any] ?? [:]
            )
        }
    }

    // MARK: - Live API import (fallback / optional)

    private func importFromLiveAPI(
        into context: ModelContext,
        preferredLanguageId: Int,
        fallbackLanguageId: Int,
        limitPerPage: Int,
        maxPages: Int
    ) async throws {
        var nextUrl: String? = "\(baseURL)/exerciseinfo/?limit=\(limitPerPage)"
        var page = 0
        let decoder = JSONDecoder()

        while let urlString = nextUrl, let url = URL(string: urlString) {
            page += 1
            if page > maxPages {
                logger.info("importFromLiveAPI: reached maxPages=\(maxPages); stopping")
                break
            }
            let data = try await fetch(url: url, retries: 3)
            let payload = try decoder.decode(WgerPage<WgerExerciseInfo>.self, from: data)
            for info in payload.results {
                upsert(info: info, into: context, preferredLanguageId: preferredLanguageId, fallbackLanguageId: fallbackLanguageId)
            }
            try context.save()
            nextUrl = payload.next
        }
    }

    // MARK: - Upsert

    private func upsert(
        info: WgerExerciseInfo,
        into context: ModelContext,
        preferredLanguageId: Int,
        fallbackLanguageId: Int
    ) {
        let uuid = info.uuid.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !uuid.isEmpty else { return }

        let es = pickTranslation(info.translations, preferred: preferredLanguageId)
        let en = pickTranslation(info.translations, preferred: fallbackLanguageId)

        let nameEs = (es?.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 } ?? "Ejercicio"
        let descEsPlain = ExerciseService.htmlToPlainTextStatic(es?.description ?? "")
        let stepsEs = ExerciseService.plainTextToStepsStatic(descEsPlain)
        let instructionsEs = stepsEs.isEmpty ? nil : stepsEs.joined(separator: "\n")

        let nameEn = (en?.name?.trimmingCharacters(in: .whitespacesAndNewlines)).flatMap { $0.isEmpty ? nil : $0 }
        let descEnPlain = en == nil ? nil : ExerciseService.htmlToPlainTextStatic(en?.description ?? "")
        let stepsEn = descEnPlain.map { ExerciseService.plainTextToStepsStatic($0) } ?? []
        let instructionsEn = stepsEn.isEmpty ? nil : stepsEn.joined(separator: "\n")

        let equipmentCSV = info.equipment
            .map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")

        let imageUrl = info.images.first(where: { $0.isMain })?.image ?? info.images.first?.image

        // Map to our current 10 muscle groups using wger category name as a best-effort baseline.
        // We can refine with real muscle ids once we add an enrichment pass.
        let mapped = Self.mapCategoryNameToMuscleGroupRaw(info.category.name)

        let fetch = FetchDescriptor<ExerciseCatalogEntry>(
            predicate: #Predicate { $0.wgerUuid == uuid },
            sortBy: []
        )
        let existing = (try? context.fetch(fetch))?.first

        if let row = existing {
            row.muscleGroupRaw = mapped
            row.nameEs = nameEs
            row.descriptionEs = descEsPlain.isEmpty ? nil : descEsPlain
            row.instructionsEs = instructionsEs
            row.nameEn = nameEn
            row.descriptionEn = (descEnPlain?.isEmpty == false ? descEnPlain : nil)
            row.instructionsEn = instructionsEn
            row.wgerCategoryId = info.category.id
            row.wgerCategoryName = info.category.name
            row.equipmentCSV = equipmentCSV.isEmpty ? nil : equipmentCSV
            row.imageUrl = imageUrl
            row.updatedAt = Date()
        } else {
            let row = ExerciseCatalogEntry(
                wgerUuid: uuid,
                muscleGroupRaw: mapped,
                nameEs: nameEs,
                descriptionEs: descEsPlain.isEmpty ? nil : descEsPlain,
                instructionsEs: instructionsEs,
                nameEn: nameEn,
                descriptionEn: (descEnPlain?.isEmpty == false ? descEnPlain : nil),
                instructionsEn: instructionsEn,
                wgerCategoryId: info.category.id,
                wgerCategoryName: info.category.name,
                equipmentCSV: equipmentCSV.isEmpty ? nil : equipmentCSV,
                imageUrl: imageUrl
            )
            context.insert(row)
        }
    }

    private func pickTranslation(_ list: [WgerTranslation], preferred: Int) -> WgerTranslation? {
        list.first(where: { $0.language == preferred }) ?? list.first
    }

    // MARK: - Network

    private func fetch(url: URL, retries: Int) async throws -> Data {
        var attempt = 0
        var lastError: Error?
        while attempt <= retries {
            attempt += 1
            do {
                var req = URLRequest(url: url)
                req.httpMethod = "GET"
                req.timeoutInterval = 30
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse else { return data }
                guard (200..<300).contains(http.statusCode) else {
                    throw NSError(domain: "wger", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
                }
                return data
            } catch {
                lastError = error
                try await Task.sleep(nanoseconds: UInt64(250_000_000 * attempt)) // backoff
            }
        }
        throw lastError ?? NSError(domain: "wger", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown fetch error"])
    }

    // MARK: - Mapping

    /// Best-effort mapping for initial import.
    /// We refine later by enriching with wger muscle IDs.
    static func mapCategoryNameToMuscleGroupRaw(_ categoryName: String) -> String {
        let n = categoryName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if n.contains("chest") || n.contains("pecho") { return MuscleGroup.chest.rawValue }
        if n.contains("back") || n.contains("espalda") { return MuscleGroup.back.rawValue }
        if n.contains("shoulder") || n.contains("homb") { return MuscleGroup.shoulders.rawValue }
        if n.contains("biceps") { return MuscleGroup.biceps.rawValue }
        if n.contains("triceps") { return MuscleGroup.triceps.rawValue }
        if n.contains("calf") || n.contains("pantorr") { return MuscleGroup.calves.rawValue }
        if n.contains("abs") || n.contains("core") || n.contains("waist") || n.contains("abdom") { return MuscleGroup.core.rawValue }
        if n.contains("leg") || n.contains("pierna") || n.contains("thigh") {
            // Default legs mapping to quads; app already differentiates in plan logic by muscle group,
            // but the catalog can be refined later by muscle IDs.
            return MuscleGroup.quads.rawValue
        }
        return MuscleGroup.core.rawValue
    }

    static func mapToAppMuscleGroupRaw(primary: [String], secondary: [String], categoryName: String?) -> String {
        let all = (primary + secondary).map { $0.lowercased() }
        func has(_ needle: String) -> Bool { all.contains(where: { $0.contains(needle) }) }

        if has("pector") || has("chest") { return MuscleGroup.chest.rawValue }
        if has("lat") || has("lats") || has("back") || has("trapezius") || has("lower back") { return MuscleGroup.back.rawValue }
        if has("deltoid") || has("shoulder") { return MuscleGroup.shoulders.rawValue }
        if has("biceps") { return MuscleGroup.biceps.rawValue }
        if has("triceps") { return MuscleGroup.triceps.rawValue }
        if has("glute") { return MuscleGroup.glutes.rawValue }
        if has("hamstring") || has("biceps femoris") { return MuscleGroup.hamstrings.rawValue }
        if has("quad") || has("quadriceps") { return MuscleGroup.quads.rawValue }
        if has("calf") || has("gastrocnemius") || has("soleus") { return MuscleGroup.calves.rawValue }
        if has("abs") || has("abdom") || has("obliqu") || has("serratus") { return MuscleGroup.core.rawValue }

        if let categoryName {
            return mapCategoryNameToMuscleGroupRaw(categoryName)
        }
        return MuscleGroup.core.rawValue
    }

    // MARK: - DTOs (wger)

    private struct Fixture<T: Decodable>: Decodable {
        let model: String
        let pk: Int
        let fields: T
    }

    private struct ExerciseFields: Decodable {
        let uuid: String
        let category: Int
        let muscles: [Int]
        let musclesSecondary: [Int]
        let equipment: [Int]

        enum CodingKeys: String, CodingKey {
            case uuid, category, muscles, equipment
            case musclesSecondary = "muscles_secondary"
        }
    }

    private struct TranslationFields: Decodable {
        let description: String
        let name: String
        let language: Int
        let uuid: String
        let exercise: Int
    }

    private struct CategoryFields: Decodable {
        let name: String
    }

    private struct EquipmentFields: Decodable {
        let name: String
    }

    private struct MuscleFields: Decodable {
        let name: String
        let isFront: Bool
        let nameEn: String

        enum CodingKeys: String, CodingKey {
            case name
            case isFront = "is_front"
            case nameEn = "name_en"
        }
    }

    private struct WgerPage<T: Decodable>: Decodable {
        let count: Int
        let next: String?
        let previous: String?
        let results: [T]
    }

    private struct WgerCategory: Decodable {
        let id: Int
        let name: String
    }

    private struct WgerEquipment: Decodable {
        let id: Int
        let name: String
    }

    private struct WgerImage: Decodable {
        let id: Int
        let image: String
        let isMain: Bool
        let exerciseUUID: String

        enum CodingKeys: String, CodingKey {
            case id, image
            case isMain = "is_main"
            case exerciseUUID = "exercise_uuid"
        }
    }

    private struct WgerTranslation: Decodable {
        let id: Int
        let language: Int
        let name: String?
        let description: String?
    }

    private struct WgerExerciseInfo: Decodable {
        let id: Int
        let uuid: String
        let category: WgerCategory
        let equipment: [WgerEquipment]
        let images: [WgerImage]
        let translations: [WgerTranslation]
    }
}

