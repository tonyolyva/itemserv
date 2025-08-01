import SwiftUI
import SwiftData

struct ManageLocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Box.numberOrName) private var boxes: [Box]
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importResultMessage: String?
    @State private var showImportResult = false

    @State private var pendingImportMeta: [String: Any]?
    @State private var showImportConfirmation = false
    @State private var showSuccessMessage = false
    @State private var successMessage = ""
    @State private var isLoadingImport = false

    var body: some View {
        // Split the view building into smaller computed properties to help the compiler
        contentView
            .sheet(isPresented: $showImportConfirmation) {
                if isLoadingImport {
                    VStack {
                        ProgressView("Loading import data…")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                    }
                } else if let meta = pendingImportMeta {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("Import Locations Backup")
                                    .font(.largeTitle)
                                    .bold()
                                    .padding(.bottom, 8)
                                
                                Label("Exported by: \(meta["exportedBy"] as? String ?? "")", systemImage: "person.crop.circle")
                                Label("Exported at: \(meta["exportedAt"] as? String ?? "")", systemImage: "calendar")
                                Label("Device: \(meta["deviceName"] as? String ?? "")", systemImage: "desktopcomputer")
                                Label("System: \(meta["systemVersion"] as? String ?? "")", systemImage: "gearshape")
                                Label("Total Locations: \(meta["totalLocations"] as? Int ?? 0)", systemImage: "shippingbox")

                            CollapsibleSection(title: "Rooms", color: .blue, items: meta["rooms"] as? [String] ?? [])
                            CollapsibleSection(title: "Sectors", color: .blue, items: meta["sectors"] as? [String] ?? [])
                            CollapsibleSection(title: "Shelves", color: .blue, items: meta["shelves"] as? [String] ?? [])
                            CollapsibleSection(title: "Box Names", color: .blue, items: meta["boxNames"] as? [String] ?? [])
                            CollapsibleSection(title: "Box Types", color: .blue, items: meta["boxTypes"] as? [String] ?? [])
                            }
                            .padding()
                        }
                        .background(Color.black.ignoresSafeArea())

                        Divider()

                        HStack {
                            Button("Cancel", role: .cancel) { showImportConfirmation = false }
                                .foregroundColor(.blue)
                            Spacer()
                            Button("Confirm Import", role: .destructive) {
                                showImportConfirmation = false
                                proceedWithImport()
                            }
                            .foregroundColor(.red)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                    }
                    .background(Color.black.ignoresSafeArea())
                }
            }
    }

    @ViewBuilder
    private var contentView: some View {
        VStack {
            locationsList
        }
        .navigationTitle("Manage Locations")
        .toolbar { toolbarContent }
        .fileImporter(isPresented: $isImporting, allowedContentTypes: [.zip], onCompletion: handleFileImport)
        .alert("Import Result", isPresented: $showImportResult) { alertButtons } message: { alertMessage }
    }

    private var locationsList: some View {
        List {
            // Move Delete button to the top
            Section {
                Button(role: .destructive, action: deleteAllLocations) {
                    Text("Delete All Locations")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                // Place the hint immediately after the delete button with tighter spacing
                Text("💡 Hint: For a clean import test, delete Locations here after deleting Items in Manage Items.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                    .padding(.top, 4) // tighter spacing from button
                    .padding(.bottom, 4)
                // Removed extra divider to avoid double separation
            }

            Section(header: Text("Locations")) {
                ForEach(boxes) { box in
                    locationRow(for: box)
                }
            }
        }
        // Success message overlay
        .overlay(
            VStack {
                if showSuccessMessage {
                    Text(successMessage)
                        .font(.footnote)
                        .padding(8)
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .padding(.top, 10)
                }
                Spacer()
            }
        )
    }
    private func deleteAllLocations() {
        // Delete all boxes (locations)
        for box in boxes {
            modelContext.delete(box)
        }

        // Delete all rooms
        if let allRooms = try? modelContext.fetch(FetchDescriptor<Room>()) {
            for room in allRooms {
                modelContext.delete(room)
            }
        }

        // Delete all sectors
        if let allSectors = try? modelContext.fetch(FetchDescriptor<Sector>()) {
            for sector in allSectors {
                modelContext.delete(sector)
            }
        }

        // Delete all shelves
        if let allShelves = try? modelContext.fetch(FetchDescriptor<Shelf>()) {
            for shelf in allShelves {
                modelContext.delete(shelf)
            }
        }

        // Delete all box types
        if let allBoxTypes = try? modelContext.fetch(FetchDescriptor<BoxType>()) {
            for type in allBoxTypes {
                modelContext.delete(type)
            }
        }

        do {
            try modelContext.save()
            successMessage = "All locations (boxes, rooms, sectors, shelves, and box types) deleted."
            withAnimation {
                showSuccessMessage = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showSuccessMessage = false
                }
            }
        } catch {
            print("Failed to delete locations: \(error)")
        }
    }

    @ViewBuilder
    private func locationRow(for box: Box) -> some View {
        VStack(alignment: .leading) {
            Text(box.numberOrName)
                .font(.headline)

            if let room = box.room,
               let sector = box.sector,
               let shelf = box.shelf,
               let boxType = box.boxType {
                locationDetails(room: room, sector: sector, shelf: shelf, boxType: boxType)
            } else {
                Text("Incomplete Location Info")
                    .font(.footnote)
                    .foregroundColor(.red)
            }
        }
    }

    private func locationDetails(room: Room, sector: Sector, shelf: Shelf, boxType: BoxType) -> some View {
        VStack(alignment: .leading) {
            Text("\(room.roomName) / \(sector.sectorName) / \(shelf.shelfName)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text("Type: \(boxType.boxTypeText)")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
    }

    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            HStack {
                Button(action: exportLocations) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                Button(action: { isImporting = true }) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
            }
        }
    }

    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            // Ensure we have permission to access the file
            guard url.startAccessingSecurityScopedResource() else {
                importResultMessage = "Failed to access file permission."
                showImportResult = true
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            let fileManager = FileManager.default
            let tempFileURL = fileManager.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
            do {
                if fileManager.fileExists(atPath: tempFileURL.path) {
                    try fileManager.removeItem(at: tempFileURL)
                }
                try fileManager.copyItem(at: url, to: tempFileURL)
                importLocations(from: tempFileURL)
            } catch {
                importResultMessage = "Failed to copy file for import: \(error.localizedDescription)"
                showImportResult = true
            }
        case .failure(let error):
            importResultMessage = "Import failed: \(error.localizedDescription)"
            showImportResult = true
        }
    }

    private var alertButtons: some View {
        Button("OK", role: .cancel) { }
    }

    private var alertMessage: some View {
        Group {
            if let msg = importResultMessage {
                Text(msg)
            }
        }
    }

    // MARK: - Export
    private func exportLocations() {
        // Fetch all boxes with their related Room, Sector, Shelf, and BoxType
        // For this we already have `boxes` from the @Query property wrapper
        // Prepare the export data
        struct ExportBox: Codable {
            let numberOrName: String
            let room: String
            let sector: String
            let shelf: String
            let boxType: String
        }

        let exportBoxes: [ExportBox] = boxes.map { box in
            ExportBox(
                numberOrName: box.numberOrName,
                room: box.room?.roomName ?? "",
                sector: box.sector?.sectorName ?? "",
                shelf: box.shelf?.shelfName ?? "",
                boxType: box.boxType?.boxTypeText ?? ""
            )
        }

        // Encode to JSON
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        guard let jsonData = try? encoder.encode(exportBoxes) else {
            return
        }

        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let exportFolderURL = tempDirectory.appendingPathComponent("locations_export", isDirectory: true)

        // Create export folder
        do {
            if fileManager.fileExists(atPath: exportFolderURL.path) {
                try fileManager.removeItem(at: exportFolderURL)
            }
            try fileManager.createDirectory(at: exportFolderURL, withIntermediateDirectories: true)
        } catch {
            return
        }

        // Write locations.json
        let jsonFileURL = exportFolderURL.appendingPathComponent("locations.json")
        do {
            try jsonData.write(to: jsonFileURL, options: .atomic)
        } catch {
            return
        }

        // Generate locations.tsv
        let tsvHeader = ["Box Name", "Room", "Sector", "Shelf", "Box Type"]
        let tsvRows = exportBoxes.map { box in
            [box.numberOrName, box.room, box.sector, box.shelf, box.boxType]
        }
        let tsvContent = ([tsvHeader] + tsvRows)
            .map { $0.joined(separator: "\t") }
            .joined(separator: "\n")
        let tsvFileURL = exportFolderURL.appendingPathComponent("locations.tsv")
        do {
            try tsvContent.write(to: tsvFileURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        // Generate meta.json with richer info (similar to items backup)
        let isoFormatter = ISO8601DateFormatter()
        let exportDateString = isoFormatter.string(from: Date())
        let appVersionFull = "itemserv \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown") (\(Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"))"
        let deviceName = UIDevice.current.name
        let deviceModel = UIDevice.current.modelIdentifier
        let systemVersion = UIDevice.current.systemVersion

        // Collect lists for meta
        let rooms = Set(boxes.compactMap { $0.room?.roomName }).sorted()
        let sectors = Set(boxes.compactMap { $0.sector?.sectorName }).sorted()
        let shelves = Set(boxes.compactMap { $0.shelf?.shelfName }).sorted()
        let boxTypes = Set(boxes.compactMap { $0.boxType?.boxTypeText }).sorted()
        let boxNames = boxes.map { $0.numberOrName }

        let metaDict: [String: Any] = [
            "exportedBy": appVersionFull,
            "exportedAt": exportDateString,
            "deviceName": deviceName,
            "deviceModel": deviceModel,
            "systemVersion": systemVersion,
            "totalLocations": boxes.count,
            "rooms": rooms,
            "sectors": sectors,
            "shelves": shelves,
            "boxNames": boxNames,
            "boxTypes": boxTypes
        ]

        // Write meta.json
        let metaJsonFileURL = exportFolderURL.appendingPathComponent("meta.json")
        do {
            let metaJsonData = try JSONSerialization.data(withJSONObject: metaDict, options: [.prettyPrinted])
            try metaJsonData.write(to: metaJsonFileURL, options: .atomic)
        } catch {
            return
        }

        // Generate meta.tsv
        var metaTsvLines: [String] = []
        metaTsvLines.append("exportedBy\t\(appVersionFull)")
        metaTsvLines.append("exportedAt\t\(exportDateString)")
        metaTsvLines.append("deviceName\t\(deviceName)")
        metaTsvLines.append("deviceModel\t\(deviceModel)")
        metaTsvLines.append("systemVersion\t\(systemVersion)")
        metaTsvLines.append("totalLocations\t\(boxes.count)")

        func appendList(_ title: String, items: [String]) {
            metaTsvLines.append("\(title)\t")
            for item in items {
                metaTsvLines.append("\t\(item)")
            }
        }
        appendList("rooms", items: rooms)
        appendList("sectors", items: sectors)
        appendList("shelves", items: shelves)
        appendList("boxNames", items: boxNames)
        appendList("boxTypes", items: boxTypes)

        let metaTsvContent = metaTsvLines.joined(separator: "\n")
        let metaTsvFileURL = exportFolderURL.appendingPathComponent("meta.tsv")
        do {
            try metaTsvContent.write(to: metaTsvFileURL, atomically: true, encoding: .utf8)
        } catch {
            return
        }

        // Create zip containing the export folder
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let dateString = dateFormatter.string(from: Date())
        let zipFileURL = tempDirectory.appendingPathComponent("locations_backup_\(dateString).zip")
        // Remove zip if exists
        try? fileManager.removeItem(at: zipFileURL)
        // Use FileManager's built-in zip API (iOS 16+)
        do {
            try fileManager.zipItem(at: exportFolderURL, to: zipFileURL, shouldKeepParent: false)
        } catch {
            return
        }

        // Present the share sheet to export the zip file
        let activityVC = UIActivityViewController(activityItems: [zipFileURL], applicationActivities: nil)
        // Find the top view controller to present
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootVC = windowScene.windows.first?.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    // MARK: - Import
    private func importLocations(from url: URL) {
        // Parse meta.json from the zip file to extract info and show confirmation dialog
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let unzipFolderURL = tempDirectory.appendingPathComponent("locations_import", isDirectory: true)

        do {
            // Clean up any previous import folder
            if fileManager.fileExists(atPath: unzipFolderURL.path) {
                try fileManager.removeItem(at: unzipFolderURL)
            }
            try fileManager.createDirectory(at: unzipFolderURL, withIntermediateDirectories: true)

            // Unzip the file to the import folder
            try fileManager.unzipItem(at: url, to: unzipFolderURL)

            // Read meta.json
            let metaJsonURL = unzipFolderURL.appendingPathComponent("meta.json")
            let metaData = try Data(contentsOf: metaJsonURL)
            let jsonObject = try JSONSerialization.jsonObject(with: metaData, options: [])
            if let metaDict = jsonObject as? [String: Any] {
                // Show loading spinner then meta confirmation UI
                DispatchQueue.main.async {
                    self.isLoadingImport = true
                    self.showImportConfirmation = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.pendingImportMeta = metaDict
                    self.isLoadingImport = false
                }
            } else {
                DispatchQueue.main.async {
                    self.importResultMessage = "Invalid meta.json format."
                    self.showImportResult = true
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.importResultMessage = "Failed to import: \(error.localizedDescription)"
                self.showImportResult = true
            }
        }
    }

    private func proceedWithImport() {
        // This function performs the actual import after user confirmation
        guard let meta = pendingImportMeta else { return }
        let fileManager = FileManager.default
        let tempDirectory = fileManager.temporaryDirectory
        let unzipFolderURL = tempDirectory.appendingPathComponent("locations_import", isDirectory: true)

        // Read locations.json
        let locationsJsonURL = unzipFolderURL.appendingPathComponent("locations.json")
        do {
            let data = try Data(contentsOf: locationsJsonURL)
            struct ImportBox: Codable {
                let numberOrName: String
                let room: String
                let sector: String
                let shelf: String
                let boxType: String
            }
            let decoder = JSONDecoder()
            let importedBoxes = try decoder.decode([ImportBox].self, from: data)

            // Before importing, delete existing boxes? (optional)
            for box in boxes {
                modelContext.delete(box)
            }

            // Import related entities maps to avoid duplicates
            var roomMap: [String: Room] = [:]
            var sectorMap: [String: Sector] = [:]
            var shelfMap: [String: Shelf] = [:]
            var boxTypeMap: [String: BoxType] = [:]

            // Helper to get or create Room
            func getOrCreateRoom(named name: String) -> Room {
                if let existing = roomMap[name] {
                    return existing
                }
                let newRoom = Room(roomName: name)
                modelContext.insert(newRoom)
                roomMap[name] = newRoom
                return newRoom
            }
            // Helper to get or create Sector
            func getOrCreateSector(named name: String) -> Sector {
                if let existing = sectorMap[name] {
                    return existing
                }
                let newSector = Sector(sectorName: name)
                modelContext.insert(newSector)
                sectorMap[name] = newSector
                return newSector
            }
            // Helper to get or create Shelf
            func getOrCreateShelf(named name: String) -> Shelf {
                if let existing = shelfMap[name] {
                    return existing
                }
                let newShelf = Shelf(shelfName: name)
                modelContext.insert(newShelf)
                shelfMap[name] = newShelf
                return newShelf
            }
            // Helper to get or create BoxType
            func getOrCreateBoxType(named name: String) -> BoxType {
                if let existing = boxTypeMap[name] {
                    return existing
                }
                let newBoxType = BoxType(boxTypeText: name)
                modelContext.insert(newBoxType)
                boxTypeMap[name] = newBoxType
                return newBoxType
            }

            // Insert boxes (handle incomplete location info)
            for impBox in importedBoxes {
                let box = Box(numberOrName: impBox.numberOrName)
                if !impBox.room.isEmpty { box.room = getOrCreateRoom(named: impBox.room) }
                if !impBox.sector.isEmpty { box.sector = getOrCreateSector(named: impBox.sector) }
                if !impBox.shelf.isEmpty { box.shelf = getOrCreateShelf(named: impBox.shelf) }
                if !impBox.boxType.isEmpty { box.boxType = getOrCreateBoxType(named: impBox.boxType) }
                modelContext.insert(box)
            }

            // Removed automatic creation of "Unboxed" box to respect import data
            // Now, "Unboxed" will only exist if included in the imported locations.json

            try modelContext.save()
            importResultMessage = "Import successful."
        } catch {
            importResultMessage = "Import failed: \(error.localizedDescription)"
        }
        showImportResult = true
        pendingImportMeta = nil
    }
}

#Preview {
    ManageLocationsView()
        .modelContainer(for: [Box.self, Room.self, Sector.self, Shelf.self, BoxType.self])
}

#if canImport(UIKit)
import UIKit
#endif

// Helper extension for device model identifier
#if canImport(UIKit)
extension UIDevice {
    var modelIdentifier: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}
#endif
