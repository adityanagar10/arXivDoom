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
