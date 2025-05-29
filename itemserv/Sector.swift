import Foundation
import SwiftData

@Model
class Sector: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var sectorName: String = ""
    @Relationship(inverse: \Item.sector) var items: [Item]? = nil

    init(sectorName: String) {
        self.sectorName = sectorName
    }
}
