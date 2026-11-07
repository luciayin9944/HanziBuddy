import SwiftUI

struct ConfirmCharacterView: View {
    let recognizedText: String
    let onSelectCharacter: (String) -> Void
    let onRescan: () -> Void

    @State private var selectedCharacter: String?

    init(
        recognizedText: String,
        onSelectCharacter: @escaping (String) -> Void,
        onRescan: @escaping () -> Void
    ) {
        self.recognizedText = recognizedText
        self.onSelectCharacter = onSelectCharacter
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
                    Text("Choose one character")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { item in
                            Button(item.element) {
                                selectedCharacter = item.element
                                onSelectCharacter(item.element)
                            }
                            .font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Choose \(item.element)")
                        }
                    }

                    if let selectedCharacter {
                        Text("Selected character: \(selectedCharacter)")
                            .font(.headline)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Choose character")
        .onChange(of: recognizedText) { _, _ in
            selectedCharacter = nil
        }
    }
}
