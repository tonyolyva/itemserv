import Foundation
import CloudKit
// Returns the device model identifier (e.g., "iPhone15,2") for more informative export metadata.
func getDeviceModelIdentifier() -> String {
    var systemInfo = utsname()
    uname(&systemInfo)
    return withUnsafePointer(to: &systemInfo.machine) {
        $0.withMemoryRebound(to: CChar.self, capacity: 1) {
            String(validatingUTF8: $0) ?? "Unknown"
        }
    }
}

import SwiftData
import OrderedCollections
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation


class ImportMetadataModel: ObservableObject {
    @Published var data: [String: Any] = [:]
}

struct ManageItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var generatedExportURL: URL?
    @State private var confirmReplace = false
    @State private var pendingImportURL: URL?
    @StateObject private var importMetadata = ImportMetadataModel()
    @State private var showImportSheet = false
    @State private var importSheetID = UUID()
    // Success banner and confirmation dialogs
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var showDeleteAllConfirmation = false
    @State private var isBusy = false
    
    var body: some View {
        NavigationStack {
            let controls = VStack {
                Text("💡 Hint: For a clean import test, delete Items first here, then delete Locations in Manage Locations.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
                Divider()
                    .padding(.vertical, 4)
                Button("Import Items") {
                    confirmReplace = true
                }
                .padding()
                .confirmationDialog("Do you want to import items? This may replace existing data.", isPresented: $confirmReplace) {
                    Button("Import", role: .destructive) {
                        withAnimation {
                            isImporting = true
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Button("Export Items") {
                    exportURL = nil
                    isExporting = true
                }
                .padding()



                Button(role: .destructive) {
                    showDeleteAllConfirmation = true
                } label: {
                    Text("Delete All Items")
                        .padding()
                }
                .confirmationDialog("Are you sure you want to delete all items? This cannot be undone.", isPresented: $showDeleteAllConfirmation) {
                    Button("Delete All Items", role: .destructive) {
                        Task {
                            isBusy = true
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            // Fetch only Items and Categories for deletion
                            let allItems = try? modelContext.fetch(FetchDescriptor<Item>())
                            let categories = try? modelContext.fetch(FetchDescriptor<Category>())

                            // Delete Items
                            for item in allItems ?? [] {
                                modelContext.delete(item)
                            }
                            // Delete Categories
                            for category in categories ?? [] {
                                modelContext.delete(category)
                            }

                            try? modelContext.save()
                            isBusy = false
                            withAnimation {
                                successMessage = "All items deleted. ✅ Now delete Locations in Manage Locations."
                                showSuccessMessage = true
                            }
                            try? await Task.sleep(nanoseconds: 3_000_000_000)
                            withAnimation {
                                showSuccessMessage = false
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                if showSuccessMessage {
                    Text(successMessage)
                        .font(.subheadline)
                        .foregroundColor(.green)
                        .padding(8)
                        .frame(maxWidth: .infinity)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.horizontal)
                }
            }

            VStack(alignment: .leading) {
                controls
            }
        }
        .navigationTitle("Manage Items")
        
        .sheet(isPresented: $isExporting, onDismiss: {
            exportURL = nil
        }) {
            NavigationStack {
                VStack {
                    if let exportURL {
                        ShareLink(item: exportURL)
                            .padding()
                    } else {
                        ProgressView("Preparing export...")
                            .padding()
                    }
                }
                .navigationTitle("Export Items")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isExporting = false
                        }
                    }
                }
                .onAppear {
                    Task {
                        isBusy = true
                        let result = await generateExport(modelContext: modelContext)
                        if let url = result {
                            exportURL = url
                            withAnimation {
                                successMessage = "Export completed"
                                showSuccessMessage = true
                            }
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation {
                                showSuccessMessage = false
                            }
                        } else {
                            isExporting = false
                        }
                        isBusy = false
                    }
                }
            }
        }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [UTType.zip], allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                for url in urls {
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
                        
                        do {
                            try FileManager.default.unzipItem(at: url, to: tempDir)
                            
                            let fileList = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)?
                                .compactMap { $0 as? URL } ?? []
                            
                            // First pass: import only metadata files
                            for file in fileList {
                                let name = file.lastPathComponent
                                let lowerName = name.lowercased()
                                if lowerName == "categories.json" {
                                    let data = try Data(contentsOf: file)
                                    // Try to decode as array of strings (new format)
                                    if let names = try? JSONSerialization.jsonObject(with: data) as? [String] {
                                        for name in names {
                                            let existing = try modelContext.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == name }))
                                            if existing.isEmpty {
                                                modelContext.insert(Category(categoryName: name))
                                            }
                                        }
                                    } else if let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        // Fallback to array of dicts (old format)
                                        for obj in objects {
                                            if let name = obj["categoryName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Category(categoryName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if lowerName == "rooms.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["roomName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Room>(predicate: #Predicate { $0.roomName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Room(roomName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if lowerName == "sectors.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["sectorName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Sector>(predicate: #Predicate { $0.sectorName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Sector(sectorName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if lowerName == "shelves.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["shelfName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Shelf>(predicate: #Predicate { $0.shelfName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Shelf(shelfName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if lowerName == "box_names.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["numberOrName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.numberOrName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Box(numberOrName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if lowerName == "box_types.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["boxTypeText"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<BoxType>(predicate: #Predicate { $0.boxTypeText == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(BoxType(boxTypeText: name))
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            try? modelContext.save()
                            
                            // Artificial delay to allow CloudKit to catch up
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                                for file in fileList {
                                    if file.lastPathComponent == "items.json" {
                                        // Load metadata first for confirmation UI
                                        if let metaFile = fileList.first(where: { $0.lastPathComponent == "meta.json" }) {
                                            let metaData = try Data(contentsOf: metaFile)
                                            if let metaDict = try JSONSerialization.jsonObject(with: metaData) as? [String: Any] {
                                                importMetadata.data = metaDict
                                                pendingImportURL = url
                                                importSheetID = UUID()
                                                showImportSheet = true
                                            }
                                        } else {
                                            // Fallback: import immediately if no meta.json found
                                            importAllItems(from: url)
                                        }
                                    }
                                }
                            }
                            
                        } catch {
                            print("❌ Error processing zip file \(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    } else {
                        print("❌ Could not access scoped resource: \(url)")
                    }
                }
            case .failure(let error):
                print("Import failed: \(error.localizedDescription)")
            }
        }
        .fullScreenCover(isPresented: $showImportSheet) {
            NavigationStack {
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Confirm Import")
                                .font(.largeTitle.bold())
                                .padding(.bottom, 4)

                            Text("Replace all items with imported data?")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .padding(.bottom, 8)

                            Group {
                                Label("Exported by: \((importMetadata.data["exportedBy"] as? String) ?? "Unknown")", systemImage: "person.fill")
                                Label("Exported at: \((importMetadata.data["exportedAt"] as? String) ?? "Unknown")", systemImage: "calendar")
                                Label("Device: \((importMetadata.data["deviceName"] as? String) ?? "Unknown")", systemImage: "iphone")
                                Label("System: \((importMetadata.data["systemVersion"] as? String) ?? "Unknown")", systemImage: "gear")
                                Label("Items: \((importMetadata.data["totalItems"] as? Int).map { String($0) } ?? "-")", systemImage: "cube.box")
                                Label("Images: \((importMetadata.data["totalImages"] as? Int).map { String($0) } ?? "-")", systemImage: "photo")
                            }
                            .font(.subheadline)
                            .padding(.bottom, 4)

                            Divider()

                            // Collapsible Sections
                            CollapsibleSection(title: "📂 Categories", color: .purple, items: (importMetadata.data["categories"] as? [String]) ?? [])
                            CollapsibleSection(title: "📦 Box Names", color: .indigo, items: (importMetadata.data["boxNames"] as? [String]) ?? [])
                        }
                        .padding()
                    }
                    .background(Color.black.ignoresSafeArea())

                    Divider()

                    HStack {
                        Button("Cancel") {
                            pendingImportURL = nil
                            importMetadata.data = [:]
                            showImportSheet = false
                        }
                        .foregroundColor(.blue)
                        Spacer()
                        Button("Replace Items") {
                            if let url = pendingImportURL {
                                importAllItems(from: url)
                            }
                            pendingImportURL = nil
                            importMetadata.data = [:]
                            showImportSheet = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
        }
        .id(importSheetID)

        // Busy overlay
        if isBusy {
            ZStack {
                Color.black.opacity(0.3).ignoresSafeArea()
                ProgressView("Working…")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
            }
        }
        // generateExport moved outside of body
    }
    
    private func importAllItems(from url: URL) {
        if url.startAccessingSecurityScopedResource() {
            defer { url.stopAccessingSecurityScopedResource() }

            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

            do {
                try FileManager.default.unzipItem(at: url, to: tempDir)
                let jsonURL = tempDir.appendingPathComponent("items.json")
                let data = try Data(contentsOf: jsonURL)

                // Clear existing items
                let existingItems = try modelContext.fetch(FetchDescriptor<Item>())
                for item in existingItems {
                    modelContext.delete(item)
                }

                // Clear existing categories
                let existingCategories = try modelContext.fetch(FetchDescriptor<Category>())
                for category in existingCategories {
                    modelContext.delete(category)
                }

                // Re-import all categories from meta.json (including unused ones)
                let metaFileURL = tempDir.appendingPathComponent("meta.json")
                if FileManager.default.fileExists(atPath: metaFileURL.path) {
                    let metaData = try Data(contentsOf: metaFileURL)
                    if let metaDict = try JSONSerialization.jsonObject(with: metaData) as? [String: Any],
                       let categoryNames = metaDict["categories"] as? [String] {
                        for name in categoryNames {
                            let existing = try modelContext.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == name }))
                            if existing.isEmpty {
                                modelContext.insert(Category(categoryName: name))
                            }
                        }
                    }
                }

                guard let rawItems = try JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }

                // Filter out invalid names
                let validRawItems = rawItems.filter {
                    let name = $0["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return !name.isEmpty
                }

                // Prepare deduplication maps
                var boxMap: [String: Box] = [:]
                var categoryMap: [String: Category] = [:]

                // Import items
                for raw in validRawItems {
                    let item = Item(
                        name: raw["name"] ?? "",
                        itemDescription: raw["description"] ?? "",
                        barcodeValue: raw["barcodeValue"] ?? ""
                    )

                    // Image
                    if let imageName = raw["imageFilename"], !imageName.isEmpty {
                        let imagePath = tempDir.appendingPathComponent(imageName)
                        item.imageData = try? Data(contentsOf: imagePath)
                    }

                    // Box (V3 simplified) with deduplication
                    if let boxName = raw["boxName"], !boxName.isEmpty {
                        if let cachedBox = boxMap[boxName] {
                            item.box = cachedBox
                        } else if let existingBox = try? modelContext.fetch(FetchDescriptor<Box>(predicate: #Predicate { $0.numberOrName == boxName })).first {
                            item.box = existingBox
                            boxMap[boxName] = existingBox
                        } else {
                            let newBox = Box(numberOrName: boxName)
                            modelContext.insert(newBox)
                            item.box = newBox
                            boxMap[boxName] = newBox
                        }
                    }

                    // Category with deduplication
                    if let categoryName = raw["categoryName"], !categoryName.isEmpty {
                        if let cachedCategory = categoryMap[categoryName] {
                            item.category = cachedCategory
                        } else if let existingCategory = try? modelContext.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == categoryName })).first {
                            item.category = existingCategory
                            categoryMap[categoryName] = existingCategory
                        } else {
                            let newCategory = Category(categoryName: categoryName)
                            modelContext.insert(newCategory)
                            item.category = newCategory
                            categoryMap[categoryName] = newCategory
                        }
                    }

                    modelContext.insert(item)
                }

                try? modelContext.save()
                
                // Show success alert after import
                withAnimation {
                    successMessage = "Items import completed successfully."
                    showSuccessMessage = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    withAnimation {
                        showSuccessMessage = false
                    }
                }

            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        } else {
            print("Access denied to file.")
        }
    }


} // End of struct ManageItemsView

extension Category {
    static func fetchOne(name: String, context: ModelContext) throws -> Category? {
        let descriptor = FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == name })
        return try context.fetch(descriptor).first
    }
}

extension Room {
    static func fetchOne(name: String, context: ModelContext) throws -> Room? {
        let descriptor = FetchDescriptor<Room>(predicate: #Predicate { $0.roomName == name })
        return try context.fetch(descriptor).first
    }
}

extension Sector {
    static func fetchOne(name: String, context: ModelContext) throws -> Sector? {
        let descriptor = FetchDescriptor<Sector>(predicate: #Predicate { $0.sectorName == name })
        return try context.fetch(descriptor).first
    }
}

extension Shelf {
    static func fetchOne(name: String, context: ModelContext) throws -> Shelf? {
        let descriptor = FetchDescriptor<Shelf>(predicate: #Predicate { $0.shelfName == name })
        return try context.fetch(descriptor).first
    }
}

extension Box {
    static func fetchOne(name: String, context: ModelContext) throws -> Box? {
        let descriptor = FetchDescriptor<Box>(predicate: #Predicate { $0.numberOrName == name })
        return try context.fetch(descriptor).first
    }
}

extension BoxType {
    static func fetchOne(name: String, context: ModelContext) throws -> BoxType? {
        let descriptor = FetchDescriptor<BoxType>(predicate: #Predicate { $0.boxTypeText == name })
        return try context.fetch(descriptor).first
    }
}


@MainActor
private func generateExport(modelContext: ModelContext) async -> URL? {
    do {
        // modelContext is directly accessible via @Environment
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let descriptor = FetchDescriptor<Item>(sortBy: [SortDescriptor(\Item.name, order: .forward)])
        let items: [Item] = try modelContext.fetch(descriptor)
        var jsonArray: [[String: String]] = []

        for item in items {
            let imageName: String
            if let imageData = item.imageData {
                imageName = item.barcodeValue + ".jpg"
                let imageURL = tempDir.appendingPathComponent(imageName)
                try imageData.write(to: imageURL)
            } else {
                imageName = ""
            }

            // Simplified export for V3: no room, sector, shelf, or boxType (handled in Location separately)
            var orderedDict = OrderedDictionary<String, String>()
            orderedDict["name"] = item.name
            orderedDict["description"] = item.itemDescription
            orderedDict["categoryName"] = item.category?.categoryName ?? ""
            orderedDict["barcodeValue"] = item.barcodeValue
            orderedDict["imageFilename"] = imageName
            orderedDict["boxName"] = item.box?.numberOrName ?? ""

            // Don't wrap with .map { ($0.key, $0.value) } anymore
            jsonArray.append(orderedDict.reduce(into: [String: String]()) { $0[$1.key] = $1.value })
        }
        // Manual JSON formatting with consistent key order and spacing
        // Simplified key order for V3 (no room, sector, shelf, boxType)
        let keyOrder = ["name", "description", "categoryName", "barcodeValue", "imageFilename", "boxName"]
        var itemStrings: [String] = []
        for dictionary in jsonArray {
            let pairs = keyOrder.map { key -> String in
                let value = dictionary[key]?.replacingOccurrences(of: "\"", with: "\\\"") ?? ""
                return "  \"\(key)\": \"\(value)\""
            }
            let jsonObject = "{\n" + pairs.joined(separator: ",\n") + "\n}"
            itemStrings.append(jsonObject)
        }
        let finalJSONString = "[\n" + itemStrings.joined(separator: ",\n") + "\n]"
        let jsonData = finalJSONString.data(using: .utf8)!
        let jsonURL = tempDir.appendingPathComponent("items.json")
        try jsonData.write(to: jsonURL)

// --- Write items.tsv ---
        let tsvURL = tempDir.appendingPathComponent("items.tsv")
        let tsvHeader = ["name", "description", "categoryName", "barcodeValue", "imageFilename", "boxName"]
        var tsvRows: [String] = [tsvHeader.joined(separator: "\t")]
        for item in items {
            let tsvValues: [String] = [
                item.name,
                item.itemDescription,
                item.category?.categoryName ?? "",
                item.barcodeValue,
                item.barcodeValue + ".jpg",
                item.box?.numberOrName ?? ""
            ].map { $0.replacingOccurrences(of: "\t", with: " ") }
            tsvRows.append(tsvValues.joined(separator: "\t"))
        }
        let finalTSV = tsvRows.joined(separator: "\n")
        try finalTSV.write(to: tsvURL, atomically: true, encoding: .utf8)
        // --- End items.tsv ---

        var categories = (try? modelContext.fetch(FetchDescriptor<Category>()).compactMap { $0.categoryName }) ?? []
        categories.sort { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }

        let rooms = (try? modelContext.fetch(FetchDescriptor<Room>()).map { $0.roomName }) ?? []
        let sectors = (try? modelContext.fetch(FetchDescriptor<Sector>()).map { $0.sectorName }) ?? []
        let shelves = (try? modelContext.fetch(FetchDescriptor<Shelf>()).map { $0.shelfName }) ?? []
        var boxNames = (try? modelContext.fetch(FetchDescriptor<Box>()).map { $0.numberOrName }) ?? []
        boxNames.sort { lhs, rhs in
            if lhs == "Unboxed" { return true }
            if rhs == "Unboxed" { return false }
            return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }
        let boxTypes = (try? modelContext.fetch(FetchDescriptor<BoxType>()).map { $0.boxTypeText }) ?? []

// Simplified meta.json export with fewer keys (V3)
        let metaKeyOrder = ["exportedBy", "exportedAt", "deviceName", "deviceModel", "systemVersion", "totalItems", "totalImages", "categories", "boxNames"]

        let metaValues: [String: Any] = [
            "exportedBy":
                "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "itemserv") " +
                "\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?") " +
                "(\(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"))",
            "exportedAt": ISO8601DateFormatter().string(from: Date()),
            "totalItems": items.count,
            "totalImages": items.filter { $0.imageData != nil }.count,
            "deviceName": UIDevice.current.name,
            "deviceModel": getDeviceModelIdentifier(),
            "systemVersion": UIDevice.current.systemVersion,
            "categories": categories,
            "boxNames": boxNames
        ]

        // Format meta.json
        let metaString = metaKeyOrder.map { key -> String in
            if let array = metaValues[key] as? [String] {
                // Multi-line JSON array
                let jsonArray = array.map { "    \"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }
                                     .joined(separator: ",\n")
                return "  \"\(key)\": [\n\(jsonArray)\n  ]"
            } else if let str = metaValues[key] as? String {
                return "  \"\(key)\": \"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
            } else {
                return "  \"\(key)\": \(metaValues[key] ?? "null")"
            }
        }.joined(separator: ",\n")

        let finalMetaString = "{\n" + metaString + "\n}"
        let metadataData = finalMetaString.data(using: String.Encoding.utf8)!
        let metadataURL = tempDir.appendingPathComponent("meta.json")
        try metadataData.write(to: metadataURL)

        // --- Write meta.tsv ---
        let metaTSVURL = tempDir.appendingPathComponent("meta.tsv")
        var metaTSVRows: [String] = ["key\tvalue"]
        for key in metaKeyOrder {
            if key == "categories", !categories.isEmpty {
                for element in categories {
                    metaTSVRows.append("\(key)\t\(element)")
                }
            } else if key == "boxNames", !boxNames.isEmpty {
                for element in boxNames {
                    metaTSVRows.append("\(key)\t\(element)")
                }
            } else if let array = metaValues[key] as? [String] {
                for element in array {
                    metaTSVRows.append("\(key)\t\(element)")
                }
            } else if let value = metaValues[key] {
                metaTSVRows.append("\(key)\t\(value)")
            }
        }
        let finalMetaTSV = metaTSVRows.joined(separator: "\n")
        try finalMetaTSV.write(to: metaTSVURL, atomically: true, encoding: .utf8)
        // --- End meta.tsv ---

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let zipURL = tempDir.deletingLastPathComponent().appendingPathComponent("items_backup_\(dateString).zip")
        try? FileManager.default.removeItem(at: zipURL)

        let archive = try Archive(url: zipURL, accessMode: .create)
        let fileEnumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)?
            .compactMap { $0 as? URL } ?? []

        for fileURL in fileEnumerator {
            let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
            try archive.addEntry(with: relativePath, relativeTo: tempDir)
        }

        return zipURL
    } catch {
        print("Export failed: \(error.localizedDescription)")
    }
    return nil
}


struct CollapsibleSection: View {
    let title: String
    let color: Color
    let items: [String]
    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { withAnimation { isExpanded.toggle() } }) {
                HStack {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.white)
                            .padding(.leading, 8)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, 4)
    }
}
