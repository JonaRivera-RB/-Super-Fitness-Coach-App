//
//  ExerciseService.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os
import UIKit

@Observable
final class ExerciseService {

    static let shared = ExerciseService()

    // MARK: - Private

    @ObservationIgnored private let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseService")
    @ObservationIgnored private let baseURL = "https://wger.de/api/v2"
    @ObservationIgnored private let session: URLSession

    /// Cached fallback exercises loaded from the bundled JSON file.
    @ObservationIgnored private var cachedFallbackExercises: [Exercise] = []

    /// Cached index: exercise_uuid → image url (prefers main images).
    @ObservationIgnored private var cachedWgerImageIndex: [String: String] = [:]
    @ObservationIgnored private var didLoadWgerImageIndex: Bool = false
    /// Cached name index: exercise uuid → display name (Spanish when available).
    @ObservationIgnored private var cachedWgerNameIndex: [String: String] = [:]

    /// In-memory cache for fetched lists: key(bodyPart|equipment) → exercises.
    @ObservationIgnored private var cachedFetchLists: [String: [Exercise]] = [:]

    // MARK: - Init

    init(
        session: URLSession = .shared,
        bundle: Bundle = .main
    ) {
        self.session = session
        self.cachedFallbackExercises = Self.loadBundledExercises(from: bundle)
    }

    // MARK: - Fetch Exercises

    /// Fetch exercises from wger API, filtered by body part category, with optional equipment filter.
    /// Uses Spanish translations when available (language=4).
    /// Falls back to bundled local exercises on any network or parsing error.
    func fetchExercises(bodyPart: String, equipment: String?) async throws -> [Exercise] {
        let cacheKey = "\(bodyPart.lowercased())|\(equipment?.lowercased() ?? "")"
        if let cached = cachedFetchLists[cacheKey], !cached.isEmpty {
            return cached
        }

        let categoryId = wgerCategoryId(forBodyPart: bodyPart)
        guard categoryId != nil else {
            logger.error("Unsupported bodyPart for wger mapping: \(bodyPart)")
            return fallbackExercises(bodyPart: bodyPart)
        }

        do {
            // Ensure we have an image index (344 images total, light enough to cache).
            if !didLoadWgerImageIndex {
                cachedWgerImageIndex = (try? await fetchWgerImageIndex(limitPerPage: 200)) ?? [:]
                didLoadWgerImageIndex = true
            }

            let infos = try await fetchAllExerciseInfo(categoryId: categoryId!, languageId: 4, limitPerPage: 200, maxTotal: 260)
            var exercises = infos.map { info in
                let translation = info.translations.first(where: { $0.language == 4 }) ?? info.translations.first
                let name = translation?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
                let descHtml = translation?.description
                let plain = Self.htmlToPlainText(descHtml ?? "")
                let steps = Self.plainTextToSteps(plain)

                let imageUrl = cachedWgerImageIndex[info.uuid]

                return Exercise(
                    id: info.uuid,
                    name: (name?.isEmpty == false ? name! : "Ejercicio"),
                    bodyPart: bodyPart,
                    target: info.category.name,
                    equipment: info.equipment.first?.name ?? "none",
                    gifUrl: imageUrl,
                    instructions: steps.isEmpty ? nil : steps,
                    description: plain.isEmpty ? nil : plain,
                    difficulty: nil,
                    category: nil,
                    secondaryMuscles: nil
                )
            }

            if let equipment {
                exercises = exercises.filter { $0.equipment.localizedCaseInsensitiveCompare(equipment) == .orderedSame }
            }

            let final = exercises.isEmpty ? fallbackExercises(bodyPart: bodyPart) : exercises
            cachedFetchLists[cacheKey] = final
            return final
        } catch {
            logger.error("wger fetch failed: \(error.localizedDescription)")
            return fallbackExercises(bodyPart: bodyPart)
        }
    }

    // MARK: - JSON Serialization

    /// Parse a JSON data blob into an array of Exercise objects.
    static func parseExercises(from data: Data) throws -> [Exercise] {
        let decoder = JSONDecoder()
        return try decoder.decode([Exercise].self, from: data)
    }

    /// Encode an array of Exercise objects into JSON data.
    static func encodeExercises(_ exercises: [Exercise]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        return try encoder.encode(exercises)
    }

    // MARK: - wger (ExerciseInfo)

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

    // MARK: - Public helpers

    /// Resolve a human-friendly exercise name for a stored uuid.
    /// - Note: The app stores wger `exerciseinfo.uuid` as Exercise.id.
    func resolveExerciseName(exerciseId: String) async -> String? {
        let key = exerciseId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty else { return nil }
        if let cached = cachedWgerNameIndex[key] { return cached }

        // Fallback to bundled catalog if this id exists there.
        if let bundled = bundledExercise(withId: key)?.name {
            cachedWgerNameIndex[key] = bundled
            return bundled
        }

        // Fetch by uuid from wger.
        guard let info = try? await fetchExerciseInfoByUUID(uuid: key, languageId: 4) else { return nil }
        let translation = info.translations.first(where: { $0.language == 4 }) ?? info.translations.first
        let name = translation?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let name, !name.isEmpty else { return nil }
        cachedWgerNameIndex[key] = name
        return name
    }

    private func fetchExerciseInfoByUUID(uuid: String, languageId: Int) async throws -> WgerExerciseInfo? {
        let urlString = "\(baseURL)/exerciseinfo/?language=\(languageId)&limit=1&uuid=\(uuid)"
        guard let url = URL(string: urlString) else { return nil }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }
        let page = try JSONDecoder().decode(WgerPage<WgerExerciseInfo>.self, from: data)
        return page.results.first
    }

    /// Builds uuid → image URL. Must not paginate unbounded or "Generar plan" blocks on first network fetch.
    private func fetchWgerImageIndex(limitPerPage: Int, maxPages: Int = 6) async throws -> [String: String] {
        var index: [String: (url: String, isMain: Bool)] = [:]
        var nextUrl: String? = "\(baseURL)/exerciseimage/?limit=\(limitPerPage)"

        let decoder = JSONDecoder()
        var pageCount = 0

        while let urlString = nextUrl, let url = URL(string: urlString) {
            pageCount += 1
            if pageCount > maxPages {
                logger.info("fetchWgerImageIndex: stopping at maxPages=\(maxPages) (~\(limitPerPage * maxPages) entries)")
                break
            }

            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { break }
            guard http.statusCode == 200 else {
                throw NSError(domain: "wger", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }

            let page = try decoder.decode(WgerPage<WgerImage>.self, from: data)
            for img in page.results {
                let key = img.exerciseUUID
                if let existing = index[key] {
                    // Prefer is_main; otherwise keep first.
                    if !existing.isMain && img.isMain {
                        index[key] = (img.image, true)
                    }
                } else {
                    index[key] = (img.image, img.isMain)
                }
            }
            nextUrl = page.next
        }

        return index.mapValues { $0.url }
    }

    private func fetchAllExerciseInfo(categoryId: Int, languageId: Int, limitPerPage: Int, maxTotal: Int) async throws -> [WgerExerciseInfo] {
        var all: [WgerExerciseInfo] = []
        var nextUrl: String? = "\(baseURL)/exerciseinfo/?language=\(languageId)&category=\(categoryId)&limit=\(limitPerPage)"

        let decoder = JSONDecoder()

        while let urlString = nextUrl, let url = URL(string: urlString) {
            var request = URLRequest(url: url)
            request.httpMethod = "GET"
            request.timeoutInterval = 20

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { break }
            guard http.statusCode == 200 else {
                throw NSError(domain: "wger", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(http.statusCode)"])
            }

            let page = try decoder.decode(WgerPage<WgerExerciseInfo>.self, from: data)
            all.append(contentsOf: page.results)
            nextUrl = page.next

            // Safety: cap per category for responsiveness.
            if all.count >= max(40, maxTotal) { break }
        }

        return all
    }

    /// Maps existing ExerciseDB-like bodyPart strings to wger category ids.
    /// This keeps existing app logic intact while switching data source.
    private func wgerCategoryId(forBodyPart bodyPart: String) -> Int? {
        switch bodyPart.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "chest": return 11
        case "back": return 12
        case "shoulders": return 13
        case "waist": return 10
        case "upper arms": return 8
        case "upper legs": return 9
        case "lower legs": return 14
        default: return nil
        }
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

    // MARK: - Fallback Exercises

    /// Return bundled local exercises filtered by body part.
    func fallbackExercises(bodyPart: String) -> [Exercise] {
        cachedFallbackExercises.filter {
            $0.bodyPart.lowercased() == bodyPart.lowercased()
        }
    }

    /// Local search over the bundled fallback catalog (offline).
    func searchBundledExercises(query: String, limit: Int = 50) -> [Exercise] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return Array(cachedFallbackExercises.prefix(limit)) }

        let matches = cachedFallbackExercises.filter { ex in
            ex.name.lowercased().contains(q) ||
            ex.bodyPart.lowercased().contains(q) ||
            ex.target.lowercased().contains(q) ||
            ex.equipment.lowercased().contains(q)
        }
        return Array(matches.prefix(limit))
    }

    func bundledEquipments() -> [String] {
        Array(Set(cachedFallbackExercises.map { $0.equipment }))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    /// Resuelve un ejercicio del catálogo local por ID (para sustitutos guardados).
    func bundledExercise(withId id: String) -> Exercise? {
        cachedFallbackExercises.first { $0.id == id }
    }

    func bundledBodyParts() -> [String] {
        Array(Set(cachedFallbackExercises.map { $0.bodyPart }))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    // MARK: - Private Helpers

    /// Load exercises from the bundled fallback_exercises.json file.
    private static func loadBundledExercises(from bundle: Bundle = .main) -> [Exercise] {
        guard let url = bundle.url(forResource: "fallback_exercises", withExtension: "json") else {
            let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseService")
            logger.error("fallback_exercises.json not found in bundle")
            return []
        }

        do {
            let data = try Data(contentsOf: url)
            return try parseExercises(from: data)
        } catch {
            let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseService")
            logger.error("Failed to load fallback exercises: \(error.localizedDescription)")
            return []
        }
    }

}
