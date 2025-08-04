import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ManageBoxesView: View {
    @Environment(\.modelContext) private var context
    @Query private var boxes: [Box]
    @State private var boxToDelete: Box?
    @State private var sortAscending: Bool = true
    @State private var searchText: String = ""
    @State private var isImportingFile = false
    @State private var exportURL: URL?
    @State private var isShowingExportSheet = false

    var filteredBoxes: [Box] {
        // Separate "Unboxed"
        let unboxed = boxes.filter { $0.numberOrName == "Unboxed" }
        let others = boxes.filter { $0.numberOrName != "Unboxed" }
        
        // Sort numerically if possible, otherwise alphabetically
        let sortedOthers = others.sorted {
            let num1 = Int($0.numberOrName)
            let num2 = Int($1.numberOrName)
            if let n1 = num1, let n2 = num2 {
                return sortAscending ? (n1 < n2) : (n1 > n2)
            } else {
                return sortAscending
                    ? $0.numberOrName.localizedCaseInsensitiveCompare($1.numberOrName) == .orderedAscending
                    : $0.numberOrName.localizedCaseInsensitiveCompare($1.numberOrName) == .orderedDescending
            }
        }
        
        let results = unboxed + sortedOthers
        
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return results
        } else {
            return results.filter { $0.numberOrName.localizedCaseInsensitiveContains(searchText) }
        }
    }

    private func addBox() {
        let trimmedNames = Set(boxes.map { $0.numberOrName.trimmingCharacters(in: .whitespaces) })

        if !trimmedNames.contains("Unboxed") {
            let unboxed = Box(numberOrName: "Unboxed")
            context.insert(unboxed)
            try? context.save()
            return
        }

        let usedNumbers = Set(
            boxes.compactMap {
                Int($0.numberOrName.trimmingCharacters(in: .whitespaces))
            }
        )

        var nextNumber = 1
        while usedNumbers.contains(nextNumber) {
            nextNumber += 1
        }

        let newBox = Box(numberOrName: "\(nextNumber)")
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
                    exportBoxes()
                }
            }
            .padding(.horizontal)

            List {
                Section(header: Text("Box Names")) {
                    ForEach(filteredBoxes, id: \.self) { box in
                        HStack {
                            if box.numberOrName == "Unboxed" {
                                Label("Unboxed", systemImage: "tray")
                                    .labelStyle(.titleAndIcon)
                            } else {
                                Text(box.numberOrName)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                boxToDelete = box
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }

                Section(header: Text("Add New Box Name")) {
                    Button("Add Next Box") {
                        addBox()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.insetGrouped)
            .animation(.easeInOut(duration: 0.3), value: filteredBoxes)
            .alert("Delete Box Name?", isPresented: .constant(boxToDelete != nil), presenting: boxToDelete) { box in
                Button("Delete", role: .destructive) {
                    if let index = boxes.firstIndex(of: box) {
                        context.delete(boxes[index])
                        try? context.save()
                    }
                    boxToDelete = nil
                }
                Button("Cancel", role: .cancel) {
                    boxToDelete = nil
                }
            } message: { box in
                Text("Are you sure you want to delete \"\(box.numberOrName)\"?")
            }
            .fileImporter(isPresented: $isImportingFile, allowedContentTypes: [.commaSeparatedText]) { result in
                switch result {
                case .success(let url):
                    importBoxes(from: url)
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

    private func exportBoxes() {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmm"
        let timestamp = formatter.string(from: Date())
        let filename = "box_names_\(timestamp).csv"

        let content = boxes
            .map { $0.numberOrName }
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

    private func importBoxes(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            do {
                let data = try String(contentsOf: url, encoding: .utf8)
                let lines = data.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }

                for box in boxes {
                    context.delete(box)
                }

                for name in lines where !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    let newBox = Box(numberOrName: name)
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
