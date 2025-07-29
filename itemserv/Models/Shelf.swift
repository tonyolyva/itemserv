import Foundation
import SwiftData

@Model
class Shelf: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var shelfName: String = ""
    @Relationship(inverse: \Box.shelf) var items: [Box]?

    init(shelfName: String) {
        self.shelfName = shelfName
    }

    var isEmpty: Bool {
        shelfName.isEmpty && (items?.isEmpty ?? true)
    }

    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Shelf>()
        if let shelves = try? context.fetch(descriptor) {
            for shelf in shelves where shelf.isEmpty {
                context.delete(shelf)
            }
        }
    }
}

