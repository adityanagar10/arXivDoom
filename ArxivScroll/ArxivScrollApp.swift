import SwiftUI
import SwiftData

@main
struct ArxivScrollApp: App {
    var body: some Scene {
        WindowGroup {
            Text("ArxivScroll")
        }
        .modelContainer(for: [FollowedCategory.self, SeenPaper.self, SavedPaper.self])
    }
}
