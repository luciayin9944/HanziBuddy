import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case scan
        case saved
        case review
    }

    @State private var isShowingScanner = false
    @State private var selectedTab: AppTab = .scan
    @State private var reviewPath: [QuizRoute] = []

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { newTab in
                if newTab == .review && selectedTab == .review {
                    reviewPath = []
                }
                selectedTab = newTab
            }
        )
    }

    var body: some View {
        TabView(selection: tabSelection) {
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
            .tag(AppTab.scan)
            

            NavigationStack {
                SavedView()
            }
            .tabItem {
                Label("Saved", systemImage: "star")
            }
            .tag(AppTab.saved)

            NavigationStack(path: $reviewPath) {
                ReviewView(path: $reviewPath)
            }
            .tabItem {
                Label("Review", systemImage: "arrow.clockwise")
            }
            .tag(AppTab.review)

        }
    }
}
