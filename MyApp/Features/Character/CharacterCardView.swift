import SwiftUI
import SwiftData

struct CharacterCardView: View {
    struct PronunciationGroup: Identifiable {
        let pinyin: String
        let examples: [Example]

        var id: String { pinyin }
    }

    struct Example {
        let word: String
        let pinyin: String
    }

    let character: String
    let pronunciations: [PronunciationGroup]
    let showsSaveButton: Bool

    init(character: String, pronunciations: [PronunciationGroup], showsSaveButton: Bool = true) {
        self.character = character
        self.pronunciations = pronunciations
        self.showsSaveButton = showsSaveButton
    }

    @Environment(\.modelContext) private var modelContext
    @Query private var records: [CharacterRecord]
    @State private var speech = SpeechService()
    @State private var didSave = false
    @State private var errorTitle = ""
    @State private var errorMessage = ""
    @State private var isShowingError = false

    private var isSaved: Bool {
        didSave || records.contains { $0.character == character && $0.isSaved }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if !pronunciations.isEmpty {
                    Text(pronunciations.map(\.pinyin).joined(separator: " / "))
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text(character)
                    .font(.system(size: 96, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .accessibilityLabel("Character \(character)")

                if pronunciations.isEmpty {
                    Label("Pronunciation lookup failed", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(pronunciations) { pronunciation in
                        pronunciationSection(pronunciation)
                    }
                }
            }
            .padding(.top, 60)
            .frame(maxWidth: 600)
            .frame(maxWidth: .infinity)
        }
        .safeAreaInset(edge: .bottom) {
            if showsSaveButton && !pronunciations.isEmpty {
                Button(action: saveCharacter) {
                    Label(
                        didSave ? "Saved" : (isSaved ? "Update saved card" : "Save character"),
                        systemImage: didSave ? "checkmark.circle.fill" : "star"
                    )
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(didSave)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
            }
        }
        .onDisappear { speech.stop() }
        .alert(errorTitle, isPresented: $isShowingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
    }

    private func pronunciationSection(_ pronunciation: PronunciationGroup) -> some View {
        VStack(spacing: 16) {
            HStack(spacing: 8) {
                Text(pronunciation.pinyin)
                    .font(.title.bold())

                Button {
                    playCharacter(pronunciation)
                } label: {
                    Image(systemName: "speaker.wave.2")
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("Play \(character) as \(pronunciation.pinyin)")
            }

            if !pronunciation.examples.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(Array(pronunciation.examples.prefix(2).enumerated()), id: \.offset) { item in
                        VStack(spacing: 4) {
                            Text(item.element.pinyin)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 4) {
                                Text(item.element.word)
                                    .font(.title)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                Button {
                                    playWord(item.element.word)
                                } label: {
                                    Image(systemName: "speaker.wave.2")
                                        .frame(width: 44, height: 44)
                                }
                                .buttonStyle(.plain)
                                .foregroundStyle(.tint)
                                .accessibilityLabel("Play \(item.element.word)")
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
    }

    private func playCharacter(_ pronunciation: PronunciationGroup) {
        do {
            let example = pronunciations.count > 1 ? pronunciation.examples.first?.word : nil
            try speech.playPronunciation(character: character, exampleWord: example)
        } catch {
            showSpeechError(error)
        }
    }

    private func playWord(_ word: String) {
        do {
            try speech.playWord(word)
        } catch {
            showSpeechError(error)
        }
    }

    private func showSpeechError(_ error: Error) {
        showError(title: "Audio unavailable", message: error.localizedDescription)
    }

    private func saveCharacter() {
        let savedPronunciations = pronunciations.map { pronunciation in
            SavedPronunciation(
                pinyin: pronunciation.pinyin,
                examples: pronunciation.examples.prefix(2).map {
                    SavedExampleWord(word: $0.word, pinyin: $0.pinyin)
                }
            )
        }

        do {
            let chosenCharacter = character
            let descriptor = FetchDescriptor<CharacterRecord>(
                predicate: #Predicate { $0.character == chosenCharacter }
            )

            if let existing = try modelContext.fetch(descriptor).first {
                let previousPronunciations = existing.pronunciations
                let previousPinyin = existing.pinyin
                let wasSaved = existing.isSaved
                existing.pronunciations = savedPronunciations
                existing.pinyin = savedPronunciations.map(\.pinyin).joined(separator: " / ")
                existing.isSaved = true
                do {
                    try modelContext.save()
                } catch {
                    existing.pronunciations = previousPronunciations
                    existing.pinyin = previousPinyin
                    existing.isSaved = wasSaved
                    throw error
                }
            } else {
                let record = CharacterRecord(character: character, pronunciations: savedPronunciations)
                modelContext.insert(record)
                do {
                    try modelContext.save()
                } catch {
                    modelContext.delete(record)
                    throw error
                }
            }

            didSave = true
        } catch {
            showError(title: "Could not save character", message: error.localizedDescription)
        }
    }

    private func showError(title: String, message: String) {
        errorTitle = title
        errorMessage = message
        isShowingError = true
    }
}


//#Preview("行") {
//    NavigationStack {
//        CharacterCardView(
//            character: "行",
//            pronunciations: [
//                .init(
//                    pinyin: "xíng",
//                    examples: [
//                        .init(word: "行走", pinyin: "xíng zǒu"),
//                        .init(word: "行人", pinyin: "xíng rén")
//                    ]
//                ),
//                .init(
//                    pinyin: "háng",
//                    examples: [
//                        .init(word: "银行", pinyin: "yín háng")
//                    ]
//                )
//            ]
//        )
//    }
//}

//#Preview("树") {
//    NavigationStack {
//        CharacterCardView(
//            character: "树",
//            pronunciations: [
//                .init(
//                    pinyin: "shù",
//                    examples: [
//                        .init(word: "树木", pinyin: "shù mù"),
//                        .init(word: "橡树", pinyin: "xiàng shù")
//                    ]
//                )
//            ]
//        )
//    }
//}
