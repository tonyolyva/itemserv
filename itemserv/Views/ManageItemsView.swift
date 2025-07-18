import Foundation
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
    @State private var showDeleteEmptyConfirmation = false
    @State private var isBusy = false
    
    var body: some View {
        NavigationStack {
            let controls = VStack {
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


                Button("Delete Empty Records") {
                    showDeleteEmptyConfirmation = true
                }
                .padding()
                .confirmationDialog("Are you sure you want to delete all empty records?", isPresented: $showDeleteEmptyConfirmation) {
                    Button("Delete", role: .destructive) {
                        Task {
                            isBusy = true
                            try? await Task.sleep(nanoseconds: 300_000_000) // Delay for animation
                            let categories = try? modelContext.fetch(FetchDescriptor<Category>())
                            let rooms = try? modelContext.fetch(FetchDescriptor<Room>())
                            let sectors = try? modelContext.fetch(FetchDescriptor<Sector>())
                            let shelves = try? modelContext.fetch(FetchDescriptor<Shelf>())
                            let boxNames = try? modelContext.fetch(FetchDescriptor<BoxName>())
                            let boxTypes = try? modelContext.fetch(FetchDescriptor<BoxType>())
                            
                            for category in categories ?? [] where (category.categoryName?.trimmed().isEmpty ?? true) {
                                modelContext.delete(category)
                            }
                            for room in rooms ?? [] where room.roomName.trimmed().isEmpty {
                                modelContext.delete(room)
                            }
                            for sector in sectors ?? [] where sector.sectorName.trimmed().isEmpty {
                                modelContext.delete(sector)
                            }
                            for shelf in shelves ?? [] where shelf.shelfName.trimmed().isEmpty {
                                modelContext.delete(shelf)
                            }
                            for boxName in boxNames ?? [] where boxName.boxNameText.trimmed().isEmpty {
                                modelContext.delete(boxName)
                            }
                            for boxType in boxTypes ?? [] where boxType.boxTypeText.trimmed().isEmpty {
                                modelContext.delete(boxType)
                            }
                            try? modelContext.save()
                            isBusy = false
                            withAnimation {
                                successMessage = "Empty records deleted"
                                showSuccessMessage = true
                            }
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
                            withAnimation {
                                showSuccessMessage = false
                            }
                        }
                    }
                    Button("Cancel", role: .cancel) {}
                }

                Button(role: .destructive) {
                    showDeleteAllConfirmation = true
                } label: {
                    Text("Delete All Data")
                        .padding()
                }
                .confirmationDialog("Are you sure you want to delete all data? This cannot be undone.", isPresented: $showDeleteAllConfirmation) {
                    Button("Delete All", role: .destructive) {
                        Task {
                            isBusy = true
                            try? await Task.sleep(nanoseconds: 300_000_000)
                            let allItems = try? modelContext.fetch(FetchDescriptor<Item>())
                            let categories = try? modelContext.fetch(FetchDescriptor<Category>())
                            let rooms = try? modelContext.fetch(FetchDescriptor<Room>())
                            let sectors = try? modelContext.fetch(FetchDescriptor<Sector>())
                            let shelves = try? modelContext.fetch(FetchDescriptor<Shelf>())
                            let boxNames = try? modelContext.fetch(FetchDescriptor<BoxName>())
                            let boxTypes = try? modelContext.fetch(FetchDescriptor<BoxType>())
                            
                            for item in allItems ?? [] {
                                modelContext.delete(item)
                            }
                            for category in categories ?? [] {
                                modelContext.delete(category)
                            }
                            for room in rooms ?? [] {
                                modelContext.delete(room)
                            }
                            for sector in sectors ?? [] {
                                modelContext.delete(sector)
                            }
                            for shelf in shelves ?? [] {
                                modelContext.delete(shelf)
                            }
                            for boxName in boxNames ?? [] {
                                modelContext.delete(boxName)
                            }
                            for boxType in boxTypes ?? [] {
                                modelContext.delete(boxType)
                            }
                            try? modelContext.save()
                            isBusy = false
                            withAnimation {
                                successMessage = "All data deleted"
                                showSuccessMessage = true
                            }
                            try? await Task.sleep(nanoseconds: 2_000_000_000)
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
                                if file.lastPathComponent == "categories.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["categoryName"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<Category>(predicate: #Predicate { $0.categoryName == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(Category(categoryName: name))
                                                }
                                            }
                                        }
                                    }
                                } else if file.lastPathComponent == "rooms.json" {
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
                                } else if file.lastPathComponent == "sectors.json" {
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
                                } else if file.lastPathComponent == "shelves.json" {
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
                                } else if file.lastPathComponent.lowercased() == "box_names.json" {
                                    let data = try Data(contentsOf: file)
                                    if let objects = try JSONSerialization.jsonObject(with: data) as? [[String: String]] {
                                        for obj in objects {
                                            if let name = obj["boxNameText"] {
                                                let existing = try modelContext.fetch(FetchDescriptor<BoxName>(predicate: #Predicate { $0.boxNameText == name }))
                                                if existing.isEmpty {
                                                    modelContext.insert(BoxName(boxNameText: name))
                                                }
                                            }
                                        }
                                    }
                                } else if file.lastPathComponent.lowercased() == "box_types.json" {
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
                                        importAllItems(from: url)
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Replace all items with imported data?")
                            .font(.headline)
                            .padding(.bottom)
                        
                        Group {
                            Text("Source: \((importMetadata.data["deviceName"] as? String) ?? "Unknown")")
                            Text("Exported At: \((importMetadata.data["exportedAt"] as? String) ?? "Unknown")")
                            Text("Items: \((importMetadata.data["totalItems"] as? Int).map { String($0) } ?? (importMetadata.data["totalItems"] as? String) ?? "-")")
                            Text("Images: \((importMetadata.data["totalImages"] as? Int).map { String($0) } ?? (importMetadata.data["totalImages"] as? String) ?? "-")")
                        }
                        .padding(.bottom)
                        
                        if let categories = importMetadata.data["categories"] as? [String] {
                            Label("Categories", systemImage: "tag").bold().foregroundStyle(.purple)
                            Text(categories.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                        if let rooms = importMetadata.data["rooms"] as? [String] {
                            Label("Rooms", systemImage: "house").bold().foregroundStyle(.orange)
                            Text(rooms.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                        if let sectors = importMetadata.data["sectors"] as? [String] {
                            Label("Sectors", systemImage: "square.grid.3x2").bold().foregroundStyle(.mint)
                            Text(sectors.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                        if let shelves = importMetadata.data["shelves"] as? [String] {
                            Label("Shelves", systemImage: "tray.2").bold().foregroundStyle(.teal)
                            Text(shelves.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                        if let boxNames = importMetadata.data["boxNames"] as? [String] {
                            Label("Box Names", systemImage: "cube.box").bold().foregroundStyle(.indigo)
                            Text(boxNames.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                        if let boxTypes = importMetadata.data["boxTypes"] as? [String] {
                            Label("Box Types", systemImage: "square.stack.3d.up").bold().foregroundStyle(.pink)
                            Text(boxTypes.joined(separator: "\n")).multilineTextAlignment(.leading)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Confirm Import")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Replace Items", role: .destructive) {
                            if let url = pendingImportURL {
                                importAllItems(from: url)
                            }
                            pendingImportURL = nil
                            importMetadata.data = [:]
                            showImportSheet = false
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            pendingImportURL = nil
                            importMetadata.data = [:]
                            showImportSheet = false
                        }
                    }
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
                guard let rawItems = try JSONSerialization.jsonObject(with: data) as? [[String: String]] else { return }

                // Filter out entries with empty or whitespace-only names
                let validRawItems = rawItems.filter {
                    let name = $0["name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return !name.isEmpty
                }

                let existingItems = try modelContext.fetch(FetchDescriptor<Item>())
                for item in existingItems {
                    modelContext.delete(item)
                }

                for raw in validRawItems {
                    // Read all keys in consistent order with default fallback
                    let item = Item(
                        name: raw["name"] ?? "",
                        itemDescription: raw["description"] ?? "",
                        barcodeValue: raw["barcodeValue"] ?? ""
                    )

                    // imageFilename
                    if let imageName = raw["imageFilename"], !imageName.isEmpty {
                        let imagePath = tempDir.appendingPathComponent(imageName)
                        item.imageData = try? Data(contentsOf: imagePath)
                    }

                    // room
                    if let roomName = raw["room"],
                       let room = try? Room.fetchOne(name: roomName, context: modelContext) {
                        item.room = room
                    }

                    // sector
                    if let sectorName = raw["sector"],
                       let sector = try? Sector.fetchOne(name: sectorName, context: modelContext) {
                        item.sector = sector
                    }

                    // shelf
                    if let shelfName = raw["shelf"],
                       let shelf = try? Shelf.fetchOne(name: shelfName, context: modelContext) {
                        item.shelf = shelf
                    }

                    // boxName
                    if let boxName = raw["boxName"],
                       let box = try? BoxName.fetchOne(name: boxName, context: modelContext) {
                        item.boxNameRef = box
                    }

                    // boxType
                    if let boxTypeName = raw["boxType"],
                       let boxType = try? BoxType.fetchOne(name: boxTypeName, context: modelContext) {
                        item.boxTypeRef = boxType
                    }

                    // categoryName
                    if let categoryName = raw["categoryName"],
                       let category = try? Category.fetchOne(name: categoryName, context: modelContext) {
                        item.category = category
                    }

                    modelContext.insert(item)
                }

                try? modelContext.save()

            } catch {
                print("Import failed: \(error.localizedDescription)")
            }
        } else {
            print("Access denied to file.")
        }
    }
}

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

extension BoxName {
    static func fetchOne(name: String, context: ModelContext) throws -> BoxName? {
        let descriptor = FetchDescriptor<BoxName>(predicate: #Predicate { $0.boxNameText == name })
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

            var orderedDict = OrderedDictionary<String, String>()
            orderedDict["name"] = item.name
            orderedDict["description"] = item.itemDescription
            orderedDict["categoryName"] = item.category?.categoryName ?? ""
            orderedDict["barcodeValue"] = item.barcodeValue
            orderedDict["imageFilename"] = imageName
            orderedDict["room"] = item.room?.roomName ?? ""
            orderedDict["sector"] = item.sector?.sectorName ?? ""
            orderedDict["shelf"] = item.shelf?.shelfName ?? ""
            orderedDict["boxName"] = item.boxNameRef?.boxNameText ?? ""
            orderedDict["boxType"] = item.boxTypeRef?.boxTypeText ?? ""

            // Don't wrap with .map { ($0.key, $0.value) } anymore
            jsonArray.append(orderedDict.reduce(into: [String: String]()) { $0[$1.key] = $1.value })
        }
        // Manual JSON formatting with consistent key order and spacing
        let keyOrder = ["name", "description", "categoryName", "barcodeValue", "imageFilename", "room", "sector", "shelf", "boxName", "boxType"]
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
        let tsvHeader = ["name", "description", "categoryName", "barcodeValue", "imageFilename", "room", "sector", "shelf", "boxName", "boxType"]
        var tsvRows: [String] = [tsvHeader.joined(separator: "\t")]
        for item in items {
            let tsvValues: [String] = [
                item.name,
                item.itemDescription,
                item.category?.categoryName ?? "",
                item.barcodeValue,
                item.barcodeValue + ".jpg",
                item.room?.roomName ?? "",
                item.sector?.sectorName ?? "",
                item.shelf?.shelfName ?? "",
                item.boxNameRef?.boxNameText ?? "",
                item.boxTypeRef?.boxTypeText ?? ""
            ].map { $0.replacingOccurrences(of: "\t", with: " ") }
            tsvRows.append(tsvValues.joined(separator: "\t"))
        }
        let finalTSV = tsvRows.joined(separator: "\n")
        try finalTSV.write(to: tsvURL, atomically: true, encoding: .utf8)
        // --- End items.tsv ---

        let categories = (try? modelContext.fetch(FetchDescriptor<Category>()).map { $0.categoryName }) ?? []
        let rooms = (try? modelContext.fetch(FetchDescriptor<Room>()).map { $0.roomName }) ?? []
        let sectors = (try? modelContext.fetch(FetchDescriptor<Sector>()).map { $0.sectorName }) ?? []
        let shelves = (try? modelContext.fetch(FetchDescriptor<Shelf>()).map { $0.shelfName }) ?? []
        let boxNames = (try? modelContext.fetch(FetchDescriptor<BoxName>()).map { $0.boxNameText }) ?? []
        let boxTypes = (try? modelContext.fetch(FetchDescriptor<BoxType>()).map { $0.boxTypeText }) ?? []

        // Manual meta.json export with fixed key order and formatting
        let metaKeyOrder = ["exportedBy", "exportedAt", "totalItems", "totalImages", "deviceName", "deviceModel", "systemVersion", "categories", "rooms", "sectors", "shelves", "boxNames", "boxTypes"]
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
            "rooms": rooms,
            "sectors": sectors,
            "shelves": shelves,
            "boxNames": boxNames,
            "boxTypes": boxTypes
        ]
        let metaString = metaKeyOrder.map { key -> String in
            if let array = metaValues[key] as? [String] {
                let jsonArray = array.map { "\"\($0.replacingOccurrences(of: "\"", with: "\\\""))\"" }.joined(separator: ", ")
                return "  \"\(key)\": [\(jsonArray)]"
            } else if let str = metaValues[key] as? String {
                return "  \"\(key)\": \"\(str.replacingOccurrences(of: "\"", with: "\\\""))\""
            } else {
                return "  \"\(key)\": \(metaValues[key] ?? "null")"
            }
        }.joined(separator: ",\n")
        let finalMetaString = "{\n" + metaString + "\n}"
        let metadataData = finalMetaString.data(using: .utf8)!
        let metadataURL = tempDir.appendingPathComponent("meta.json")
        try metadataData.write(to: metadataURL)

        // --- Write meta.tsv ---
        let metaTSVURL = tempDir.appendingPathComponent("meta.tsv")
        var metaTSVRows: [String] = ["key\tvalue"]
        for key in metaKeyOrder {
            if let array = metaValues[key] as? [String] {
                let value = array.joined(separator: ", ")
                metaTSVRows.append("\(key)\t\(value)")
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

