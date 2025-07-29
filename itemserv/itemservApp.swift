import SwiftUI
import SwiftData
import CloudKit

let sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Item.self,
        Category.self,
        Room.self,
        Sector.self,
        Shelf.self,
        Box.self,
        BoxType.self
    ])
    
    let config = ModelConfiguration(
        schema: schema,
        cloudKitDatabase: .private("iCloud.com.tonyyutaka.itemserv3")
    )
    do {
        return try ModelContainer(for: schema, configurations: [config])
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()

@main
struct itemservApp: App {
    init() {
        print("App launched.")
    }
    
    var body: some Scene {
        WindowGroup {
            AppTabView()
                .modelContainer(sharedModelContainer)
//                .task {
//                    let context = sharedModelContainer.mainContext
//                    let item = Item(name: "Test Zone")
//                    context.insert(item)
//                    try? context.save()
//
//                    let configName = context.container.configurations.first?.name ?? "nil"
//                    let dbType = String(describing: context.container.configurations.first?.cloudKitDatabase ?? .automatic)
//                    print("🧪 Created item with ID: \(item.id)")
//                    print("🧪 Container configuration: \(configName)")
//                    print("🧪 CloudKit DB type for inserted item: \(dbType)")
//                }
                .onOpenURL { url in
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }

                        if url.pathExtension.lowercased() == "csv" {
                            print("Opened CSV file: \(url.lastPathComponent)")
                            // Future enhancement: route this URL to an import handler
                        }
                    }
                }
                .task {
                    let startTime = Date()
                    let osVersion = ProcessInfo.processInfo.operatingSystemVersion
                    func log(_ message: String) {
                        let elapsed = Date().timeIntervalSince(startTime)
                        let prefix = String(format: "[+%.2fs]", elapsed)
                        print("\(prefix) \(message)")
                    }

                    log("🛠 iOS Version: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion)")
                    log("App version: \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] ?? "nil") (\(Bundle.main.infoDictionary?["CFBundleVersion"] ?? "nil"))")
                    log("🧩 CloudKit Config: \(sharedModelContainer.configurations.map { $0.name })")
                    if let firstConfig = sharedModelContainer.configurations.first {
                        let zoneName = firstConfig.name
                        log("📦 Declared SwiftData zone name: \(zoneName)")
                        if zoneName == "zonev3" {
                            log("✅ Shared zone name is configured as expected.")
                        } else if zoneName == "com.apple.coredata.cloudkit.zone" {
                            log("⚠️ Still using default zone. If running iOS 17 or earlier, this is expected.")
                        } else {
                            log("ℹ️ Active zone name: \(zoneName)")
                        }
                    }
                    log("🧩 CloudKit DB: \(String(describing: sharedModelContainer.configurations.first?.cloudKitDatabase))")
                    if let db = sharedModelContainer.configurations.first?.cloudKitDatabase {
                        switch String(describing: db) {
                        case String(describing: ModelConfiguration.CloudKitDatabase.private("iCloud.com.tonyyutaka.itemserv2")):
                            log("📦 CloudKit is configured for PRIVATE DB with container ID: iCloud.com.tonyyutaka.itemserv2")
                        case String(describing: ModelConfiguration.CloudKitDatabase.automatic):
                            log("📦 CloudKit is set to automatic mode.")
                        case String(describing: ModelConfiguration.CloudKitDatabase.none):
                            log("📦 CloudKit DB is explicitly set to none.")
                        default:
                            log("📦 CloudKit DB is set to an unknown or unsupported value.")
                        }
                    } else {
                        log("📦 CloudKit DB not configured.")
                    }
                    log("🔎 Container Configurations: \(sharedModelContainer.configurations)")
                    let context = sharedModelContainer.mainContext
                    log("🔎 Using context: \(context)")
                    log("🔎 Is context cloudKitEnabled? \(context.container.configurations.first?.cloudKitDatabase != nil)")
                    do {
                        let descriptor = FetchDescriptor<Item>()
                        let items = try context.fetch(descriptor)
                        var debugOutput: [String] = []
                        debugOutput.append("✅ App loaded with \(items.count) items.")
                        for item in items {
                            debugOutput.append("🔍 Item: \(item.name) | id: \(item.id)")
                        }
                        let emptyItems = items.filter {
                            $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            $0.itemDescription.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                            ($0.imageData == nil || $0.imageData?.isEmpty == true)
                        }
                        for item in emptyItems {
                            context.delete(item)
                        }

                        // Clean up empty Categories
                        let emptyCategories = try context.fetch(FetchDescriptor<Category>()).filter {
                            ($0.categoryName ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptyCategories.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptyCategories.count) empty categories on app launch.")

                        // Clean up empty Rooms
                        let emptyRooms = try context.fetch(FetchDescriptor<Room>()).filter {
                            $0.roomName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptyRooms.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptyRooms.count) empty rooms on app launch.")

                        // Clean up empty Sectors
                        let emptySectors = try context.fetch(FetchDescriptor<Sector>()).filter {
                            $0.sectorName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptySectors.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptySectors.count) empty sectors on app launch.")

                        // Clean up empty Shelves
                        let emptyShelves = try context.fetch(FetchDescriptor<Shelf>()).filter {
                            $0.shelfName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptyShelves.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptyShelves.count) empty shelves on app launch.")

                        // Clean up empty Boxes
                        let emptyBoxes = try context.fetch(FetchDescriptor<Box>()).filter {
                            $0.numberOrName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptyBoxes.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptyBoxes.count) empty boxes on app launch.")

                        // Clean up empty BoxTypes
                        let emptyBoxTypes = try context.fetch(FetchDescriptor<BoxType>()).filter {
                            $0.boxTypeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        }
                        emptyBoxTypes.forEach { context.delete($0) }
                        print("🧹 Deleted \(emptyBoxTypes.count) empty box types on app launch.")

                        try context.save()
                        print("🧹 Deleted \(emptyItems.count) empty items on app launch.")
                        
                    } catch {
                        print("⚠️ Failed to delete empty items: \(error)")
                    }
                }
        }
    }
}
