import Foundation
import SwiftData

@Model
class Shelf: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var shelfName: String = ""
    @Relationship(inverse: \Item.shelf) var items: [Item]? = nil

    init(shelfName: String) {
        self.shelfName = shelfName
    }
}
