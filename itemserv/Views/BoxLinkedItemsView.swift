import SwiftUI
import SwiftData
import AudioToolbox

struct BoxLinkedItemsView: View {
    @Namespace private var scrollAnchor
    @Environment(\.modelContext) private var context
    @Query private var boxNames: [BoxName]
    
    @State private var newBoxName: String = ""
    @State private var searchText: String = ""
    @State private var sortAscending: Bool = true
    @State private var boxNameToDelete: BoxName?
    
    @State private var expandedBoxes: [UUID: Bool] = [:]
    @State private var filterSelection: FilterSelection = .allBoxes
    @State private var isShowingScanner = false
    @State private var scrollToBoxID: UUID?
    
    enum FilterSelection: String, CaseIterable, Identifiable {
        case allBoxes = "All Boxes"
        case onlyUnboxed = "Unboxed"
        case excludeEmptyBoxes = "Exclude Empty"
        case emptyBoxesOnly = "Empty Only"
        
        var id: String { rawValue }
    }
    
    private var sortedBoxNames: [BoxName] {
        let unboxed = boxNames.first(where: { $0.boxNameText == "Unboxed" })
        let numericBoxes = boxNames.filter { $0.boxNameText != "Unboxed" }

        let paired = numericBoxes.map { box in
            let hashComponent = abs(box.boxNameText.hashValue % 1000)
            let number = Int(box.boxNameText) ?? (Int.max - hashComponent)
            return (box, number)
        }

        let sorted = sortAscending
            ? paired.sorted { $0.1 < $1.1 }.map { $0.0 }
            : paired.sorted { $0.1 > $1.1 }.map { $0.0 }

        if let unboxed = unboxed {
            return sortAscending ? [unboxed] + sorted : sorted + [unboxed]
        } else {
            return sorted
        }
    }
    
    // MARK: - Virtual "Unboxed" Items (for future use)
    private var virtualUnboxedItems: [Item] {
        boxNames.flatMap { $0.items?.filter { $0.boxNameRef?.boxNameText == "Unboxed" } ?? [] }
    }
    
    private var filteredBoxNames: [BoxName] {
        var filtered = sortedBoxNames
        if searchText.trimmed().isEmpty == false {
            filtered = filtered.filter { $0.boxNameText.localizedCaseInsensitiveContains(searchText) }
        }
        switch filterSelection {
        case .allBoxes:
            break
        case .onlyUnboxed:
            filtered = []
            if let realUnboxed = boxNames.first(where: { $0.boxNameText == "Unboxed" }) {
                filtered.append(realUnboxed)
            }
        case .excludeEmptyBoxes:
            filtered = filtered.filter { ($0.items?.isEmpty == false) }
        case .emptyBoxesOnly:
            filtered = filtered.filter { ($0.items?.isEmpty ?? true) }
        }
        return filtered
    }
    
    private var allBoxesExpanded: Bool {
        filteredBoxNames.allSatisfy { expandedBoxes[$0.id, default: false] }
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
                        TextField("Search Box Names", text: $searchText)
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

                // Sort Picker
                Picker("Sort Order", selection: $sortAscending) {
                    Text("A → Z").tag(true)
                    Text("Z → A").tag(false)
                }
                .pickerStyle(.segmented)
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
                            expandedBoxes = Dictionary(uniqueKeysWithValues: filteredBoxNames.map { ($0.id, true) })
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
                        ForEach(filteredBoxNames, id: \.self) { boxName in
                            Section {
                                if expandedBoxes[boxName.id, default: false] {
                                    ForEach(boxName.items ?? []) { item in
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
                                    boxName: boxName,
                                    isExpanded: expandedBoxes[boxName.id, default: false],
                                    searchText: searchText,
                                    toggleAction: {
                                        expandedBoxes[boxName.id, default: false].toggle()
                                    },
                                    printAction: { printBoxLabel(box: boxName) }
                                )
                            }
                            .id(boxName.id)
                        }
                    }
                    .listStyle(.plain)
                    .animation(.easeInOut(duration: 0.4), value: filteredBoxNames)
                    .alert("Delete Box Name?", isPresented: .constant(boxNameToDelete != nil), presenting: boxNameToDelete) { boxName in
                        Button("Delete", role: .destructive) {
                            withAnimation {
                                context.delete(boxName)
                                try? context.save()
                                boxNameToDelete = nil
                            }
                        }
                        Button("Cancel", role: .cancel) {
                            boxNameToDelete = nil
                        }
                    } message: { boxName in
                        Text("Are you sure you want to delete the Box Name “\(boxName.boxNameText)”?")
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
        // Removed explicit .navigationTitle to let the in-view Text serve as the title
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView { scanned in
                isShowingScanner = false
                if let matchedBox = boxNames.first(where: { $0.boxNameText == scanned }) {
                    expandedBoxes[matchedBox.id] = true
                    scrollToBoxID = matchedBox.id
                    AudioServicesPlaySystemSound(SystemSoundID(1103)) // play success beep
                }
            }
        }
    }

    var body: some View {
        NavigationStack {
            contentView
        }
    }
    
    // MARK: - Actions
    func addBoxName() {
        withAnimation {
            // 1. Extract numeric box numbers from existing BoxName entries
            let existingNumbers = boxNames.compactMap { Int($0.boxNameText.trimmed()) }.sorted()
            // 2. Find the smallest missing positive integer
            var nextNumber = 1
            for number in existingNumbers {
                if number == nextNumber {
                    nextNumber += 1
                } else if number > nextNumber {
                    break
                }
            }
            let newBoxNameText = "\(nextNumber)"
            // 3. Prevent duplicates (case insensitive, trimmed)
            guard !boxNames.contains(where: { $0.boxNameText.trimmed().caseInsensitiveCompare(newBoxNameText) == .orderedSame }) else { return }
            let newBox = BoxName(boxNameText: newBoxNameText)
            context.insert(newBox)
            try? context.save()
            newBoxName = ""
        }
    }

    func deleteBoxNames(at offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                let boxName = self.filteredBoxNames[index]
                context.delete(boxName)
            }
            try? context.save()
        }
    }
} // End of BoxLinkedItemsView struct

    // MARK: - Print Box Label
    func printBoxLabel(box: BoxName) {
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
        let boxName: BoxName
        let isExpanded: Bool
        let searchText: String
        let toggleAction: () -> Void
        let printAction: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center, spacing: 6) {
                    Button(action: toggleAction) {
                        HStack(spacing: 6) {
                            highlightedText(for: boxName.boxNameText, matching: searchText)
                                .font(.title3)
                                .fontWeight(.semibold)
                            Text("(\(boxName.items?.count ?? 0))")
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
                            ThumbnailLayoutView(items: boxName.items ?? [], totalWidth: geometry.size.width)
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

