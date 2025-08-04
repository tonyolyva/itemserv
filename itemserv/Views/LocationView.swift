import SwiftUI
import SwiftData

struct LocationView: View {
    @Query(sort: \Box.numberOrName) private var boxes: [Box]
    @State private var selectedBox: Box?
    @State private var sortSelection: Int = 0
    @State private var showInfo: Bool = false
    @State private var searchText: String = ""
    @State private var selectedFilter: BoxFilter = .all

    var body: some View {
        NavigationStack {
            VStack {
                // Search field
                HStack {
                    TextField("Search Boxes", text: $searchText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }

// Moved Filter buttons under Sort buttons line

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

                // Use segmented picker style for filters similar to BoxLinkedItemsView
                Picker("Filter Boxes", selection: $selectedFilter) {
                    Text("All Boxes").tag(BoxFilter.all)
                    Text("Unboxed").tag(BoxFilter.unboxed)
                    Text("Exclude Empty").tag(BoxFilter.excludeEmpty)
                    Text("Empty Only").tag(BoxFilter.emptyOnly)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 4)

                List {
                    ForEach(filteredBoxes()) { box in
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
    
    // MARK: - Filtering Logic
    private func filteredBoxes() -> [Box] {
        var filtered = boxes.filter { box in
            searchText.isEmpty || box.numberOrName.localizedCaseInsensitiveContains(searchText)
        }
        
        switch selectedFilter {
        case .all:
            break
        case .unboxed:
            filtered = filtered.filter { $0.numberOrName == "Unboxed" }
        case .excludeEmpty:
            filtered = filtered.filter { !($0.items?.isEmpty ?? true) }
        case .emptyOnly:
            filtered = filtered.filter { $0.items?.isEmpty ?? true }
        }
        
        switch sortSelection {
        case 0:
            return filtered.sorted { effectiveActivityDate(for: $0) > effectiveActivityDate(for: $1) }
        case 1:
            return filtered.sorted {
                if $0.numberOrName == "Unboxed" { return true }
                if $1.numberOrName == "Unboxed" { return false }
                let num0 = Int($0.numberOrName)
                let num1 = Int($1.numberOrName)
                if let n0 = num0, let n1 = num1 {
                    return n0 < n1
                }
                return $0.numberOrName.localizedCompare($1.numberOrName) == .orderedAscending
            }
        case 2:
            return filtered.sorted {
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
            return filtered
        }
    }
}

private func handleBoxUpdate(_ box: Box) {
    print("Box \(box.numberOrName) was updated. lastModified: \(box.lastModified)")
}

enum BoxFilter {
    case all
    case unboxed
    case excludeEmpty
    case emptyOnly
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .lineLimit(1) // Limit text to one line
                .truncationMode(.tail) // Add ellipsis if text doesn't fit
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                .foregroundColor(isSelected ? .primary : .secondary)
                .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 0) // Removed extra horizontal gaps between buttons
        .frame(maxWidth: .infinity, alignment: .leading) // Stretch buttons block to fill width without right padding
    }
}
