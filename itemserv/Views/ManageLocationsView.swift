import SwiftUI
import SwiftData

struct ManageLocationsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Box.numberOrName) private var boxes: [Box]
    @State private var isExporting = false
    @State private var isImporting = false
    @State private var importResultMessage: String?
    @State private var showImportResult = false

    var body: some View {
        // Split the view building into smaller computed properties to help the compiler
        contentView
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
            Section(header: Text("Locations")) {
                ForEach(boxes) { box in
                    locationRow(for: box)
                }
            }
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
            importLocations(from: url)
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

        let exportBoxes: [ExportBox] = boxes.compactMap { box in
            guard let room = box.room,
                  let sector = box.sector,
                  let shelf = box.shelf,
                  let boxType = box.boxType else {
                return nil
            }
            return ExportBox(
                numberOrName: box.numberOrName,
                room: room.roomName,
                sector: sector.sectorName,
                shelf: shelf.shelfName,
                boxType: boxType.boxTypeText
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

        // Generate meta.json
        let isoFormatter = ISO8601DateFormatter()
        let exportDateString = isoFormatter.string(from: Date())
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let schemaVersion = "v3"
        let metaDict: [String: Any] = [
            "exportType": "locations",
            "exportDate": exportDateString,
            "appVersion": appVersion,
            "schemaVersion": schemaVersion
        ]
        let metaJsonFileURL = exportFolderURL.appendingPathComponent("meta.json")
        do {
            let metaJsonData = try JSONSerialization.data(withJSONObject: metaDict, options: [.prettyPrinted])
            try metaJsonData.write(to: metaJsonFileURL, options: .atomic)
        } catch {
            return
        }

        // Generate meta.tsv
        let metaTsvLines = metaDict.map { key, value in
            "\(key)\t\(value)"
        }
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
        // TODO: Implement import logic for boxes (locations with room/sector/shelf/box type)
    }
}

#Preview {
    ManageLocationsView()
        .modelContainer(for: [Box.self, Room.self, Sector.self, Shelf.self, BoxType.self])
}
