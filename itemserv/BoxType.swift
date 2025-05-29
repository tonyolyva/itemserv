import Foundation
import SwiftData

@Model
class BoxType: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var boxTypeText: String = ""

    @Relationship(inverse: \Item.boxTypeRef) var items: [Item]? = [] // ✅ Always initialized to empty array

    init(boxTypeText: String) {
        self.boxTypeText = boxTypeText
        self.items = [] // ✅ (Optional, redundant but safe)
    }
}
