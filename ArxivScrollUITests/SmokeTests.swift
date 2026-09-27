import XCTest

/// These tests assume a freshly-installed app (no prior SwiftData state).
/// Run with `xcodebuild test -only-testing:ArxivScrollUITests/SmokeTests/<name>`
/// after `xcrun simctl uninstall <device> com.dev.arxivscroll`, or run this
/// class's tests one at a time — running multiple tests in one invocation
/// without reinstalling between them will carry state (e.g. followed
/// categories, saved papers) from one test into the next.
final class SmokeTests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func test_onboardingThenFeedThenLibraryThenSettings() {
        let app = XCUIApplication()
        app.launch()

        // Onboarding: Done should start disabled.
        let doneButton = app.navigationBars.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 10))
        XCTAssertFalse(doneButton.isEnabled)

        app.buttons["Artificial Intelligence"].tap()
        app.buttons["Machine Learning"].tap()
        XCTAssertTrue(doneButton.isEnabled)
        doneButton.tap()

        // Main TabView should now appear.
        let feedTab = app.tabBars.buttons["Feed"]
        XCTAssertTrue(feedTab.waitForExistence(timeout: 10))

        let libraryTab = app.tabBars.buttons["Library"]
        libraryTab.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        let settingsTab = app.tabBars.buttons["Settings"]
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Followed Categories"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Artificial Intelligence"].waitForExistence(timeout: 5))

        feedTab.tap()
        XCTAssertTrue(feedTab.waitForExistence(timeout: 5))
    }

    @MainActor
    func test_feedLoadsRealPapersFromNetwork() {
        let app = XCUIApplication()
        app.launch()

        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.waitForExistence(timeout: 5) {
            app.buttons["Artificial Intelligence"].tap()
            doneButton.tap()
        }

        // Wait generously for the network fetch (arXiv API) to complete.
        let retryButton = app.buttons["Retry"]
        _ = retryButton.waitForExistence(timeout: 3)
        if retryButton.exists {
            retryButton.tap()
        }

        // A loaded paper card shows a "Read PDF" button. Multiple cards may be
        // rendered/lazily loaded at once, so match the first one.
        let readPDFButton = app.buttons["Read PDF"].firstMatch
        XCTAssertTrue(readPDFButton.waitForExistence(timeout: 30), "Expected at least one paper card with a Read PDF button to load from the network")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "feed-loaded"
        attachment.lifetime = .keepAlways
        add(attachment)

        // Tap Read PDF to exercise the PDFKit reader / download flow.
        readPDFButton.tap()
        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 15), "Expected the PDF reader sheet to open with a Close button")

        let readerAttachment = XCTAttachment(screenshot: app.screenshot())
        readerAttachment.name = "pdf-reader"
        readerAttachment.lifetime = .keepAlways
        add(readerAttachment)

        closeButton.tap()
    }

    @MainActor
    func test_saveFromFeedAppearsInLibrary() {
        let app = XCUIApplication()
        app.launch()

        let doneButton = app.navigationBars.buttons["Done"]
        if doneButton.waitForExistence(timeout: 5) {
            app.buttons["Artificial Intelligence"].tap()
            doneButton.tap()
        }

        let retryButton = app.buttons["Retry"]
        _ = retryButton.waitForExistence(timeout: 3)
        if retryButton.exists {
            retryButton.tap()
        }

        let saveButton = app.buttons["Save"].firstMatch
        XCTAssertTrue(saveButton.waitForExistence(timeout: 30))
        saveButton.tap()

        // Give the save a moment, then check the Library tab.
        let libraryTab = app.tabBars.buttons["Library"]
        libraryTab.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5))

        // The saved row should exist, and since it was saved without opening
        // the reader first, it should show the "not downloaded yet" caption
        // rather than a save date (see LibraryView's isAvailable handling).
        let notDownloadedCaption = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS[c] %@", "Not downloaded yet")
        ).firstMatch
        XCTAssertTrue(notDownloadedCaption.waitForExistence(timeout: 5), "Expected the saved-but-undownloaded paper to appear with the not-downloaded indicator")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "library-with-saved-paper"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
