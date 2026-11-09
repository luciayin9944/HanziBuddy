import SwiftUI

struct ContentView: View {
    @State private var isShowingScanner = false

    var body: some View {
        TabView {
            NavigationStack {
                HomeView(onStartScanning: {
                    isShowingScanner = true
                })
                .navigationDestination(isPresented: $isShowingScanner) {
                    ScanFlowView()
                }
            }
            .tabItem {
                Label("Scan", systemImage:"camera.viewfinder")
            }
            

            NavigationStack {
                SavedView()
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
