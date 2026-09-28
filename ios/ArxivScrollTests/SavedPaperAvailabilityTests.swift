import XCTest
@testable import ArxivScroll

final class SavedPaperAvailabilityTests: XCTestCase {
    func test_isAvailable_falseWhenPathIsNil() {
        XCTAssertFalse(SavedPaper.isAvailable(localPDFPath: nil, fileManager: .default))
    }

    func test_isAvailable_falseWhenFileDoesNotExistOnDisk() {
        let missingPath = NSTemporaryDirectory() + "arxivscroll-nonexistent-\(UUID().uuidString).pdf"
        XCTAssertFalse(SavedPaper.isAvailable(localPDFPath: missingPath, fileManager: .default))
    }

    func test_isAvailable_trueWhenFileExistsOnDisk() throws {
        let path = NSTemporaryDirectory() + "arxivscroll-existing-\(UUID().uuidString).pdf"
        FileManager.default.createFile(atPath: path, contents: Data("test".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }

        XCTAssertTrue(SavedPaper.isAvailable(localPDFPath: path, fileManager: .default))
    }

    func test_savedPaperInstance_isAvailable_reflectsDiskState() throws {
        let path = NSTemporaryDirectory() + "arxivscroll-instance-\(UUID().uuidString).pdf"
        FileManager.default.createFile(atPath: path, contents: Data("test".utf8))
        defer { try? FileManager.default.removeItem(atPath: path) }

        let downloaded = SavedPaper(paperID: "p1", title: "Downloaded", localPDFPath: path)
        XCTAssertTrue(downloaded.isAvailable)

        let notDownloaded = SavedPaper(paperID: "p2", title: "Not Downloaded", localPDFPath: nil)
        XCTAssertFalse(notDownloaded.isAvailable)

        let deletedFile = SavedPaper(paperID: "p3", title: "Deleted", localPDFPath: NSTemporaryDirectory() + "does-not-exist-\(UUID().uuidString).pdf")
        XCTAssertFalse(deletedFile.isAvailable)
    }
}
