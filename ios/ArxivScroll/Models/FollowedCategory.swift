import Foundation
import SwiftData

@Model
final class FollowedCategory {
    @Attribute(.unique) var code: String
    var displayName: String

    init(code: String, displayName: String) {
        self.code = code
        self.displayName = displayName
    }
}
