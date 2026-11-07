import SwiftUI

struct ConfirmCharacterView: View {
    let recognizedText: String
    let onRescan: () -> Void

    @State private var cardCharacter: String?
    @State private var cardPronunciations: [CharacterCardView.PronunciationGroup] = []
    @State private var isShowingCard = false
    @State private var lookupError = ""
    @State private var isShowingLookupError = false
    private let dictionary = DictionaryService()

    init(
        recognizedText: String,
        onRescan: @escaping () -> Void
    ) {
        self.recognizedText = recognizedText
        self.onRescan = onRescan
    }

    private var characters: [String] {
        recognizedText.unicodeScalars
            .filter { $0.properties.isUnifiedIdeograph }
            .map(String.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text(recognizedText)
                    .font(.title3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                    .accessibilityLabel("Recognized text")

                if characters.isEmpty {
                    Text("No Chinese characters found. Try scanning again.")
                        .foregroundStyle(.secondary)
                } else {
//                    Text("Choose one character")
//                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { item in
                            Button(item.element) {
                                do {
                                    cardPronunciations = try dictionary.pronunciations(for: item.element)
                                    cardCharacter = item.element
                                    isShowingCard = true
                                } catch {
                                    lookupError = error.localizedDescription
                                    isShowingLookupError = true
                                }
                            }
                            .font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Choose \(item.element)")
                        }
                    }
                }
//                Button(action: onRescan) {
//                    Label("Rescan", systemImage: "arrow.clockwise")
//                }
//                .buttonStyle(.bordered)
            }
            .padding()
        }
        .navigationTitle("Choose character")
        .navigationDestination(isPresented: $isShowingCard) {
            if let cardCharacter {
                CharacterCardView(character: cardCharacter, pronunciations: cardPronunciations)
            }
        }
        .alert("Could not open character", isPresented: $isShowingLookupError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(lookupError)
        }
    }
}
