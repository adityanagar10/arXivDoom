import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class FeedViewModel {
    private(set) var papers: [Paper] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?

    private let repository: PaperRepository
    private var nextStart = 0
    private let pageSize = 25
    private var followedCodes: [String] = []

    /// Paper IDs marked seen since the last flush to disk. Batching these avoids a
    /// synchronous SwiftData `context.save()` on every single card scrolled past
    /// (see `markSeen` / `flushSeenPapers`).
    private var pendingSeenIDs: [String] = []
    private let seenFlushThreshold = 5

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    func loadInitial() async {
        do {
            followedCodes = try repository.fetchFollowedCategories().map(\.code)
        } catch {
            errorMessage = "Couldn't load followed categories."
            return
        }
        guard !followedCodes.isEmpty else {
            errorMessage = "No categories followed."
            return
        }
        papers = []
        nextStart = 0
        await loadNextPage()
    }

    func loadNextPage() async {
        guard !isLoading, !followedCodes.isEmpty else { return }
        isLoading = true
        errorMessage = nil
        // Flush any buffered "seen" marks before fetching more, so progress is
        // persisted at a natural checkpoint (a new page load) rather than never.
        flushSeenPapers()
        do {
            let fetched = try await ArxivAPIClient.fetchPapers(categories: followedCodes, start: nextStart, maxResults: pageSize)
            let unseen = try repository.filterUnseen(fetched)
            papers.append(contentsOf: unseen)
            nextStart += pageSize
        } catch {
            errorMessage = "Couldn't load new papers. Check your connection."
        }
        isLoading = false
    }

    /// Call when a card has been scrolled past. Buffers the paper ID and only
    /// flushes to disk (a single `context.save()`) every `seenFlushThreshold`
    /// marks, or when a new page load happens, or when the view model is torn
    /// down (`flushSeenPapers` on deinit-adjacent paths). This avoids a disk
    /// flush per row during fast scrolling while still persisting promptly.
    func markSeen(_ paper: Paper) {
        pendingSeenIDs.append(paper.id)
        if pendingSeenIDs.count >= seenFlushThreshold {
            flushSeenPapers()
        }
    }

    /// Persists all buffered "seen" marks in a single SwiftData save.
    func flushSeenPapers() {
        guard !pendingSeenIDs.isEmpty else { return }
        let idsToFlush = pendingSeenIDs
        pendingSeenIDs.removeAll()
        try? repository.markSeenBatch(paperIDs: idsToFlush)
    }

    func isSaved(_ paper: Paper) -> Bool {
        (try? repository.isSaved(paperID: paper.id)) ?? false
    }

    func toggleSave(_ paper: Paper) {
        try? repository.toggleSave(paper: paper, localPDFPath: nil)
    }

    /// Call when the user is a few cards from the end of the loaded list.
    func loadMoreIfNeeded(currentPaper: Paper) async {
        guard let index = papers.firstIndex(where: { $0.id == currentPaper.id }) else { return }
        // `max(0, ...)` guards against `papers.count` being small enough (e.g. after
        // `filterUnseen` strips most of a page) that `papers.count - 5` would go
        // negative, which would make this true for every index.
        if index >= max(0, papers.count - 5) {
            await loadNextPage()
        }
    }
}
