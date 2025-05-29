import SwiftUI
import SwiftData
import CoreData
import SQLite3

// MARK: - Vacuum Extension for Core Data
extension NSManagedObjectContext {
    func vacuumIfNeeded() {
        guard let coordinator = persistentStoreCoordinator,
              let storeURL = coordinator.persistentStores.first?.url else { return }

        var db: OpaquePointer?
        if sqlite3_open(storeURL.path, &db) == SQLITE_OK {
            defer { sqlite3_close(db) }
            if sqlite3_exec(db, "VACUUM;", nil, nil, nil) == SQLITE_OK {
                print("🧹 Vacuum successful")
            } else {
                print("⚠️ Vacuum failed")
            }
        }
    }
}

// MARK: - Main Tab View
struct AppTabView: View {
    @State private var selection = 0

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                ItemListView()
            }
            .tabItem {
                Label("Items", systemImage: "archivebox")
            }
            .tag(0)

            NavigationStack {
                BoxLinkedItemsView()
            }
            .tabItem {
                Label("Boxes", systemImage: "shippingbox")
            }
            .tag(1)

            NavigationStack {
                AdminPanelView()
            }
            .tabItem {
                Label("Admin", systemImage: "gearshape")
            }
            .tag(2)
        }
        .tint(.blue)
        .animation(.easeInOut, value: selection)
        .debugVacuumIfNeeded()
    }
}

// MARK: - Debug Vacuum Trigger
#if DEBUG
extension AppTabView {
    private func triggerDebugVacuum(context: ModelContext) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            let nsContext = context.container.mainContext as? NSManagedObjectContext
            nsContext?.vacuumIfNeeded()
            print("✅ Vacuum complete (DEBUG mode)")
        }
    }
}
#endif

// MARK: - Debug Modifier
struct DebugVacuumModifier: ViewModifier {
    @Environment(\.modelContext) private var context

    func body(content: Content) -> some View {
        #if DEBUG
        content.onAppear {
            print("✅ Running in DEBUG mode")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                let nsContext = context.container.mainContext as? NSManagedObjectContext
                nsContext?.vacuumIfNeeded()
            }
        }
        #else
        content
        #endif
    }
}

// MARK: - View Extension
extension View {
    func debugVacuumIfNeeded() -> some View {
        self.modifier(DebugVacuumModifier())
    }
}

#Preview {
    AppTabView()
}
