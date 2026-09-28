# arXivDoom — Swipe Smoothing, Read More, and Most Cited Filter

## Overview
Three related improvements to the Feed screen:
1. Fix vertical swiping so it snaps cleanly to one card per swipe.
2. Replace the abstract's inner scroll with a "Read more" expand/collapse toggle.
3. Add a "Most Cited" sort mode alongside the existing "Newest" mode, using Semantic Scholar's citation data to surface influential (not just recent) papers.

## Goals
- Swiping through the feed feels like one deliberate gesture = one card, no half-scrolled states.
- Abstracts are fully readable without a nested scroll gesture competing with the outer feed scroll.
- Users can switch to a citation-ranked view of papers in their followed categories, not just newest-first.

## Non-goals
- No general-purpose "trending" algorithm beyond citation count.
- No caching/persistence of citation counts across sessions (fetched fresh per page load in Most Cited mode).
- No Semantic Scholar API key setup — usage stays within their free unauthenticated rate limit (batched, one call per page of ~25 papers).

## 1. Swipe smoothing

**Problem**: `FeedView`'s `ScrollView(.vertical)` + `.scrollTargetBehavior(.paging)` pages by the scroll view's own visible height, but each `PaperCardView` is a fixed `.frame(height: 600)`. These don't match, so paging snaps to screen-height boundaries that fall in the middle of cards.

**Fix**: Give each card a `.containerRelativeFrame(.vertical)` frame (fills exactly one screen's worth of vertical space) instead of a fixed 600pt height, and add `.scrollTargetLayout()` to the `LazyVStack`. This makes the paging behavior's snap points align exactly with card boundaries, so each swipe lands on exactly one card.

## 2. Read More instead of inner scroll

**Problem**: The abstract is wrapped in its own `ScrollView`, which competes with the outer feed `ScrollView` for the same vertical swipe gesture, causing inconsistent scroll capture.

**Fix**: Remove the inner `ScrollView`. `PaperCardView` gains `@State private var isExpanded = false`. The abstract `Text` uses `.lineLimit(isExpanded ? nil : 6)`. Directly below it, a "Read more" / "Read less" `Button` toggles `isExpanded`, wrapped in `withAnimation`. Because the card's outer frame is now a fixed screen-height (from the swipe fix above), the card's content column (categories, title, authors, abstract, Save/Read PDF buttons) is wrapped in its own internal `ScrollView` so that an expanded long abstract can push content below the fold without breaking the card's fixed height — this internal scroll only becomes relevant when content overflows an expanded card, and doesn't fight the outer paging gesture in the collapsed (default) state since collapsed content always fits.

## 3. Most Cited filter

**New type**: `FeedViewModel.SortMode: newest, mostCited` — `@Observable` state on the view model, defaulting to `.newest`.

**New network client**: `SemanticScholarClient`
```
enum SemanticScholarClient {
    static func fetchCitationCounts(arxivIDs: [String]) async throws -> [String: Int]
}
```
- POSTs to `https://api.semanticscholar.org/graph/v1/paper/batch?fields=externalIds,citationCount` with `{"ids": ["ARXIV:<id>", ...]}` (stripping any `vN` version suffix from arXiv IDs, since Semantic Scholar keys on the bare arXiv identifier).
- Parses the response into a `[String: Int]` keyed by arXiv id (no version suffix) → citation count.
- Papers not found in the response (e.g. too new to be indexed) are simply absent from the returned dictionary; callers treat missing entries as 0 citations for sorting purposes, without treating it as an error.
- No API key: usage is one batched call (≤25 ids) per page load, well within Semantic Scholar's public unauthenticated rate limit.

**`FeedViewModel` changes**:
- `loadNextPage()` branches on `sortMode`:
  - `.newest`: unchanged — `ArxivAPIClient.fetchPapers(..., sortBy: .submittedDate)`.
  - `.mostCited`: calls `ArxivAPIClient.fetchPapers(..., sortBy: .relevance)` (no date restriction — searches all time within followed categories), then calls `SemanticScholarClient.fetchCitationCounts` on the fetched batch's ids, then sorts the batch by citation count descending (missing/0-citation papers sort last) before appending to `papers`.
  - If `SemanticScholarClient` throws (rate-limited, offline), the fetched batch is still appended in its original (relevance) order rather than blocking the feed — citation enrichment is a nice-to-have.
- `ArxivAPIClient.feedURL` gains a `sortBy: SortBy` parameter (`enum SortBy: submittedDate, relevance`) instead of hardcoding `sortBy=submittedDate`.
- Changing `sortMode` (via the UI) resets `papers`/`nextStart` and calls `loadInitial()` fresh, mirroring how changing followed categories already triggers a refresh.

**UI**: `FeedView` gains a `Picker("Sort", selection: $viewModel.sortMode)` styled as a segmented control ("Newest" / "Most Cited") pinned above the paging scroll view.

## Error handling & edge cases
- Semantic Scholar batch call failure: silently falls back to unsorted-by-citation (still shows papers), per above.
- A paper with no Semantic Scholar match (very new, or arXiv-only preprint never indexed): treated as 0 citations, sorts last in Most Cited mode, still displayed normally.
- Old-style arXiv IDs (containing `/`) passed to Semantic Scholar: their batch API accepts the same `ARXIV:<id>` format arXiv itself uses for these, including the slash — no special-casing needed beyond what `ArxivFeedParser` already extracts.
- Switching sort modes mid-load (before a page finishes loading): the in-flight request's results are discarded if the mode changed before it completes (guard against a stale-mode race), consistent with how category changes are handled today.

## Testing approach
- Unit tests for `SemanticScholarClient`: parsing a fixture JSON response into `[String: Int]`, and confirming a missing-id response doesn't throw.
- Unit tests for `ArxivAPIClient.feedURL` with the new `sortBy` parameter (extending the existing query-construction tests).
- Manual verification in Simulator: swipe feels like one-card-per-swipe; Read More expands/collapses cleanly; toggling to Most Cited shows a citation-sorted, non-recency-biased set of papers for a followed category.
