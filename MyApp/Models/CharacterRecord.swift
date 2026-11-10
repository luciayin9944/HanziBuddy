import Foundation
import SwiftData

struct SavedExampleWord: Codable, Hashable {
    let word: String
    let pinyin: String
}

struct SavedPronunciation: Codable, Hashable {
    let pinyin: String
    let examples: [SavedExampleWord]
}

@Model
class CharacterRecord {
    @Attribute(.unique) var id: UUID
    var character: String
    // Kept for records created before pronunciation groups were added.
    var pinyin: String
    var pronunciations: [SavedPronunciation] = []
    var createdAt: Date
    var isSaved: Bool
    var reviewCount: Int
    var successfulReviewCount: Int = 0
    var learnedAt: Date?
    var lastPracticeResult: String?

    init(character: String, pronunciations: [SavedPronunciation], createdAt: Date = .now) {
        self.id = UUID()
        self.character = character
        self.pinyin = pronunciations.map(\.pinyin).joined(separator: " / ")
        self.pronunciations = pronunciations
        self.createdAt = createdAt
        self.isSaved = true
        self.reviewCount = 0
        self.successfulReviewCount = 0
        self.learnedAt = nil
        self.lastPracticeResult = nil
    }

    var isLearned: Bool {
        learnedAt != nil
    }

    var savedPronunciations: [SavedPronunciation] {
        if !pronunciations.isEmpty {
            return pronunciations
        }
        return pinyin.isEmpty ? [] : [SavedPronunciation(pinyin: pinyin, examples: [])]
    }

    func recordReview(passed: Bool, at date: Date = .now) {
        guard !isLearned else { return }

        reviewCount += 1
        lastPracticeResult = passed ? "correct" : "incorrect"

        if passed {
            successfulReviewCount += 1
            if successfulReviewCount >= 3 {
                learnedAt = date
            }
        }
    }

    func moveBackToSaved() {
        learnedAt = nil
        successfulReviewCount = 0
    }
}
