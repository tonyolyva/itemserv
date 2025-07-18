import SwiftUI
import SwiftData
import UIKit

struct ItemListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var allItems: [Item]
    @Query private var rooms: [Room]
    @Query private var categories: [Category]
    @Query private var boxTypes: [BoxType]
    @State private var searchText = ""
    @State private var sortAscending = true
    @State private var isShowingScanner = false
    @State private var scannedCode: String?
    @State private var selectedItemToNavigate: Item?
    @State private var isAddingNewItem = false
    enum FilterSelection: String, CaseIterable, Identifiable {
        case all = "All"
        case room = "Room"
        case category = "Category"
        case boxType = "Box Type"
        case clearAll = "Clear All"

        var id: String { rawValue }
    }

    @State private var filterSelection: FilterSelection = .all
    @State private var selectedRoom: Room?
    @State private var selectedCategory: Category?
    @State private var selectedBoxType: BoxType?

    private var filteredItems: [Item] {
        let sorted = sortAscending
            ? allItems.sorted { $0.name.lowercased() < $1.name.lowercased() }
            : allItems.sorted { $0.name.lowercased() > $1.name.lowercased() }

        let searched = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? sorted
            : sorted.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

        switch filterSelection {
        case .all:
            return searched
        case .room:
            if let room = selectedRoom {
                return searched.filter { $0.room == room }
            }
        case .category:
            if let category = selectedCategory {
                return searched.filter { $0.category == category }
            }
        case .boxType:
            if let boxType = selectedBoxType {
                return searched.filter { $0.boxTypeRef == boxType }
            }
        case .clearAll:
            return searched
        }
        return searched
    }

var body: some View {
    NavigationStack {
        Group {
            contentView
        }
        .navigationTitle("Items")
        .sheet(isPresented: $isShowingScanner) {
            scannerSheetContent
        }
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    isAddingNewItem = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $isAddingNewItem) {
            AddItemView(item: Item(name: "", itemDescription: "", barcodeValue: ""))
        }
        .navigationDestination(isPresented: Binding(
            get: { selectedItemToNavigate != nil },
            set: { if !$0 { selectedItemToNavigate = nil } }
        )) {
            if let item = selectedItemToNavigate {
                ItemDetailView(item: item)
            }
        }
    }
}

private var scannerSheetContent: some View {
    BarcodeScannerView { scanned in
        isShowingScanner = false
        scannedCode = scanned
        if let matchedItem = allItems.first(where: { $0.barcodeValue == scanned }) {
            selectedItemToNavigate = matchedItem
        }
    }
}

@ViewBuilder
private var contentView: some View {
    if allItems.isEmpty {
        // Empty database: no items at all
        VStack {
            Image(systemName: "tray")
                .font(.largeTitle)
                .padding(.bottom)
            Text("No items yet")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            NavigationLink(destination: AddItemView(item: Item(name: "", itemDescription: "", barcodeValue: ""))) {
                Label("Add Your First Item", systemImage: "plus.circle")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else if filteredItems.isEmpty {
        // Filtered to no visible results
        VStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(.largeTitle)
                .padding(.bottom)
            Text("No matching items")
                .font(.title2)
                .foregroundColor(.secondary)
                .padding(.bottom, 8)
            Button("Clear Filters") {
                filterSelection = .all
                selectedRoom = nil
                selectedCategory = nil
                selectedBoxType = nil
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    } else {
        VStack(spacing: 10) {
            HStack {
                TextField("Search Items", text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                Button(action: {
                    isShowingScanner = true
                }) {
                    Image(systemName: "barcode.viewfinder")
                        .font(.title2)
                        .padding(.leading, 4)
                }
            }
            .padding(.horizontal)

            Picker("Sort", selection: $sortAscending) {
                Text("A → Z").tag(true)
                Text("Z → A").tag(false)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            Picker("Filter", selection: $filterSelection) {
                ForEach(FilterSelection.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .onChange(of: filterSelection) { oldValue, newValue in
                if newValue == .clearAll {
                    filterSelection = .all
                    selectedRoom = nil
                    selectedCategory = nil
                    selectedBoxType = nil
                }
            }

            // Active filter tags below filter picker
            if filterSelection != .all && filterSelection != .clearAll {
                HStack(spacing: 12) {
                    if filterSelection == .room {
                        Menu {
                            Picker("Select Room", selection: $selectedRoom) {
                                Text("None").tag(Room?.none)
                                ForEach(rooms, id: \.self) {
                                    Text($0.roomName).tag(Optional($0))
                                }
                            }
                        } label: {
                            Label(selectedRoom?.roomName ?? "None", systemImage: "mappin")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue))
                        }
                    } else if filterSelection == .category {
                        Menu {
                            Picker("Select Category", selection: $selectedCategory) {
                                Text("None").tag(Category?.none)
                                ForEach(categories, id: \.self) {
                                    Text($0.categoryName ?? "Untitled").tag(Optional($0))
                                }
                            }
                        } label: {
                            Label(selectedCategory?.categoryName ?? "None", systemImage: "tag")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue))
                        }
                    } else if filterSelection == .boxType {
                        Menu {
                            Picker("Select Box Type", selection: $selectedBoxType) {
                                Text("None").tag(BoxType?.none)
                                ForEach(boxTypes, id: \.self) {
                                    Text($0.boxTypeText).tag(Optional($0))
                                }
                            }
                        } label: {
                            Label(selectedBoxType?.boxTypeText ?? "None", systemImage: "cube.box")
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.blue))
                        }
                    }

                    if (filterSelection == .room && selectedRoom != nil) ||
                       (filterSelection == .category && selectedCategory != nil) ||
                       (filterSelection == .boxType && selectedBoxType != nil) {
                        Button("Clear") {
                            filterSelection = .all
                            selectedRoom = nil
                            selectedCategory = nil
                            selectedBoxType = nil
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                .transition(.opacity.combined(with: .move(edge: .top)))
                .animation(.easeInOut(duration: 0.3), value: filterSelection)
            }

            switch filterSelection {
            default:
                EmptyView()
            }

            List {
                ForEach(filteredItems) { item in
                    NavigationLink(destination: ItemDetailView(item: item)) {
                        HStack {
                            if let imageData = item.imageData,
                               let originalImage = UIImage(data: imageData),
                               let jpegData = originalImage.resizedAndCompressed(toMaxDimension: 200, compressionQuality: 0.35),
                               let resizedImage = UIImage(data: jpegData) {
                                Image(uiImage: resizedImage)
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
                            }
                            VStack(alignment: .leading) {
                                Text(item.name)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                if !item.itemDescription.isEmpty {
                                    Text(item.itemDescription)
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .onDelete(perform: deleteItems)
            }
        }
    }
}

private func deleteItems(at offsets: IndexSet) {
    for index in offsets {
        modelContext.delete(filteredItems[index])
    }
}
}

#Preview {
    ItemListView()
        .modelContainer(sharedModelContainer)
}
