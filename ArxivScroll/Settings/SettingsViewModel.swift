import Foundation
import SwiftData
import Observation

@MainActor
@Observable
final class SettingsViewModel {
    var selectedCodes: Set<String> = []
    private let repository: PaperRepository

    init(context: ModelContext) {
        self.repository = PaperRepository(context: context)
    }

    func load() {
        let followed = (try? repository.fetchFollowedCategories()) ?? []
        selectedCodes = Set(followed.map(\.code))
    }

    func toggle(_ category: ArxivCategory) {
        if selectedCodes.contains(category.code) {
            selectedCodes.remove(category.code)
        } else {
            selectedCodes.insert(category.code)
        }
    }

    func isSelected(_ category: ArxivCategory) -> Bool {
        selectedCodes.contains(category.code)
    }

    func save() {
        let selected = ArxivTaxonomy.archives
            .flatMap(\.categories)
            .filter { selectedCodes.contains($0.code) }
        try? repository.setFollowedCategories(selected)
    }
}
