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
