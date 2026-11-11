import SwiftUI
import SwiftData
import UIKit

private struct ExportFile: Identifiable {
    let id = UUID()
    let url: URL
}

private struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) { }
}

struct SavedView: View {
    private enum SavedSection: String {
        case learning = "Learning"
        case learned = "Learned"
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CharacterRecord.createdAt, order: .reverse) private var records: [CharacterRecord]

    @State private var selectedSection: SavedSection = .learning
    @State private var moveError = ""
    @State private var isShowingMoveError = false
    @State private var exportFile: ExportFile?
    @State private var exportError = ""
    @State private var isShowingExportError = false

    private var learningRecords: [CharacterRecord] {
        records.filter { $0.isSaved && !$0.isLearned }
    }

    private var learnedRecords: [CharacterRecord] {
        records.filter { $0.isSaved && $0.isLearned }
    }

    private var displayedRecords: [CharacterRecord] {
        selectedSection == .learning ? learningRecords : learnedRecords
    }

    var body: some View {
        Group {
            if learningRecords.isEmpty && learnedRecords.isEmpty {
                ContentUnavailableView(
                    "No saved characters yet",
                    systemImage: "star",
                    description: Text("Scan a character and tap Save character.")
                )
            } else {
                VStack(spacing: 0) {
                    Picker("Saved characters", selection: $selectedSection) {
                        Text("Learning").tag(SavedSection.learning)
                        Text("Learned").tag(SavedSection.learned)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)

                    if selectedSection == .learned {
                        HStack {
                            Spacer()
                            Button(action: exportLearned) {
                                Label("Export CSV", systemImage: "square.and.arrow.up")
                            }
                            .buttonStyle(.bordered)
                            .disabled(learnedRecords.isEmpty)
                        }
                        .padding(.horizontal)
                        .padding(.top, 12)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                    }

                    if displayedRecords.isEmpty {
                        ContentUnavailableView(
                            selectedSection == .learning ? "No learning characters" : "No learned characters yet",
                            systemImage: selectedSection == .learning ? "star" : "checkmark.circle",
                            description: Text(
                                selectedSection == .learning
                                    ? "Saved characters appear here until they are learned."
                                    : "Three successful quizzes move a character here."
                            )
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 24) {
                                section(records: displayedRecords, isLearned: selectedSection == .learned)
                            }
                            .padding()
                            .frame(maxWidth: 600)
                            .frame(maxWidth: .infinity)
                        }
                        .id(selectedSection)
                    }
                }
            }
        }
        .navigationTitle("Saved")
        .onAppear {
            if learningRecords.isEmpty && !learnedRecords.isEmpty {
                selectedSection = .learned
            }
        }
        .onChange(of: learningRecords.isEmpty && !learnedRecords.isEmpty) { _, onlyLearned in
            if onlyLearned {
                selectedSection = .learned
            }
        }
        .alert("Could not move character", isPresented: $isShowingMoveError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(moveError)
        }
        .alert("Could not export characters", isPresented: $isShowingExportError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(exportError)
        }
        .sheet(item: $exportFile) { file in
            ShareSheet(url: file.url)
        }
    }

    private func section(records: [CharacterRecord], isLearned: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("\(records.count) \(records.count == 1 ? "character" : "characters")")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ForEach(records, id: \.id) { record in
                recordRow(record, isLearned: isLearned)
            }
        }
    }

    private func recordRow(_ record: CharacterRecord, isLearned: Bool) -> some View {
        HStack(spacing: 0) {
            NavigationLink {
                CharacterCardView(
                    character: record.character,
                    pronunciations: record.savedPronunciations.map { pronunciation in
                        CharacterCardView.PronunciationGroup(
                            pinyin: pronunciation.pinyin,
                            examples: pronunciation.examples.map {
                                CharacterCardView.Example(word: $0.word, pinyin: $0.pinyin)
                            }
                        )
                    },
                    showsSaveButton: false
                )
            } label: {
                HStack(spacing: 14) {
                    Text(record.character)
                        .font(.system(size: 38))
                        .frame(width: 52)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(record.savedPronunciations.map(\.pinyin).joined(separator: " / "))
                            .font(.headline)

                        let examples = examplePreview(for: record)
                        if !examples.isEmpty {
                            Text(examples)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .frame(minHeight: 54)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Open \(record.character), \(record.savedPronunciations.map(\.pinyin).joined(separator: ", "))")

            if isLearned {
                Menu {
                    Button("Move back to Learning", systemImage: "arrow.uturn.backward") {
                        moveBackToLearning(record)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Options for \(record.character)")
            }
        }
        .padding(14)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
    }

    private func examplePreview(for record: CharacterRecord) -> String {
        let pronunciations = record.savedPronunciations
        let firstExamples = pronunciations.compactMap { $0.examples.first?.word }
        let remainingExamples = pronunciations.flatMap { $0.examples.dropFirst().map(\.word) }
        return (firstExamples + remainingExamples).prefix(2).joined(separator: " · ")
    }

    private func moveBackToLearning(_ record: CharacterRecord) {
        let learnedAt = record.learnedAt
        let successfulReviewCount = record.successfulReviewCount
        record.moveBackToSaved()

        do {
            try modelContext.save()
        } catch {
            record.learnedAt = learnedAt
            record.successfulReviewCount = successfulReviewCount
            moveError = error.localizedDescription
            isShowingMoveError = true
        }
    }

    private func exportLearned() {
        do {
            exportFile = ExportFile(url: try CSVExportService().exportLearnedCharacters(learnedRecords))
        } catch {
            exportError = error.localizedDescription
            isShowingExportError = true
        }
    }
}




//#Preview("Learning and Learned") {
//    NavigationStack {
//        SavedView()
//    }
//    .modelContainer(savedViewPreviewContainer())
//}
//
//@MainActor
//private func savedViewPreviewContainer() -> ModelContainer {
//    let container = try! ModelContainer(
//        for: CharacterRecord.self,
//        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
//    )
//
//    let tree = CharacterRecord(character: "树", pronunciations: [
//        SavedPronunciation(pinyin: "shù", examples: [
//            SavedExampleWord(word: "树木", pinyin: "shù mù"),
//            SavedExampleWord(word: "橡树", pinyin: "xiàng shù")
//        ])
//    ])
//    let travel = CharacterRecord(character: "行", pronunciations: [
//        SavedPronunciation(pinyin: "xíng", examples: [
//            SavedExampleWord(word: "行走", pinyin: "xíng zǒu")
//        ]),
//        SavedPronunciation(pinyin: "háng", examples: [
//            SavedExampleWord(word: "银行", pinyin: "yín háng")
//        ])
//    ])
//    let big = CharacterRecord(character: "大", pronunciations: [
//        SavedPronunciation(pinyin: "dà", examples: [
//            SavedExampleWord(word: "大小", pinyin: "dà xiǎo"),
//            SavedExampleWord(word: "大家", pinyin: "dà jiā")
//        ])
//    ])
//    let person = CharacterRecord(character: "人", pronunciations: [
//        SavedPronunciation(pinyin: "rén", examples: [
//            SavedExampleWord(word: "人民", pinyin: "rén mín"),
//            SavedExampleWord(word: "工人", pinyin: "gōng rén")
//        ])
//    ])
//
//    let long = CharacterRecord(character: "长", pronunciations: [
//        SavedPronunciation(pinyin: "cháng", examples: [
//            SavedExampleWord(word: "长短", pinyin: "cháng duǎn")
//        ]),
//        SavedPronunciation(pinyin: "zhǎng", examples: [
//            SavedExampleWord(word: "长大", pinyin: "zhǎng dà")
//        ])
//    ])
//    let tall = CharacterRecord(character: "高", pronunciations: [
//        SavedPronunciation(pinyin: "gāo", examples: [
//            SavedExampleWord(word: "高山", pinyin: "gāo shān"),
//            SavedExampleWord(word: "高兴", pinyin: "gāo xìng")
//        ])
//    ])
//    let wood = CharacterRecord(character: "木", pronunciations: [
//        SavedPronunciation(pinyin: "mù", examples: [
//            SavedExampleWord(word: "木材", pinyin: "mù cái"),
//            SavedExampleWord(word: "树木", pinyin: "shù mù")
//        ])
//    ])
//    let heart = CharacterRecord(character: "心", pronunciations: [
//        SavedPronunciation(pinyin: "xīn", examples: [
//            SavedExampleWord(word: "中心", pinyin: "zhōng xīn"),
//            SavedExampleWord(word: "开心", pinyin: "kāi xīn")
//        ])
//    ])
//
//    let learnedRecords = [long, tall, wood, heart]
//    for record in learnedRecords {
//        for _ in 0..<3 {
//            record.recordReview(passed: true)
//        }
//    }
//
//    for record in [tree, travel, big, person] + learnedRecords {
//        container.mainContext.insert(record)
//    }
//    try! container.mainContext.save()
//    return container
//}
