import SwiftUI
import SwiftData

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
        .modelContainer(sharedModelContainer)
        .tint(.blue)
        .animation(.easeInOut, value: selection)
        .overlay(alignment: .topLeading) {
            #if DEBUG
//                VersionBannerView()
            #endif
        }
    }
}

// MARK: - Debug Vacuum Trigger
#if DEBUG
extension AppTabView {
}
#endif

// MARK: - View Extension
extension View {
}

// MARK: - Version Info Display
struct VersionBannerView: View {
    var body: some View {
        if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
           let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String {
            Text("Version \(version) (\(build))")
                .font(.caption2)
                .foregroundColor(.gray)
                .padding(4)
        }
    }
}

#Preview {
    AppTabView()
        .modelContainer(sharedModelContainer)
}
