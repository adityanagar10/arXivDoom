import XCTest
@testable import ArxivScroll

final class PDFDownloaderTests: XCTestCase {
    func test_sanitizedFilename_modernID_isUnchanged() {
        let filename = PDFDownloader.sanitizedFilename(forPaperID: "2409.12345v1")

        XCTAssertEqual(filename, "2409.12345v1.pdf")
    }

    func test_sanitizedFilename_oldStyleID_replacesSlashWithUnderscore() {
        let filename = PDFDownloader.sanitizedFilename(forPaperID: "hep-th/9901001v1")

        XCTAssertEqual(filename, "hep-th_9901001v1.pdf")
    }

    func test_sanitizedFilename_oldStyleID_producesSinglePathComponent() {
        let filename = PDFDownloader.sanitizedFilename(forPaperID: "quant-ph/0201001v2")
        let documentsURL = URL(fileURLWithPath: "/tmp/Documents")
        let destinationURL = documentsURL.appendingPathComponent(filename)

        // The sanitized filename must not introduce a nested directory:
        // resolving it against Documents should stay a direct child.
        XCTAssertEqual(destinationURL.deletingLastPathComponent().path, documentsURL.path)
        XCTAssertEqual(destinationURL.lastPathComponent, "quant-ph_0201001v2.pdf")
    }
}
