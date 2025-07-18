import Foundation
import SwiftData

@Model
class Category: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var categoryName: String?
    @Relationship(inverse: \Item.category) var items: [Item]?

    init(categoryName: String?) {
        self.categoryName = categoryName
    }

    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Category>()
        if let results = try? context.fetch(descriptor) {
            for category in results where category.isEmpty {
                context.delete(category)
            }
        }
    }
}

extension Category {
    var categoryNameWrapped: String {
        categoryName ?? ""
    }
    
    var isEmpty: Bool {
        categoryNameWrapped.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

