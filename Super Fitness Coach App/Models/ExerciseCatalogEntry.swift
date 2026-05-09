//
//  ExerciseCatalogEntry.swift
//  Super Fitness Coach App
//

import Foundation
import SwiftData

/// Local exercise catalog row (offline-first).
///
/// - Note: We use our own `id` (UUID) and keep `wgerUuid` for sync/migration.
/// - Note: We store lists as newline/CSV strings to avoid SwiftData Codable edge cases.
@Model
final class ExerciseCatalogEntry {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var wgerUuid: String

    /// Canonical muscle group used by the app today (10 groups).
    var muscleGroupRaw: String

    /// Spanish (primary) display fields.
    var nameEs: String
    var descriptionEs: String?
    var instructionsEs: String? // newline-separated steps

    /// Optional English fallback (useful for entries lacking ES translations).
    var nameEn: String?
    var descriptionEn: String?
    var instructionsEn: String?

    /// wger metadata (helpful for future Firebase sync / re-import).
    var wgerCategoryId: Int?
    var wgerCategoryName: String?

    /// Comma-separated equipment names (wger can have multiple).
    var equipmentCSV: String?

    /// Comma-separated muscle names/ids if available.
    var primaryMusclesCSV: String?
    var secondaryMusclesCSV: String?

    /// Image URL (main if available).
    var imageUrl: String?
    /// Video URL (YouTube / etc) manually curated in-app.
    var videoUrl: String?

    /// True when we have EN but ES is missing (for future Firebase translation pipeline).
    var needsEsTranslation: Bool
    var translationRequestedAt: Date?

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        wgerUuid: String,
        muscleGroupRaw: String,
        nameEs: String,
        descriptionEs: String? = nil,
        instructionsEs: String? = nil,
        nameEn: String? = nil,
        descriptionEn: String? = nil,
        instructionsEn: String? = nil,
        wgerCategoryId: Int? = nil,
        wgerCategoryName: String? = nil,
        equipmentCSV: String? = nil,
        primaryMusclesCSV: String? = nil,
        secondaryMusclesCSV: String? = nil,
        imageUrl: String? = nil,
        videoUrl: String? = nil,
        needsEsTranslation: Bool = false,
        translationRequestedAt: Date? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.wgerUuid = wgerUuid
        self.muscleGroupRaw = muscleGroupRaw
        self.nameEs = nameEs
        self.descriptionEs = descriptionEs
        self.instructionsEs = instructionsEs
        self.nameEn = nameEn
        self.descriptionEn = descriptionEn
        self.instructionsEn = instructionsEn
        self.wgerCategoryId = wgerCategoryId
        self.wgerCategoryName = wgerCategoryName
        self.equipmentCSV = equipmentCSV
        self.primaryMusclesCSV = primaryMusclesCSV
        self.secondaryMusclesCSV = secondaryMusclesCSV
        self.imageUrl = imageUrl
        self.videoUrl = videoUrl
        self.needsEsTranslation = needsEsTranslation
        self.translationRequestedAt = translationRequestedAt
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

