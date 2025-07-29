import Foundation
import SwiftData

@Model
class Room: Identifiable {
    @Attribute var id: UUID = UUID()
    @Attribute(.externalStorage) var roomName: String = ""
    @Relationship(inverse: \Box.room) var items: [Box]?

    init(roomName: String) {
        self.roomName = roomName
    }
    
    var isEmpty: Bool {
        roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

extension Room {
    static func deleteEmpty(in context: ModelContext) {
        let descriptor = FetchDescriptor<Room>()
        if let rooms = try? context.fetch(descriptor) {
            for room in rooms where room.isEmpty {
                context.delete(room)
            }
        }
    }
}

