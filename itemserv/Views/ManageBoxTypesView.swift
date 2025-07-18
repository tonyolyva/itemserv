import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageBoxTypesView: View {
    @Environment(\.modelContext) private var context
    @Query private var boxTypes: [BoxType]

    @State private var searchText: String = ""
    @State private var sortAscending: Bool = true
    @State private var newBoxType: String = ""
    @State private var editingBoxType: BoxType?
    @State private var editingText: String = ""
    @State private var boxTypeToDelete: BoxType?
    
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false
    
    private var sortedBoxTypes: [BoxType] {
        let prepared = boxTypes.map { ($0, $0.boxTypeText.lowercased()) }
        if sortAscending {
            return prepared.sorted { $0.1 < $1.1 }.map { $0.0 }
        } else {
            return prepared.sorted { $0.1 > $1.1 }.map { $0.0 }
        }
    }
    
    private var filteredBoxTypes: [BoxType] {
        if searchText.trimmed().isEmpty {
            return sortedBoxTypes
        } else {
            return sortedBoxTypes.filter { $0.boxTypeText.localizedCaseInsensitiveContains(searchText) }
        }
    }
    
    var body: some View {
        VStack {
            Text("Manage Box Types")
                .font(.title)
                .bold()
                .padding(.top)
            
            HStack {
                TextField("Search Box Types", text: $searchText)
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
                    exportBoxTypes()
                }
            }
            .padding(.horizontal)
            
            List {
                Section(header: Text("Box Types")) {
                    ForEach(filteredBoxTypes, id: \.id) { boxType in
                        if editingBoxType == boxType {
                            HStack {
                                TextField("Edit Box Type", text: $editingText)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Save") {
                                    saveEditedBoxType()
                                }
                                .buttonStyle(.borderedProminent)
                            }
                        } else {
                            Text(boxType.boxTypeText)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        boxTypeToDelete = boxType
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading) {
                                    Button {
                                        editBoxType(boxType)
                                    } label: {
                                        Label("Edit", systemImage: "pencil")
                                    }
                                    .tint(.blue)
                                }
                        }
                    }
                    .onDelete(perform: deleteBoxTypes)
                }
                
                Section(header: Text("Add New Box Type")) {
                    HStack {
                        TextField("Box Type", text: $newBoxType)
                        Button("Add") {
                            addBoxType()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(newBoxType.trimmed().isEmpty)
                    }
                }
                
            }
            .listStyle(.insetGrouped)
            .animation(.default, value: filteredBoxTypes)
            .alert("Delete Box Type?", isPresented: .constant(boxTypeToDelete != nil), presenting: boxTypeToDelete) { boxType in
                Button("Delete", role: .destructive) {
                    withAnimation {
                        context.delete(boxType)
                        try? context.save()
                        boxTypeToDelete = nil
                    }
                }
                Button("Cancel", role: .cancel) {
                    boxTypeToDelete = nil
                }
            } message: { boxType in
                Text("Are you sure you want to delete the Box Type “\(boxType.boxTypeText)”?")
            }
        }
        .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
            switch result {
            case .success(let url):
                importBoxTypes(from: url)
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
                .navigationTitle("Export Box Types")
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
    
    private func addBoxType() {
        withAnimation {
            let trimmedName = newBoxType.trimmed()
            guard !trimmedName.isEmpty else { return }
            guard !boxTypes.contains(where: { $0.boxTypeText.lowercased() == trimmedName.lowercased() }) else { return }
            
            let newBoxTypeModel = BoxType(boxTypeText: trimmedName)
            context.insert(newBoxTypeModel)
            try? context.save()
            newBoxType = ""
        }
    }
    
    private func editBoxType(_ boxType: BoxType) {
        withAnimation {
            editingBoxType = boxType
            editingText = boxType.boxTypeText
        }
    }
    
    private func saveEditedBoxType() {
        guard let boxType = editingBoxType else { return }
        let trimmedText = editingText.trimmed()
        guard !trimmedText.isEmpty else { return }
        
        withAnimation {
            boxType.boxTypeText = trimmedText
            try? context.save()
            editingBoxType = nil
            editingText = ""
        }
    }
    
    private func deleteBoxTypes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let boxType = filteredBoxTypes[index]
                context.delete(boxType)
            }
            try? context.save()
        }
    }
    
    private func exportBoxTypes() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "box_types_\(timestamp).csv"

        let content = boxTypes
            .map { $0.boxTypeText }
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

    private func importBoxTypes(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

                for boxType in boxTypes {
                    context.delete(boxType)
                }

                for name in lines {
                    let newType = BoxType(boxTypeText: name)
                    context.insert(newType)
                }

                try? context.save()
            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        } else {
            print("Access to the file was denied.")
        }
    }
}
