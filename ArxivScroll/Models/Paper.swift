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
