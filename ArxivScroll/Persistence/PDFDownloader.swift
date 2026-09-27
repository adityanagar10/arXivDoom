import Foundation

enum PDFDownloadError: Error {
    case invalidResponse
}

enum PDFDownloader {
    /// Downloads the PDF for `paperID` from `pdfURL` into the app's Documents
    /// directory (if not already present) and returns the local file path.
    static func downloadIfNeeded(paperID: String, pdfURL: URL) async throws -> String {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let filename = "\(paperID).pdf"
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
