import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasFollowedCategories: Bool?

    var body: some View {
        Group {
            switch hasFollowedCategories {
            case .some(true):
                TabView {
                    FeedView()
                        .tabItem { Label("Feed", systemImage: "list.bullet") }
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "bookmark") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            case .some(false):
                OnboardingView {
                    hasFollowedCategories = true
                }
            case .none:
                ProgressView()
            }
        }
        .task {
            let repository = PaperRepository(context: modelContext)
            let followed = (try? repository.fetchFollowedCategories()) ?? []
            hasFollowedCategories = !followed.isEmpty
        }
    }
}
