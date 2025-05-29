import SwiftUI
import SwiftData

@main
struct itemservApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            Category.self,
            Room.self,
            Sector.self,
            Shelf.self,
            BoxName.self,
            BoxType.self
        ])
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .private("iCloud.com.tonyyuta.itemserv")
        )

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            AppTabView()
                .onOpenURL { url in
                    if url.startAccessingSecurityScopedResource() {
                        defer { url.stopAccessingSecurityScopedResource() }
                        
                        if url.pathExtension.lowercased() == "csv" {
                            print("Opened CSV file: \(url.lastPathComponent)")
                            // Future enhancement: route this URL to an import handler
                        }
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
