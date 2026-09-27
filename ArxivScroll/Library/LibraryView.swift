import SwiftUI
import SwiftData
import PDFKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LibraryViewModel?
    @State private var openDocument: PDFDocument?
    @State private var openTitle: String = ""
    @State private var unavailableTitle: String?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.savedPapers.isEmpty {
                        ContentUnavailableView("No Saved Papers", systemImage: "bookmark")
                    } else {
                        List(viewModel.savedPapers) { saved in
                            Button {
                                guard saved.isAvailable,
                                      let path = saved.localPDFPath,
                                      let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
                                    unavailableTitle = saved.title
                                    return
                                }
                                openTitle = saved.title
                                openDocument = document
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(saved.title)
                                        .foregroundStyle(saved.isAvailable ? .primary : .secondary)
                                    if saved.isAvailable {
                                        Text(saved.savedDate, style: .date)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Not downloaded yet — open it from the Feed to save a copy")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .opacity(saved.isAvailable ? 1 : 0.6)
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Library")
            .task {
                let vm = LibraryViewModel(context: modelContext)
                vm.load()
                viewModel = vm
            }
        }
        .sheet(isPresented: Binding(get: { openDocument != nil }, set: { if !$0 { openDocument = nil } })) {
            if let openDocument {
                NavigationStack {
                    PDFReaderView(document: openDocument)
                        .navigationTitle(openTitle)
                }
            }
        }
        .alert(
            "Not Downloaded",
            isPresented: Binding(get: { unavailableTitle != nil }, set: { if !$0 { unavailableTitle = nil } }),
            presenting: unavailableTitle
        ) { _ in
            Button("OK", role: .cancel) {}
        } message: { title in
            Text("\"\(title)\" hasn't been downloaded yet. Open it from the Feed to save a copy for offline reading.")
        }
    }
}
