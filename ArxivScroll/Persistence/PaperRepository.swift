import Foundation
import SwiftData

@MainActor
final class PaperRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func filterUnseen(_ papers: [Paper]) throws -> [Paper] {
        let descriptor = FetchDescriptor<SeenPaper>()
        let seenIDs = Set(try context.fetch(descriptor).map(\.paperID))
        return papers.filter { !seenIDs.contains($0.id) }
    }

    func markSeen(paperID: String) throws {
        let descriptor = FetchDescriptor<SeenPaper>(predicate: #Predicate { $0.paperID == paperID })
        if try context.fetch(descriptor).isEmpty {
            context.insert(SeenPaper(paperID: paperID))
            try context.save()
        }
    }

    /// Inserts a `SeenPaper` for each of `paperIDs` that isn't already recorded,
    /// then persists all of them in a single `context.save()`. Intended for callers
    /// (e.g. `FeedViewModel`) that want to batch many "seen" marks together rather
    /// than saving on every individual `markSeen` call.
    func markSeenBatch(paperIDs: [String]) throws {
        guard !paperIDs.isEmpty else { return }
        let descriptor = FetchDescriptor<SeenPaper>()
        var seenIDs = Set(try context.fetch(descriptor).map(\.paperID))
        for paperID in paperIDs {
            guard !seenIDs.contains(paperID) else { continue }
            context.insert(SeenPaper(paperID: paperID))
            seenIDs.insert(paperID)
        }
        try context.save()
    }

    func isSaved(paperID: String) throws -> Bool {
        let descriptor = FetchDescriptor<SavedPaper>(predicate: #Predicate { $0.paperID == paperID })
        return try !context.fetch(descriptor).isEmpty
    }

    /// Adds a SavedPaper if not present, removes it if present.
    func toggleSave(paper: Paper, localPDFPath: String?) throws {
        let paperID = paper.id
        let descriptor = FetchDescriptor<SavedPaper>(predicate: #Predicate { $0.paperID == paperID })
        let existing = try context.fetch(descriptor)

        if let existing = existing.first {
            context.delete(existing)
        } else {
            context.insert(SavedPaper(paperID: paper.id, title: paper.title, localPDFPath: localPDFPath))
        }
        try context.save()
    }

    func fetchAllSaved() throws -> [SavedPaper] {
        let descriptor = FetchDescriptor<SavedPaper>(sortBy: [SortDescriptor(\.savedDate, order: .reverse)])
        return try context.fetch(descriptor)
    }

    func fetchFollowedCategories() throws -> [FollowedCategory] {
        try context.fetch(FetchDescriptor<FollowedCategory>())
    }

    func setFollowedCategories(_ categories: [ArxivCategory]) throws {
        let existing = try context.fetch(FetchDescriptor<FollowedCategory>())
        for item in existing {
            context.delete(item)
        }
        for category in categories {
            context.insert(FollowedCategory(code: category.code, displayName: category.displayName))
        }
        try context.save()
    }
}
