import Foundation
import SwiftData

@Model
class Box {
    @Attribute var numberOrName: String = ""  // ✅ Default value added
    @Relationship var boxType: BoxType?
    @Relationship var room: Room?
    @Relationship var sector: Sector?
    @Relationship var shelf: Shelf?
@Relationship(inverse: \Item.box) var items: [Item]?  // ✅ Made optional for CloudKit
    @Attribute var dateAdded: Date = Date()         // ✅ Track when box was created
    @Attribute var lastModified: Date = Date()      // ✅ Track when box was last modified

    init(numberOrName: String = "", boxType: BoxType? = nil, room: Room? = nil, sector: Sector? = nil, shelf: Shelf? = nil) {
        self.numberOrName = numberOrName
        self.boxType = boxType
        self.room = room
        self.sector = sector
        self.shelf = shelf
        self.dateAdded = Date()
        self.lastModified = Date()
    }

    var isEmpty: Bool {
        numberOrName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (items?.isEmpty ?? true)
    }
}

extension Box {
    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Box>()
        if let results = try? context.fetch(descriptor) {
            for box in results where box.isEmpty {
                context.delete(box)
            }
        }
    }
    
    var uuid: UUID {
        UUID(uuidString: String(describing: id)) ?? UUID()
    }
}
