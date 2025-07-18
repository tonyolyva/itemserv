import Foundation
import SwiftData

@Model
class BoxName: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var boxNameText: String = ""

    @Relationship(inverse: \Item.boxNameRef) var items: [Item]?

    init(boxNameText: String) {
        self.boxNameText = boxNameText
    }

    var isEmpty: Bool {
        boxNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && (items?.isEmpty ?? true)
    }
}

extension BoxName {
    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<BoxName>()
        if let results = try? context.fetch(descriptor) {
            for boxName in results where boxName.isEmpty {
                context.delete(boxName)
            }
        }
    }
}

