import SwiftUI
import SwiftData

struct AdminPanelView: View {
    @State private var showFallbackLog = false
    @State private var fallbackLogText = ""

    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Manage Categories", destination: ManageCategoriesView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Rooms", destination: ManageRoomsView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Sectors", destination: ManageSectorsView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Shelves", destination: ManageShelvesView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Boxes", destination: ManageBoxesView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Box Types", destination: ManageBoxTypesView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Items", destination: ManageItemsView().modelContext(sharedModelContainer.mainContext))
                NavigationLink("Manage Locations", destination: ManageLocationsView().modelContext(sharedModelContainer.mainContext))
//                NavigationLink("Share Collection", destination: ShareCollectionView())
//                NavigationLink("Manage Sync", destination: ManageSyncView().modelContext(sharedModelContainer.mainContext))
            }
            .navigationTitle("Admin Panel")
        }

    }
}

#Preview {
    AdminPanelView()
        .modelContainer(sharedModelContainer)
}
