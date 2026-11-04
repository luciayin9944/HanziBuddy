import SwiftUI
import SwiftData

struct HomeView: View {
    let onStartScanning: () -> Void

    @Query private var records: [CharacterRecord]

    private var learningCount: Int {
        records.filter { $0.isSaved && !$0.isLearned }.count
    }

    private var learnedCount: Int {
        records.filter { $0.isSaved && $0.isLearned }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 12) {
                    Image(systemName: "text.viewfinder")
                        .font(.system(size: 60))
                        .foregroundStyle(.tint)
                        .frame(maxWidth: .infinity)
                        .accessibilityHidden(true)

                    Text("Discover Chinese characters around you")
                        .font(.title2.bold())

                    Text("Take a photo of Chinese text, choose a character, and learn it at your own pace.")
                        .foregroundStyle(.secondary)
                }

                Button(action: onStartScanning) {
                    Label("Start scanning", systemImage: "camera.viewfinder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                VStack(alignment: .leading, spacing: 12) {
                    Text("Your progress")
                        .font(.headline)

                    HStack(spacing: 12) {
                        progressCard(title: "Learning", count: learningCount, symbol: "bookmark")
                        progressCard(title: "Learned", count: learnedCount, symbol: "checkmark.circle")
                    }
                }
                .padding(.top, 60)
            }
            .padding(48)
            .frame(maxWidth: 600, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .navigationTitle("HanziBuddy")
    }

    private func progressCard(title: String, count: Int, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: symbol)
                .foregroundStyle(.tint)
                .accessibilityHidden(true)

            Text(count, format: .number)
                .font(.title.bold())

            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        HomeView(onStartScanning: {})
    }
    .modelContainer(for: CharacterRecord.self, inMemory: true)
}
