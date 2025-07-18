import SwiftUI
import SwiftData

public struct AddItemView: View {
    @Bindable var item: Item

    @FocusState private var nameFieldFocused: Bool
    @State private var scrollTarget: String?
    @State private var showSaveToast: Bool = false
    @State private var isShowingScanner = false
    @State private var isLoadingLookup = false
    
    @State private var tempSelectedCategoryID: PersistentIdentifier?
    @State private var tempSelectedRoomID: PersistentIdentifier?
    @State private var tempSelectedSectorID: PersistentIdentifier?
    @State private var tempSelectedShelfID: PersistentIdentifier?
    @State private var tempSelectedBoxNameID: PersistentIdentifier?
    @State private var tempSelectedBoxTypeID: PersistentIdentifier?
    // Full-screen picker
    @State private var activePicker: ActivePicker?

    // Lookup error/cancel state
    @State private var lookupFailed = false
    @State private var didCancelLookup = false
    
    @State private var showImagePicker = false
    @State private var imageSourceType: UIImagePickerController.SourceType = .photoLibrary
    @State private var pendingSourceType: UIImagePickerController.SourceType?
    @State private var selectedImage: UIImage?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var categories: [Category] = []
    @State private var rooms: [Room] = []
    @State private var sectors: [Sector] = []
    @State private var shelves: [Shelf] = []
    @State private var boxNames: [BoxName] = []
    @State private var boxTypes: [BoxType] = []

    // Picker enum for full-screen selection
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

    init(item: Item) {
        self._item = Bindable(wrappedValue: item)
    }

    public var body: some View {
        contentBody
    }

    private var contentBody: some View {
        let scannerSheet: some View = BarcodeScannerView(completion: handleScannedBarcode)
        return NavigationStack {
            Form {
                itemInfoSection()

                // Category Picker
                HStack {
                    Text("Category")
                    Spacer()
                    Text(categories.first(where: { $0.persistentModelID == tempSelectedCategoryID })?.categoryNameWrapped ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .category
                }

                // Room Picker
                HStack {
                    Text("Room")
                    Spacer()
                    Text(rooms.first(where: { $0.persistentModelID == tempSelectedRoomID })?.roomName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .room
                }

                // Sector Picker
                HStack {
                    Text("Sector")
                    Spacer()
                    Text(sectors.first(where: { $0.persistentModelID == tempSelectedSectorID })?.sectorName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .sector
                }

                // Shelf Picker
                HStack {
                    Text("Shelf")
                    Spacer()
                    Text(shelves.first(where: { $0.persistentModelID == tempSelectedShelfID })?.shelfName ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .shelf
                }

                // Box Name Picker
                HStack {
                    Text("Box Name")
                    Spacer()
                    Text(boxNames.first(where: { $0.persistentModelID == tempSelectedBoxNameID })?.boxNameText ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .boxName
                }

                // Box Type Picker
                HStack {
                    Text("Box Type")
                    Spacer()
                    Text(boxTypes.first(where: { $0.persistentModelID == tempSelectedBoxTypeID })?.boxTypeText ?? "None")
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    activePicker = .boxType
                }

                Section(header: Text("Add Photo").font(.caption).foregroundStyle(.secondary)) {
                    PhotoSourcePickerView(
                        onSelectLibrary: { pendingSourceType = .photoLibrary },
                        onSelectCamera: { pendingSourceType = .camera }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: selectedImage)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Back") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Item")
                        .font(.headline)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveItem()
                    }
                }
            }
            .overlay(saveToastOverlay)
            .overlay(loadingOverlay)
            .animation(.easeInOut(duration: 0.25), value: isLoadingLookup)
            .alert("Lookup Failed", isPresented: $lookupFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We couldn't find any data for the scanned barcode.")
            }
            .onTapGesture { hideKeyboard() }
            .onAppear(perform: setupView)
            .sheet(isPresented: $showImagePicker) {
                ImagePicker(sourceType: imageSourceType, selectedImage: $selectedImage)
            }
            .onChange(of: selectedImage) {
                guard let newImage = selectedImage else { return }
                Task { await applyResizedImage(newImage) }
            }
            .sheet(isPresented: $isShowingScanner) {
                scannerSheet
            }
            .onChange(of: pendingSourceType) {
                guard let source = pendingSourceType else { return }
                imageSourceType = source
                showImagePicker = true
                pendingSourceType = nil
            }
            // Full-screen custom picker
            .sheet(item: $activePicker) { picker in
                NavigationStack {
                    switch picker {
                    case .category:
                        FullScreenPicker(
                            title: "Category",
                            items: categories,
                            selected: categories.first(where: { $0.persistentModelID == tempSelectedCategoryID }),
                            label: { $0.categoryNameWrapped },
                            onSelect: { tempSelectedCategoryID = $0?.persistentModelID }
                        )
                    case .room:
                        FullScreenPicker(
                            title: "Room",
                            items: rooms,
                            selected: rooms.first(where: { $0.persistentModelID == tempSelectedRoomID }),
                            label: { $0.roomName },
                            onSelect: { tempSelectedRoomID = $0?.persistentModelID }
                        )
                    case .sector:
                        FullScreenPicker(
                            title: "Sector",
                            items: sectors,
                            selected: sectors.first(where: { $0.persistentModelID == tempSelectedSectorID }),
                            label: { $0.sectorName },
                            onSelect: { tempSelectedSectorID = $0?.persistentModelID }
                        )
                    case .shelf:
                        FullScreenPicker(
                            title: "Shelf",
                            items: shelves,
                            selected: shelves.first(where: { $0.persistentModelID == tempSelectedShelfID }),
                            label: { $0.shelfName },
                            onSelect: { tempSelectedShelfID = $0?.persistentModelID }
                        )
                    case .boxName:
                        FullScreenPicker(
                            title: "Box Name",
                            items: boxNames,
                            selected: boxNames.first(where: { $0.persistentModelID == tempSelectedBoxNameID }),
                            label: { $0.boxNameText },
                            onSelect: { tempSelectedBoxNameID = $0?.persistentModelID }
                        )
                    case .boxType:
                        FullScreenPicker(
                            title: "Box Type",
                            items: boxTypes,
                            selected: boxTypes.first(where: { $0.persistentModelID == tempSelectedBoxTypeID }),
                            label: { $0.boxTypeText },
                            onSelect: { tempSelectedBoxTypeID = $0?.persistentModelID }
                        )
                    }
                }
            }
        }
    }

    private var loadingOverlay: some View {
        Group {
            if isLoadingLookup {
                ZStack {
                    Color.black.opacity(0.3).ignoresSafeArea()
                    VStack(spacing: 16) {
                        ProgressView("Looking up item...")
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(10)
                            .transition(.opacity)
                        Button("Cancel") {
                            didCancelLookup = true
                            isLoadingLookup = false
                        }
                        .padding(.top, 8)
                    }
                }
            }
        }
    }
}

// MARK: - Subviews
private extension AddItemView {
    func itemInfoForm() -> some View {
        Form {
            itemInfoSection()
                .padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
    }


    var saveToastOverlay: some View {
        Group {
            if showSaveToast {
                Text("Item saved!")
                    .padding()
                    .background(.ultraThinMaterial)
                    .cornerRadius(10)
                    .shadow(radius: 5)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: showSaveToast)
    }
}

// MARK: - Sections
private extension AddItemView {
    func itemInfoSection() -> some View {
        Group {
            if let selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
                    .padding(.bottom, 8)
            }
            Section(header: Text("ITEM NAME").font(.caption).foregroundStyle(.secondary)) {
                TextField("Name", text: $item.name)
                    .focused($nameFieldFocused)
                    .textFieldStyle(.roundedBorder)
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets())

            Section(header: Text("ITEM DESCRIPTION").font(.caption).foregroundStyle(.secondary)) {
                TextField("Description", text: $item.itemDescription)
                    .focused($nameFieldFocused)
                    .textFieldStyle(.roundedBorder)
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets())

            Section(header: Text("BARCODE").font(.caption).foregroundStyle(.secondary)) {
                HStack {
                    TextField("Barcode", text: $item.barcodeValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                        .textFieldStyle(.roundedBorder)
                    Button(action: {
                        isShowingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
            }
            .textCase(nil)
            .listRowInsets(EdgeInsets())
        }
    }

    // Save button now in toolbar; remove section from form.
}

// MARK: - Setup & Helpers
private extension AddItemView {
    func setupView() {
        categories = (try? modelContext.fetch(
            FetchDescriptor<Category>(
                sortBy: [SortDescriptor(\.categoryName, order: .forward)]
            )
        )) ?? []
        rooms = (try? modelContext.fetch(FetchDescriptor<Room>(sortBy: [SortDescriptor(\.roomName, order: .forward)]))) ?? []
        sectors = (try? modelContext.fetch(FetchDescriptor<Sector>(sortBy: [SortDescriptor(\.sectorName, order: .forward)]))) ?? []
        shelves = (try? modelContext.fetch(FetchDescriptor<Shelf>(sortBy: [SortDescriptor(\.shelfName, order: .forward)]))) ?? []
        let fetchedBoxNames = (try? modelContext.fetch(FetchDescriptor<BoxName>(sortBy: [SortDescriptor(\.boxNameText, order: .forward)]))) ?? []
        if let unboxed = fetchedBoxNames.first(where: { $0.boxNameText.lowercased() == "unboxed" }) {
            boxNames = [unboxed] + fetchedBoxNames.filter { $0.persistentModelID != unboxed.persistentModelID }
        } else {
            boxNames = fetchedBoxNames
        }
        boxTypes = (try? modelContext.fetch(FetchDescriptor<BoxType>(sortBy: [SortDescriptor(\.boxTypeText, order: .forward)]))) ?? []

        tempSelectedCategoryID = item.category?.persistentModelID
        tempSelectedRoomID = item.room?.persistentModelID
        tempSelectedSectorID = item.sector?.persistentModelID
        tempSelectedSectorID = item.sector?.persistentModelID
        tempSelectedShelfID = item.shelf?.persistentModelID
        tempSelectedBoxNameID = item.boxNameRef?.persistentModelID
        tempSelectedBoxTypeID = item.boxTypeRef?.persistentModelID

        nameFieldFocused = true
    }

    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Picker update handlers
private extension AddItemView {
    func updateSelectedCategory(id: PersistentIdentifier?) {
        tempSelectedCategoryID = id
    }

    func updateSelectedRoom(id: PersistentIdentifier?) {
        tempSelectedRoomID = id
    }

    func updateSelectedSector(id: PersistentIdentifier?) {
        tempSelectedSectorID = id
    }

    func updateSelectedShelf(id: PersistentIdentifier?) {
        tempSelectedShelfID = id
    }

    func updateSelectedBoxName(id: PersistentIdentifier?) {
        tempSelectedBoxNameID = id
    }

    func updateSelectedBoxType(id: PersistentIdentifier?) {
        tempSelectedBoxTypeID = id
    }

    func saveItem() {
        if item.barcodeValue.trimmingCharacters(in: .whitespaces).isEmpty {
//            item.barcodeValue = "ITEM-\(UUID().uuidString.prefix(8))"
            item.barcodeValue = generateRandomEAN13()
        }
        if let selectedID = tempSelectedCategoryID {
            item.category = categories.first(where: { $0.persistentModelID == selectedID })
        }
        
        if let selectedID = tempSelectedRoomID {
            item.room = rooms.first(where: { $0.persistentModelID == selectedID })
        }
        
        if let selectedID = tempSelectedSectorID {
            item.sector = sectors.first(where: { $0.persistentModelID == selectedID })
        }
        
        if let selectedID = tempSelectedShelfID {
            item.shelf = shelves.first(where: { $0.persistentModelID == selectedID })
        }
        
        if let selectedID = tempSelectedBoxNameID {
            item.boxNameRef = boxNames.first(where: { $0.persistentModelID == selectedID })
        } else {
            item.boxNameRef = boxNames.first(where: { $0.boxNameText == "Unboxed" })
        }
        
        if let selectedID = tempSelectedBoxTypeID {
            item.boxTypeRef = boxTypes.first(where: { $0.persistentModelID == selectedID })
        }
        
        if item.modelContext == nil {
            modelContext.insert(item)
        }
        try? modelContext.save()
        showSaveToast = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            showSaveToast = false
            handleImageAndDismiss()
        }
    }
}

// MARK: - Image Processing Helper
private extension AddItemView {
    func applyResizedImage(_ image: UIImage) async {
        guard let compressedData = image.resizedAndCompressed(toMaxDimension: ImageCompressionConfig.maxDimension, compressionQuality: ImageCompressionConfig.quality) else { return }
        await MainActor.run {
            item.imageData = compressedData
            selectedImage = UIImage(data: compressedData)
        }
    }
}


// MARK: - Image and Dismiss Helper
private extension AddItemView {
    func handleImageAndDismiss() {
        guard let selectedImage else {
            dismiss()
            return
        }

        let resizedData = selectedImage.resizedAndCompressed(toMaxDimension: ImageCompressionConfig.maxDimension, compressionQuality: ImageCompressionConfig.quality)
        guard let data = resizedData else {
            dismiss()
            return
        }

        item.imageData = data
        self.selectedImage = UIImage(data: data)
        dismiss()
    }
}

// MARK: - Barcode Handler
private extension AddItemView {
    func handleScannedBarcode(scanned: String) {
        isShowingScanner = false
        item.barcodeValue = scanned
        didCancelLookup = false
        lookupFailed = false
        
        BarcodeLookupService.shared.lookup(
            upc: scanned,
            isLoading: { loading in
                self.isLoadingLookup = loading
            },
            completion: { result in
                if let result = result {
                    let converted = BarcodeLookupResult(
                        title: result.title,
                        description: result.description,
                        images: result.images
                    )
                    self.handleLookupResult(converted)
                } else {
                    self.handleLookupResult(nil)
                }
            }
        )
    }
    
    func handleLookupResult(_ result: BarcodeLookupResult?) {
        guard !didCancelLookup else { return }
        
        DispatchQueue.main.async {
            if let result = result {
                item.name = result.title ?? item.name
                item.itemDescription = result.description ?? item.itemDescription
                
                if let imageURLString = result.images?.first,
                   let url = URL(string: imageURLString) {
                    Task {
                        await fetchAndSetImage(from: url)
                    }
                }
            } else {
                lookupFailed = true
            }
        }
    }
    
    func fetchAndSetImage(from url: URL) async {
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let uiImage = UIImage(data: data),
               let resizedData = uiImage.resizedAndCompressed(toMaxDimension: ImageCompressionConfig.maxDimension, compressionQuality: ImageCompressionConfig.quality),
               let finalImage = UIImage(data: resizedData) {
                await MainActor.run {
                    item.imageData = resizedData
                    selectedImage = finalImage
                }
            }
        } catch {
            print("Failed to fetch or process image from URL: \(error)")
        }
    }
    
    //    func generateFakeEAN13() -> String {
    //        var digits = (0..<12).map { _ in Int.random(in: 0...9) }
    //
    //        // Calculate EAN-13 check digit
    //        let sum = digits.enumerated().reduce(0) { acc, pair in
    //            let (index, digit) = pair
    //            return acc + digit * (index.isMultiple(of: 2) ? 1 : 3)
    //        }
    //        let checkDigit = (10 - (sum % 10)) % 10
    //        digits.append(checkDigit)
    //
    //        return digits.map(String.init).joined()
    //    }
}



// MARK: - Full-Screen Picker View
struct FullScreenPicker<T: Identifiable & Equatable>: View {
    let title: String
    let items: [T]
    let selected: T?
    let label: (T) -> String
    let onSelect: (T?) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button("None") {
                    onSelect(nil)
                    dismiss()
                }
            }

            Section {
                ForEach(items) { item in
                    Button {
                        onSelect(item)
                        dismiss()
                    } label: {
                        HStack {
                            Text(label(item))
                                .lineLimit(1)
                            if item == selected {
                                Spacer()
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Back") {
                    dismiss()
                }
            }
        }
    }
}
