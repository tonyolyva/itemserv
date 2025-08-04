import SwiftUI
import SwiftData

struct LocationView: View {
    @Query(sort: \Box.numberOrName) private var boxes: [Box]
    @State private var selectedBox: Box?
    @State private var sortSelection: Int = 0
    @State private var showInfo: Bool = false

    var body: some View {
        NavigationStack {
            VStack {
                // Sorting and Info buttons
                HStack {
                    Picker("Sort", selection: $sortSelection) {
                        Text("Recent").tag(0)
                        Text("A → Z").tag(1)
                        Text("Z → A").tag(2)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: sortSelection) { oldValue, newValue in
                        handleSortChange()
                    }

                    Spacer()

                    Button(action: {
                        showInfo.toggle()
                        print("Info button tapped: \(showInfo)")
                    }) {
                        Image(systemName: "info.circle")
                            .imageScale(.large)
                    }
                }
                .padding(.horizontal)

                List {
                    ForEach(sortedBoxes()) { box in
                        Button {
                            selectedBox = box
                        } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
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
                                Spacer()
                                if showInfo {
                                    HStack(spacing: 4) {
                                        Text(prefixForBox(box))
                                        Text(relativeUpdateText(for: box))
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
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

    private func handleSortChange() {
        switch sortSelection {
        case 0:
            print("Sort changed to: Recent")
        case 1:
            print("Sort changed to: A → Z")
        case 2:
            print("Sort changed to: Z → A")
        default:
            break
        }
    }
    
    // MARK: - Sorting Logic
    private func sortedBoxes() -> [Box] {
        switch sortSelection {
        case 0: // Recent
            return boxes.sorted { effectiveActivityDate(for: $0) > effectiveActivityDate(for: $1) }
        case 1: // A → Z
            return boxes.sorted {
                if $0.numberOrName == "Unboxed" { return true }
                if $1.numberOrName == "Unboxed" { return false }
                let num0 = Int($0.numberOrName)
                let num1 = Int($1.numberOrName)
                if let n0 = num0, let n1 = num1 {
                    return n0 < n1
                }
                return $0.numberOrName.localizedCompare($1.numberOrName) == .orderedAscending
            }
        case 2: // Z → A
            return boxes.sorted {
                if $0.numberOrName == "Unboxed" { return true }
                if $1.numberOrName == "Unboxed" { return false }
                let num0 = Int($0.numberOrName)
                let num1 = Int($1.numberOrName)
                if let n0 = num0, let n1 = num1 {
                    return n0 > n1
                }
                return $0.numberOrName.localizedCompare($1.numberOrName) == .orderedDescending
            }
        default:
            return boxes
        }
    }
    
    private func effectiveActivityDate(for box: Box) -> Date {
        let itemsArray = Array(box.items ?? [])
        let itemActivityDate = itemsArray.map { $0.dateAdded }.max() ?? .distantPast
        let effectiveDate = max(box.lastModified, itemActivityDate)
        print("Effective date for box \(box.numberOrName): \(effectiveDate)")
        return effectiveDate
    }

    private func prefixForBox(_ box: Box) -> String {
        let activityDate = effectiveActivityDate(for: box)
        return activityDate == box.dateAdded ? "🆕" : "✏️"
    }

    private func relativeUpdateText(for box: Box) -> String {
        let referenceDate = effectiveActivityDate(for: box)
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: referenceDate, relativeTo: Date())
    }
}

    private func handleBoxUpdate(_ box: Box) {
        print("Box \(box.numberOrName) was updated. lastModified: \(box.lastModified)")
    }
