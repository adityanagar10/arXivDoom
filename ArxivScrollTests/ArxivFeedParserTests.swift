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
