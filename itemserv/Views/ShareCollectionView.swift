import CloudKit
import SwiftUI
import SwiftData
import CoreData

private func isItemEmpty(_ item: Item) -> Bool {
    item.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    item.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    item.boxNameRef == nil &&
    item.boxTypeRef == nil &&
    item.room == nil &&
    item.sector == nil &&
    item.shelf == nil &&
    item.category == nil
}

struct ShareSnapshot {
    let items: [Item]
    let categories: [Category]
    let rooms: [Room]
    let sectors: [Sector]
    let shelves: [Shelf]
    let boxNames: [BoxName]
    let boxTypes: [BoxType]
}

func contextSnapshot(from context: ModelContext) throws -> ShareSnapshot {
    // Fetch all items, then filter out empty items before snapshot
    let nonEmptyItems = try context.fetch(FetchDescriptor<Item>()).filter {
        !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        !$0.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        $0.boxNameRef != nil ||
        $0.boxTypeRef != nil ||
        $0.room != nil ||
        $0.sector != nil ||
        $0.shelf != nil ||
        $0.category != nil
    }

    // Establish inverse relationships for shared records
    for item in nonEmptyItems {
        if let category = item.category {
            category.items?.append(item)
        }
        if let room = item.room {
            room.items?.append(item)
        }
        if let sector = item.sector {
            sector.items?.append(item)
        }
        if let shelf = item.shelf {
            shelf.items?.append(item)
        }
        if let boxName = item.boxNameRef {
            boxName.items?.append(item)
        }
        if let boxType = item.boxTypeRef {
            boxType.items?.append(item)
        }
    }
    try context.save()

    return ShareSnapshot(
        items: nonEmptyItems,
        categories: try context.fetch(FetchDescriptor<Category>()).filter {
            !($0.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        },
        rooms: try context.fetch(FetchDescriptor<Room>()).filter {
            !$0.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        },
        sectors: try context.fetch(FetchDescriptor<Sector>()).filter {
            !$0.sectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        },
        shelves: try context.fetch(FetchDescriptor<Shelf>()).filter {
            !$0.shelfName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        },
        boxNames: try context.fetch(FetchDescriptor<BoxName>()).filter {
            !$0.boxNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        },
        boxTypes: try context.fetch(FetchDescriptor<BoxType>()).filter {
            !$0.boxTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    )
}

struct ShareCollectionView: View {
    static let sharedContainer: ModelContainer = {
        do {
            let schema = Schema([
                Item.self,
                Category.self,
                Room.self,
                Sector.self,
                Shelf.self,
                BoxName.self,
                BoxType.self
            ])
            print("✅ Attempting to register schema with types: \(schema)")

            let configurations = [
                ModelConfiguration(
                    "zonev3",
                    schema: schema,
                    cloudKitDatabase: .private("iCloud.com.tonyyutaka.itemserv2")
                )
            ]
            return try ModelContainer(for: schema, configurations: configurations)
        } catch {
            fatalError("❌ Failed to create shared ModelContainer: \(error)")
        }
    }()

    static func cleanPlaceholderItemsOnLaunch() {
        let context = sharedContainer.mainContext
        let itemsToDelete = try? context.fetch(FetchDescriptor<Item>()).filter {
            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            $0.boxNameRef == nil &&
            $0.boxTypeRef == nil &&
            $0.room == nil &&
            $0.sector == nil &&
            $0.shelf == nil &&
            $0.category == nil
        }
        itemsToDelete?.forEach { context.delete($0) }
        try? context.save()
    }
    
    @Environment(\.modelContext) private var modelContext
    @State private var share: CKShare?
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @State private var shareURL: URL?

    var body: some View {
        VStack {
            errorSection(errorMessage)

            Button("Start Sharing") {
                Task { @MainActor in
                    do {
                        let sharedContext = ShareCollectionView.sharedContainer.mainContext
                        let itemsToDelete = try? sharedContext.fetch(FetchDescriptor<Item>()).filter { isItemEmpty($0) }
                        print("🧹 Deleting \(itemsToDelete?.count ?? 0) empty items before snapshot")
                        itemsToDelete?.forEach { sharedContext.delete($0) }
                        try? sharedContext.save()

                        let snapshot = try contextSnapshot(from: sharedContext)
                        print("📸 Snapshot contains \(snapshot.items.count) non-empty items")

                        let share = try await CloudKitSharingManager.shared.createShare(from: snapshot)
                        await MainActor.run {
                            self.share = share
                            self.shareURL = share.url
                            #if DEBUG
                            print("✅ Created share: \(String(describing: share))")
                            print("🔗 Share URL: \(share.url?.absoluteString ?? "nil")")
                            #endif
                        }
                    } catch {
                        await MainActor.run {
                            self.errorMessage = error.localizedDescription
                        }
                    }
                }
            }
            .padding()

            shareURLSection(shareURL)
        }
        .onAppear {
            Task {
                await performInitialSyncCleanup()
            }

            NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { notification in
                guard
                    let event = notification.userInfo?["event"] as? NSPersistentCloudKitContainer.Event,
                    event.type == .import,
                    event.endDate != nil,
                    event.succeeded
                else {
                    return
                }

                Task { @MainActor in
                    let context = modelContext
                    let itemsToDelete = try? context.fetch(FetchDescriptor<Item>()).filter { isItemEmpty($0) }
                    itemsToDelete?.forEach { context.delete($0) }
                    try? context.save()
                    print("🧽 Event-based post-sync cleanup removed \(itemsToDelete?.count ?? 0) empty items")
                }
            }
        }
        .sheet(isPresented: .constant(share != nil)) {
            if let share = share {
                CloudSharingView(share: share, container: CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2"))
            }
        }
        .navigationTitle("Share Collection")
    }

    private func performInitialSyncCleanup() async {
        let context = modelContext
        do {
            let fetchDesc = FetchDescriptor<Item>()
            let fetchedItems = try context.fetch(fetchDesc)
            let itemsToDelete = fetchedItems.filter { isItemEmpty($0) }
            itemsToDelete.forEach { context.delete($0) }
            try context.save()
        } catch {
            print("❌ Error during initial cleanup:", error.localizedDescription)
        }

        print("🧭 App launched in TestFlight build. Using container: iCloud.com.tonyyutaka.itemserv2")

        do {
            let status = try await CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2").accountStatus()
            print("🔍 CloudKit account status:", status.rawValue)

            Task {
                await checkForSharedZone()
            }
        } catch {
            print("❌ CloudKit error:", error.localizedDescription)
        }
    }

    private func checkForSharedZone() async {
        do {
            let container = CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2")
            let zones = try await container.privateCloudDatabase.allRecordZones()
            let sharedZoneExists = zones.contains { $0.zoneID.zoneName == "zonev3" }
            if !sharedZoneExists {
                print("⚠️ zonev3 missing after relaunch. CloudKit may be delivering stale state.")
            } else {
                print("✅ zonev3 found.")
            }
        } catch {
            print("❌ Failed to fetch zones:", error.localizedDescription)
        }
    }
}

@ViewBuilder
private func errorSection(_ errorMessage: String?) -> some View {
    if let errorMessage = errorMessage {
        Text("Error: \(errorMessage)")
            .foregroundColor(.red)
            .padding()
    }
}

@ViewBuilder
private func shareURLSection(_ shareURL: URL?) -> some View {
    if let shareURL = shareURL {
        VStack {
            Text("Share URL:")
                .font(.headline)
                .padding(.top)
            Text(shareURL.absoluteString)
                .font(.footnote)
                .foregroundColor(.blue)
                .multilineTextAlignment(.center)
                .padding()

            Button("Copy to Clipboard") {
                UIPasteboard.general.string = shareURL.absoluteString
            }
            .padding(.bottom)
        }
        .padding()
    }
}

struct CloudSharingView: UIViewControllerRepresentable {
    let share: CKShare
    let container: CKContainer

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController(share: share, container: container)
        controller.modalPresentationStyle = .formSheet
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}
}

extension CloudSharingView {
    class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func cloudSharingController(_ c: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("❌ Failed to save share:", error.localizedDescription)
        }

        func cloudSharingControllerDidSaveShare(_ c: UICloudSharingController) {
            print("✅ Share saved")
        }

        func cloudSharingControllerDidStopSharing(_ c: UICloudSharingController) {
            print("ℹ️ Sharing stopped")
        }

        func itemTitle(for c: UICloudSharingController) -> String? {
            return "Shared Collection"
        }

        func itemThumbnailData(for controller: UICloudSharingController) -> Data? {
            return nil
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator()
    }
}

// ShareMetadata is not used in manual CloudKit sharing. Consider removing or replacing with custom logic.



func buildCombinedSnapshot(from snapshot: ShareSnapshot) -> [any PersistentModel] {
    var combined: [any PersistentModel] = []
    combined.append(contentsOf: snapshot.items)
    combined.append(contentsOf: snapshot.categories)
    combined.append(contentsOf: snapshot.rooms)
    combined.append(contentsOf: snapshot.sectors)
    combined.append(contentsOf: snapshot.shelves)
    combined.append(contentsOf: snapshot.boxNames)
    combined.append(contentsOf: snapshot.boxTypes)
    return combined
}
class CloudKitSharingManager {
    static let shared = CloudKitSharingManager()
    static let sharedContainer = ShareCollectionView.sharedContainer

    static func recordID(for item: Item, in zone: CKRecordZone) -> CKRecord.ID {
        let name = item.id
        return CKRecord.ID(recordName: name, zoneID: zone.zoneID)
    }

    func createShare(from snapshot: ShareSnapshot) async throws -> CKShare {
        let container = CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2")
        let privateDB = container.privateCloudDatabase
        print("📦 Using container: \(container)")
        print("📂 Saving to zone: zonev3")

        // Step 1: Create and clean up zone
        let zone = CKRecordZone(zoneName: "zonev3")

        // Attempt to fetch all existing record IDs in the zone for deletion
        var existingRecordIDs: [CKRecord.ID] = []

        let config = CKFetchRecordZoneChangesOperation.ZoneConfiguration()
        let options = [zone.zoneID: config]
        let operation = CKFetchRecordZoneChangesOperation(recordZoneIDs: [zone.zoneID], configurationsByRecordZoneID: options)

        operation.recordWasChangedBlock = { recordID, result in
            switch result {
            case .success(let record):
                existingRecordIDs.append(record.recordID)
            case .failure(let error):
                print("⚠️ Failed to decode record \(recordID): \(error.localizedDescription)")
            }
        }
        operation.recordWithIDWasDeletedBlock = { recordID, _ in
            existingRecordIDs.append(recordID)
        }

        try await withCheckedThrowingContinuation { continuation in
            operation.fetchRecordZoneChangesResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
            privateDB.add(operation)
        }
        

        if !existingRecordIDs.isEmpty {
            try await withCheckedThrowingContinuation { continuation in
                let deleteOp = CKModifyRecordsOperation(recordsToSave: [], recordIDsToDelete: existingRecordIDs)
                deleteOp.savePolicy = .ifServerRecordUnchanged
                deleteOp.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDB.add(deleteOp)
            }
            print("🗑️ Deleted \(existingRecordIDs.count) old records in zonev3 before sharing.")
            // Wait briefly to ensure record deletions are processed before zone deletion
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }

        // Delete the zone itself to reset change tokens
        try? await withCheckedThrowingContinuation { continuation in
            privateDB.delete(withRecordZoneID: zone.zoneID) { _, _ in
                continuation.resume()
            }
        }

        // Recreate the zone
        try await privateDB.save(zone)

        var allRecords: [CKRecord] = []

        // Step 2: Convert each model type from snapshot
        let filteredItems = snapshot.items.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !$0.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredItems.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Item", recordID: recordID)
            record["name"] = $0.name as CKRecordValue
            record["itemDescription"] = $0.itemDescription as CKRecordValue
            return record
        }

        // Filter and map categories
        let filteredCategories = snapshot.categories.filter {
            !($0.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        }
        allRecords += filteredCategories.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Category", recordID: recordID)
            record["categoryName"] = ($0.categoryName ?? "") as CKRecordValue
            return record
        }

        // Filter and map rooms
        let filteredRooms = snapshot.rooms.filter {
            !$0.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredRooms.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Room", recordID: recordID)
            record["roomName"] = $0.roomName as CKRecordValue
            return record
        }

        // Filter and map sectors
        let filteredSectors = snapshot.sectors.filter {
            !$0.sectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredSectors.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Sector", recordID: recordID)
            record["sectorName"] = $0.sectorName as CKRecordValue
            return record
        }

        // Filter and map shelves
        let filteredShelves = snapshot.shelves.filter {
            !$0.shelfName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredShelves.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "Shelf", recordID: recordID)
            record["shelfName"] = $0.shelfName as CKRecordValue
            return record
        }

        // Filter and map boxNames
        let filteredBoxNames = snapshot.boxNames.filter {
            !$0.boxNameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredBoxNames.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "BoxName", recordID: recordID)
            record["boxNameText"] = $0.boxNameText as CKRecordValue
            return record
        }

        // Filter and map boxTypes
        let filteredBoxTypes = snapshot.boxTypes.filter {
            !$0.boxTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        allRecords += filteredBoxTypes.map {
            let recordID = CKRecord.ID(recordName: UUID().uuidString, zoneID: zone.zoneID)
            let record = CKRecord(recordType: "BoxType", recordID: recordID)
            record["boxTypeText"] = $0.boxTypeText as CKRecordValue
            return record
        }

        // Step 3: Create share record
        let rootCandidate = allRecords.first { record in
            guard record.recordType != "Item" else {
                let name = (record["name"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                return !name.isEmpty
            }
            return true
        }

        guard let rootRecord = rootCandidate else {
            throw NSError(domain: "ShareError", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable root record to share"])
        }
        let share = CKShare(rootRecord: rootRecord)
        // Assign parent references after share is created
        for record in allRecords where record.recordType != "cloudkit.share" {
            record["parent"] = CKRecord.Reference(record: share, action: .none)
        }
        share[CKShare.SystemFieldKey.title] = "Shared Collection" as CKRecordValue
        share.publicPermission = .none
        // Step 4: Save all records + share
        var recordsToSave = allRecords
        if let rootIndex = recordsToSave.firstIndex(where: { $0.recordID == rootRecord.recordID }) {
            recordsToSave.insert(share, at: rootIndex + 1)
        } else {
            recordsToSave.insert(share, at: 0)
        }

        // No need to delete placeholder records here; already deleted before snapshot.
        let batches = recordsToSave.chunked(into: 400)
        for batch in batches {
            try await withCheckedThrowingContinuation { continuation in
                let op = CKModifyRecordsOperation(
                    recordsToSave: batch,
                    recordIDsToDelete: []
                )
                op.savePolicy = .ifServerRecordUnchanged
                op.isAtomic = true
                op.modifyRecordsResultBlock = { result in
                    switch result {
                    case .success:
                        continuation.resume()
                    case .failure(let error):
                        continuation.resume(throwing: error)
                    }
                }
                privateDB.add(op)
            }
        }
        print("📤 Saving \(recordsToSave.count) CKRecords to CloudKit (including share).")
        return share
    }
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
