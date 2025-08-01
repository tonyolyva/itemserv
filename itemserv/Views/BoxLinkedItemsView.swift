import SwiftUI
import SwiftData
import AudioToolbox

struct BoxLinkedItemsView: View {
    @Namespace private var scrollAnchor
    @Environment(\.modelContext) private var context
    @Query private var boxes: [Box]
    
    @State private var newBox: String = ""
    @State private var searchText: String = ""
    enum SortSelection: String, CaseIterable, Identifiable {
        case recent = "Recent"
        case az = "A → Z"
        case za = "Z → A"
        var id: String { rawValue }
    }
    @State private var sortSelection: SortSelection = .recent
    @State private var boxToDelete: Box?
    
    @State private var expandedBoxes: [PersistentIdentifier: Bool] = [:]
    @State private var filterSelection: FilterSelection = .allBoxes
    @State private var isShowingScanner = false
    @State private var scrollToBoxID: PersistentIdentifier?
    @State private var showingSortInfo: Bool = false
    
    enum FilterSelection: String, CaseIterable, Identifiable {
        case allBoxes = "All Boxes"
        case onlyUnboxed = "Unboxed"
        case excludeEmptyBoxes = "Exclude Empty"
        case emptyBoxesOnly = "Empty Only"
        
        var id: String { rawValue }
    }
    
    private var sortedBoxes: [Box] {
        let allBoxes = boxes // Include Unboxed naturally
        
        var sorted: [Box] = []
        switch sortSelection {
        case .recent:
            // Sort all boxes (including Unboxed) by latest activity
            sorted = allBoxes.sorted {
                let aDate = $0.items?.compactMap { item in max(item.lastUpdated, item.dateAdded) }.max() ?? .distantPast
                let bDate = $1.items?.compactMap { item in max(item.lastUpdated, item.dateAdded) }.max() ?? .distantPast
                return aDate > bDate
            }
        case .az:
            sorted = allBoxes.sorted { $0.numberOrName.localizedStandardCompare($1.numberOrName) == .orderedAscending }
        case .za:
            sorted = allBoxes.sorted { $0.numberOrName.localizedStandardCompare($1.numberOrName) == .orderedDescending }
        }
        
        // For A→Z/Z→A only: stick Unboxed at top
        if sortSelection != .recent,
           let unboxedIndex = sorted.firstIndex(where: { $0.numberOrName == "Unboxed" }) {
            let unboxed = sorted.remove(at: unboxedIndex)
            sorted.insert(unboxed, at: 0)
        }
        
        return sorted
    }
    
    // MARK: - Virtual "Unboxed" Items (for future use)
    private var virtualUnboxedItems: [Item] {
        boxes.flatMap { ($0.items ?? []).filter { $0.box?.numberOrName == "Unboxed" } }
    }

    private var filteredBoxes: [Box] {
        var seen = Set<String>()
        var deduped = sortedBoxes.filter { seen.insert($0.numberOrName).inserted }

        if searchText.trimmed().isEmpty == false {
            deduped = deduped.filter { $0.numberOrName.localizedCaseInsensitiveContains(searchText) }
        }

        switch filterSelection {
        case .allBoxes:
            break
        case .onlyUnboxed:
            deduped = []
            if let realUnboxed = boxes.first(where: { $0.numberOrName == "Unboxed" }) {
                deduped.append(realUnboxed)
            }
        case .excludeEmptyBoxes:
            deduped = deduped.filter { ($0.items?.isEmpty == false) }
        case .emptyBoxesOnly:
            deduped = deduped.filter { ($0.items?.isEmpty ?? true) }
        }
        // Move "Unboxed" to the top only for A→Z and Z→A sorts
        if sortSelection != .recent,
           let unboxedIndex = deduped.firstIndex(where: { $0.numberOrName == "Unboxed" }) {
            let unboxed = deduped.remove(at: unboxedIndex)
            deduped.insert(unboxed, at: 0)
        }
        return deduped
    }

    private var allBoxesExpanded: Bool {
        filteredBoxes.allSatisfy {
            expandedBoxes[$0.persistentModelID, default: false]
        }
    }
    
    private var contentView: some View {
        ZStack {
            VStack {
                Text("Box Linked Items")
                    .font(.largeTitle.bold())
                    .padding(.top, 12)
                // Search + Clear Button + Barcode Scanner
                ZStack {
                    HStack {
                        TextField("Search Boxes", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                            .submitLabel(.done)
                            .onSubmit {
                                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                            }
                        if !searchText.isEmpty {
                            Button(action: {
                                withAnimation { searchText = "" }
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .transition(.scale)
                        }

                        Spacer().frame(width: 12)

                        Button(action: {
                            isShowingScanner = true
                        }) {
                            Image(systemName: "barcode.viewfinder")
                                .font(.title3)
                                .foregroundColor(.blue)
                        }
                    }
                    .padding(.horizontal)
                }
                .simultaneousGesture(
                    TapGesture().onEnded {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                )

                // Sort Picker (matches Items tab layout)
                HStack {
                    Picker("Sort", selection: $sortSelection) {
                        ForEach(SortSelection.allCases) { selection in
                            Text(selection.rawValue).tag(selection)
                        }
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                    Button(action: {
                        showingSortInfo.toggle()
                    }) {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                    .accessibilityLabel("Sorting Info")
                }
                .padding(.horizontal)
                .padding(.top)

                // Filter segmented control
                Picker("Filter Boxes", selection: $filterSelection) {
                    ForEach(FilterSelection.allCases) { selection in
                        Text(selection.rawValue).tag(selection)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top)

                // Expand/Collapse All button
                HStack {
                    Spacer()
                    Button(action: {
                        if allBoxesExpanded {
                            expandedBoxes = [:]
                        } else {
                            expandedBoxes = Dictionary(uniqueKeysWithValues: filteredBoxes.map { ($0.persistentModelID, true) })
                        }
                    }) {
                        Text(allBoxesExpanded ? "Collapse All" : "Expand All")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing)
                }

                Text("Tap to View Linked Items")
                    .font(.headline)
                    .padding(.top, 4)
                    .padding(.bottom, 2)

                ScrollViewReader { proxy in
                    List {
                        ForEach(filteredBoxes, id: \.persistentModelID) { box in
                            Section {
                                if expandedBoxes[box.persistentModelID, default: false] {
                                    ForEach(box.items ?? []) { item in
                                        NavigationLink(destination: ItemDetailView(item: item)) {
                                            HStack {
                                                if let data = item.imageData, let uiImage = UIImage(data: data) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: 48, height: 48)
                                                        .cornerRadius(4)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                                        )
                                                        .clipped()
                                                        .padding(.trailing, 8)
                                                } else {
                                                    Color.gray
                                                        .frame(width: 48, height: 48)
                                                        .cornerRadius(4)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 4)
                                                                .stroke(Color.secondary.opacity(0.4), lineWidth: 1)
                                                        )
                                                        .padding(.trailing, 8)
                                                }
                                                VStack(alignment: .leading) {
                                                    Text(item.name)
                                                        .fontWeight(.semibold)
                                                    Text(item.itemDescription)
                                                        .font(.caption)
                                                        .lineLimit(1)
                                                        .foregroundColor(.secondary)
                                                }
                                                Spacer()
                                            }
                                            .padding(.vertical, 4)
                                        }
                                    }
                                }
                            } header: {
                                BoxHeaderView(
                                    box: box,
                                    isExpanded: expandedBoxes[box.persistentModelID, default: false],
                                    searchText: searchText,
                                    toggleAction: {
                                        expandedBoxes[box.persistentModelID, default: false].toggle()
                                    },
                                    printAction: { printBoxLabel(box: box) },
                                    showInfo: showingSortInfo
                                )
                            }
                            .id(box.persistentModelID)
                        }
                    }
                    .listStyle(.plain)
                    .animation(Animation.easeInOut(duration: 0.4), value: filteredBoxes.map { $0.persistentModelID })
                    .alert("Delete Box?", isPresented: .constant(boxToDelete != nil), presenting: boxToDelete) { box in
                        Button("Delete", role: .destructive) {
                            withAnimation {
                                context.delete(box)
                                try? context.save()
                                boxToDelete = nil
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            boxToDelete = nil
                        }
                    } message: { box in
                        Text("Are you sure you want to delete the Box “\(box.numberOrName)”?")
                    }
                    .onChange(of: scrollToBoxID) { oldValue, newValue in
                        if let id = newValue {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                            scrollToBoxID = nil
                        }
                    }
                }
            }
        }
      .sheet(isPresented: $isShowingScanner) {
          BarcodeScannerView { scanned in
              isShowingScanner = false
              if let matchedBox = boxes.first(where: { $0.numberOrName == scanned }) {
                  let boxID = matchedBox.persistentModelID
                  expandedBoxes[boxID] = true
                  scrollToBoxID = boxID
                  AudioServicesPlaySystemSound(SystemSoundID(1103)) // play success beep
              }
          }
      }
    }

    var body: some View {
        NavigationStack {
            contentView
        }
        // Removed alert for sorting info; now inline info is shown in headers
    }
    
    // MARK: - Actions
    func addBox() {
        withAnimation {
            // 1. Extract numeric box numbers from existing Box entries
            let existingNumbers = boxes.compactMap { Int($0.numberOrName.trimmed()) }.sorted()
            // 2. Find the smallest missing positive integer
            var nextNumber = 1
            for number in existingNumbers {
                if number == nextNumber {
                    nextNumber += 1
                } else if number > nextNumber {
                    break
                }
            }
            let newBoxText = "\(nextNumber)"
            // 3. Prevent duplicates (case insensitive, trimmed)
            guard !boxes.contains(where: { $0.numberOrName.trimmed().caseInsensitiveCompare(newBoxText) == .orderedSame }) else { return }
            let newBoxObj = Box(numberOrName: newBoxText)
            context.insert(newBoxObj)
            try? context.save()
            newBox = ""
        }
    }

    func deleteBoxes(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let box = self.filteredBoxes[index]
                context.delete(box)
            }
            try? context.save()
        }
    }
} // End of BoxLinkedItemsView struct

    // MARK: - Print Box Label
    func printBoxLabel(box: Box) {
        let image = LabelCanvasRenderer.renderLabel(box: box)

        let printInfo = UIPrintInfo(dictionary: nil)
        printInfo.outputType = .photo
        printInfo.jobName = "Box Label"

        let printController = UIPrintInteractionController.shared
        printController.printInfo = printInfo
        printController.printingItem = image
        printController.present(animated: true, completionHandler: nil)
    }
    
    // MARK: - Highlight Matches
    @ViewBuilder
    func highlightedText(for text: String, matching query: String) -> some View {
        if query.isEmpty {
            Text(text)
        } else if let range = text.lowercased().range(of: query.lowercased()) {
            let startIndex = text.distance(from: text.startIndex, to: range.lowerBound)
            let endIndex = text.distance(from: text.startIndex, to: range.upperBound)

            let before = String(text.prefix(startIndex))
            let match = String(text[range])
            let after = String(text.suffix(text.count - endIndex))

            (
                Text(before) +
                Text(match).foregroundColor(.blue).bold() +
                Text(after)
            )
        } else {
            Text(text)
        }
    }

    struct ThumbnailLayoutView: View {
        let items: [Item]
        let totalWidth: CGFloat

        var body: some View {
            let thumbSize: CGFloat = 48
            let spacing: CGFloat = 4
        let itemsWithImages = items.filter { $0.imageData != nil }

            // Estimate room for thumbnails
            let badgeReserve: CGFloat = 40 // space for "+N" badge
            let maxThumbnails = Int((totalWidth - badgeReserve + spacing) / (thumbSize + spacing))
            let previewItems = itemsWithImages.prefix(maxThumbnails)
            let remainingCount = itemsWithImages.count - previewItems.count

            return HStack {
                LazyHStack(alignment: .top, spacing: 8) {
                    ForEach(previewItems) { item in
                        if let data = item.imageData, let uiImage = UIImage(data: data) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: thumbSize, height: thumbSize)
                                .clipped()
                                .cornerRadius(4)
                        }
                    }

                    if remainingCount > 0 {
                        Text("+\(remainingCount)")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.secondary)
                            .cornerRadius(4)
                    }
                }
                Spacer()
            }
            .frame(maxWidth: totalWidth)
        }
    }

    struct BoxHeaderView: View {
        let box: Box
        let isExpanded: Bool
        let searchText: String
        let toggleAction: () -> Void
        let printAction: () -> Void
        let showInfo: Bool

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Button(action: toggleAction) {
                        HStack(spacing: 6) {
                            highlightedText(for: box.numberOrName, matching: searchText)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("(\(box.items?.count ?? 0))")
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)

                    // Thumbnails inline with label and count
                    if !isExpanded {
                        Spacer(minLength: 8)
                        GeometryReader { geometry in
                            ThumbnailLayoutView(items: box.items ?? [], totalWidth: geometry.size.width)
                        }
                        .frame(height: 48)
                    } else {
                        Spacer(minLength: 8)
                    }

                    Button(action: printAction) {
                        Image(systemName: "printer")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .foregroundColor(.secondary)
                }
                if showInfo {
                    if let mostRecentItem = box.items?.max(by: {
                        ($0.lastUpdated < $1.lastUpdated)
                    }) {
                        let isModified = Calendar.current.compare(mostRecentItem.lastUpdated, to: mostRecentItem.dateAdded, toGranularity: .second) == .orderedDescending
                        let recentDate = mostRecentItem.lastUpdated

                        HStack(spacing: 4) {
                            Text(isModified ? "✏️" : "🆕")
                            Text(recentDate, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    } else if let newestItem = box.items?.max(by: { $0.dateAdded < $1.dateAdded }) {
                        // Fallback to show 🆕 if item was just added and never modified
                        HStack(spacing: 4) {
                            Text("🆕")
                            Text(newestItem.dateAdded, style: .relative)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
        }
    }

    struct WidthPreferenceKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
            value += nextValue()
        }
    }

// MARK: - String Helper
extension String {
    func trimmed() -> String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}


