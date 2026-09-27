import Foundation

enum PDFDownloadError: Error {
    case invalidResponse
}

enum PDFDownloader {
    /// Converts a paper ID into a filesystem-safe filename.
    ///
    /// Most arXiv IDs (e.g. `"2409.12345v1"`) are already safe to use directly.
    /// Old-style arXiv IDs (pre-2007, e.g. `"hep-th/9901001v1"`) contain a
    /// literal `/` separating the archive name from the paper number, which
    /// `URL.appendingPathComponent` would otherwise interpret as a nested
    /// directory. Replace it with `_` so the ID stays a single path component.
    static func sanitizedFilename(forPaperID paperID: String) -> String {
        let safeID = paperID.replacingOccurrences(of: "/", with: "_")
        return "\(safeID).pdf"
    }

    /// Downloads the PDF for `paperID` from `pdfURL` into the app's Documents
    /// directory (if not already present) and returns the local file path.
    static func downloadIfNeeded(paperID: String, pdfURL: URL) async throws -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = sanitizedFilename(forPaperID: paperID)
        let destinationURL = documentsURL.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return destinationURL.path
        }

        let (tempURL, response) = try await URLSession.shared.download(from: pdfURL)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw PDFDownloadError.invalidResponse
        }

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: tempURL, to: destinationURL)

        return destinationURL.path
    }
}
