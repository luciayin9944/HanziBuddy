import SwiftUI
import SwiftData

private enum ReviewAmount: String, CaseIterable, Identifiable {
    case ten = "10"
    case twenty = "20"
    case all = "All"

    var id: Self { self }

    var limit: Int? {
        switch self {
        case .ten: 10
        case .twenty: 20
        case .all: nil
        }
    }
}

struct QuizRoute: Hashable {
    let recordIDs: [UUID]
}

struct ReviewView: View {
    @Binding var path: [QuizRoute]
    @Query(sort: \CharacterRecord.createdAt, order: .reverse) private var records: [CharacterRecord]

    @State private var selectedAmount: ReviewAmount = .all

    private var learningRecords: [CharacterRecord] {
        var seenCharacters = Set<String>()
        return records.filter {
            $0.isSaved && !$0.isLearned && seenCharacters.insert($0.character).inserted
        }
    }

    var body: some View {
        Group {
            if learningRecords.isEmpty {
                ContentUnavailableView(
                    "No characters to review",
                    systemImage: "rectangle.on.rectangle.angled",
                    description: Text("Save a character to start a quiz.")
                )
            } else {
                reviewSetup
            }
        }
        .navigationTitle("Review")
        .navigationDestination(for: QuizRoute.self) { route in
            QuizView(recordIDs: route.recordIDs)
        }
        .onChange(of: learningRecords.count) { _, count in
            if let limit = selectedAmount.limit, count < limit {
                selectedAmount = .all
            }
        }
    }

    private var reviewSetup: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("\(learningRecords.count)")
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(learningRecords.count == 1
                     ? "Character ready to review" : "Characters ready to review")
                    .font(.headline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(28)
            .background(.quaternary, in: RoundedRectangle(cornerRadius: 28))

            VStack(alignment: .leading, spacing: 12) {
                Text("How many characters to review?")
                    .font(.headline)

                HStack(spacing: 12) {
                    ForEach(ReviewAmount.allCases) { amount in
                        let available = isAvailable(amount)
                        let selected = selectedAmount == amount

                        Button {
                            selectedAmount = amount
                        } label: {
                            Text(amount.rawValue)
                                .font(.headline)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .foregroundStyle(selected ? Color.white : Color.primary)
                                .background(
                                    selected ? Color.accentColor : Color(uiColor: .secondarySystemFill),
                                    in: RoundedRectangle(cornerRadius: 12)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(!available)
                        .opacity(available ? 1 : 0.45)
                        .accessibilityLabel(
                            amount == .all ? "All \(learningRecords.count) characters" :
                                "\(amount.rawValue) characters"
                        )
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }

            Button(action: startQuiz) {
                Text("Start quiz")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(maxWidth: 480)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func isAvailable(_ amount: ReviewAmount) -> Bool {
        amount.limit.map { learningRecords.count >= $0 } ?? true
    }

    private func startQuiz() {
        guard isAvailable(selectedAmount), !learningRecords.isEmpty else { return }
        let count = selectedAmount.limit ?? learningRecords.count
        let recordIDs = Array(learningRecords.shuffled().prefix(count)).map(\.id)
        path.append(QuizRoute(recordIDs: recordIDs))
    }
}
