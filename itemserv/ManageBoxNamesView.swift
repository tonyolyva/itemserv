import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageBoxNamesView: View {
    @Environment(\.modelContext) private var context
    @Query private var boxNames: [BoxName]
    @State private var boxNameToDelete: BoxName?
    @State private var sortAscending: Bool = true
    @State private var searchText: String = ""
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false

    var filteredBoxNames: [BoxName] {
        let names = boxNames.map { ($0, $0.boxNameText.lowercased()) }
        let sorted = sortAscending
            ? names.sorted { $0.1 < $1.1 }
            : names.sorted { $0.1 > $1.1 }
        let results = sorted.map { $0.0 }

        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return results
        } else {
            return results.filter { $0.boxNameText.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func addBoxName() {
        let trimmedNames = Set(boxNames.map { $0.boxNameText.trimmingCharacters(in: .whitespaces) })

        if !trimmedNames.contains("Unboxed") {
            let unboxed = BoxName(boxNameText: "Unboxed")
            context.insert(unboxed)
            try? context.save()
            return
        }

        let usedNumbers = Set(
            boxNames.compactMap {
                Int($0.boxNameText.trimmingCharacters(in: .whitespaces))
            }
        )

        var nextNumber = 1
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }

        let newBox = BoxName(boxNameText: "\(nextNumber)")
        context.insert(newBox)
        try? context.save()
    }

    var body: some View {
        VStack {
            Text("Manage Box Names")
                .font(.title2)
                .padding(.top)

            HStack {
                TextField("Search Boxes", text: $searchText)
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
                    exportBoxNames()
                }
            }
            .padding(.horizontal)

            List {
                Section(header: Text("Box Names")) {
                    ForEach(filteredBoxNames, id: \.self) { boxName in
                        HStack {
                            if boxName.boxNameText == "Unboxed" {
                                Label("Unboxed", systemImage: "tray")
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Text(boxName.boxNameText)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                boxNameToDelete = boxName
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }

                Section(header: Text("Add New Box Name")) {
                    Button("Add Next Box") {
                        addBoxName()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .animation(.easeInOut(duration: 0.3), value: filteredBoxNames)
            .alert("Delete Box Name?", isPresented: .constant(boxNameToDelete != nil), presenting: boxNameToDelete) { boxName in
                Button("Delete", role: .destructive) {
                    if let index = boxNames.firstIndex(of: boxName) {
                        context.delete(boxNames[index])
                        try? context.save()
                    }
                    boxNameToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    boxNameToDelete = nil
                }
            } message: { boxName in
                Text("Are you sure you want to delete \"\(boxName.boxNameText)\"?")
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importBoxNames(from: url)
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
                    .navigationTitle("Export Box Names")
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

    private func exportBoxNames() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "box_names_\(timestamp).csv"

        let content = boxNames
            .map { $0.boxNameText }
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

    private func importBoxNames(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for box in boxNames {
                    context.delete(box)
                }

                for name in lines {
                    let newBox = BoxName(boxNameText: name)
                    context.insert(newBox)
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
