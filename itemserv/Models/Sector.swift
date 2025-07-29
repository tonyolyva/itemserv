import Foundation
import SwiftData

@Model
class Sector: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var sectorName: String = ""
    @Relationship(inverse: \Box.sector) var items: [Box]?

    init(sectorName: String) {
        self.sectorName = sectorName
    }
    var isEmpty: Bool {
        sectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Sector>()
        if let sectors = try? context.fetch(descriptor) {
            for sector in sectors where sector.isEmpty {
                context.delete(sector)
            }
        }
    }
}

