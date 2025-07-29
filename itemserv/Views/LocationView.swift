import SwiftUI
import SwiftData

struct LocationView: View {
    @Query(sort: \Box.numberOrName) private var boxes: [Box]
    @State private var selectedBox: Box?

    var body: some View {
        NavigationStack {
            List {
                ForEach(boxes) { box in
                    Button {
                        selectedBox = box
                    } label: {
                        VStack(alignment: .leading) {
                            Text("📦 \(box.numberOrName)")
                                .font(.headline)
                            if let room = box.room?.roomName,
                               let sector = box.sector?.sectorName,
                               let shelf = box.shelf?.shelfName,
                               let boxType = box.boxType?.boxTypeText {
                                Text("\(room) / \(sector) / \(shelf) • \(boxType)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Location not set")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Manage Location")
            .sheet(item: $selectedBox) { box in
                EditBoxLocationView(box: box)
            }
        }
    }
}

#Preview {
    LocationView()
        .modelContainer(sharedModelContainer)
}
