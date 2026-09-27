import XCTest
import SwiftData
@testable import ArxivScroll

@MainActor
final class PersistenceDedupTests: XCTestCase {
    private func makeInMemoryContext() throws -> ModelContext {
        let schema = Schema([FollowedCategory.self, SeenPaper.self, SavedPaper.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [config])
        return ModelContext(container)
    }

    func test_filterUnseen_excludesAlreadySeenPapers() throws {
        let context = try makeInMemoryContext()
        let repo = PaperRepository(context: context)

        let seen = Paper(id: "seen-1", title: "Seen", authors: [], abstract: "", categories: [], pdfURL: URL(string: "https://example.com/seen.pdf")!, publishedDate: .now)
        let unseen = Paper(id: "unseen-1", title: "Unseen", authors: [], abstract: "", categories: [], pdfURL: URL(string: "https://example.com/unseen.pdf")!, publishedDate: .now)

        try repo.markSeen(paperID: seen.id)

        let result = try repo.filterUnseen([seen, unseen])

        XCTAssertEqual(result.map(\.id), ["unseen-1"])
    }

    func test_toggleSave_addsAndRemovesSavedPaper() throws {
        let context = try makeInMemoryContext()
        let repo = PaperRepository(context: context)

        let paper = Paper(id: "save-1", title: "Save Me", authors: [], abstract: "", categories: [], pdfURL: URL(string: "https://example.com/save.pdf")!, publishedDate: .now)

        XCTAssertFalse(try repo.isSaved(paperID: paper.id))

        try repo.toggleSave(paper: paper, localPDFPath: nil)
        XCTAssertTrue(try repo.isSaved(paperID: paper.id))

        try repo.toggleSave(paper: paper, localPDFPath: nil)
        XCTAssertFalse(try repo.isSaved(paperID: paper.id))
    }
}
