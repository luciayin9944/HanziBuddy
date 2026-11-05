import SwiftUI

struct ConfirmCharacterView: View {
    let recognizedText: String
    let onSelectCharacter: (String) -> Void
    let onRescan: () -> Void

    @State private var editedText: String
    @FocusState private var isEditing: Bool

    init(
        recognizedText: String,
        onSelectCharacter: @escaping (String) -> Void,
        onRescan: @escaping () -> Void
    ) {
        self.recognizedText = recognizedText
        self.onSelectCharacter = onSelectCharacter
        self.onRescan = onRescan
        _editedText = State(initialValue: recognizedText)
    }

    private var characters: [String] {
        editedText.unicodeScalars
            .filter { $0.properties.isUnifiedIdeograph }
            .map(String.init)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Check the recognized text")
                    .font(.headline)

                Text("Fix any mistakes, then tap one Chinese character to learn.")
                    .foregroundStyle(.secondary)

                TextEditor(text: $editedText)
                    .focused($isEditing)
                    .frame(height: 150)
                    .padding(8)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(.quaternary)
                    }
                    .accessibilityLabel("Recognized text")

                if characters.isEmpty {
                    Text("No Chinese characters found. Edit the text or rescan.")
                        .foregroundStyle(.secondary)
                } else {
                    Text("Choose one character")
                        .font(.headline)

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 12)], spacing: 12) {
                        ForEach(Array(characters.enumerated()), id: \.offset) { item in
                            Button(item.element) {
                                isEditing = false
                                onSelectCharacter(item.element)
                            }
                            .font(.title2)
                            .frame(minWidth: 44, minHeight: 44)
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Choose \(item.element)")
                        }
                    }
                }

                Button(action: onRescan) {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle("Choose character")
        .onChange(of: recognizedText) { _, newText in
            editedText = newText
        }
    }
}
