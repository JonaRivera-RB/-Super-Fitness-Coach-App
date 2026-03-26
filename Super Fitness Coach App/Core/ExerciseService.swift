//
//  ExerciseService.swift
//  Super Fitness Coach App
//

import Foundation
import Observation
import os

@Observable
final class ExerciseService {

    // MARK: - Private

    @ObservationIgnored private let logger = Logger(subsystem: "com.superfitness.coach", category: "ExerciseService")
    @ObservationIgnored private let baseURL = "https://exercisedb.p.rapidapi.com"
    @ObservationIgnored private let apiKey: String
    @ObservationIgnored private let apiHost: String
    @ObservationIgnored private let session: URLSession

    /// Cached fallback exercises loaded from the bundled JSON file.
    @ObservationIgnored private var cachedFallbackExercises: [Exercise] = []

    // MARK: - Init

    init(
        apiKey: String = "",
        apiHost: String = "exercisedb.p.rapidapi.com",
        session: URLSession = .shared,
        bundle: Bundle = .main
    ) {
        self.apiKey = apiKey
        self.apiHost = apiHost
        self.session = session
        self.cachedFallbackExercises = Self.loadBundledExercises(from: bundle)
    }

    // MARK: - Fetch Exercises

    /// Fetch exercises from ExerciseDB API filtered by body part, with optional equipment filter.
    /// Falls back to bundled local exercises on any network or parsing error.
    func fetchExercises(bodyPart: String, equipment: String?) async throws -> [Exercise] {
        let encodedBodyPart = bodyPart.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? bodyPart
        let urlString = "\(baseURL)/exercises/bodyPart/\(encodedBodyPart)"

        guard let url = URL(string: urlString) else {
            logger.error("Invalid URL: \(urlString)")
            return fallbackExercises(bodyPart: bodyPart)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(apiKey, forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(apiHost, forHTTPHeaderField: "X-RapidAPI-Host")
        request.timeoutInterval = 15

        let data: Data
        let response: URLResponse

        do {
            (data, response) = try await session.data(for: request)
        } catch {
            logger.error("Network error fetching exercises: \(error.localizedDescription)")
            return fallbackExercises(bodyPart: bodyPart)
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.error("Invalid response type")
            return fallbackExercises(bodyPart: bodyPart)
        }

        guard httpResponse.statusCode == 200 else {
            logger.error("Non-200 status code: \(httpResponse.statusCode)")
            return fallbackExercises(bodyPart: bodyPart)
        }

        do {
            var exercises = try Self.parseExercises(from: data)

            // Filter by equipment if specified
            if let equipment = equipment {
                exercises = exercises.filter {
                    $0.equipment.lowercased() == equipment.lowercased()
                }
            }

            return exercises
        } catch {
            logger.error("JSON parsing error: \(error.localizedDescription)")
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
