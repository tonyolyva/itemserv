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
    @Attribute var lastUpdated: Date = Date()

    @Relationship var category: Category?
    @Relationship var box: Box?

    var isEmpty: Bool {
        name.isEmpty &&
        itemDescription.isEmpty &&
        (imageData == nil || imageData?.isEmpty == true) &&
        barcodeValue.isEmpty &&
        category == nil
    }

    init(
        name: String,
        category: Category? = nil,
        itemDescription: String = "",
        imageData: Data? = nil,
        box: Box? = nil,
        dateAdded: Date = Date(),
        barcodeValue: String = ""
    ) {
        print("🚨 Item initialized!")
        self.name = name
        self.category = category
        self.itemDescription = itemDescription
        self.imageData = imageData
        self.box = box
        self.dateAdded = dateAdded
        self.barcodeValue = barcodeValue
        self.lastUpdated = Date()
    }

    init() {
        print("🚨 Item default-initialized!")
        self.lastUpdated = Date()
    }
}
