import SwiftUI
import SwiftData
import PDFKit

struct PDFReaderScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let paper: Paper

    @State private var document: PDFDocument?
    @State private var errorMessage: String?
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            Group {
                if let document {
                    PDFReaderView(document: document)
                } else if let errorMessage {
                    ContentUnavailableView {
                        Label("Can't Open PDF", systemImage: "doc.questionmark")
                    } description: {
                        Text(errorMessage)
                    } actions: {
                        Button("Retry") { Task { await load() } }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle(paper.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .task { await load() }
    }

    private func load() async {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        do {
            let path = try await PDFDownloader.downloadIfNeeded(paperID: paper.id, pdfURL: paper.pdfURL)
            let repository = PaperRepository(context: modelContext)
            if try repository.isSaved(paperID: paper.id) {
                // Update the existing saved entry's local path now that the PDF has
                // been downloaded. Using a dedicated update method (rather than
                // toggling `toggleSave` off-then-on) avoids a transient window where
                // the paper would appear unsaved, and avoids relying on `toggleSave`'s
                // add/remove semantics to compose into an upsert.
                try repository.updateLocalPath(paperID: paper.id, path: path)
            }
            guard let document = PDFDocument(url: URL(fileURLWithPath: path)) else {
                errorMessage = "The downloaded file isn't a valid PDF."
                isLoading = false
                return
            }
            self.document = document
        } catch {
            errorMessage = "Couldn't download the PDF. Check your connection."
        }
        isLoading = false
    }
}
