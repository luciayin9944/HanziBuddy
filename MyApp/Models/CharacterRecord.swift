import Foundation
import SwiftData

@Model
class CharacterRecord {
    @Attribute(.unique) var id: UUID
    var character: String
    var pinyin: String
    var createdAt: Date
    var isSaved: Bool
    var reviewCount: Int
    var successfulReviewCount: Int = 0
    var learnedAt: Date?
    var lastPracticeResult: String?

    init(character: String, pinyin: String, createdAt: Date = .now) {
        self.id = UUID()
        self.character = character
        self.pinyin = pinyin
        self.createdAt = createdAt
        self.isSaved = false
        self.reviewCount = 0
        self.successfulReviewCount = 0
        self.learnedAt = nil
        self.lastPracticeResult = nil
    }

    var isLearned: Bool {
        learnedAt != nil
    }

    func recordReview(passed: Bool, at date: Date = .now) {
        guard !isLearned else { return }

        reviewCount += 1
        lastPracticeResult = passed ? "knowIt" : "practiceAgain"

        if passed {
            successfulReviewCount += 1
            if successfulReviewCount >= 4 {
                learnedAt = date
            }
        }
    }

    func moveBackToSaved() {
        learnedAt = nil
        successfulReviewCount = 0
    }
}


