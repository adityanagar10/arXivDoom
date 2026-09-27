import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OnboardingViewModel?
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
                                try? viewModel.saveSelection()
                                onComplete()
                            }
                            .disabled(!viewModel.canContinue)
                        }
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
