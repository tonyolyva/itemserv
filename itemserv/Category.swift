import Foundation
import SwiftData

@Model
class Category: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var categoryName: String?
    @Relationship var items: [Item]? = nil

    init(categoryName: String?) {
        self.categoryName = categoryName
    }
}

extension Category {
    var categoryNameWrapped: String {
        categoryName ?? ""
    }
}
