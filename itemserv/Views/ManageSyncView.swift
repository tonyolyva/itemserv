import CoreData
import SwiftUI
import SwiftData
import CloudKit
import UIKit

struct ManageSyncView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var cloudKitZones: [String] = []
    @State private var debugOutput: [String] = []
    @State private var cloudKitEvents: [String] = []
    @State private var buttonTapFlow: [String] = []
    @State private var showFallbackLog = false
    @State private var fallbackLogText = ""
    
    var body: some View {
        Form {
            Section(header: Text("Developer Tools").font(.body)) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("🔢 Tap Flow:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    ForEach(buttonTapFlow.indices, id: \.self) { index in
                        Text("• \(index + 1). \(buttonTapFlow[index])")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                Button("Debug Sync") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Debug Sync’")
                        await debugSync()
                    }
                }
                .foregroundColor(.blue)

                Button("Check CloudKit Zones") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Check CloudKit Zones’")
                        await checkCloudKitZones()
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Trigger CloudKit Sync") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Trigger CloudKit Sync’")
                        do {
                            try modelContext.save()
                            debugOutput.append("✅ Triggered modelContext.save() successfully.")
                        } catch {
                            debugOutput.append("❌ Error during modelContext.save(): \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Force CloudKit Push") {
                    buttonTapFlow.append("Tapped ‘Force CloudKit Push’")
                    NotificationCenter.default.post(name: .NSPersistentStoreRemoteChange, object: nil)
                    debugOutput.append("📤 Posted .NSPersistentStoreRemoteChange notification to trigger CloudKit push.")
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Trigger CloudKit Upload") {
                    buttonTapFlow.append("Tapped ‘Trigger CloudKit Upload’")
                    do {
                        let context = sharedModelContainer.mainContext
                        try context.save()
                        debugOutput.append("📤 Saved context from sharedModelContainer (zone: \(context.container.configurations.first?.name ?? "?"))")
                    } catch {
                        debugOutput.append("❌ Failed to save shared context: \(error)")
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Check Model Configuration") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Check Model Configuration’")
                        let config = modelContext.container.configurations.first
                        var summary: [String] = []
                        summary.append("🧩 Model Configuration Info:")
                        summary.append("• Configuration name: \(config?.name ?? "(none)")")
                        if let db = config?.cloudKitDatabase {
                            summary.append("• CloudKit DB: \(db)")
                        } else {
                            summary.append("• CloudKit DB: not configured")
                        }
                        debugOutput.append(contentsOf: summary)
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Force Touch Items") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Force Touch Items’")
                        do {
                            let items = try modelContext.fetch(FetchDescriptor<Item>())
                            let now = Date()
                            for item in items {
                                item.dateAdded = now
                            }
                            try modelContext.save()
                            debugOutput.append("✅ Force-touched \(items.count) items and saved.")
                        } catch {
                            debugOutput.append("❌ Error force-touching items: \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Nudge All Items for CloudKit") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Nudge All Items for CloudKit’")
                        do {
                            let items = try modelContext.fetch(FetchDescriptor<Item>())
                            for item in items {
                                item.name += " "  // Append space to mark as dirty
                            }
                            try modelContext.save()
                            debugOutput.append("✅ Nudged and saved \(items.count) items for CloudKit sync.")
                        } catch {
                            debugOutput.append("❌ Failed to nudge items: \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Export to CloudKit") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Export to CloudKit’")
                        // retain original implementation
                        do {
                            try modelContext.save()
                            debugOutput.append("📤 modelContext.save() triggered.")
                            debugOutput.append("🕒 Waiting to allow CloudKit to process export…")
                            try await Task.sleep(nanoseconds: 3 * 1_000_000_000)

                            let container = CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2")
                            let privateDB = container.privateCloudDatabase
                            let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))
                            // Ensure zonev3 exists before querying
                            let zoneID = CKRecordZone.ID(zoneName: "zonev3", ownerName: CKCurrentUserDefaultName)
                            let existingZoneIDs = try await privateDB.allRecordZones().map { $0.zoneID }
                            if !existingZoneIDs.contains(zoneID) {
                                let newZone = CKRecordZone(zoneID: zoneID)
                                try await privateDB.save(newZone)
                                debugOutput.append("🆕 Created missing CloudKit zone: zonev3")
                            }

                            debugOutput.append("🧾 Attempting CloudKit query with recordType: 'CD_Item' in zone: zonev3")
                            let allZones = try await privateDB.allRecordZones()
                            debugOutput.append("📂 Available zones: \(allZones.map { $0.zoneID.zoneName }.joined(separator: ", "))")

                            do {
                                let (matchResults, _) = try await privateDB.records(matching: query, inZoneWith: zoneID)
                                debugOutput.append("🔎 Queried CloudKit: found \(matchResults.count) Item records in zonev3.")
                                for (recordID, result) in matchResults {
                                    switch result {
                                    case .success(let record):
                                        if let name = record["name"] as? String {
                                            debugOutput.append("📦 CK Item: \(name)")
                                        } else {
                                            debugOutput.append("📦 CK Item (no name field): \(recordID.recordName)")
                                        }
                                    case .failure(let error):
                                        debugOutput.append("❌ Error fetching record \(recordID): \(error)")
                                    }
                                }
                            } catch {
                                debugOutput.append("❌ Error querying CloudKit after export: \(error)")
                            }

                            debugOutput.append("🔍 Export may still be queued. Check Dashboard after some delay.")
                        } catch {
                            debugOutput.append("❌ Error exporting to CloudKit: \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Check Syncing Stores") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Check Syncing Stores’")
                        if let container = modelContext.container.configurations.first {
                            debugOutput.append("🧩 Config Name: \(container.name)")
                            debugOutput.append("🔗 CloudKit DB: \(String(describing: container.cloudKitDatabase))")
                        } else {
                            debugOutput.append("⚠️ No container configuration found.")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Show CloudKit Sync Events") {
                    buttonTapFlow.append("Tapped ‘Show CloudKit Sync Events’")
                    NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { notification in
                        if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] {
                            cloudKitEvents.append("🗓️ Sync Event: \(event)")
                        } else {
                            cloudKitEvents.append("🗓️ Sync Event: (no event info)")
                        }
                    }
                    debugOutput.append("ℹ️ Started observing CloudKit sync events.")
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Create Item in zonev3") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Create Item in zonev3’")
                        let context = sharedModelContainer.mainContext
                        let item = Item()
//                        item.name = "Trigger Item"
                        item.name = "Trigger Item \(UUID().uuidString.prefix(4))"
                        context.insert(item)
                        do {
                            try context.save()
                            debugOutput.append("✅ Inserted and saved a new Item into zonev3 to force zone creation.")
                        } catch {
                            debugOutput.append("❌ Failed to save new Item: \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Export Debug Output") {
                    buttonTapFlow.append("Tapped ‘Export Debug Output’")
                    exportDebugOutput()
                }
                .foregroundColor(.blue)
                .font(.body)

                Button("Migrate Items to CloudKit") {
                    Task {
                        buttonTapFlow.append("Tapped ‘Migrate Items to CloudKit’")
                        // retain original implementation
                        do {
                            let oldItems = try modelContext.fetch(FetchDescriptor<Item>())
                            let context = sharedModelContainer.mainContext
                            let existingItems = try context.fetch(FetchDescriptor<Item>())
                            let existingIDs = Set(existingItems.map { $0.id })

                            debugOutput.append("🧩 Context configuration: \(context.container.configurations.first?.name ?? "(none)")")
                            debugOutput.append("🔍 Inserting \(oldItems.count) items into shared context…")
                            for old in oldItems where !existingIDs.contains(old.id) {
                                debugOutput.append("📦 Migrating Item: \(old.name) [\(old.id)]")
                            }

                            for old in oldItems where !existingIDs.contains(old.id) {
                                let migrated = Item()
                                context.insert(migrated)
                                migrated.id = old.id
                                migrated.name = old.name
                                migrated.name += " " // trigger CloudKit sync by marking as dirty
                                debugOutput.append("✏️ Nudged name to trigger sync: \(migrated.name)")
                                migrated.itemDescription = old.itemDescription
                                migrated.imageData = old.imageData
                                migrated.dateAdded = old.dateAdded
                                migrated.barcodeValue = old.barcodeValue
                                migrated.category = old.category
                                migrated.box = old.box
                            }
                            try context.save()
                            debugOutput.append("💾 context.save() succeeded after migration.")
                            try await Task.sleep(nanoseconds: 3_000_000_000)
                            debugOutput.append("📡 Save complete. Waiting for CloudKit to reflect changes…")
                            debugOutput.append("⏱️ Waited 3 seconds after save to allow CloudKit to sync.")
                            debugOutput.append("✅ Migrated \(oldItems.count) items into CloudKit-bound context (skipped already-migrated items).")
                        } catch {
                            debugOutput.append("❌ Error saving migrated items: \(error)")
                            debugOutput.append("❌ Error migrating items to CloudKit context: \(error)")
                        }
                    }
                }
                .foregroundColor(.blue)
                .font(.body)
            }
            if !cloudKitZones.isEmpty {
                Section("CloudKit Zones") {
                    ForEach(cloudKitZones, id: \.self) { zone in
                        Text(zone)
                    }
                }
            }
            if !debugOutput.isEmpty {
                Section("Debug Output") {
                    ForEach(debugOutput, id: \.self) { line in
                        Text(line)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
            }
            if !cloudKitEvents.isEmpty {
                Section("Sync Events") {
                    ForEach(cloudKitEvents.reversed(), id: \.self) { raw in
                        let string = raw
                        if string.contains("NSPersistentCloudKitContainerEvent") {
                            let isImport = string.contains("type: Import")
                            let isSuccess = string.contains("succeeded: YES")
                            let start = string.components(separatedBy: "started: ").last?.components(separatedBy: " ").first ?? "?"
                            let end = string.contains("ended: (null)") ? "…" : string.components(separatedBy: "ended: ").last?.components(separatedBy: " ").first ?? "?"

                            VStack(alignment: .leading, spacing: 4) {
                                Text(isImport ? "📥 Import" : "📤 Export")
                                    .font(.subheadline)
                                    .bold()
                                Text(isSuccess ? "✅ Succeeded" : "❌ Failed")
                                    .font(.footnote)
                                    .foregroundColor(isSuccess ? .green : .red)
                                Text("🕐 Started: \(start)")
                                    .font(.footnote)
                                Text("🛑 Ended: \(end)")
                                    .font(.footnote)
                            }
                            .padding(.vertical, 4)
                        } else {
                            Text(string)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("Manage Sync")
        .onAppear {
            NotificationCenter.default.addObserver(forName: NSPersistentCloudKitContainer.eventChangedNotification, object: nil, queue: .main) { notification in
                if let event = notification.userInfo?[NSPersistentCloudKitContainer.eventNotificationUserInfoKey] {
                    debugOutput.append("🛰️ CloudKit Sync Event: \(event)")
                } else {
                    debugOutput.append("🛰️ CloudKit Sync Event: (no event info)")
                }
            }
            debugOutput.append("📡 Listening for CloudKit sync events (onAppear).")
        }
        .sheet(isPresented: $showFallbackLog) {
            NavigationStack {
                TextEditor(text: $fallbackLogText)
                    .navigationTitle("Debug Output")
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") {
                                showFallbackLog = false
                            }
                        }
                    }
            }
        }
    }
    
    func debugSync() async {
        do {
            debugOutput.removeAll()
            let dateString = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium)
            debugOutput.append("───────────────")
            debugOutput.append("🕒 Debug Sync @ \(dateString)")
            let items = try modelContext.fetch(FetchDescriptor<Item>())
            debugOutput.append("🧮 Total Items in SwiftData: \(items.count)")
            debugOutput.append("🧵 modelContext container configuration: \(modelContext.container.configurations.first?.name ?? "(none)")")
            for item in items {
                debugOutput.append("📦 Item: \(item.name) (id: \(item.id))")
                debugOutput.append("🕓 dateAdded: \(item.dateAdded.formatted())")
            }

            let container = CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2")
            let privateDB = container.privateCloudDatabase
            let query = CKQuery(recordType: "CD_Item", predicate: NSPredicate(value: true))

            do {
                let (matchResults, _) = try await privateDB.records(matching: query, inZoneWith: CKRecordZone.ID(zoneName: "zonev3", ownerName: CKCurrentUserDefaultName))
                debugOutput.append("☁️ CloudKit Item records in zonev3: \(matchResults.count)")
            } catch {
                debugOutput.append("❌ Error querying CloudKit items: \(error)")
            }

            debugOutput.append("ℹ️ CloudKit configuration check not available in this context.")
            debugOutput.append("✅ Debug sync complete.")
        } catch {
            debugOutput.append("❌ Error during Debug Sync diagnostics: \(error)")
        }
    }
    
    func checkCloudKitZones() async {
        let container = CKContainer(identifier: "iCloud.com.tonyyutaka.itemserv2")
        let privateDB = container.privateCloudDatabase
        
        do {
            let zones = try await privateDB.allRecordZones()
            cloudKitZones = zones.map { $0.zoneID.zoneName }
            debugOutput.append("📂 Retrieved CloudKit zones:")
            for zone in cloudKitZones {
                debugOutput.append("🔹 \(zone)")
            }
            debugOutput.append("✅ Zone check complete.")
        } catch {
            debugOutput.append("❌ Error fetching CloudKit zones: \(error)")
        }
    }
    func exportDebugOutput() {
        let output = (self.debugOutput + self.cloudKitEvents).joined(separator: "\n")
        let cacheURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("debug_output.txt")
        do {
            try output.write(to: cacheURL, atomically: true, encoding: .utf8)
            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = scene.windows.first?.rootViewController {
                let av = UIActivityViewController(activityItems: [cacheURL], applicationActivities: nil)
                rootVC.present(av, animated: true)
            }
        } catch {
            self.fallbackLogText = output
            self.showFallbackLog = true
        }
    }
}

