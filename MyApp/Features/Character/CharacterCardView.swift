import SwiftUI

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
    }

    private func pronunciationSection(_ pronunciation: PronunciationGroup) -> some View {
        VStack(spacing: 16) {
            Text(pronunciation.pinyin)
                .font(.title.bold())

            if !pronunciation.examples.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 12)], spacing: 12) {
                    ForEach(Array(pronunciation.examples.prefix(2).enumerated()), id: \.offset) { item in
                        VStack(spacing: 4) {
                            Text(item.element.pinyin)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            Text(item.element.word)
                                .font(.title)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.background, in: RoundedRectangle(cornerRadius: 12))
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 20))
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

#Preview("树") {
    NavigationStack {
        CharacterCardView(
            character: "树",
            pronunciations: [
                .init(
                    pinyin: "shù",
                    examples: [
                        .init(word: "树木", pinyin: "shù mù"),
                        .init(word: "大树", pinyin: "dà shù")
                    ]
                )
            ]
        )
    }
}
