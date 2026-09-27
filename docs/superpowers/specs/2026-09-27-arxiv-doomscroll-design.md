# ArxivScroll — Design Spec

## Overview
A Swift app (iOS + macOS via Catalyst) that lets the user "doom scroll" through new arXiv papers in categories they follow. Each card shows a paper's title and abstract; tapping opens the full PDF in an in-app reader. Seen papers aren't repeated, and papers can be saved to a local offline library.

## Goals
- Free, no-account, no-backend feed of new arXiv papers filtered by followed categories.
- Fast vertical swipe/scroll UX (title + abstract per card).
- In-app PDF reading (PDFKit), no external browser needed.
- Full local library: seen-tracking, save/favorite, offline-downloaded PDFs.
- Editable category following, set up during onboarding and changeable later in Settings.

## Non-goals
- No user accounts or cloud sync.
- No server/backend component — the app talks directly to arXiv's public API.
- No recommendation/ranking beyond "newest first" within followed categories.

## Architecture
- **SwiftUI**, multiplatform target (iOS + macOS via Catalyst), MVVM with `@Observable` view models.
- **Networking**: `URLSession` against arXiv's public Atom API:
  `https://export.arxiv.org/api/query?search_query=cat:X+OR+cat:Y&sortBy=submittedDate&sortOrder=descending&start=N&max_results=25`
  No API key required. Response is Atom XML, parsed with `XMLParser` into a `Paper` struct: `id`, `title`, `authors`, `abstract`, `categories`, `pdfURL`, `publishedDate`.
- **Persistence**: SwiftData models:
  - `FollowedCategory` (code, displayName)
  - `SeenPaper` (id, seenDate)
  - `SavedPaper` (id, savedDate, localPDFPath)
  Downloaded PDFs are stored in the app's Documents directory; `SavedPaper.localPDFPath` references the file.
- **Reading**: PDFKit `PDFView` wrapped as a SwiftUI `UIViewRepresentable` (iOS) / `NSViewRepresentable` (macOS Catalyst-compatible) for cross-platform display.

## Feed & data flow
- **Onboarding**: first launch presents a category picker built from arXiv's taxonomy (grouped by archive, e.g. Computer Science → cs.AI, cs.LG, cs.CL; Condensed Matter → cond-mat.str-el, etc.), multi-select, saved as `FollowedCategory` rows. At least one category must be selected to proceed.
- **Feed screen**: vertical paging scroll, one paper per card, swipe up/down to move next/previous.
- **Query construction**: combine all followed categories with `OR` in `search_query`, sort by `submittedDate` descending, paginate in batches of ~25 via `start`/`max_results`.
- **Infinite scroll**: when the user nears the end of the currently loaded batch, fetch the next page.
- **Dedup**: skip any fetched paper whose `id` already exists in `SeenPaper`.
- **Marking seen**: when a card is scrolled past, insert its id into `SeenPaper`.
- **Card actions**:
  - Tap card → open PDFKit reader; downloads the PDF to Documents (if not already present) and upserts a `SavedPaper` row with the local path.
  - Save/unsave action (button or swipe gesture) → toggle a `SavedPaper` row without necessarily opening the reader.
  - Share action → share the arXiv abstract page URL.
- **Library tab**: lists all `SavedPaper` entries; opens the already-downloaded local PDF directly, works fully offline.
- **Settings tab**: add/remove followed categories; changing selection triggers a feed refresh (new query, existing `SeenPaper` history still respected).

## Error handling & edge cases
- **No network on feed screen**: show any already-fetched-but-unseen papers if available; otherwise show an offline state with a retry action. The Library tab is unaffected (fully local).
- **arXiv API failures / rate limiting**: arXiv's API expects a modest request rate; pagination fetches are debounced (not fired on every single scroll frame). On failure, show a non-blocking retry banner rather than an error screen.
- **PDF download failure**: reader view shows a retry button; does not crash or block the rest of the feed.
- **No categories followed**: user cannot reach the main feed until at least one category is selected (applies both at onboarding and if all are later removed in Settings).
- **Malformed/incomplete Atom entries**: entries missing required fields (title or id) are skipped during parsing rather than causing a crash.

## Testing approach
- Unit tests:
  - Atom XML parser: fixture XML responses → expected `Paper` arrays, including malformed-entry skipping.
  - Feed query construction from a given set of followed categories.
  - SwiftData persistence logic: seen/save dedup behavior.
- Manual testing in Simulator: scroll/swipe feed UX and PDFKit reader interactions, since these are inherently visual/gestural and not well suited to automated tests.
