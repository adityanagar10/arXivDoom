import Foundation
import SwiftData

@Model
final class SeenPaper {
    @Attribute(.unique) var paperID: String
    var seenDate: Date

    init(paperID: String, seenDate: Date = .now) {
        self.paperID = paperID
        self.seenDate = seenDate
    }
}
