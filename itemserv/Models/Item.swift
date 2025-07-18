import Foundation
import SwiftData

@Model
class Item {
    @Attribute var id: String = UUID().uuidString
    @Attribute var name: String = ""
    @Attribute var itemDescription: String = ""
    @Attribute var imageData: Data?
    @Attribute var dateAdded: Date = Date()
    @Attribute var barcodeValue: String = ""

    @Relationship var category: Category?
    @Relationship var room: Room?
    @Relationship var sector: Sector?
    @Relationship var shelf: Shelf?
    @Relationship var boxNameRef: BoxName?
    @Relationship var boxTypeRef: BoxType?

    var isEmpty: Bool {
        name.isEmpty &&
        itemDescription.isEmpty &&
        (imageData == nil || imageData?.isEmpty == true) &&
        barcodeValue.isEmpty &&
        category == nil &&
        room == nil &&
        sector == nil &&
        shelf == nil &&
        boxNameRef == nil &&
        boxTypeRef == nil
    }

    init(
        name: String,
        category: Category? = nil,
        itemDescription: String = "",
        imageData: Data? = nil,
        room: Room? = nil,
        sector: Sector? = nil,
        shelf: Shelf? = nil,
        boxNameRef: BoxName? = nil,
        boxTypeRef: BoxType? = nil,
        dateAdded: Date = Date(),
        barcodeValue: String = ""
    ) {
        print("🚨 Item initialized!")
        self.name = name
        self.category = category
        self.itemDescription = itemDescription
        self.imageData = imageData
        self.room = room
        self.sector = sector
        self.shelf = shelf
        self.boxNameRef = boxNameRef
        self.boxTypeRef = boxTypeRef
        self.dateAdded = dateAdded
        self.barcodeValue = barcodeValue
    }

    init() {
        print("🚨 Item default-initialized!")
    }
}
