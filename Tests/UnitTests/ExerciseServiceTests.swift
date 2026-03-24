//
//  ExerciseServiceTests.swift
//  Super Fitness Coach App
//

import Testing
import Foundation
@testable import Super_Fitness_Coach_App

struct ExerciseServiceTests {

    // MARK: - parseExercises

    @Test func parseExercisesValidJSON() throws {
        let json = """
        [
            {
                "id": "0001",
                "name": "Bench Press",
                "bodyPart": "chest",
                "target": "pectorals",
                "equipment": "barbell",
                "gifUrl": "https://example.com/bench.gif"
            }
        ]
        """.data(using: .utf8)!

        let exercises = try ExerciseService.parseExercises(from: json)
        #expect(exercises.count == 1)
        #expect(exercises[0].id == "0001")
        #expect(exercises[0].name == "Bench Press")
        #expect(exercises[0].bodyPart == "chest")
        #expect(exercises[0].target == "pectorals")
        #expect(exercises[0].equipment == "barbell")
        #expect(exercises[0].gifUrl == "https://example.com/bench.gif")
    }

    @Test func parseExercisesWithoutGifUrl() throws {
        let json = """
        [
            {
                "id": "0002",
                "name": "Squat",
                "bodyPart": "upper legs",
                "target": "quads",
                "equipment": "barbell",
                "instructions": ["Stand with feet shoulder-width apart.", "Lower your body."],
                "difficulty": "intermediate"
            }
        ]
        """.data(using: .utf8)!

        let exercises = try ExerciseService.parseExercises(from: json)
        #expect(exercises.count == 1)
        #expect(exercises[0].gifUrl == nil)
        #expect(exercises[0].instructions?.count == 2)
        #expect(exercises[0].difficulty == "intermediate")
    }

    @Test func parseExercisesMalformedJSONThrows() {
        let badJSON = "not valid json".data(using: .utf8)!
        #expect(throws: (any Error).self) {
            try ExerciseService.parseExercises(from: badJSON)
        }
    }

    @Test func parseExercisesEmptyArray() throws {
        let json = "[]".data(using: .utf8)!
        let exercises = try ExerciseService.parseExercises(from: json)
        #expect(exercises.isEmpty)
    }

    // MARK: - encodeExercises

    @Test func encodeExercisesRoundTrip() throws {
        let original = Exercise(
            id: "0042",
            name: "Squat",
            bodyPart: "upper legs",
            target: "quads",
            equipment: "barbell",
            gifUrl: "https://example.com/squat.gif",
            instructions: ["Step 1", "Step 2"]
        )

        let data = try ExerciseService.encodeExercises([original])
        let decoded = try ExerciseService.parseExercises(from: data)

        #expect(decoded.count == 1)
        #expect(decoded[0] == original)
    }

    @Test func encodeExercisesMultiple() throws {
        let exercises = [
            Exercise(id: "1", name: "A", bodyPart: "chest", target: "pecs", equipment: "barbell"),
            Exercise(id: "2", name: "B", bodyPart: "back", target: "lats", equipment: "cable")
        ]

        let data = try ExerciseService.encodeExercises(exercises)
        let decoded = try ExerciseService.parseExercises(from: data)

        #expect(decoded == exercises)
    }

    // MARK: - fallbackExercises

    @Test func fallbackExercisesFiltersByBodyPart() {
        let service = ExerciseService()
        let result = service.fallbackExercises(bodyPart: "chest")
        for exercise in result {
            #expect(exercise.bodyPart.lowercased() == "chest")
        }
    }

    @Test func fallbackExercisesHaveInstructions() {
        let service = ExerciseService()
        let result = service.fallbackExercises(bodyPart: "chest")
        for exercise in result {
            #expect(exercise.instructions != nil)
            #expect(exercise.instructions?.isEmpty == false)
        }
    }

    @Test func fallbackExercisesUnknownBodyPartReturnsEmpty() {
        let service = ExerciseService()
        let result = service.fallbackExercises(bodyPart: "nonexistent")
        #expect(result.isEmpty)
    }
}
