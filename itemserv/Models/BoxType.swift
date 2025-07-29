import Foundation
import SwiftData

@Model
class BoxType: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var boxTypeText: String = ""

    @Relationship(inverse: \Box.boxType) var boxes: [Box]?

    var isEmpty: Bool {
        boxTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    init(boxTypeText: String) {
        self.boxTypeText = boxTypeText
    }

    static func deleteEmptyBoxTypes(using context: ModelContext) {
        let descriptor = FetchDescriptor<BoxType>()
        if let results = try? context.fetch(descriptor) {
            for boxType in results {
                if boxType.isEmpty {
                    context.delete(boxType)
                }
            }
            try? context.save()
        }
    }
}
