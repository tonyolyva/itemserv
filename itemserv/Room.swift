import Foundation
import SwiftData

@Model
class Room: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute var roomName: String = ""
    @Relationship(inverse: \Item.room) var items: [Item]? = nil

    init(roomName: String) {
        self.roomName = roomName
    }
}
