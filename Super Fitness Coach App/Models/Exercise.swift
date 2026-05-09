//
//  Exercise.swift
//  Super Fitness Coach App
//

import Foundation

struct Exercise: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var bodyPart: String
    var target: String
    var equipment: String
    var gifUrl: String?
    var instructions: [String]?
    var description: String?
    var difficulty: String?
    var category: String?
    var secondaryMuscles: [String]?

    enum CodingKeys: String, CodingKey {
        case id, name, bodyPart, target, equipment
        case gifUrl, instructions, description, difficulty, category, secondaryMuscles
    }
}
