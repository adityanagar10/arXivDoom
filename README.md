# arXivDoom

Doomscroll new arXiv papers. Follow the categories you care about, swipe
through title-and-abstract cards, read the full PDF in-app when something
catches your eye, and keep a local offline library of papers you've saved.

## Repo structure

```
arXivDoom/
├── ios/            SwiftUI app (iOS + macOS via Catalyst) — the current, working app
├── android/        Planned Android app (not started yet)
└── docs/
    └── superpowers/
        ├── specs/  Design specs for each feature
        └── plans/  Implementation plans for each feature
```

Each platform directory is a self-contained project with its own build
tooling; `docs/` holds product specs and implementation plans that apply
across platforms.

## iOS app

**Stack:** SwiftUI, SwiftData, PDFKit, XCTest. Project files are generated
from `ios/project.yml` via [XcodeGen](https://github.com/yonaskolb/XcodeGen)
rather than hand-maintained — this keeps the `.xcodeproj` diff-free and
lets new source files be picked up automatically.

### Setup

```bash
brew install xcodegen   # if not already installed
cd ios
xcodegen generate
open ArxivScroll.xcodeproj
```

Whenever you add, remove, or rename a Swift file, re-run `xcodegen generate`
before building — the generated project is a snapshot of the directory
structure at generation time, not a live sync.

### Build & test

```bash
cd ios
xcodebuild -project ArxivScroll.xcodeproj -scheme ArxivScroll \
  -destination 'platform=iOS Simulator,name=iPhone 16' build

xcodebuild test -project ArxivScroll.xcodeproj -scheme ArxivScroll \
  -destination 'platform=iOS Simulator,name=iPhone 16'
```

### How it works

- **Feed**: fetches new papers from arXiv's public Atom API
  (`export.arxiv.org/api/query`) for your followed categories, sorted
  newest-first (or most-cited — see below), and pages through them as you
  scroll.
- **Persistence**: SwiftData tracks which papers you've followed, seen,
  and saved — all local, no account or cloud sync.
- **Reading**: tapping a paper downloads its PDF and displays it in-app
  via PDFKit. Papers you save are kept in a local Library and remain
  readable offline once downloaded.
- **Most Cited filter**: an alternate sort mode that enriches fetched
  papers with citation counts from the
  [Semantic Scholar API](https://api.semanticscholar.org/) to surface
  influential papers, not just the newest ones.

No backend, no user accounts — the app talks directly to arXiv's and
Semantic Scholar's public APIs.

## Android app

Not started. See `android/README.md`.

## Design docs

Product specs and implementation plans live under
`docs/superpowers/specs/` and `docs/superpowers/plans/`, one file per
feature, dated by when they were written.
