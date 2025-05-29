import SwiftUI
import SwiftData

struct AdminPanelView: View {
    var body: some View {
        NavigationStack {
            List {
                NavigationLink("Manage Categories", destination: ManageCategoriesView())
                NavigationLink("Manage Rooms", destination: ManageRoomsView())
                NavigationLink("Manage Sectors", destination: ManageSectorsView())
                NavigationLink("Manage Shelves", destination: ManageShelvesView())
                NavigationLink("Manage Box Names", destination: ManageBoxNamesView())
                NavigationLink("Manage Box Types", destination: ManageBoxTypesView())
                NavigationLink("Manage Items", destination: ManageItemsView())
            }
            .navigationTitle("Admin Panel")
        }
    }
}

#Preview {
    AdminPanelView()
}
