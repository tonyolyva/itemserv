import Foundation
import SwiftData

@Model
class BoxName: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var boxNameText: String = ""

    @Relationship(inverse: \Item.boxNameRef) var items: [Item]? = [] // ✅ Always initialized to empty array

    init(boxNameText: String) {
        self.boxNameText = boxNameText
        self.items = [] // ✅ Optional: defensive, but @Relationship already initialized
    }
}
