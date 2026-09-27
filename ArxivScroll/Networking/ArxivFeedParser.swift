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

        private static nonisolated(unsafe) let dateFormatter: ISO8601DateFormatter = {
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
