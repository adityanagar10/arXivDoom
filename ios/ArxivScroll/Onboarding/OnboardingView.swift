import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OnboardingViewModel?
    @State private var showSaveError = false
    let onComplete: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    List {
                        ForEach(ArxivTaxonomy.archives) { archive in
                            Section(archive.name) {
                                ForEach(archive.categories) { category in
                                    Button {
                                        viewModel.toggle(category)
                                    } label: {
                                        HStack {
                                            Text(category.displayName)
                                            Spacer()
                                            if viewModel.isSelected(category) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Follow Categories")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                do {
                                    try viewModel.saveSelection()
                                    onComplete()
                                } catch {
                                    // Non-fatal, but must not let onComplete() fire: doing so would
                                    // flip RootView to the TabView with zero categories actually
                                    // saved. Keep the user on this screen and surface the failure.
                                    #if DEBUG
                                    print("OnboardingView: failed to save selection: \(error)")
                                    #endif
                                    showSaveError = true
                                }
                            }
                            .disabled(!viewModel.canContinue)
                        }
                    }
                    .alert("Couldn't Save Categories", isPresented: $showSaveError) {
                        Button("OK", role: .cancel) {}
                    } message: {
                        Text("Something went wrong saving your selection. Please try again.")
                    }
                }
            } else {
                ProgressView()
                    .task {
                        viewModel = OnboardingViewModel(context: modelContext)
                    }
            }
        }
    }
}
