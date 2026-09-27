# ArxivScroll Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build ArxivScroll, a SwiftUI iOS/macOS app that lets the user doom-scroll new arXiv papers by followed category, read them in an in-app PDFKit viewer, and maintain a local offline library of saved papers.

**Architecture:** Single SwiftUI multiplatform app (iOS + macOS Catalyst), MVVM with `@Observable` view models, SwiftData for persistence (followed categories, seen papers, saved papers), `URLSession` + `XMLParser` against arXiv's public Atom API, PDFKit for in-app PDF reading. No backend, no accounts.

**Tech Stack:** Swift 6, SwiftUI, SwiftData, PDFKit, XCTest. Xcode 16+.

---

## Prerequisites

This plan assumes an Xcode project does not yet exist. Task 1 creates it.

---

### Task 1: Xcode project scaffold

**Files:**
- Create: `ArxivScroll.xcodeproj` (via Xcode project generation)
- Create: `ArxivScroll/ArxivScrollApp.swift`
- Create: `ArxivScrollTests/ArxivScrollTests.swift` (placeholder, removed once real tests exist)

- [ ] **Step 1: Create the Xcode project**

Run:
```bash
mkdir -p /Users/dev/projects/paper
cd /Users/dev/projects/paper
```

Since this must be done through Xcode's project generation (no CLI-only equivalent produces a valid `.xcodeproj`), use Xcode: File → New → Project → Multiplatform → App. Product Name: `ArxivScroll`. Interface: SwiftUI. Language: Swift. Include Tests: checked. Save into `/Users/dev/projects/paper`.

Expected: `/Users/dev/projects/paper/ArxivScroll.xcodeproj` and `/Users/dev/projects/paper/ArxivScroll/ArxivScrollApp.swift` exist.

- [ ] **Step 2: Verify the empty project builds**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ArxivScroll.xcodeproj ArxivScroll ArxivScrollTests
git commit -m "chore: scaffold ArxivScroll Xcode multiplatform project"
```

---

### Task 2: Paper model and arXiv taxonomy data

**Files:**
- Create: `ArxivScroll/Models/Paper.swift`
- Create: `ArxivScroll/Models/ArxivCategory.swift`

- [ ] **Step 1: Write `Paper`**

```swift
// ArxivScroll/Models/Paper.swift
import Foundation

struct Paper: Identifiable, Hashable {
    let id: String // arXiv id, e.g. "2409.12345v1"
    let title: String
    let authors: [String]
    let abstract: String
    let categories: [String]
    let pdfURL: URL
    let publishedDate: Date
}
```

- [ ] **Step 2: Write the arXiv taxonomy data**

```swift
// ArxivScroll/Models/ArxivCategory.swift
import Foundation

struct ArxivCategory: Identifiable, Hashable {
    let code: String
    let displayName: String
    var id: String { code }
}

struct ArxivArchive: Identifiable {
    let name: String
    let categories: [ArxivCategory]
    var id: String { name }
}

enum ArxivTaxonomy {
    static let archives: [ArxivArchive] = [
        ArxivArchive(name: "Computer Science", categories: [
            ArxivCategory(code: "cs.AI", displayName: "Artificial Intelligence"),
            ArxivCategory(code: "cs.LG", displayName: "Machine Learning"),
            ArxivCategory(code: "cs.CL", displayName: "Computation and Language"),
            ArxivCategory(code: "cs.CV", displayName: "Computer Vision"),
            ArxivCategory(code: "cs.CR", displayName: "Cryptography and Security"),
            ArxivCategory(code: "cs.DC", displayName: "Distributed Computing"),
            ArxivCategory(code: "cs.SE", displayName: "Software Engineering"),
        ]),
        ArxivArchive(name: "Condensed Matter", categories: [
            ArxivCategory(code: "cond-mat.str-el", displayName: "Strongly Correlated Electrons"),
            ArxivCategory(code: "cond-mat.mes-hall", displayName: "Mesoscale and Nanoscale Physics"),
            ArxivCategory(code: "cond-mat.supr-con", displayName: "Superconductivity"),
        ]),
        ArxivArchive(name: "Physics", categories: [
            ArxivCategory(code: "physics.gen-ph", displayName: "General Physics"),
            ArxivCategory(code: "astro-ph.CO", displayName: "Cosmology and Nongalactic Astrophysics"),
            ArxivCategory(code: "quant-ph", displayName: "Quantum Physics"),
        ]),
        ArxivArchive(name: "Mathematics", categories: [
            ArxivCategory(code: "math.CO", displayName: "Combinatorics"),
            ArxivCategory(code: "math.PR", displayName: "Probability"),
            ArxivCategory(code: "math.ST", displayName: "Statistics Theory"),
        ]),
    ]
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ArxivScroll/Models/Paper.swift ArxivScroll/Models/ArxivCategory.swift
git commit -m "feat: add Paper model and arXiv taxonomy data"
```

---

### Task 3: SwiftData models (FollowedCategory, SeenPaper, SavedPaper)

**Files:**
- Create: `ArxivScroll/Models/FollowedCategory.swift`
- Create: `ArxivScroll/Models/SeenPaper.swift`
- Create: `ArxivScroll/Models/SavedPaper.swift`
- Modify: `ArxivScroll/ArxivScrollApp.swift`

- [ ] **Step 1: Write the three SwiftData models**

```swift
// ArxivScroll/Models/FollowedCategory.swift
import Foundation
import SwiftData

@Model
final class FollowedCategory {
    @Attribute(.unique) var code: String
    var displayName: String

    init(code: String, displayName: String) {
        self.code = code
        self.displayName = displayName
    }
}
```

```swift
// ArxivScroll/Models/SeenPaper.swift
import Foundation
import SwiftData

@Model
final class SeenPaper {
    @Attribute(.unique) var paperID: String
    var seenDate: Date

    init(paperID: String, seenDate: Date = .now) {
        self.paperID = paperID
        self.seenDate = seenDate
    }
}
```

```swift
// ArxivScroll/Models/SavedPaper.swift
import Foundation
import SwiftData

@Model
final class SavedPaper {
    @Attribute(.unique) var paperID: String
    var title: String
    var savedDate: Date
    var localPDFPath: String?

    init(paperID: String, title: String, savedDate: Date = .now, localPDFPath: String? = nil) {
        self.paperID = paperID
        self.title = title
        self.savedDate = savedDate
        self.localPDFPath = localPDFPath
    }
}
```

- [ ] **Step 2: Wire the ModelContainer into the app entry point**

Read the current contents of `ArxivScroll/ArxivScrollApp.swift` first (Xcode's default template), then replace its body with:

```swift
// ArxivScroll/ArxivScrollApp.swift
import SwiftUI
import SwiftData

@main
struct ArxivScrollApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [FollowedCategory.self, SeenPaper.self, SavedPaper.self])
    }
}
```

Note: `RootView` doesn't exist yet — Task 9 creates it. For now, temporarily replace `RootView()` with `Text("ArxivScroll")` so this task builds standalone; Task 9 will change it back.

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/Models/FollowedCategory.swift ArxivScroll/Models/SeenPaper.swift ArxivScroll/Models/SavedPaper.swift ArxivScroll/ArxivScrollApp.swift
git commit -m "feat: add SwiftData models and wire ModelContainer"
```

---

### Task 4: Atom XML feed parser (TDD)

**Files:**
- Create: `ArxivScroll/Networking/ArxivFeedParser.swift`
- Test: `ArxivScrollTests/ArxivFeedParserTests.swift`

- [ ] **Step 1: Write the failing test with a fixture Atom response**

```swift
// ArxivScrollTests/ArxivFeedParserTests.swift
import XCTest
@testable import ArxivScroll

final class ArxivFeedParserTests: XCTestCase {
    func test_parsesValidEntryIntoPaper() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom" xmlns:arxiv="http://arxiv.org/schemas/atom">
          <entry>
            <id>http://arxiv.org/abs/2409.12345v1</id>
            <title>A Great Paper Title</title>
            <summary>  This is the abstract text.  </summary>
            <published>2026-09-20T12:00:00Z</published>
            <author><name>Jane Doe</name></author>
            <author><name>John Smith</name></author>
            <category term="cs.AI" />
            <category term="cs.LG" />
            <link title="pdf" href="http://arxiv.org/pdf/2409.12345v1" rel="related" type="application/pdf" />
          </entry>
        </feed>
        """
        let data = xml.data(using: .utf8)!

        let papers = try ArxivFeedParser.parse(data: data)

        XCTAssertEqual(papers.count, 1)
        let paper = papers[0]
        XCTAssertEqual(paper.id, "2409.12345v1")
        XCTAssertEqual(paper.title, "A Great Paper Title")
        XCTAssertEqual(paper.abstract, "This is the abstract text.")
        XCTAssertEqual(paper.authors, ["Jane Doe", "John Smith"])
        XCTAssertEqual(paper.categories, ["cs.AI", "cs.LG"])
        XCTAssertEqual(paper.pdfURL, URL(string: "http://arxiv.org/pdf/2409.12345v1")!)
    }

    func test_skipsEntryMissingTitle() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <id>http://arxiv.org/abs/2409.99999v1</id>
            <summary>No title here.</summary>
            <published>2026-09-20T12:00:00Z</published>
            <link title="pdf" href="http://arxiv.org/pdf/2409.99999v1" rel="related" type="application/pdf" />
          </entry>
        </feed>
        """
        let data = xml.data(using: .utf8)!

        let papers = try ArxivFeedParser.parse(data: data)

        XCTAssertEqual(papers.count, 0)
    }

    func test_skipsEntryMissingID() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <feed xmlns="http://www.w3.org/2005/Atom">
          <entry>
            <title>Untitled but no id</title>
            <summary>Abstract text.</summary>
            <published>2026-09-20T12:00:00Z</published>
            <link title="pdf" href="http://arxiv.org/pdf/2409.88888v1" rel="related" type="application/pdf" />
          </entry>
        </feed>
        """
        let data = xml.data(using: .utf8)!

        let papers = try ArxivFeedParser.parse(data: data)

        XCTAssertEqual(papers.count, 0)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivFeedParserTests`
Expected: FAIL — `ArxivFeedParser` is not defined (compile error).

- [ ] **Step 3: Implement `ArxivFeedParser`**

```swift
// ArxivScroll/Networking/ArxivFeedParser.swift
import Foundation

enum ArxivFeedParser {
    static func parse(data: Data) throws -> [Paper] {
        let delegate = ParserDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate
        parser.parse()
        return delegate.papers
    }

    private final class ParserDelegate: NSObject, XMLParserDelegate {
        var papers: [Paper] = []

        private var currentElement = ""
        private var currentID: String?
        private var currentTitle: String?
        private var currentSummary: String?
        private var currentPublished: String?
        private var currentAuthors: [String] = []
        private var currentCategories: [String] = []
        private var currentPDFURL: URL?
        private var currentText = ""
        private var inEntry = false

        private static let dateFormatter: ISO8601DateFormatter = {
            let f = ISO8601DateFormatter()
            f.formatOptions = [.withInternetDateTime]
            return f
        }()

        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
            currentElement = elementName
            currentText = ""

            if elementName == "entry" {
                inEntry = true
                currentID = nil
                currentTitle = nil
                currentSummary = nil
                currentPublished = nil
                currentAuthors = []
                currentCategories = []
                currentPDFURL = nil
            } else if inEntry, elementName == "category", let term = attributeDict["term"] {
                currentCategories.append(term)
            } else if inEntry, elementName == "link",
                      attributeDict["title"] == "pdf",
                      let href = attributeDict["href"],
                      let url = URL(string: href) {
                currentPDFURL = url
            }
        }

        func parser(_ parser: XMLParser, foundCharacters string: String) {
            currentText += string
        }

        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            guard inEntry else { return }

            let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)

            switch elementName {
            case "id":
                // Atom id is a full URL like http://arxiv.org/abs/2409.12345v1
                currentID = trimmed.components(separatedBy: "/abs/").last
            case "title":
                currentTitle = trimmed
            case "summary":
                currentSummary = trimmed
            case "published":
                currentPublished = trimmed
            case "name":
                currentAuthors.append(trimmed)
            case "entry":
                inEntry = false
                if let id = currentID,
                   let title = currentTitle, !title.isEmpty,
                   let summary = currentSummary,
                   let publishedString = currentPublished,
                   let publishedDate = Self.dateFormatter.date(from: publishedString),
                   let pdfURL = currentPDFURL {
                    papers.append(Paper(
                        id: id,
                        title: title,
                        authors: currentAuthors,
                        abstract: summary,
                        categories: currentCategories,
                        pdfURL: pdfURL,
                        publishedDate: publishedDate
                    ))
                }
            default:
                break
            }
        }
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivFeedParserTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add ArxivScroll/Networking/ArxivFeedParser.swift ArxivScrollTests/ArxivFeedParserTests.swift
git commit -m "feat: add Atom XML feed parser with TDD coverage"
```

---

### Task 5: arXiv query construction and API client (TDD)

**Files:**
- Create: `ArxivScroll/Networking/ArxivAPIClient.swift`
- Test: `ArxivScrollTests/ArxivAPIClientQueryTests.swift`

- [ ] **Step 1: Write the failing test for query construction**

```swift
// ArxivScrollTests/ArxivAPIClientQueryTests.swift
import XCTest
@testable import ArxivScroll

final class ArxivAPIClientQueryTests: XCTestCase {
    func test_buildsURL_withSingleCategory() {
        let url = ArxivAPIClient.feedURL(categories: ["cs.AI"], start: 0, maxResults: 25)

        XCTAssertEqual(
            url.absoluteString,
            "https://export.arxiv.org/api/query?search_query=cat:cs.AI&sortBy=submittedDate&sortOrder=descending&start=0&max_results=25"
        )
    }

    func test_buildsURL_withMultipleCategories_joinedByOR() {
        let url = ArxivAPIClient.feedURL(categories: ["cs.AI", "cs.LG"], start: 25, maxResults: 25)

        XCTAssertEqual(
            url.absoluteString,
            "https://export.arxiv.org/api/query?search_query=cat:cs.AI+OR+cat:cs.LG&sortBy=submittedDate&sortOrder=descending&start=25&max_results=25"
        )
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivAPIClientQueryTests`
Expected: FAIL — `ArxivAPIClient` is not defined.

- [ ] **Step 3: Implement `ArxivAPIClient`**

```swift
// ArxivScroll/Networking/ArxivAPIClient.swift
import Foundation

enum ArxivAPIError: Error {
    case invalidResponse
}

enum ArxivAPIClient {
    static func feedURL(categories: [String], start: Int, maxResults: Int) -> URL {
        let searchQuery = categories.map { "cat:\($0)" }.joined(separator: "+OR+")
        // Built manually (not via URLComponents' percent-encoding) so "+" between
        // terms and inside "OR" stays literal, matching arXiv's documented query format.
        let urlString = "https://export.arxiv.org/api/query?search_query=\(searchQuery)&sortBy=submittedDate&sortOrder=descending&start=\(start)&max_results=\(maxResults)"
        guard let url = URL(string: urlString) else {
            preconditionFailure("Constructed an invalid arXiv feed URL from categories: \(categories)")
        }
        return url
    }

    static func fetchPapers(categories: [String], start: Int, maxResults: Int = 25) async throws -> [Paper] {
        let url = feedURL(categories: categories, start: start, maxResults: maxResults)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw ArxivAPIError.invalidResponse
        }
        return try ArxivFeedParser.parse(data: data)
    }
}
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/ArxivAPIClientQueryTests`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add ArxivScroll/Networking/ArxivAPIClient.swift ArxivScrollTests/ArxivAPIClientQueryTests.swift
git commit -m "feat: add arXiv API client with query construction"
```

---

### Task 6: PDF downloader

**Files:**
- Create: `ArxivScroll/Persistence/PDFDownloader.swift`

- [ ] **Step 1: Implement the downloader**

```swift
// ArxivScroll/Persistence/PDFDownloader.swift
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
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: Commit**

```bash
git add ArxivScroll/Persistence/PDFDownloader.swift
git commit -m "feat: add PDF downloader for local library storage"
```

---

### Task 7: Persistence dedup logic (TDD)

**Files:**
- Create: `ArxivScroll/Persistence/PaperRepository.swift`
- Test: `ArxivScrollTests/PersistenceDedupTests.swift`

This isolates the SwiftData read/write rules (seen dedup, save/unsave toggling) behind one type so `FeedViewModel` and `LibraryViewModel` don't duplicate query logic.

- [ ] **Step 1: Write the failing tests**

```swift
// ArxivScrollTests/PersistenceDedupTests.swift
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
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/PersistenceDedupTests`
Expected: FAIL — `PaperRepository` is not defined.

- [ ] **Step 3: Implement `PaperRepository`**

```swift
// ArxivScroll/Persistence/PaperRepository.swift
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
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' -only-testing:ArxivScrollTests/PersistenceDedupTests`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add ArxivScroll/Persistence/PaperRepository.swift ArxivScrollTests/PersistenceDedupTests.swift
git commit -m "feat: add PaperRepository for seen/save persistence logic"
```

---

### Task 8: Onboarding (category picker)

**Files:**
- Create: `ArxivScroll/Onboarding/OnboardingViewModel.swift`
- Create: `ArxivScroll/Onboarding/OnboardingView.swift`

- [ ] **Step 1: Implement the view model**

```swift
// ArxivScroll/Onboarding/OnboardingViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    var selectedCodes: Set<String> = []
    private let repository: PaperRepository

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    var canContinue: Bool { !selectedCodes.isEmpty }

    func toggle(_ category: ArxivCategory) {
        if selectedCodes.contains(category.code) {
            selectedCodes.remove(category.code)
        } else {
            selectedCodes.insert(category.code)
        }
    }

    func isSelected(_ category: ArxivCategory) -> Bool {
        selectedCodes.contains(category.code)
    }

    func saveSelection() throws {
        let selected = ArxivTaxonomy.archives
            .flatMap(\.categories)
            .filter { selectedCodes.contains($0.code) }
        try repository.setFollowedCategories(selected)
    }
}
```

- [ ] **Step 2: Implement the view**

```swift
// ArxivScroll/Onboarding/OnboardingView.swift
import SwiftUI
import SwiftData

struct OnboardingView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: OnboardingViewModel?
    let onComplete: () -> Void

    var body: some View {
        Group {
            if let viewModel {
                NavigationStack {
                    List {
                        ForEach(ArxivTaxonomy.archives) { archive in
                            Section(archive.name) {
                                ForEach(archive.categories) { category in
                                    Button {
                                        viewModel.toggle(category)
                                    } label: {
                                        HStack {
                                            Text(category.displayName)
                                            Spacer()
                                            if viewModel.isSelected(category) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .navigationTitle("Follow Categories")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                try? viewModel.saveSelection()
                                onComplete()
                            }
                            .disabled(!viewModel.canContinue)
                        }
                    }
                }
            } else {
                ProgressView()
                    .task {
                        viewModel = OnboardingViewModel(context: modelContext)
                    }
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/Onboarding/OnboardingViewModel.swift ArxivScroll/Onboarding/OnboardingView.swift
git commit -m "feat: add onboarding category picker"
```

---

### Task 9: Feed view model and paging card UI

**Files:**
- Create: `ArxivScroll/Feed/FeedViewModel.swift`
- Create: `ArxivScroll/Feed/PaperCardView.swift`
- Create: `ArxivScroll/Feed/FeedView.swift`

- [ ] **Step 1: Implement the feed view model**

```swift
// ArxivScroll/Feed/FeedViewModel.swift
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

    /// Call when a card has been scrolled past.
    func markSeen(_ paper: Paper) {
        try? repository.markSeen(paperID: paper.id)
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
        if index >= papers.count - 5 {
            await loadNextPage()
        }
    }
}
```

- [ ] **Step 2: Implement the card view**

```swift
// ArxivScroll/Feed/PaperCardView.swift
import SwiftUI

struct PaperCardView: View {
    let paper: Paper
    let isSaved: Bool
    let onOpen: () -> Void
    let onToggleSave: () -> Void

    var body: some View {
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

            ScrollView {
                Text(paper.abstract)
                    .font(.body)
            }

            Spacer()

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
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
```

- [ ] **Step 3: Implement the paging feed view**

```swift
// ArxivScroll/Feed/FeedView.swift
import SwiftUI
import SwiftData

struct FeedView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: FeedViewModel?
    @State private var readerPaper: Paper?

    var body: some View {
        Group {
            if let viewModel {
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
                                .frame(height: 600)
                                .onDisappear {
                                    viewModel.markSeen(paper)
                                    Task { await viewModel.loadMoreIfNeeded(currentPaper: paper) }
                                }
                            }
                        }
                    }
                    .scrollTargetBehavior(.paging)
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
        .sheet(item: $readerPaper) { paper in
            PDFReaderScreen(paper: paper)
        }
    }
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`
Note: this will fail until Task 10 creates `PDFReaderScreen` — if executing tasks in strict order, do Task 10 before this build check, or stub `PDFReaderScreen` temporarily. Recommended: implement Task 10 immediately after this step before committing.

- [ ] **Step 5: Commit**

```bash
git add ArxivScroll/Feed/FeedViewModel.swift ArxivScroll/Feed/PaperCardView.swift ArxivScroll/Feed/FeedView.swift
git commit -m "feat: add feed view model and paging card UI"
```

---

### Task 10: PDFKit reader

**Files:**
- Create: `ArxivScroll/Reader/PDFReaderView.swift`
- Create: `ArxivScroll/Reader/PDFReaderScreen.swift`

- [ ] **Step 1: Implement the cross-platform PDFKit wrapper**

```swift
// ArxivScroll/Reader/PDFReaderView.swift
import SwiftUI
import PDFKit

#if os(macOS)
struct PDFReaderView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#else
struct PDFReaderView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.document = document
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#endif
```

- [ ] **Step 2: Implement the screen that downloads and hosts the reader**

```swift
// ArxivScroll/Reader/PDFReaderScreen.swift
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
                // Update existing saved entry with the local path now that it's downloaded.
                try repository.toggleSave(paper: paper, localPDFPath: path)
                try repository.toggleSave(paper: paper, localPDFPath: path)
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
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/Reader/PDFReaderView.swift ArxivScroll/Reader/PDFReaderScreen.swift
git commit -m "feat: add PDFKit reader screen with download-on-open"
```

---

### Task 11: Library tab

**Files:**
- Create: `ArxivScroll/Library/LibraryViewModel.swift`
- Create: `ArxivScroll/Library/LibraryView.swift`

- [ ] **Step 1: Implement the view model**

```swift
// ArxivScroll/Library/LibraryViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var savedPapers: [SavedPaper] = []
    private let repository: PaperRepository

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    func load() {
        savedPapers = (try? repository.fetchAllSaved()) ?? []
    }
}
```

- [ ] **Step 2: Implement the view**

```swift
// ArxivScroll/Library/LibraryView.swift
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
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/Library/LibraryViewModel.swift ArxivScroll/Library/LibraryView.swift
git commit -m "feat: add local library tab for offline saved papers"
```

---

### Task 12: Settings tab (edit followed categories)

**Files:**
- Create: `ArxivScroll/Settings/SettingsViewModel.swift`
- Create: `ArxivScroll/Settings/SettingsView.swift`

- [ ] **Step 1: Implement the view model**

```swift
// ArxivScroll/Settings/SettingsViewModel.swift
import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var selectedCodes: Set<String> = []
    private let repository: PaperRepository

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    func load() {
        let followed = (try? repository.fetchFollowedCategories()) ?? []
        selectedCodes = Set(followed.map(\.code))
    }

    func toggle(_ category: ArxivCategory) {
        if selectedCodes.contains(category.code) {
            selectedCodes.remove(category.code)
        } else {
            selectedCodes.insert(category.code)
        }
    }

    func isSelected(_ category: ArxivCategory) -> Bool {
        selectedCodes.contains(category.code)
    }

    func save() {
        let selected = ArxivTaxonomy.archives
            .flatMap(\.categories)
            .filter { selectedCodes.contains($0.code) }
        try? repository.setFollowedCategories(selected)
    }
}
```

- [ ] **Step 2: Implement the view**

```swift
// ArxivScroll/Settings/SettingsView.swift
import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var viewModel: SettingsViewModel?

    var body: some View {
        NavigationStack {
            Group {
                if let viewModel {
                    List {
                        ForEach(ArxivTaxonomy.archives) { archive in
                            Section(archive.name) {
                                ForEach(archive.categories) { category in
                                    Button {
                                        viewModel.toggle(category)
                                        viewModel.save()
                                    } label: {
                                        HStack {
                                            Text(category.displayName)
                                            Spacer()
                                            if viewModel.isSelected(category) {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                    .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                } else {
                    ProgressView()
                }
            }
            .navigationTitle("Followed Categories")
            .task {
                let vm = SettingsViewModel(context: modelContext)
                vm.load()
                viewModel = vm
            }
        }
    }
}
```

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/Settings/SettingsViewModel.swift ArxivScroll/Settings/SettingsView.swift
git commit -m "feat: add settings tab for editing followed categories"
```

---

### Task 13: RootView — onboarding gate + main TabView

**Files:**
- Create: `ArxivScroll/RootView.swift`
- Modify: `ArxivScroll/ArxivScrollApp.swift`

- [ ] **Step 1: Implement `RootView`**

```swift
// ArxivScroll/RootView.swift
import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var hasFollowedCategories: Bool?

    var body: some View {
        Group {
            switch hasFollowedCategories {
            case .some(true):
                TabView {
                    FeedView()
                        .tabItem { Label("Feed", systemImage: "list.bullet") }
                    LibraryView()
                        .tabItem { Label("Library", systemImage: "bookmark") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            case .some(false):
                OnboardingView {
                    hasFollowedCategories = true
                }
            case .none:
                ProgressView()
            }
        }
        .task {
            let repository = PaperRepository(context: modelContext)
            let followed = (try? repository.fetchFollowedCategories()) ?? []
            hasFollowedCategories = !followed.isEmpty
        }
    }
}
```

- [ ] **Step 2: Point the app entry back at `RootView`**

Edit `ArxivScroll/ArxivScrollApp.swift` (from Task 3, Step 2) so the `WindowGroup` body is:

```swift
        WindowGroup {
            RootView()
        }
```

(Removing the temporary `Text("ArxivScroll")` placeholder.)

- [ ] **Step 3: Build to verify it compiles**

Run: `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' build`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 4: Commit**

```bash
git add ArxivScroll/RootView.swift ArxivScroll/ArxivScrollApp.swift
git commit -m "feat: wire onboarding gate and main TabView into app root"
```

---

### Task 14: Run full test suite and manual smoke test

**Files:** none (verification task)

- [ ] **Step 1: Run the full automated test suite**

Run: `xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16'`
Expected: All tests PASS (`ArxivFeedParserTests`, `ArxivAPIClientQueryTests`, `PersistenceDedupTests`).

- [ ] **Step 2: Manual smoke test in Simulator**

Run the app in Simulator (Xcode ▶ Run, or `xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll -destination 'platform=iOS Simulator,name=iPhone 16' run`). Manually verify:
- Onboarding shows category list; selecting none disables "Done"; selecting one enables it.
- After onboarding, Feed tab loads real papers from arXiv for the selected categories.
- Scrolling past a card and relaunching the app does not re-show that paper.
- Tapping "Read PDF" downloads and displays the PDF in-app.
- Tapping "Save" marks a card as saved; it appears in the Library tab and opens offline (toggle Airplane Mode to confirm).
- Settings tab reflects the onboarding selection and changing it changes the Feed's results.

- [ ] **Step 3: Commit if any fixes were needed during smoke test**

```bash
git add -A
git commit -m "fix: address issues found during manual smoke test"
```
(Skip this step if no fixes were needed.)

---

## Self-Review Notes

- **Spec coverage:** Onboarding picker (Task 8), editable Settings (Task 12), title+abstract cards (Task 9), in-app PDFKit reader (Task 10), full local library with seen/save/offline PDFs (Tasks 3, 7, 9, 11), error/edge cases — no network, API failure, PDF failure, empty categories, malformed XML (Tasks 4 test coverage, 9 error states, 10 error states, 8/12 canContinue gating) — all covered.
- **Type consistency checked:** `Paper`, `FollowedCategory`, `SeenPaper`, `SavedPaper`, `PaperRepository`, `ArxivCategory`/`ArxivTaxonomy` are defined once (Tasks 2, 3, 7) and reused with identical signatures across Feed, Library, Settings, Onboarding, Reader tasks.
- **No placeholders remain** — every step has complete, runnable code.
