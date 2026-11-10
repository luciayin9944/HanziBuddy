import SwiftUI
import SwiftData

private enum ReviewQuestionKind {
    case pronunciation
    case word
}

private struct ReviewQuestion: Identifiable {
    let id = UUID()
    let record: CharacterRecord
    let prompt: String
    let options: [String]
    let correctAnswer: String
    let answerPinyin: String
    let kind: ReviewQuestionKind
}

struct QuizView: View {
    let recordIDs: [UUID]

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterRecord.createdAt, order: .reverse) private var records: [CharacterRecord]

    @State private var questions: [ReviewQuestion] = []
    @State private var questionIndex = 0
    @State private var selectedAnswer: String?
    @State private var isFlipped = false
    @State private var sessionPasses = 0
    @State private var correctAnswerCount = 0
    @State private var missedQuestions: [ReviewQuestion] = []
    @State private var isPracticeRound = false
    @State private var characterPassedSoFar = true
    @State private var hasStarted = false
    @State private var saveError = ""
    @State private var isShowingSaveError = false
    @State private var speech = SpeechService()
    @State private var audioError = ""
    @State private var isShowingAudioError = false

    private var selectedRecords: [CharacterRecord] {
        let recordsByID = Dictionary(uniqueKeysWithValues: records.map { ($0.id, $0) })
        return recordIDs.compactMap { recordsByID[$0] }
            .filter { $0.isSaved && !$0.isLearned }
    }

    private var currentQuestion: ReviewQuestion? {
        questions.indices.contains(questionIndex) ? questions[questionIndex] : nil
    }

    private var isLastQuestionForCharacter: Bool {
        questionIndex + 1 == questions.count ||
            questions[questionIndex + 1].record.id != questions[questionIndex].record.id
    }

    private var sessionCharacterCount: Int {
        Set(questions.map { $0.record.id }).count
    }

    var body: some View {
        Group {
            if !hasStarted || questions.isEmpty {
                emptyState
            } else if let question = currentQuestion {
                quiz(question)
            } else {
                sessionSummary
            }
        }
        .navigationTitle("Quiz")
        .onAppear {
            if !hasStarted { startSession() }
        }
        .alert("Could not save review", isPresented: $isShowingSaveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(saveError)
        }
        .alert("Audio unavailable", isPresented: $isShowingAudioError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(audioError)
        }
        .onDisappear { speech.stop() }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            selectedRecords.isEmpty ? "No characters to review" : "No quiz questions available",
            systemImage: "rectangle.on.rectangle.angled",
            description: Text(
                selectedRecords.isEmpty
                    ? "Return to Review and choose another group."
                    : "These characters need saved pronunciations to make quiz questions."
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func quiz(_ question: ReviewQuestion) -> some View {
        return VStack(spacing: 20) {
            Text("Question \(questionIndex + 1) of \(questions.count)")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ZStack {
                cardFront(question)
                    .opacity(isFlipped ? 0 : 1)
                cardBack(question)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
                    .opacity(isFlipped ? 1 : 0)
            }
            .frame(maxWidth: 540)
            .frame(maxHeight: 560)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 28))
            .rotation3DEffect(.degrees(isFlipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))

            if isFlipped {
                Button("Next card") {
                    nextQuestion()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cardFront(_ question: ReviewQuestion) -> some View {
        VStack(spacing: 28) {
            Text(question.record.character)
                .font(.system(size: 96, weight: .semibold))
                .accessibilityLabel("Character \(question.record.character)")

            Text(question.prompt)
                .font(.title3.weight(.semibold))
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                ForEach(question.options, id: \.self) { option in
                    Button {
                        answer(option, for: question)
                    } label: {
                        Text(option)
                            .font(.title3)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func cardBack(_ question: ReviewQuestion) -> some View {
        let isCorrect = selectedAnswer == question.correctAnswer
        let resultColor: Color = isCorrect ? .green : .orange

        return VStack(spacing: 22) {
            Text(isCorrect ? "Correct" : "WRONG")
                .font(.headline.bold())
                .foregroundStyle(resultColor)
                .padding(.horizontal, 22)
                .padding(.vertical, 10)
                .background(resultColor.opacity(0.12), in: Capsule())
                .overlay(Capsule().strokeBorder(resultColor, lineWidth: 1.5))

            HStack(spacing: 8) {
                Color.clear
                    .frame(width: 44, height: 44)
                Text(question.answerPinyin)
                    .font(.system(size: 36, weight: .light))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Button {
                    playAnswer(for: question)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title2)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel(
                    question.kind == .pronunciation
                        ? "Play character \(question.record.character)"
                        : "Play word \(question.correctAnswer)"
                )
            }
            .frame(maxWidth: .infinity)

            Text(question.kind == .pronunciation
                 ? question.record.character : question.correctAnswer)
                .font(.system(size: 88, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
        }
        .multilineTextAlignment(.center)
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func playAnswer(for question: ReviewQuestion) {
        do {
            if question.kind == .pronunciation {
                try speech.playPronunciation(character: question.record.character)
            } else {
                try speech.playWord(question.correctAnswer)
            }
        } catch {
            audioError = error.localizedDescription
            isShowingAudioError = true
        }
    }

    private var sessionSummary: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 54))
                .foregroundStyle(.tint)

            Text(isPracticeRound ? "Practice complete" : "Review complete")
                .font(.title.bold())

            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("\(correctAnswerCount) / \(questions.count)")
                        .font(.largeTitle.weight(.semibold))
                        .monospacedDigit()
                    Text("Questions correct")
                        .foregroundStyle(.secondary)
                }

                Divider()

                if !isPracticeRound {
                    VStack(spacing: 4) {
                        Text("\(sessionPasses) / \(sessionCharacterCount)")
                            .font(.title2.weight(.semibold))
                            .monospacedDigit()
                        Text("Characters passed")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text("Practice only · passes unchanged")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(32)
            .frame(maxWidth: 480)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 28))

            if !missedQuestions.isEmpty {
                Button("Practice again", action: startPractice)
                    .buttonStyle(.borderedProminent)
            }
        }
        .multilineTextAlignment(.center)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func startSession() {
        var seenCharacters = Set<String>()
        let learning = selectedRecords.filter { seenCharacters.insert($0.character).inserted }
        let saved = records.filter(\.isSaved)
        questions = learning.flatMap { makeQuestions(for: $0, from: saved) }
        questionIndex = 0
        sessionPasses = 0
        correctAnswerCount = 0
        missedQuestions = []
        isPracticeRound = false
        characterPassedSoFar = true
        hasStarted = true
        selectedAnswer = nil
        isFlipped = false
    }

    private func startPractice() {
        questions = missedQuestions.map { question in
            ReviewQuestion(
                record: question.record,
                prompt: question.prompt,
                options: question.options.shuffled(),
                correctAnswer: question.correctAnswer,
                answerPinyin: question.answerPinyin,
                kind: question.kind
            )
        }
        missedQuestions = []
        questionIndex = 0
        correctAnswerCount = 0
        sessionPasses = 0
        characterPassedSoFar = true
        isPracticeRound = true
        selectedAnswer = nil
        isFlipped = false
    }

    private func makeQuestions(for record: CharacterRecord, from saved: [CharacterRecord]) -> [ReviewQuestion] {
        let pronunciations = record.savedPronunciations
        let validPronunciations = Set(pronunciations.map(\.pinyin))
        let pronunciationChoices = saved.flatMap { $0.savedPronunciations.map(\.pinyin) } +
            ["mā", "rén", "hǎo", "shān", "xué", "gāo", "mù", "dà"]

        return pronunciations.flatMap { pronunciation -> [ReviewQuestion] in
            let examples = pronunciation.examples
            let example = examples.isEmpty ? nil : examples[record.reviewCount % examples.count]

            let pronunciationQuestion = ReviewQuestion(
                record: record,
                prompt: pronunciations.count > 1
                    ? "Which of these is a correct pronunciation of \(record.character)?"
                    : "How is \(record.character) pronounced?",
                options: options(
                    answer: pronunciation.pinyin,
                    candidates: pronunciationChoices,
                    excluding: validPronunciations
                ),
                correctAnswer: pronunciation.pinyin,
                answerPinyin: pronunciation.pinyin,
                kind: .pronunciation
            )

            guard let example else { return [pronunciationQuestion] }
            let correctWords = Set(examples.map(\.word))
            let distractors = (try? DictionaryService().wordDistractors(
                containing: record.character,
                excludingPinyin: example.pinyin,
                excludingWords: correctWords
            )) ?? []
            guard distractors.count >= 2 else { return [pronunciationQuestion] }
            let wordChoices = ([example.word] + Array(distractors.prefix(2))).shuffled()
            let wordQuestion = ReviewQuestion(
                record: record,
                prompt: "Which word containing \(record.character) is pronounced \(example.pinyin)?",
                options: wordChoices,
                correctAnswer: example.word,
                answerPinyin: example.pinyin,
                kind: .word
            )
            return [pronunciationQuestion, wordQuestion]
        }
    }

    private func options(answer: String, candidates: [String], excluding validAnswers: Set<String>) -> [String] {
        let distractors = Array(Set(candidates).subtracting(validAnswers)).shuffled().prefix(2)
        return ([answer] + distractors).shuffled()
    }

    private func answer(_ option: String, for question: ReviewQuestion) {
        guard !isFlipped, !question.record.isLearned else { return }
        speech.stop()
        let questionPassed = option == question.correctAnswer
        if isPracticeRound {
            recordQuestionResult(question, passed: questionPassed)
            selectedAnswer = option
            withAnimation(.easeInOut(duration: 0.5)) {
                isFlipped = true
            }
            return
        }
        if !isLastQuestionForCharacter {
            characterPassedSoFar = characterPassedSoFar && questionPassed
            recordQuestionResult(question, passed: questionPassed)
            selectedAnswer = option
            withAnimation(.easeInOut(duration: 0.5)) {
                isFlipped = true
            }
            return
        }

        let characterPassed = characterPassedSoFar && questionPassed
        let oldReviewCount = question.record.reviewCount
        let oldSuccessfulCount = question.record.successfulReviewCount
        let oldLearnedAt = question.record.learnedAt
        let oldResult = question.record.lastPracticeResult
        question.record.recordReview(passed: characterPassed)

        do {
            try modelContext.save()
            recordQuestionResult(question, passed: questionPassed)
            selectedAnswer = option
            if characterPassed { sessionPasses += 1 }
            withAnimation(.easeInOut(duration: 0.5)) {
                isFlipped = true
            }
        } catch {
            question.record.reviewCount = oldReviewCount
            question.record.successfulReviewCount = oldSuccessfulCount
            question.record.learnedAt = oldLearnedAt
            question.record.lastPracticeResult = oldResult
            saveError = error.localizedDescription
            isShowingSaveError = true
        }
    }

    private func recordQuestionResult(_ question: ReviewQuestion, passed: Bool) {
        if passed {
            correctAnswerCount += 1
        } else {
            missedQuestions.append(question)
        }
    }

    private func nextQuestion() {
        guard isFlipped else { return }
        speech.stop()
        if isLastQuestionForCharacter {
            characterPassedSoFar = true
        }
        isFlipped = false
        selectedAnswer = nil
        questionIndex += 1
    }
}
