import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class LibraryViewModel {
    private(set) var savedPapers: [SavedPaper] = []
    private let repository: PaperRepository

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    func load() {
        savedPapers = (try? repository.fetchAllSaved()) ?? []
    }
}
