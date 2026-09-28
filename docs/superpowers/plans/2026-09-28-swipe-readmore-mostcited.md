# Swipe Smoothing, Read More, and Most Cited Filter Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix vertical swipe snapping in the Feed, replace the abstract's inner scroll with a Read More toggle, and add a "Most Cited" sort mode backed by Semantic Scholar citation data.

**Architecture:** All changes are additive/modifying within the existing `ios/ArxivScroll` SwiftUI app (MVVM). A new `SemanticScholarClient` networking type mirrors the existing `ArxivAPIClient` pattern. `ArxivAPIClient.feedURL`/`fetchPapers` gain a `sortBy` parameter. `FeedViewModel` gains a `sortMode` enum driving which arXiv sort + optional citation enrichment/re-sort is used.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, XCTest (existing project — no new dependencies).

---

### Task 1: Add `sortBy` parameter to `ArxivAPIClient` (TDD)

**Files:**
- Modify: `ios/ArxivScroll/Networking/ArxivAPIClient.swift`
- Modify: `ios/ArxivScrollTests/ArxivAPIClientQueryTests.swift`

The current `feedURL`/`fetchPapers` hardcode `sortBy=submittedDate`. This task makes that parameterizable so `.mostCited` mode (Task 4) can request `sortBy=relevance` with no date restriction.

- [ ] **Step 1: Update the existing tests for the new signature, and add a relevance-sort test**

Replace the full contents of `ios/ArxivScrollTests/ArxivAPIClientQueryTests.swift`:

```swift
import XCTest
@testable import ArxivScroll

final class ArxivAPIClientQueryTests: XCTestCase {
    func test_buildsURL_withSingleCategory_sortedBySubmittedDate() {
        let url = ArxivAPIClient.feedURL(categories: ["cs.AI"], start: 0, maxResults: 25, sortBy: .submittedDate)

        XCTAssertEqual(
            url.absoluteString,
            "https://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=submittedDate&sortOrder=descending&start=0&max_results=25"
        )
    }

    func test_buildsURL_withMultipleCategories_joinedByOR() {
        let url = ArxivAPIClient.feedURL(categories: ["cs.AI", "cs.LG"], start: 25, maxResults: 25, sortBy: .submittedDate)

        XCTAssertEqual(
            url.absoluteString,
            "https://export.arxiv.org/api/query?search_query=cat:cs.AI+OR+cat:cs.LG&sortBy=submittedDate&sortOrder=descending&start=25&max_results=25"
        )
    }

    func test_buildsURL_withRelevanceSort() {
        let url = ArxivAPIClient.feedURL(categories: ["cs.AI"], start: 0, maxResults: 25, sortBy: .relevance)

        XCTAssertEqual(
            url.absoluteString,
            "https://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=relevance&sortOrder=descending&start=0&max_results=25"
        )
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ios && xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivAPIClientQueryTests`
Expected: FAIL — `feedURL` doesn't have a `sortBy` parameter yet (compile error), and `ArxivAPIClient.SortBy` doesn't exist.

- [ ] **Step 3: Implement the `sortBy` parameter**

Replace the full contents of `ios/ArxivScroll/Networking/ArxivAPIClient.swift`:

```swift
import Foundation

enum ArxivAPIError: Error {
    case invalidResponse
}

enum ArxivAPIClient {
    enum SortBy: String {
        case submittedDate
        case relevance
    }

    static func feedURL(categories: [String], start: Int, maxResults: Int, sortBy: SortBy) -> URL {
        let searchQuery = categories.map { "cat:\($0)" }.joined(separator: "+OR+")
        // Built manually (not via URLComponents' percent-encoding) so "+" between
        // terms and inside "OR" stays literal, matching arXiv's documented query format.
        let urlString = "https://export.arxiv.org/api/query?search_query=\(searchQuery)&sortBy=\(sortBy.rawValue)&sortOrder=descending&start=\(start)&max_results=\(maxResults)"
        guard let url = URL(string: urlString) else {
            preconditionFailure("Constructed an invalid arXiv feed URL from categories: \(categories)")
        }
        return url
    }

    static func fetchPapers(categories: [String], start: Int, maxResults: Int = 25, sortBy: SortBy = .submittedDate) async throws -> [Paper] {
        let url = feedURL(categories: categories, start: start, maxResults: maxResults, sortBy: sortBy)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ArxivAPIError.invalidResponse
        }
        return try ArxivFeedParser.parse(data: data)
    }
}
```

Note: `fetchPapers`'s `sortBy` parameter defaults to `.submittedDate` so the one existing call site (`FeedViewModel.loadNextPage`, before Task 4 modifies it) keeps compiling unchanged until Task 4 makes it explicit.

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ios && xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivAPIClientQueryTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Full build check (this task changes a shared type's signature)**

Run: `cd ios && xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 6: Commit**

```bash
git add ios/ArxivScroll/Networking/ArxivAPIClient.swift ios/ArxivScrollTests/ArxivAPIClientQueryTests.swift
git commit -m "feat: add sortBy parameter to ArxivAPIClient for relevance vs. date sorting"
```

---

### Task 2: `SemanticScholarClient` for citation lookups (TDD)

**Files:**
- Create: `ios/ArxivScroll/Networking/SemanticScholarClient.swift`
- Test: `ios/ArxivScrollTests/SemanticScholarClientTests.swift`

This is a standalone networking type with no dependency on Task 1/4's changes — implementable independently.

- [ ] **Step 1: Write the failing tests**

```swift
// ios/ArxivScrollTests/SemanticScholarClientTests.swift
import XCTest
@testable import ArxivScroll

final class SemanticScholarClientTests: XCTestCase {
    func test_parsesCitationCounts_keyedByBareArxivID() throws {
        let json = """
        [
          {"externalIds": {"ArXiv": "2409.12345"}, "citationCount": 42},
          {"externalIds": {"ArXiv": "2410.00001"}, "citationCount": 7}
        ]
        """
        let data = json.data(using: .utf8)!

        let result = try SemanticScholarClient.parseCitationCounts(data: data)

        XCTAssertEqual(result, ["2409.12345": 42, "2410.00001": 7])
    }

    func test_parsesCitationCounts_skipsNullEntriesForUnmatchedIDs() throws {
        // Semantic Scholar's batch endpoint returns `null` in the array position
        // for any requested ID it has no match for, rather than omitting it.
        let json = """
        [
          {"externalIds": {"ArXiv": "2409.12345"}, "citationCount": 42},
          null
        ]
        """
        let data = json.data(using: .utf8)!

        let result = try SemanticScholarClient.parseCitationCounts(data: data)

        XCTAssertEqual(result, ["2409.12345": 42])
    }

    func test_stripsVersionSuffix_whenBuildingRequestIDs() {
        let ids = SemanticScholarClient.requestIDs(forArxivIDs: ["2409.12345v1", "2410.00001v2", "hep-th/9901001v1"])

        XCTAssertEqual(ids, ["ARXIV:2409.12345", "ARXIV:2410.00001", "ARXIV:hep-th/9901001"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `cd ios && xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/SemanticScholarClientTests`
Expected: FAIL — `SemanticScholarClient` is not defined.

- [ ] **Step 3: Implement `SemanticScholarClient`**

```swift
// ios/ArxivScroll/Networking/SemanticScholarClient.swift
import Foundation

enum SemanticScholarError: Error {
    case invalidResponse
}

enum SemanticScholarClient {
    private struct BatchResponseEntry: Decodable {
        struct ExternalIDs: Decodable {
            let ArXiv: String?
        }
        let externalIds: ExternalIDs?
        let citationCount: Int?
    }

    /// Strips a trailing version suffix (e.g. "v1", "v2") from an arXiv ID and
    /// prefixes it for Semantic Scholar's external-ID lookup format. Works for
    /// both modern ("2409.12345") and old-style ("hep-th/9901001") IDs, since
    /// the version suffix is always a trailing "vN" regardless of ID style.
    static func requestIDs(forArxivIDs arxivIDs: [String]) -> [String] {
        arxivIDs.map { id in
            let withoutVersion: String
            if let vIndex = id.range(of: "v", options: .backwards)?.lowerBound,
               id[id.index(after: vIndex)...].allSatisfy(\.isNumber),
               id.index(after: vIndex) < id.endIndex {
                withoutVersion = String(id[..<vIndex])
            } else {
                withoutVersion = id
            }
            return "ARXIV:\(withoutVersion)"
        }
    }

    /// Parses a Semantic Scholar `/paper/batch` response into a
    /// [bare arXiv ID: citationCount] dictionary. Entries the API couldn't
    /// match (returned as `null` in the response array) are skipped, not
    /// treated as an error — callers should treat a missing ID as 0 citations.
    static func parseCitationCounts(data: Data) throws -> [String: Int] {
        let entries = try JSONDecoder().decode([BatchResponseEntry?].self, from: data)
        var result: [String: Int] = [:]
        for entry in entries {
            guard let entry, let arxivID = entry.externalIds?.ArXiv, let citationCount = entry.citationCount else {
                continue
            }
            result[arxivID] = citationCount
        }
        return result
    }

    /// Fetches citation counts for a batch of arXiv IDs (with or without a
    /// version suffix; the suffix is stripped before lookup and the returned
    /// dictionary is keyed by the bare ID). Uses Semantic Scholar's free,
    /// unauthenticated batch endpoint — no API key required for this volume
    /// (one call per ~25-paper page).
    static func fetchCitationCounts(arxivIDs: [String]) async throws -> [String: Int] {
        guard !arxivIDs.isEmpty else { return [:] }

        let url = URL(string: "https://api.semanticscholar.org/graph/v1/paper/batch?fields=externalIds,citationCount")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["ids": requestIDs(forArxivIDs: arxivIDs)])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw SemanticScholarError.invalidResponse
        }
        return try parseCitationCounts(data: data)
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `cd ios && xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/SemanticScholarClientTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Regenerate the Xcode project and verify the new test file is genuinely wired in**

Run: `cd ios && xcodegen generate`
Then re-run Step 4's command. If `project.pbxproj` changed, include it in the commit below.

- [ ] **Step 6: Commit**

```bash
git add ios/ArxivScroll/Networking/SemanticScholarClient.swift ios/ArxivScrollTests/SemanticScholarClientTests.swift ios/ArxivScroll.xcodeproj/project.pbxproj
git commit -m "feat: add SemanticScholarClient for batch citation count lookups"
```

---

### Task 3: Fix swipe snapping and add Read More to `PaperCardView`

**Files:**
- Modify: `ios/ArxivScroll/Feed/PaperCardView.swift`
- Modify: `ios/ArxivScroll/Feed/FeedView.swift`

These two changes are grouped because they touch the same card-sizing mechanics: the fixed `.frame(height: 600)` in `FeedView` is replaced with `.containerRelativeFrame(.vertical)` so cards snap correctly, and `PaperCardView`'s content needs its own internal scroll to handle an expanded abstract within that new frame.

- [ ] **Step 1: Rewrite `PaperCardView` with Read More instead of an inner-scrolling abstract**

Replace the full contents of `ios/ArxivScroll/Feed/PaperCardView.swift`:

```swift
import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    @State private var isExpanded = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(paper.categories.joined(separator: ", "))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(paper.title)
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(paper.authors.joined(separator: ", "))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Text(paper.abstract)
                    .font(.body)
                    .lineLimit(isExpanded ? nil : 6)

                Button(isExpanded ? "Read less" : "Read more") {
                    withAnimation {
                        isExpanded.toggle()
                    }
                }
                .font(.subheadline)

                Spacer(minLength: 24)

                HStack {
                    Button(action: onToggleSave) {
                        Label(isSaved ? "Saved" : "Save", systemImage: isSaved ? "bookmark.fill" : "bookmark")
                    }
                    Spacer()
                    Button("Read PDF", action: onOpen)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

Note: the outer `ScrollView` here is the card's *own* internal scroll (only relevant when an expanded abstract overflows the card's fixed screen-height frame from Step 2 below) — it is a separate gesture recognizer nested inside `FeedView`'s outer paging `ScrollView`. SwiftUI resolves nested scroll gestures by giving the innermost one priority when its content actually overflows, and passing the gesture through to the outer scroll view when the inner content fits — this is standard, expected nested-ScrollView behavior, not a new gesture-conflict risk introduced here (the previous implementation already had an inner `ScrollView` around just the abstract; this keeps the same nesting pattern, just around the whole card's content column instead).

- [ ] **Step 2: Replace the fixed card frame with a container-relative frame in `FeedView`**

In `ios/ArxivScroll/Feed/FeedView.swift`, find this block inside the `ForEach`:

```swift
                                PaperCardView(
                                    paper: paper,
                                    isSaved: viewModel.isSaved(paper),
                                    onOpen: { readerPaper = paper },
                                    onToggleSave: { viewModel.toggleSave(paper) }
                                )
                                .frame(height: 600)
                                .onDisappear {
```

Replace the `.frame(height: 600)` line only, so the block becomes:

```swift
                                PaperCardView(
                                    paper: paper,
                                    isSaved: viewModel.isSaved(paper),
                                    onOpen: { readerPaper = paper },
                                    onToggleSave: { viewModel.toggleSave(paper) }
                                )
                                .containerRelativeFrame(.vertical)
                                .onDisappear {
```

And find this block:

```swift
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.papers) { paper in
```

Replace it with (adding `.scrollTargetLayout()` to the `LazyVStack`):

```swift
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.papers) { paper in
```
```swift
                        }
                        .scrollTargetLayout()
                    }
```

(i.e., add `.scrollTargetLayout()` as a modifier on the `LazyVStack`, right after its closing brace, before the outer `ScrollView`'s closing brace — the `ForEach`'s own closing brace is unaffected.)

The full modified section of `FeedView.swift` should read:

```swift
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.papers) { paper in
                                PaperCardView(
                                    paper: paper,
                                    isSaved: viewModel.isSaved(paper),
                                    onOpen: { readerPaper = paper },
                                    onToggleSave: { viewModel.toggleSave(paper) }
                                )
                                .containerRelativeFrame(.vertical)
                                .onDisappear {
                                    viewModel.markSeen(paper)
                                    Task { await viewModel.loadMoreIfNeeded(currentPaper: paper) }
                                }
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .scrollTargetBehavior(.paging)
                }
```

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ios && xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Manual verification in Simulator**

Run the app (Xcode ▶ Run, or `xcodebuild ... -destination 'platform=iOS Simulator,name=iPhone 16' run` — but interactive verification requires the Simulator GUI, not just a headless run). With at least 2-3 papers loaded in the feed:
- Swipe up/down: each swipe should land on exactly one full card, not a partial scroll between two cards.
- Tap "Read more" on a card with a long abstract: text expands, button changes to "Read less". Tap again to collapse.
- If an expanded abstract makes the card's content taller than the screen, the card's own content should become internally scrollable without breaking the outer swipe-to-next-card gesture when you swipe from an area of the card that isn't the abstract text itself.

- [ ] **Step 5: Commit**

```bash
git add ios/ArxivScroll/Feed/PaperCardView.swift ios/ArxivScroll/Feed/FeedView.swift
git commit -m "feat: fix swipe-to-card snapping and add Read More to abstracts"
```

---

### Task 4: Wire "Most Cited" sort mode into `FeedViewModel` and `FeedView`

**Files:**
- Modify: `ios/ArxivScroll/Feed/FeedViewModel.swift`
- Modify: `ios/ArxivScroll/Feed/FeedView.swift`

This task depends on Task 1 (`ArxivAPIClient.SortBy`) and Task 2 (`SemanticScholarClient`) both being complete.

- [ ] **Step 1: Add `SortMode` and citation-aware loading to `FeedViewModel`**

Replace the full contents of `ios/ArxivScroll/Feed/FeedViewModel.swift`:

```swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class FeedViewModel {
    enum SortMode: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case mostCited = "Most Cited"
        var id: String { rawValue }
    }

    private(set) var papers: [Paper] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    var sortMode: SortMode = .newest {
        didSet {
            guard sortMode != oldValue else { return }
            Task { await loadInitial() }
        }
    }

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

        // Capture the mode this load started under, so that if the user changes
        // sortMode again before this completes, we discard the stale result
        // instead of appending papers fetched under a mode the user already left.
        let modeAtStart = sortMode

        do {
            let fetched: [Paper]
            switch modeAtStart {
            case .newest:
                fetched = try await ArxivAPIClient.fetchPapers(categories: followedCodes, start: nextStart, maxResults: pageSize, sortBy: .submittedDate)
            case .mostCited:
                let relevanceSorted = try await ArxivAPIClient.fetchPapers(categories: followedCodes, start: nextStart, maxResults: pageSize, sortBy: .relevance)
                fetched = await Self.sortedByCitationCount(relevanceSorted)
            }

            guard modeAtStart == sortMode else {
                isLoading = false
                return
            }

            let unseen = try repository.filterUnseen(fetched)
            papers.append(contentsOf: unseen)
            nextStart += pageSize
        } catch {
            errorMessage = "Couldn't load new papers. Check your connection."
        }
        isLoading = false
    }

    /// Enriches a batch of papers with Semantic Scholar citation counts and
    /// sorts them descending by citation count. Papers with no citation data
    /// (too new to be indexed, or the lookup failed) sort last, treated as 0
    /// citations, rather than being dropped from the feed. If the citation
    /// lookup itself fails entirely (rate-limited, offline), the original
    /// relevance-sorted order is returned unchanged — citation enrichment is
    /// a nice-to-have, not a hard requirement to display papers.
    private static func sortedByCitationCount(_ papers: [Paper]) async -> [Paper] {
        guard let citationCounts = try? await SemanticScholarClient.fetchCitationCounts(arxivIDs: papers.map(\.id)) else {
            return papers
        }
        let bareIDs = SemanticScholarClient.requestIDs(forArxivIDs: papers.map(\.id))
        return zip(papers, bareIDs)
            .sorted { lhs, rhs in
                let lhsCount = citationCounts[String(lhs.1.dropFirst("ARXIV:".count))] ?? 0
                let rhsCount = citationCounts[String(rhs.1.dropFirst("ARXIV:".count))] ?? 0
                return lhsCount > rhsCount
            }
            .map(\.0)
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
```

Note on `sortedByCitationCount`'s ID matching: `SemanticScholarClient.requestIDs` returns strings like `"ARXIV:2409.12345"` (version-stripped, prefixed). The citation-count dictionary from `fetchCitationCounts` is keyed by the bare ID (e.g. `"2409.12345"`, matching `parseCitationCounts`'s output). `sortedByCitationCount` re-derives the bare ID by stripping the `"ARXIV:"` prefix from each `requestIDs` output to look up the dictionary — this avoids needing a second version-stripping pass, since `requestIDs` already stripped the version suffix.

- [ ] **Step 2: Add the sort-mode picker to `FeedView`**

In `ios/ArxivScroll/Feed/FeedView.swift`, add a `Picker` above the existing `ScrollView`/`ContentUnavailableView` branch. The full `body` should become:

```swift
    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    Picker("Sort", selection: Binding(
                        get: { viewModel.sortMode },
                        set: { viewModel.sortMode = $0 }
                    )) {
                        ForEach(FeedViewModel.SortMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 8)

                    if let errorMessage = viewModel.errorMessage, viewModel.papers.isEmpty {
                        ContentUnavailableView {
                            Label("Can't Load Feed", systemImage: "wifi.slash")
                        } description: {
                            Text(errorMessage)
                        } actions: {
                            Button("Retry") {
                                Task { await viewModel.loadInitial() }
                            }
                        }
                    } else {
                        ScrollView(.vertical) {
                            LazyVStack(spacing: 0) {
                                ForEach(viewModel.papers) { paper in
                                    PaperCardView(
                                        paper: paper,
                                        isSaved: viewModel.isSaved(paper),
                                        onOpen: { readerPaper = paper },
                                        onToggleSave: { viewModel.toggleSave(paper) }
                                    )
                                    .containerRelativeFrame(.vertical)
                                    .onDisappear {
                                        viewModel.markSeen(paper)
                                        Task { await viewModel.loadMoreIfNeeded(currentPaper: paper) }
                                    }
                                }
                            }
                            .scrollTargetLayout()
                        }
                        .scrollTargetBehavior(.paging)
                    }
                }
            } else {
                ProgressView()
                    .task {
                        let vm = FeedViewModel(context: modelContext)
                        viewModel = vm
                        await vm.loadInitial()
                    }
            }
        }
        .onDisappear {
            // Ensure any buffered "seen" marks are persisted even if the feed is
            // dismissed before another page-load flush point is reached.
            viewModel?.flushSeenPapers()
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Ensure buffered "seen" marks are persisted before the app is
            // backgrounded (and possibly killed while backgrounded), since
            // `.onDisappear` alone doesn't fire in that case. Flushing on both
            // `.inactive` and `.background` double-fires on a normal
            // active -> inactive -> background transition; harmless since
            // `flushSeenPapers()` no-ops on an empty buffer, and catching
            // `.inactive` also covers transient interruptions (e.g. an
            // incoming call) that don't reach `.background`.
            if newPhase == .background || newPhase == .inactive {
                viewModel?.flushSeenPapers()
            }
        }
        .sheet(item: $readerPaper) { paper in
            PDFReaderScreen(paper: paper)
        }
    }
```

Note: the container-relative card frame (`.containerRelativeFrame(.vertical)`, from Task 3) now sizes each card to the `ScrollView`'s own visible height, which is slightly less than full-screen because the `Picker` above it takes some vertical space. This is expected and correct — cards should fill whatever space is actually available for the feed, not the full screen including the picker.

- [ ] **Step 3: Build to verify it compiles**

Run: `cd ios && xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Run the full test suite to confirm no regressions**

Run: `cd ios && xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests`
Expected: All tests pass, with 0 failures. Test count should be 16 (prior baseline) + 1 net new from Task 1 (2 tests replaced by 3) + 3 net new from Task 2 (`SemanticScholarClientTests`) = 20 total.

- [ ] **Step 5: Manual verification in Simulator**

With at least one followed category that has real arXiv papers:
- Tapping "Most Cited" in the segmented control clears the current feed and loads a new one.
- The Most Cited feed should NOT look like a simple re-ordering of the newest 25 papers — since it queries `sortBy=relevance` across all time, you should see papers from a range of dates (some visibly older/well-known), not exclusively very recent ones.
- Switching back to "Newest" returns to the original date-sorted behavior.
- If offline or Semantic Scholar is rate-limited, Most Cited mode still shows papers (unsorted-by-citation fallback), not an empty/broken feed.

- [ ] **Step 6: Commit**

```bash
git add ios/ArxivScroll/Feed/FeedViewModel.swift ios/ArxivScroll/Feed/FeedView.swift
git commit -m "feat: add Most Cited sort mode using Semantic Scholar citation data"
```

---

## Self-Review Notes

- **Spec coverage:** Swipe smoothing (Task 3), Read More (Task 3), Most Cited filter with all-time relevance search + citation re-sort (Task 4), stale-mode race guard (Task 4 Step 1's `modeAtStart` check), Semantic Scholar failure fallback (Task 4 Step 1's `sortedByCitationCount` try?), old-style arXiv ID handling in citation lookups (Task 2's `requestIDs` test) — all covered.
- **Type consistency checked:** `ArxivAPIClient.SortBy`, `SemanticScholarClient.fetchCitationCounts`/`requestIDs`/`parseCitationCounts`, `FeedViewModel.SortMode` are each defined once and used with identical signatures across the tasks that reference them.
- **No placeholders remain** — every step has complete, runnable code, and the existing test file rewrite in Task 1 explicitly shows the full new contents rather than a diff description.
- **Test count math verified:** starting from 16 tests (per prior plan's final state), Task 1 replaces `ArxivAPIClientQueryTests`'s 2 tests with 3 (net +1 = 17), Task 2 adds 3 new tests in `SemanticScholarClientTests` (net +3 = 20). Task 4 Step 4 now correctly expects 20.
