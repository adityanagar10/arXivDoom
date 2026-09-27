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
