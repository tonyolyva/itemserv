import SwiftUI
import SwiftData

struct ManageShelvesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Shelf.shelfName) private var shelves: [Shelf]
    
    @State private var newShelfName: String = ""
    @State private var searchText: String = ""
    @State private var sortAscending: Bool = true
    @State private var shelfToDelete: Shelf?
    @State private var shelfToEdit: Shelf?
    @State private var editedShelfName: String = ""
    @State private var newlyAddedShelfID: UUID?
    @State private var bounceAnimation: Animation = .spring(response: 0.4, dampingFraction: 0.5)
    @State private var editedShelfID: UUID?
    @State private var editedGlowPulse: Bool = false
    @State private var bounceShelfID: UUID?
    
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false
    
    private var sortedShelves: [Shelf] {
        let paired = shelves.map { ($0, $0.shelfName.lowercased()) }
        if sortAscending {
            return paired.sorted { $0.1 < $1.1 }.map { $0.0 }
        } else {
            return paired.sorted { $0.1 > $1.1 }.map { $0.0 }
        }
    }
    
    private var filteredShelves: [Shelf] {
        if searchText.trimmed().isEmpty {
            return sortedShelves
        } else {
            return sortedShelves.filter { $0.shelfName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            Text("Manage Shelves")
                .font(.title)
                .fontWeight(.bold)
                .padding(.top)
            
            // 🔥 Search Field with Clear Button
            HStack {
                TextField("Search Shelves", text: $searchText)
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
                    exportShelves()
                }
            }
            .padding(.horizontal)
            
            ScrollViewReader { scrollViewProxy in
                List {
                    Section(header: Text("Shelves")) {
                        if filteredShelves.isEmpty {
                            // your EmptyState Button here
                        } else {
                            ForEach(filteredShelves, id: \.id) { shelf in
                                HStack {
                                    highlightedText(for: shelf.shelfName, matching: searchText)
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        shelfToDelete = shelf
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                    Button {
                                        shelfToEdit = shelf
                                        editedShelfName = shelf.shelfName
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                                .padding(.vertical, 4)
                                .scaleEffect(
                                    shelf.id == bounceShelfID ? 1.1 :
                                        (shelf.id == editedShelfID && editedGlowPulse ? 1.05 : 1.0) // ✅ Add pulse scaling
                                )
                                .animation(bounceAnimation, value: bounceShelfID)
                                .animation(.easeInOut(duration: 0.6).repeatCount(editedGlowPulse ? 1 : 0, autoreverses: true), value: editedGlowPulse)
                                .background(
                                    Group {
                                        if shelf.id == newlyAddedShelfID {
                                            Color.blue.opacity(0.15)
                                        } else if shelf.id == editedShelfID {
                                            Color.green.opacity(0.2)
                                        } else {
                                            Color.clear
                                        }
                                    }
                                        .animation(.easeInOut(duration: 0.5), value: newlyAddedShelfID)
                                        .animation(.easeInOut(duration: 0.5), value: editedShelfID)
                                )
                                .cornerRadius(8)
                                .contentShape(Rectangle())
                                .id(shelf.id)
                            }
                            .onDelete(perform: deleteShelves)
                        }
                    }
                    Section(header: Text("Add New Shelf")) {
                        HStack {
                            TextField("Shelf Name", text: $newShelfName)
                            Button("Add") {
                                addShelfAndScroll(scrollViewProxy: scrollViewProxy)
                            }
                            .disabled(newShelfName.trimmed().isEmpty)
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.vertical, 4)
                    }        
                }
                .listStyle(.insetGrouped)
    //            .listStyle(.plain)
                .animation(.easeInOut(duration: 0.4), value: filteredShelves)
            }
            .alert("Delete Shelf?", isPresented: .constant(shelfToDelete != nil), presenting: shelfToDelete) { shelf in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        modelContext.delete(shelf)
                        try? modelContext.save()
                        shelfToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    shelfToDelete = nil
                }
            } message: { shelf in
                Text("Are you sure you want to delete the shelf “\(shelf.shelfName)”?")
            }
            .sheet(item: $shelfToEdit) { shelf in
                NavigationStack {
                    Form {
                        TextField("Shelf Name", text: $editedShelfName)
                    }
                    .navigationTitle("Edit Shelf")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEditedShelf(shelf)
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                shelfToEdit = nil
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                importShelves(from: url)
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
                .navigationTitle("Export Shelves")
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
    }
    
    // MARK: - Actions
    
    private func addShelf() {
        withAnimation {
            let trimmedName = newShelfName.trimmed()
            guard !trimmedName.isEmpty else { return }
            guard !shelves.contains(where: { $0.shelfName.lowercased() == trimmedName.lowercased() }) else { return }
            
            let newShelf = Shelf(shelfName: trimmedName)
            modelContext.insert(newShelf)
            try? modelContext.save()
            newShelfName = ""
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private func addShelfAndScroll(scrollViewProxy: ScrollViewProxy) {
        withAnimation {
            let trimmedName = newShelfName.trimmed()
            guard !trimmedName.isEmpty else { return }
            guard !shelves.contains(where: { $0.shelfName.lowercased() == trimmedName.lowercased() }) else { return }
            
            let newShelf = Shelf(shelfName: trimmedName)
            modelContext.insert(newShelf)
            try? modelContext.save()
            newShelfName = ""
            
            newlyAddedShelfID = newShelf.id
            
            bounceAnimation = .spring(
                response: Double.random(in: 0.3...0.5),
                dampingFraction: Double.random(in: 0.4...0.6),
                blendDuration: Double.random(in: 0.1...0.3)
            )
            bounceShelfID = newShelf.id
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                withAnimation {
                    scrollViewProxy.scrollTo(newShelf.id, anchor: .center)
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    bounceShelfID = nil
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation {
                    newlyAddedShelfID = nil
                }
            }
            
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private func deleteShelves(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let shelf = filteredShelves[index]
                modelContext.delete(shelf)
            }
            try? modelContext.save()
        }
    }
    
    private func saveEditedShelf(_ shelf: Shelf) {
        let trimmedName = editedShelfName.trimmed()
        guard !trimmedName.isEmpty else {
            shelfToEdit = nil
            return
        }
        
        withAnimation {
            shelf.shelfName = trimmedName
            try? modelContext.save()
            
            // 🎯 Trigger bounce after editing
            bounceAnimation = .spring(
                response: Double.random(in: 0.3...0.5),
                dampingFraction: Double.random(in: 0.4...0.6),
                blendDuration: Double.random(in: 0.1...0.3)
            )
            bounceShelfID = shelf.id
            editedShelfID = shelf.id // ✅ Trigger glow!
            editedGlowPulse = true // Start pulsing
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) {
                    bounceShelfID = nil
                }
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                withAnimation {
                    editedGlowPulse = false
                    editedShelfID = nil
                }
            }
            
            shelfToEdit = nil
        }
    }
    
    private func exportShelves() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "shelves_\(timestamp).csv"

        let content = shelves
            .map { $0.shelfName }
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

    private func importShelves(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for shelf in shelves {
                    modelContext.delete(shelf)
                }

                for name in lines {
                    let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmedName.isEmpty else { continue }
                    let newShelf = Shelf(shelfName: trimmedName)
                    modelContext.insert(newShelf)
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
