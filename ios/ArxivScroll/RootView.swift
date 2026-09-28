import SwiftUI
import SwiftData

struct RootView: View {
    // @Query re-runs its fetch whenever the model context saves changes to
    // FollowedCategory, so this stays correct for the whole session: it flips to
    // showing OnboardingView again if the user unfollows every category later
    // (e.g. from Settings), with no one-shot `.task` fetch to go stale.
    @Query private var followedCategories: [FollowedCategory]

    var body: some View {
        Group {
            if followedCategories.isEmpty {
                OnboardingView {
                    // No-op: saving a selection inserts FollowedCategory rows and
                    // saves the context, which @Query observes directly. Nothing
                    // else needs to happen here for RootView to switch to the
                    // TabView.
                }
            } else {
                TabView {
                    FeedView()
                        .tabItem { Label("Feed", systemImage: "list.bullet") }
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "bookmark") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            }
        }
    }
}
