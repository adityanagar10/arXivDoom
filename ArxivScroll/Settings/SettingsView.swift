import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    List {
                        ForEach(ArxivTaxonomy.archives) { archive in
                            Section(archive.name) {
                                ForEach(archive.categories) { category in
                                    Button {
                                        viewModel.toggle(category)
                                        viewModel.save()
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
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Followed Categories")
            .task {
                let vm = SettingsViewModel(context: modelContext)
                vm.load()
                viewModel = vm
            }
        }
    }
}
