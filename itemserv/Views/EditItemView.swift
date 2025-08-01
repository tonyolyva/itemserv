import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    
    @State private var selectedCategory: Category?
    @State private var isAddingCategory = false
    @State private var newCategoryName = ""
    
    @State private var selectedRoom: Room?
    @State private var isAddingRoom = false
    @State private var newRoomName = ""
    
    @State private var selectedSector: Sector?
    @State private var isAddingSector = false
    @State private var newSectorName = ""
    
    @State private var selectedShelf: Shelf?
    @State private var isAddingShelf = false
    @State private var newShelfName = ""
    
    @State private var selectedBoxName: BoxName?
    @State private var isAddingBoxName = false
    @State private var newBoxName = ""
    
    @State private var selectedBoxType: BoxType?
    @State private var isAddingBoxType = false
    @State private var newBoxType = ""
    
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var selectedImage: UIImage?
    @State private var presentedPickerID = UUID()
    @State private var pendingSourceType: UIImagePickerController.SourceType?
    
    @State private var isShowingScanner = false
    
    @Query(filter: nil, sort: \Category.categoryName) private var allCategories: [Category]
    private var categories: [Category] {
        Dictionary(grouping: allCategories, by: { $0.categoryNameWrapped.lowercased() })
            .compactMap { $0.value.first }
            .sorted { $0.categoryNameWrapped.localizedCaseInsensitiveCompare($1.categoryNameWrapped) == .orderedAscending }
    }
    @Query(filter: nil, sort: \Room.roomName) private var allRooms: [Room]
    private var rooms: [Room] {
        Dictionary(grouping: allRooms, by: { $0.roomName.lowercased() })
            .compactMap { $0.value.first }
            .sorted { $0.roomName.localizedCaseInsensitiveCompare($1.roomName) == .orderedAscending }
    }
    @Query(filter: nil, sort: \Sector.sectorName) private var allSectors: [Sector]
    private var sectors: [Sector] {
        Dictionary(grouping: allSectors, by: { $0.sectorName.lowercased() })
            .compactMap { $0.value.first }
            .sorted { $0.sectorName.localizedCaseInsensitiveCompare($1.sectorName) == .orderedAscending }
    }
    @Query(filter: nil, sort: \Shelf.shelfName) private var allShelves: [Shelf]
    private var shelves: [Shelf] {
        Dictionary(grouping: allShelves, by: { $0.shelfName.lowercased() })
            .compactMap { $0.value.first }
            .sorted { $0.shelfName.localizedCaseInsensitiveCompare($1.shelfName) == .orderedAscending }
    }
    @Query(filter: nil, sort: \BoxName.boxNameText) private var allBoxNames: [BoxName]
    private var boxNames: [BoxName] {
        let filtered = allBoxNames.filter { $0.boxNameText != "None" }
        let deduplicated = Dictionary(grouping: filtered, by: { $0.boxNameText })
            .compactMap { $0.value.first }

        let sorted = deduplicated.sorted {
            $0.boxNameText.localizedStandardCompare($1.boxNameText) == .orderedAscending
        }

        if let unboxed = sorted.first(where: { $0.boxNameText == "Unboxed" }) {
            return [unboxed] + sorted.filter { $0.boxNameText != "Unboxed" }
        }

        return sorted
    }

    private func boxNameLabel(_ boxName: BoxName) -> some View {
        let count = boxName.items?.count ?? 0
        return HStack {
            HStack(spacing: 8) {
                Image(systemName: "shippingbox")
                    .foregroundColor(.accentColor)
                Text(boxName.boxNameText)
                    .foregroundColor(.primary)
            }
            Spacer()
            if count > 0 {
                HStack(spacing: 4) {
                    Text("✨")
                    Text("\(count)")
                        .monospacedDigit()
                }
                .foregroundColor(.secondary)
                .frame(minWidth: 44, alignment: .trailing)
            }
        }
    }
    @Query(filter: nil, sort: \BoxType.boxTypeText) private var allBoxTypes: [BoxType]
    private var boxTypes: [BoxType] {
        Dictionary(grouping: allBoxTypes, by: { $0.boxTypeText.lowercased() })
            .compactMap { $0.value.first }
            .sorted { $0.boxTypeText.localizedCaseInsensitiveCompare($1.boxTypeText) == .orderedAscending }
    }
    
    private enum ActivePicker: Identifiable {
        case category, room, sector, shelf, boxName, boxType
        var id: String {
            switch self {
            case .category: return "category"
            case .room: return "room"
            case .sector: return "sector"
            case .shelf: return "shelf"
            case .boxName: return "boxName"
            case .boxType: return "boxType"
            }
        }
    }

    @State private var activePicker: ActivePicker?
    
    init(item: Item) {
        self.item = item
        _selectedPhoto = State(initialValue: nil)
        
        _selectedCategory = State(initialValue: item.category)
        _selectedRoom = State(initialValue: item.room)
        _selectedSector = State(initialValue: item.sector)
        _selectedShelf = State(initialValue: item.shelf)
        if let boxRef = item.boxNameRef {
            _selectedBoxName = State(initialValue: boxRef)
        } else {
            let unboxed = boxNames.first(where: { $0.boxNameText == "Unboxed" })
            _selectedBoxName = State(initialValue: unboxed)
        }
        _selectedBoxType = State(initialValue: item.boxTypeRef)
        _selectedImage = State(initialValue: nil)
    }
    
    var body: some View {
        NavigationStack {
            contentView
        }
        .navigationTitle("Edit Item")
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text("✏️ Edit Item")
                    .font(.headline)
                    .foregroundColor(.primary)
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if item.barcodeValue.trimmingCharacters(in: .whitespaces).isEmpty {
                        item.barcodeValue = generateRandomEAN13()
                    }
                    item.category = selectedCategory
                    item.room = selectedRoom
                    item.sector = selectedSector
                    item.shelf = selectedShelf
                    item.boxNameRef = selectedBoxName
                    item.boxTypeRef = selectedBoxType
                    item.lastUpdated = Date()
                    dismiss()
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
            }
        }
        .fullScreenCover(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imageSourceType, selectedImage: $selectedImage)
                .id(presentedPickerID)
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView { scanned in
                isShowingScanner = false
                item.barcodeValue = scanned

                BarcodeLookupService.shared.lookup(upc: scanned, isLoading: { _ in }) { result in
                    guard let result = result else { return }

                    DispatchQueue.main.async {
                        item.name = result.title ?? item.name
                        item.itemDescription = result.description ?? item.itemDescription

                        guard
                            let imageURLString = result.images?.first,
                            let url = URL(string: imageURLString),
                            let data = try? Data(contentsOf: url),
                            let uiImage = UIImage(data: data)
                        else { return }

                        let resized = uiImage.resizedAndCompressed(toMaxDimension: ImageCompressionConfig.maxDimension, compressionQuality: ImageCompressionConfig.quality)
                        if let resized {
                            item.imageData = resized
                            selectedImage = UIImage(data: resized)
                        }
                    }
                }
            }
        }
        .onChange(of: selectedImage) { _, newImage in
            guard let newImage else { return }
            let resized = newImage.resized(toMaxDimension: ImageCompressionConfig.maxDimension)
            item.imageData = resized.jpegData(compressionQuality: ImageCompressionConfig.quality)
        }
        .onChange(of: pendingSourceType) { _, newType in
            guard let source = newType else { return }
            imageSourceType = source
            presentedPickerID = UUID()
            showImagePicker = true
            pendingSourceType = nil
        }
        .onAppear {
            guard selectedImage == nil,
                  let data = item.imageData,
                  let uiImage = UIImage(data: data),
                  let resizedData = uiImage.resizedAndCompressed(
                      toMaxDimension: ImageCompressionConfig.maxDimension,
                      compressionQuality: ImageCompressionConfig.quality),
                  let resizedImage = UIImage(data: resizedData)
            else {
                return
            }

            item.imageData = resizedData
            selectedImage = resizedImage
        }
        .sheet(item: $activePicker) { picker in
            switch picker {
            case .category:
                NavigationStack {
                    FullScreenPicker(
                        title: "Category",
                        items: categories,
                        selected: selectedCategory,
                        label: { $0.categoryNameWrapped },
                        onSelect: { selectedCategory = $0 }
                    )
                    .navigationTitle("Category")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(false)
                }
            case .room:
                NavigationStack {
                    FullScreenPicker(
                        title: "Room",
                        items: rooms,
                        selected: selectedRoom,
                        label: { $0.roomName },
                        onSelect: { selectedRoom = $0 }
                    )
                    .navigationTitle("Room")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(false)
                }
            case .sector:
                NavigationStack {
                    FullScreenPicker(
                        title: "Sector",
                        items: sectors,
                        selected: selectedSector,
                        label: { $0.sectorName },
                        onSelect: { selectedSector = $0 }
                    )
                    .navigationTitle("Sector")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(false)
                }
            case .shelf:
                NavigationStack {
                    FullScreenPicker(
                        title: "Shelf",
                        items: shelves,
                        selected: selectedShelf,
                        label: { $0.shelfName },
                        onSelect: { selectedShelf = $0 }
                    )
                    .navigationTitle("Shelf")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(false)
                }
            case .boxName:
                NavigationStack {
                    FullScreenPicker(
                        title: "Box Name",
                        items: boxNames,
                        selected: selectedBoxName,
                        label: { boxName in
                            let count = boxName.items?.count ?? 0
                            let isUnboxed = boxName.boxNameText == "Unboxed"
                            let spacing = isUnboxed ? "    " : "                   " // adjust as needed
                            return count > 0
                                ? "📦 \(boxName.boxNameText)\(spacing)✨ \(count)"
                                : "📦 \(boxName.boxNameText)"
                        },
                        onSelect: { selectedBoxName = $0 }
                    )
                    .navigationTitle("Box Name")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(false)
                }
            case .boxType:
                NavigationStack {
                    FullScreenPicker(
                        title: "Box Type",
                        items: boxTypes,
                        selected: selectedBoxType,
                        label: { "📦 \($0.boxTypeText)" },
                        onSelect: { selectedBoxType = $0 }
                    )
                    .navigationTitle("Box Type")
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                activePicker = nil
                            } label: {
                                Label("Back", systemImage: "chevron.backward")
                            }
                        }
                    }
                }
            }
        }
    }

    private var contentView: some View {
        VStack(spacing: 0) {
            Form {
                itemNameSection
                itemDescriptionSection

                Section(header: Text("Item Barcode")) {
                    HStack {
                        TextField("Barcode", text: $item.barcodeValue)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled(true)
                        Button(action: {
                            let impact = UIImpactFeedbackGenerator(style: .medium)
                            impact.impactOccurred()
                            withAnimation {
                                isShowingScanner = true
                            }
                        }) {
                            Image(systemName: "barcode.viewfinder")
                        }
                    }
                }
                HStack {
                    Text("Category")
                    Spacer()
                    Text(selectedCategory?.categoryNameWrapped ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .category }

                HStack {
                    Text("Room")
                    Spacer()
                    Text(selectedRoom?.roomName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .room }

                HStack {
                    Text("Sector")
                    Spacer()
                    Text(selectedSector?.sectorName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .sector }

                HStack {
                    Text("Shelf")
                    Spacer()
                    Text(selectedShelf?.shelfName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .shelf }

                HStack {
                    Text("Box Name")
                    Spacer()
                    if let boxName = selectedBoxName {
                        Text(boxName.boxNameText)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .boxName }

                HStack {
                    Text("Box Type")
                    Spacer()
                    Text(selectedBoxType?.boxTypeText ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture { activePicker = .boxType }

                Section(header: Text("Photo")) {
                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(height: 200)
                            .cornerRadius(12)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                            .animation(.easeInOut(duration: 0.3), value: selectedImage)
                    }
                }

                Section(header: Text("Replace Photo")) {
                    Group {
                        PhotoSourcePickerView(
                            onSelectLibrary: { pendingSourceType = .photoLibrary },
                            onSelectCamera: { pendingSourceType = .camera }
                        )
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: selectedImage)
                }
            }
        }
    }
    
    private var itemNameSection: some View {
        Section(header: Text("Item Name")) {
            TextField("Name", text: $item.name)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeOut(duration: 0.4)) {
                    // no-op for now; AddItemView uses scrollTo
                }
            }
        }
    }
    
    private var itemDescriptionSection: some View {
        Section(header: Text("Item Description")) {
            TextField("Description", text: $item.itemDescription)
        }
    }
    
    private func addEntitySection(name: Binding<String>, saveAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading) {
            TextField("Name", text: name)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Save", action: saveAction)
                Button("Cancel") {
                    name.wrappedValue = ""
                    cancelAddingEntity()
                }
            }
        }
    }
    
    private func cancelAddingEntity() {
        isAddingCategory = false
        isAddingRoom = false
        isAddingSector = false
        isAddingShelf = false
        isAddingBoxName = false
        isAddingBoxType = false
    }
    
    // Save New Entities
    private func saveNewCategory() {
        saveNewEntity(
            newName: &newCategoryName,
            entities: categories,
            keyPath: \.categoryNameWrapped,
            createEntity: { Category(categoryName: $0) },
            assignToItem: { item.category = $0 },
            finishAdding: { isAddingCategory = false }
        )
    }
    
    private func saveNewRoom() {
        saveNewEntity(
            newName: &newRoomName,
            entities: rooms,
            keyPath: \.roomName,
            createEntity: { Room(roomName: $0) },
            assignToItem: { item.room = $0 },
            finishAdding: { isAddingRoom = false }
        )
    }
    
    private func saveNewSector() {
        saveNewEntity(
            newName: &newSectorName,
            entities: sectors,
            keyPath: \.sectorName,
            createEntity: { Sector(sectorName: $0) },
            assignToItem: { item.sector = $0 },
            finishAdding: { isAddingSector = false }
        )
    }
    
    private func saveNewShelf() {
        saveNewEntity(
            newName: &newShelfName,
            entities: shelves,
            keyPath: \.shelfName,
            createEntity: { Shelf(shelfName: $0) },
            assignToItem: { item.shelf = $0 },
            finishAdding: { isAddingShelf = false }
        )
    }
    
    private func saveNewBoxName() {
        saveNewEntity(
            newName: &newBoxName,
            entities: boxNames,
            keyPath: \.boxNameText,
            createEntity: { BoxName(boxNameText: $0) },
            assignToItem: { item.boxNameRef = $0 },
            finishAdding: { isAddingBoxName = false }
        )
    }
    
    private func saveNewBoxType() {
        saveNewEntity(
            newName: &newBoxType,
            entities: boxTypes,
            keyPath: \.boxTypeText,
            createEntity: { BoxType(boxTypeText: $0) },
            assignToItem: { item.boxTypeRef = $0 },
            finishAdding: { isAddingBoxType = false }
        )
    }
    
    private func saveNewEntity<T: PersistentModel & Identifiable>(
        newName: inout String,
        entities: [T],
        keyPath: KeyPath<T, String>,
        createEntity: (String) -> T,
        assignToItem: (T) -> Void,
        finishAdding: @escaping () -> Void
    ) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        if !entities.contains(where: { $0[keyPath: keyPath].caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            let newEntity = createEntity(trimmedName)
            modelContext.insert(newEntity)
            assignToItem(newEntity)
            newName = ""
        }
        finishAdding()
    }
}

// MARK: - Entity Picker Component
struct EntityPickerView<T: Identifiable & Hashable>: View {
    var title: String
    @Binding var selectedEntity: T?
    var entities: [T]
    var keyPath: KeyPath<T, String>
    var onAdd: (() -> Void)?
    var showNoneOption: Bool = true
    
    var body: some View {
        Section(header: Text(title)) {
            Menu {
                Picker(title, selection: $selectedEntity) {
                    if showNoneOption {
                        Text("None").tag(Optional<T>(nil))
                    }
                    ForEach(entities, id: \.id) { entity in
                        Text(entity[keyPath: keyPath])
                            .tag(Optional(entity))
                    }
                }
                if let onAdd {
                    Button("+ Add \(title)...", action: onAdd)
                }
            } label: {
                HStack {
                    Text(title)
                    Spacer()
                    Text(selectedEntity.map { $0[keyPath: keyPath] } ?? "None")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Photo Section
struct PhotoSectionView: View {
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var imageData: Data?
    
    var body: some View {
        Section(header: Text("Photo")) {
            if let data = imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
            } else {
                Text("No photo selected")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            }
            
            PhotosPicker("Select Photo", selection: $selectedPhoto, matching: .images)
                .onChange(of: selectedPhoto) { _, newItem in
                    print("Selected photo: \(String(describing: newItem))")
                    Task {
                        if let newItem {
                            do {
                                let data = try await newItem.loadTransferable(type: Data.self)
                                await MainActor.run {
                                    imageData = data
                                }
                            } catch {
                                print("Failed to load image data: \(error)")
                            }
                        }
                    }
                }
        }
    }
}

// MARK: - Extensions
private extension Optional where Wrapped == String {
    var nonEmptyOrNil: String? {
        self?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? self : nil
    }
}
