import SwiftUI
import SwiftData

struct ManageSectorsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Sector.sectorName) private var sectors: [Sector]
    
    @State private var newSectorName = ""
    @State private var searchText = ""
    @State private var sortAscending = true
    @State private var sectorToRename: Sector?
    @State private var editedSectorName = ""
    @State private var sectorToDelete: Sector?
    @State private var editMode: EditMode = .inactive
    
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false
    
    private var sortedSectors: [Sector] {
        let paired = sectors.map { ($0, $0.sectorName.lowercased()) }
        if sortAscending {
            return paired.sorted { $0.1 < $1.1 }.map { $0.0 }
        } else {
            return paired.sorted { $0.1 > $1.1 }.map { $0.0 }
        }
    }
    
    private var filteredSectors: [Sector] {
        if searchText.trimmed().isEmpty {
            return sortedSectors
        } else {
            return sortedSectors.filter { $0.sectorName.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button("Import") {
                        isImportingFile = true
                    }
                    Spacer()
                    Button("Export") {
                        exportSectors()
                    }
                }
                .padding(.horizontal)
                
                Text("Manage Sectors")
                    .font(.largeTitle)
                    .bold()
                    .padding(.horizontal)
                
                // 🔥 Search Field
                HStack {
                    TextField("Search Sectors", text: $searchText)
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
                
                Form {
                    Section(header: Text("Sectors")) {
                        ForEach(filteredSectors, id: \.id) { sector in
                            HStack {
                                highlightedText(for: sector.sectorName, matching: searchText)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    sectorToDelete = sector
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                                Button {
                                    sectorToRename = sector
                                    editedSectorName = sector.sectorName
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                        .onDelete(perform: deleteSectors)
                        .onMove(perform: moveSector)
                    }
                    
                    Section(header: Text("Add New Sector")) {
                        HStack {
                            TextField("Sector Name", text: $newSectorName)
                            Button("Add") {
                                addNewSector()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(newSectorName.trimmed().isEmpty)
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.4), value: filteredSectors)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
            }
            .environment(\.editMode, $editMode)
            .sheet(item: $sectorToRename) { sector in
                NavigationStack {
                    Form {
                        TextField("Sector Name", text: $editedSectorName)
                    }
                    .navigationTitle("Edit Sector")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Save") {
                                saveEditedSector(sector)
                            }
                        }
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                sectorToRename = nil
                            }
                        }
                    }
                }
            }
            .alert("Delete Sector?", isPresented: .constant(sectorToDelete != nil), presenting: sectorToDelete) { sector in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        modelContext.delete(sector)
                        try? modelContext.save()
                        sectorToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    sectorToDelete = nil
                }
            } message: { sector in
                Text("Are you sure you want to delete the sector “\(sector.sectorName)”?")
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importSectors(from: url)
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
                    .navigationTitle("Export Sectors")
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
    }
    
    // MARK: - Actions
    
    private func addNewSector() {
        withAnimation {
            let trimmedName = newSectorName.trimmed()
            guard !trimmedName.isEmpty else { return }
            guard !sectors.contains(where: { $0.sectorName.lowercased() == trimmedName.lowercased() }) else { return }
            
            let newSector = Sector(sectorName: trimmedName)
            modelContext.insert(newSector)
            try? modelContext.save()
            newSectorName = ""
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    private func deleteSectors(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let sector = filteredSectors[index]
                modelContext.delete(sector)
            }
            try? modelContext.save()
        }
    }
    
    private func saveEditedSector(_ sector: Sector) {
        let trimmedName = editedSectorName.trimmed()
        guard !trimmedName.isEmpty else {
            sectorToRename = nil
            return
        }
        
        withAnimation {
            sector.sectorName = trimmedName
            try? modelContext.save()
            sectorToRename = nil
        }
    }
    
    private func moveSector(from source: IndexSet, to destination: Int) {
        guard searchText.isEmpty else { return } // Only allow moving when not filtering
        var reordered = sectors
        reordered.move(fromOffsets: source, toOffset: destination)
        // Optional: persist reorder later if needed
    }
    
    private func exportSectors() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "sectors_\(timestamp).csv"

        let content = sectors
            .map { $0.sectorName }
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

    private func importSectors(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for sector in sectors {
                    modelContext.delete(sector)
                }

                for name in lines {
                    let newSector = Sector(sectorName: name)
                    modelContext.insert(newSector)
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
