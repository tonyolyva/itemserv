import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageRoomsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Room.roomName) private var rooms: [Room]
    
    @State private var newRoomName: String = ""
    @State private var searchText: String = ""
    @State private var sortAscending: Bool = true
    @State private var roomToDelete: Room?
    @State private var roomToEdit: Room?
    @State private var editedRoomName: String = ""
    
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false
    
    private var sortedRooms: [Room] {
        let paired = rooms.map { ($0, $0.roomName.lowercased()) }
        if sortAscending {
            return paired.sorted { $0.1 < $1.1 }.map { $0.0 }
        } else {
            return paired.sorted { $0.1 > $1.1 }.map { $0.0 }
        }
    }
    
    private var filteredRooms: [Room] {
        if searchText.trimmed().isEmpty {
            return sortedRooms
        } else {
            return sortedRooms.filter { $0.roomName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            Text("Manage Rooms")
                .font(.title)
                .bold()
                .padding(.top)
            
            // 🔥 Search Field + Clear Button
            HStack {
                TextField("Search Rooms", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                
                if !searchText.isEmpty {
                    Button(action: {
                        withAnimation {
                            searchText = ""
                        }
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .transition(.scale)
                }
            }
            .padding(.horizontal)
            
            // 🔥 Sort Picker
            Picker("Sort Order", selection: $sortAscending) {
                Text("A → Z").tag(true)
                Text("Z → A").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.top)
            
            HStack {
                Button("Import") {
                    isImportingFile = true
                }
                Spacer()
                Button("Export") {
                    exportRooms()
                }
            }
            .padding(.horizontal)
            
            List {
                Section(header: Text("Rooms")) {
                    ForEach(filteredRooms, id: \.id) { room in
                        HStack {
                            highlightedText(for: room.roomName, matching: searchText)
                            Spacer()
                        }
                        .contentShape(Rectangle())
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                roomToDelete = room
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: false) {
                            Button {
                                roomToEdit = room
                                editedRoomName = room.roomName
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete(perform: deleteRooms)
                }
                
                Section(header: Text("Add New Room")) {
                    HStack {
                        TextField("Room Name", text: $newRoomName)
                        Button("Add") {
                            addRoom()
                        }
                        .disabled(newRoomName.trimmed().isEmpty)
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
//            .listStyle(.plain)
            .animation(.easeInOut(duration: 0.4), value: filteredRooms)
            .alert("Delete Room?", isPresented: .constant(roomToDelete != nil), presenting: roomToDelete) { room in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        modelContext.delete(room)
                        try? modelContext.save()
                        roomToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    roomToDelete = nil
                }
            } message: { room in
                Text("Are you sure you want to delete the room “\(room.roomName)”?")
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importRooms(from: url)
                case .failure(let error):
                    print("Import failed: \(error.localizedDescription)")
                }
            }
            .sheet(isPresented: Binding(get: {
                exportURL != nil && isShowingExportSheet
            }, set: { newValue in
                if !newValue {
                    isShowingExportSheet = false
                    exportURL = nil
                }
            })) {
                NavigationStack {
                    VStack {
                        ShareLink(item: exportURL!)
                            .padding()
                    }
                    .navigationTitle("Export Rooms")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                isShowingExportSheet = false
                                exportURL = nil
                            }
                        }
                    }
                }
            }
            .sheet(item: $roomToEdit) { room in
                NavigationStack {
                    Form {
                        TextField("Room Name", text: $editedRoomName)
                    }
                    .navigationTitle("Edit Room")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEditedRoom(room)
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                roomToEdit = nil
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func addRoom() {
        withAnimation {
            let trimmedName = newRoomName.trimmed()
            guard !trimmedName.isEmpty else { return }
            guard !rooms.contains(where: { $0.roomName.lowercased() == trimmedName.lowercased() }) else { return }
            
            let newRoom = Room(roomName: trimmedName)
            modelContext.insert(newRoom)
            try? modelContext.save()
            newRoomName = ""
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private func deleteRooms(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let room = filteredRooms[index]
                modelContext.delete(room)
            }
            try? modelContext.save()
        }
    }
    
    private func saveEditedRoom(_ room: Room) {
        let trimmedName = editedRoomName.trimmed()
        guard !trimmedName.isEmpty else {
            roomToEdit = nil
            return
        }
        
        withAnimation {
            room.roomName = trimmedName
            try? modelContext.save()
            roomToEdit = nil
        }
    }
    
    private func exportRooms() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "rooms_\(timestamp).csv"

        let content = rooms
            .map { $0.roomName }
            .joined(separator: "\n")

        do {
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try content.write(to: url, atomically: true, encoding: .utf8)
            exportURL = url
            isShowingExportSheet = true
        } catch {
            print("Export failed: \(error.localizedDescription)")
        }
    }

    private func importRooms(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for room in rooms {
                    modelContext.delete(room)
                }

                for name in lines {
                    let newRoom = Room(roomName: name)
                    modelContext.insert(newRoom)
                }

                try? modelContext.save()
            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        } else {
            print("Access to the file was denied.")
        }
    }
}
