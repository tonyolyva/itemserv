class ImportMetadataModel: ObservableObject {
    @Published var data: [String: Any] = [:]
}

import SwiftData
import SwiftUI
import UniformTypeIdentifiers
import ZIPFoundation

struct ManageItemsView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var isImporting = false
    @State private var isExporting = false
    @State private var exportURL: URL?
    @State private var confirmReplace = false
    @State private var pendingImportURL: URL?
    @StateObject private var importMetadata = ImportMetadataModel()
    @State private var showImportSheet = false
    @State private var importSheetID = UUID()

    var body: some View {
        NavigationStack {
            VStack {
                Button("Import Items") {
                    isImporting = true
                }
                .padding()

                Button("Export Items") {
                    Task {
                        do {
                            let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
                            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

                            let items: [Item] = try modelContext.fetch(FetchDescriptor<Item>())
                            var jsonArray: [[String: String]] = []

                            for item in items {
                                var dict: [String: String] = [
                                    "name": item.name,
                                    "description": item.itemDescription,
                                    "barcodeValue": item.barcodeValue
                                ]

                                if let category = item.category?.categoryName {
                                    dict["categoryName"] = category
                                }
                                if let boxName = item.boxNameRef?.boxNameText {
                                    dict["boxName"] = boxName
                                }
                                if let boxType = item.boxTypeRef?.boxTypeText {
                                    dict["boxType"] = boxType
                                }
                                if let shelf = item.shelf?.shelfName {
                                    dict["shelf"] = shelf
                                }
                                if let room = item.room?.roomName {
                                    dict["room"] = room
                                }
                                if let sector = item.sector?.sectorName {
                                    dict["sector"] = sector
                                }
                                if let imageData = item.imageData {
                                    let imageName = UUID().uuidString + ".jpg"
                                    let imageURL = tempDir.appendingPathComponent(imageName)
                                    try imageData.write(to: imageURL)
                                    dict["imageFilename"] = imageName
                                }

                                jsonArray.append(dict)
                            }

                            let jsonData = try JSONSerialization.data(withJSONObject: jsonArray, options: .prettyPrinted)
                            let jsonURL = tempDir.appendingPathComponent("items.json")
                            try jsonData.write(to: jsonURL)

                            let categories = try modelContext.fetch(FetchDescriptor<Category>()).map { $0.categoryName }
                            let rooms = try modelContext.fetch(FetchDescriptor<Room>()).map { $0.roomName }
                            let sectors = try modelContext.fetch(FetchDescriptor<Sector>()).map { $0.sectorName }
                            let shelves = try modelContext.fetch(FetchDescriptor<Shelf>()).map { $0.shelfName }
                            let boxNames = try modelContext.fetch(FetchDescriptor<BoxName>()).map { $0.boxNameText }
                            let boxTypes = try modelContext.fetch(FetchDescriptor<BoxType>()).map { $0.boxTypeText }

                            let metadata: [String: Any] = [
                                "exportedBy": "itemserv 1.0",
                                "exportedAt": ISO8601DateFormatter().string(from: Date()),
                                "totalItems": items.count,
                                "totalImages": items.filter { $0.imageData != nil }.count,
                                "deviceName": UIDevice.current.name,
                                "categories": categories,
                                "rooms": rooms,
                                "sectors": sectors,
                                "shelves": shelves,
                                "boxNames": boxNames,
                                "boxTypes": boxTypes
                            ]
                            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: .prettyPrinted)
                            let metadataURL = tempDir.appendingPathComponent("meta.json")
                            try metadataData.write(to: metadataURL)

                            let dateFormatter = DateFormatter()
                            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
                            let dateString = dateFormatter.string(from: Date())
                            let zipURL = tempDir.deletingLastPathComponent().appendingPathComponent("items_backup_\(dateString).zip")
                            try? FileManager.default.removeItem(at: zipURL)

                            let archive = Archive(url: zipURL, accessMode: .create)!
                            let fileEnumerator = FileManager.default.enumerator(at: tempDir, includingPropertiesForKeys: nil)?
                                .compactMap { $0 as? URL } ?? []

                            for fileURL in fileEnumerator {
                                let relativePath = fileURL.path.replacingOccurrences(of: tempDir.path + "/", with: "")
                                try archive.addEntry(with: relativePath, relativeTo: tempDir)
                            }

                            exportURL = zipURL
                            isExporting = true

                        } catch {
                            print("Export failed: \(error.localizedDescription)")
                        }
                    }
                }
                .padding()
            }
        }
        .sheet(isPresented: $isExporting) {
            NavigationStack {
                VStack {
                    if let exportURL {
                        ShareLink(item: exportURL)
                            .padding()
                    }
                }
                .navigationTitle("Export Items")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isExporting = false
                            exportURL = nil
                        }
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
                                }

                                if file.lastPathComponent == "rooms.json" {
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
                                }

                                if file.lastPathComponent == "sectors.json" {
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
                                }

                                if file.lastPathComponent == "shelves.json" {
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
                                }

                                if file.lastPathComponent.lowercased() == "box_names.json" {
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
                                }
                                if file.lastPathComponent.lowercased() == "box_types.json" {
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

                                if file.lastPathComponent == "items.json" {
                                    importAllItems(from: url)
                                }
                            }

                            try? modelContext.save()

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

                let existingItems = try modelContext.fetch(FetchDescriptor<Item>())
                for item in existingItems {
                    modelContext.delete(item)
                }

                for raw in rawItems {
                    let item = Item(
                        name: raw["name"] ?? "",
                        itemDescription: raw["description"] ?? "",
                        barcodeValue: raw["barcodeValue"] ?? ""
                    )

                    if let categoryName = raw["categoryName"],
                       let category = try? Category.fetchOne(name: categoryName, context: modelContext) {
                        item.category = category
                    }

                    if let boxName = raw["boxName"],
                       let box = try? BoxName.fetchOne(name: boxName, context: modelContext) {
                        item.boxNameRef = box
                    }

                    if let boxTypeName = raw["boxType"],
                       let boxType = try? BoxType.fetchOne(name: boxTypeName, context: modelContext) {
                        item.boxTypeRef = boxType
                    }

                    if let shelfName = raw["shelf"],
                       let shelf = try? Shelf.fetchOne(name: shelfName, context: modelContext) {
                        item.shelf = shelf
                    }

                    if let roomName = raw["room"],
                       let room = try? Room.fetchOne(name: roomName, context: modelContext) {
                        item.room = room
                    }

                    if let sectorName = raw["sector"],
                       let sector = try? Sector.fetchOne(name: sectorName, context: modelContext) {
                        item.sector = sector
                    }

                    if let imageName = raw["imageFilename"] {
                        let imagePath = tempDir.appendingPathComponent(imageName)
                        item.imageData = try? Data(contentsOf: imagePath)
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

extension BoxName {
    static func fetchOne(name: String, context: ModelContext) throws -> BoxName? {
        let descriptor = FetchDescriptor<BoxName>(predicate: #Predicate { $0.boxNameText == name })
        return try context.fetch(descriptor).first
    }
}

extension Shelf {
    static func fetchOne(name: String, context: ModelContext) throws -> Shelf? {
        let descriptor = FetchDescriptor<Shelf>(predicate: #Predicate { $0.shelfName == name })
        return try context.fetch(descriptor).first
    }
}

extension BoxType {
    static func fetchOne(name: String, context: ModelContext) throws -> BoxType? {
        let descriptor = FetchDescriptor<BoxType>(predicate: #Predicate { $0.boxTypeText == name })
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

