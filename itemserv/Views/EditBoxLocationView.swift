

import SwiftUI
import SwiftData

struct EditBoxLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var box: Box
    
    @Query(sort: \Room.roomName) private var rooms: [Room]
    @Query(sort: \Sector.sectorName) private var sectors: [Sector]
    @Query(sort: \Shelf.shelfName) private var shelves: [Shelf]
    @Query(sort: \BoxType.boxTypeText) private var boxTypes: [BoxType]
    
    @State private var selectedRoom: Room?
    @State private var selectedSector: Sector?
    @State private var selectedShelf: Shelf?
    @State private var selectedBoxType: BoxType?
    
    init(box: Box) {
        self.box = box
        _selectedRoom = State(initialValue: box.room)
        _selectedSector = State(initialValue: box.sector)
        _selectedShelf = State(initialValue: box.shelf)
        _selectedBoxType = State(initialValue: box.boxType)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Room")) {
                    Picker("Room", selection: $selectedRoom) {
                        ForEach(rooms) { room in
                            Text(room.roomName).tag(Optional(room))
                        }
                    }
                }
                
                Section(header: Text("Sector")) {
                    Picker("Sector", selection: $selectedSector) {
                        ForEach(sectors) { sector in
                            Text(sector.sectorName).tag(Optional(sector))
                        }
                    }
                }
                
                Section(header: Text("Shelf")) {
                    Picker("Shelf", selection: $selectedShelf) {
                        ForEach(shelves) { shelf in
                            Text(shelf.shelfName).tag(Optional(shelf))
                        }
                    }
                }
                
                Section(header: Text("Box Type")) {
                    Picker("Box Type", selection: $selectedBoxType) {
                        ForEach(boxTypes) { boxType in
                            Text(boxType.boxTypeText).tag(Optional(boxType))
                        }
                    }
                }
            }
            .navigationTitle("Edit Location")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        box.room = selectedRoom
                        box.sector = selectedSector
                        box.shelf = selectedShelf
                        box.boxType = selectedBoxType
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EditBoxLocationView(box: .init(numberOrName: "1"))
        .modelContainer(sharedModelContainer)
}
