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

    /// Whether this saved paper currently has a readable PDF on disk. `false` when
    /// it was saved directly from the feed (never downloaded, so `localPDFPath` is
    /// `nil`) or when the file at `localPDFPath` was since deleted or moved.
    /// Used by `LibraryView` to show a "not downloaded" state instead of a row that
    /// silently does nothing when tapped.
    var isAvailable: Bool {
        Self.isAvailable(localPDFPath: localPDFPath, fileManager: .default)
    }

    /// Testable helper: given a path and a `FileManager`, reports availability
    /// without requiring a real `SavedPaper`/SwiftData instance.
    static func isAvailable(localPDFPath: String?, fileManager: FileManager) -> Bool {
        guard let localPDFPath else { return false }
        return fileManager.fileExists(atPath: localPDFPath)
    }
}
