import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            NavigationStack {
                ContentUnavailableView(
                    "Scan",
                    systemImage: "camera.viewfinder",
                    description: Text("Scan characters")
                )
                    .navigationTitle("Scan")
            }
            .tabItem {
                Label("Scan", systemImage:"camera.viewfinder")
            }
            

            NavigationStack {
                ContentUnavailableView(
                    "Saved characters",
                    systemImage: "star",
                    description: Text("Learning and learned")
                )
                    .navigationTitle("Saved")
            }
            .tabItem {
                Label("Saved", systemImage: "star")
            }

            NavigationStack {
                ContentUnavailableView(
                    "Review",
                    systemImage: "arrow.clockwise",
                    description: Text("Review Quiz")
                )
                    .navigationTitle("Review")
            }
            .tabItem {
                Label("Review", systemImage: "arrow.clockwise")
            }

        }
    }
}

#Preview {
    ContentView()
}
