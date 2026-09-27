import SwiftUI
import SwiftData
import PDFKit

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: LibraryViewModel?
    @State private var openDocument: PDFDocument?
    @State private var openTitle: String = ""

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    if viewModel.savedPapers.isEmpty {
                        ContentUnavailableView("No Saved Papers", systemImage: "bookmark")
                    } else {
                        List(viewModel.savedPapers) { saved in
                            Button {
                                if let path = saved.localPDFPath,
                                   let document = PDFDocument(url: URL(fileURLWithPath: path)) {
                                    openTitle = saved.title
                                    openDocument = document
                                }
                            } label: {
                                VStack(alignment: .leading) {
                                    Text(saved.title)
                                    Text(saved.savedDate, style: .date)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
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
    }
}
