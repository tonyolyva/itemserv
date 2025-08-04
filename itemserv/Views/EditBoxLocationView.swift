import SwiftUI
import Combine
import SwiftData

struct EditBoxLocationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @Bindable var box: Box
    
    @Query(sort: \Room.roomName) private var rooms: [Room]
    @Query(sort: \Sector.sectorName) private var sectors: [Sector]
    @Query(sort: \Shelf.shelfName) private var shelves: [Shelf]
    @Query(sort: \BoxType.boxTypeText) private var boxTypes: [BoxType]
    @Query(sort: \Box.numberOrName) private var allBoxes: [Box]
    
    @State private var selectedRoom: Room?
    @State private var selectedSector: Sector?
    @State private var selectedShelf: Shelf?
    @State private var selectedBoxType: BoxType?
    @State private var targetBox: Box? = nil
    @State private var showMoveConfirmation: Bool = false
    
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
                
                // New section for selecting a target box to move/merge items
                Section(header: Text("Move Items to Another Box")) {
                    Picker("Target Box", selection: $targetBox) {
                        Text("None").tag(Optional<Box>(nil))
                        ForEach(allBoxes.filter { $0.id != box.id }) { candidateBox in
                            Text(candidateBox.numberOrName).tag(Optional(candidateBox))
                        }
                    }
                    .onChange(of: targetBox) {
                        if targetBox != nil {
                            showMoveConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle("Edit Location")
            .padding(.top, 8)
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("for \(box.numberOrName == "Unboxed" ? "Unboxed" : "Box \(box.numberOrName)")")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .padding(.leading, 18)
                }
                .background(Color(.systemBackground))
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        updateBoxLocation()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert(isPresented: $showMoveConfirmation) {
                let targetItemCount = (try? modelContext.fetch(FetchDescriptor<Item>()).filter { $0.box?.id == targetBox?.id }.count) ?? 0
                let isMerge = targetItemCount > 0
                let actionText = isMerge ? "Merge" : "Move"
                let message = isMerge
                    ? "Merge all items from \(box.numberOrName) into \(targetBox?.numberOrName ?? "")? Target box already contains \(targetItemCount) items."
                    : "Move all items from \(box.numberOrName) to \(targetBox?.numberOrName ?? "")?"
                
                return Alert(
                    title: Text(isMerge ? "Merge Items" : "Move Items"),
                    message: Text(message),
                    primaryButton: .destructive(Text(actionText)) {
                        performBatchMove()
                    },
                    secondaryButton: .cancel {
                        targetBox = nil
                    }
                )
            }
        }
    }
    
    private func updateBoxLocation() {
        let locationChanged = box.room != selectedRoom ||
                              box.sector != selectedSector ||
                              box.shelf != selectedShelf ||
                              box.boxType != selectedBoxType
        
        if locationChanged {
            box.room = selectedRoom
            box.sector = selectedSector
            box.shelf = selectedShelf
            box.boxType = selectedBoxType
            
            // Update timestamp
            box.lastModified = Date()
            print("Box location updated. lastModified set to: \(box.lastModified)")
            
            // Save and validate persistence
            do {
                try modelContext.save()
                print("Box saved successfully: \(box.numberOrName)")
            } catch {
                print("Failed to save box changes: \(error)")
            }
            
            // Trigger UI refresh
            NotificationCenter.default.post(name: .refreshLocationsView, object: nil)
        }
    }
    
    private func performBatchMove() {
        guard let target = targetBox else { return }
        
        do {
            // Fetch all items, then filter manually to avoid predicate errors
            let allItems = try modelContext.fetch(FetchDescriptor<Item>())
            let itemsToMove = allItems.filter { $0.box?.id == box.id }
            
            print("Found \(itemsToMove.count) items in box \(box.numberOrName) to move.")
            
            // Move each item to the target box
            for item in itemsToMove {
                item.box = target
                print("Item \(item.name) moved to box \(target.numberOrName).")
            }
            
            // Update timestamps for both boxes
            let now = Date()
            target.lastModified = now
            box.lastModified = now
            
            try modelContext.save()
            print("Batch move complete: \(itemsToMove.count) items moved from \(box.numberOrName) to \(target.numberOrName).")
            
            // Notify UI to refresh
            NotificationCenter.default.post(name: .refreshLocationsView, object: nil)
            targetBox = nil
            
        } catch {
            print("Error during batch move: \(error)")
        }
    }
}

// Notification extension
extension Notification.Name {
    static let refreshLocationsView = Notification.Name("refreshLocationsView")
}

#Preview {
    EditBoxLocationView(box: .init(numberOrName: "1"))
        .modelContainer(sharedModelContainer)
}
