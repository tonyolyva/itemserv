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

    init(item: Item) {
        self._item = Bindable(wrappedValue: item)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                itemInfoForm()
                locationForm()
                saveButtonForm()
            }
            .padding(.top)
            .navigationTitle(item.modelContext == nil ? "Add Item" : "Edit Item")
            .navigationBarTitleDisplayMode(.inline)
            .overlay(saveToastOverlay)
            .overlay {
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
            .animation(.easeInOut(duration: 0.25), value: isLoadingLookup)
            .alert("Lookup Failed", isPresented: $lookupFailed) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("We couldn't find any data for the scanned barcode.")
            }
            .onAppear(perform: setupView)
            .onChange(of: scrollTarget) { oldValue, newValue in
                if let target = newValue {
                    withAnimation {
                        proxy.scrollTo(target, anchor: .center)
                    }
                }
            }
        }
        .onTapGesture {
            hideKeyboard()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(sourceType: imageSourceType, selectedImage: $selectedImage)
        }
        .sheet(isPresented: $isShowingScanner) {
            BarcodeScannerView { scanned in
                isShowingScanner = false
                item.barcodeValue = scanned
                didCancelLookup = false
                lookupFailed = false

                BarcodeLookupService.shared.lookup(
                    upc: scanned,
                    isLoading: { loading in isLoadingLookup = loading }
                ) { result in
                    guard !didCancelLookup else { return }
                    DispatchQueue.main.async {
                        if let result = result {
                            item.name = result.title ?? item.name
                            item.itemDescription = result.description ?? item.itemDescription

                            if let imageURLString = result.images?.first,
                               let url = URL(string: imageURLString),
                               let data = try? Data(contentsOf: url) {
                                item.imageData = data
                                selectedImage = UIImage(data: data)
                            }
                        } else {
                            lookupFailed = true
                        }
                    }
                }
            }
        }
        .onChange(of: pendingSourceType) { newType in
            guard let source = newType else { return }
            imageSourceType = source
            showImagePicker = true
            pendingSourceType = nil
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

    func locationForm() -> some View {
        Form {
            locationSection()
                .padding(.horizontal)
        }
        .scrollContentBackground(.hidden)
    }

    func saveButtonForm() -> some View {
        Form {
            saveButtonSection()
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
        Section(header: Text("Item Info")) {
            VStack(alignment: .leading) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                        .padding(.bottom, 8)
                }

                TextField("Name", text: $item.name)
                    .focused($nameFieldFocused)
                    .padding(.bottom, 8)

                TextField("Description", text: $item.itemDescription, axis: .vertical)
                    .lineLimit(3...6)
                
                HStack {
                    TextField("Barcode", text: $item.barcodeValue)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled(true)
                    Button(action: {
                        isShowingScanner = true
                    }) {
                        Image(systemName: "barcode.viewfinder")
                    }
                }
                .padding(.top, 8)
            }
        }
        .background(Color(.systemGroupedBackground))
        .listRowBackground(Color.clear)
    }
    
    func locationSection() -> some View {
        Section(header: Text("Location")) {
            categoryPickerSection()
            roomPickerSection()
            sectorPickerSection()
            shelfPickerSection()
            boxNamePickerSection()
            boxTypePickerSection()
            PhotoSourcePickerView(
                onSelectLibrary: {
                    pendingSourceType = .photoLibrary
                },
                onSelectCamera: {
                    pendingSourceType = .camera
                }
            )
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: selectedImage)
        }
        .background(Color(.systemGroupedBackground))
        .listRowBackground(Color.clear)
    }
    
    func saveButtonSection() -> some View {
        Section {
            Button("Save") {
                saveItem()
            }
            .buttonStyle(.borderedProminent)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(.systemGroupedBackground))
        .listRowBackground(Color.clear)
    }
    
    private func categoryPickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Category", selection: $tempSelectedCategoryID) {
                ForEach(categories, id: \.persistentModelID) { category in
                    Text(category.categoryName ?? "").tag(Optional(category.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("categoryPicker")
        }
    }
    
    private func roomPickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Room", selection: $tempSelectedRoomID) {
                ForEach(rooms, id: \.persistentModelID) { room in
                    Text(room.roomName).tag(Optional(room.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("roomPicker")
        }
    }
    
    private func sectorPickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Sector", selection: $tempSelectedSectorID) {
                ForEach(sectors, id: \.persistentModelID) { sector in
//                    Text(sector.sectorName ?? "").tag(Optional(sector.persistentModelID))
                    Text(sector.sectorName).tag(Optional(sector.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("sectorPicker")
        }
    }
    
    private func shelfPickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Shelf", selection: $tempSelectedShelfID) {
                ForEach(shelves, id: \.persistentModelID) { shelf in
//                    Text(shelf.shelfName ?? "").tag(Optional(shelf.persistentModelID))
                    Text(shelf.shelfName).tag(Optional(shelf.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("shelfPicker")
        }
    }
    
    private func boxNamePickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Box Name", selection: $tempSelectedBoxNameID) {
                Text("Unboxed").tag(Optional<PersistentIdentifier>.none)
                ForEach(boxNames.filter { $0.boxNameText != "Unboxed" }, id: \.persistentModelID) { boxName in
                    Text(boxName.boxNameText).tag(Optional(boxName.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("boxNamePicker")
        }
    }
    
    private func boxTypePickerSection() -> some View {
        VStack(alignment: .leading) {
            Picker("Box Type", selection: $tempSelectedBoxTypeID) {
                ForEach(boxTypes, id: \.persistentModelID) { boxType in
//                    Text(boxType.boxTypeText ?? "").tag(Optional(boxType.persistentModelID))
                    Text(boxType.boxTypeText).tag(Optional(boxType.persistentModelID))
                }
            }
            .pickerStyle(MenuPickerStyle())
            .id("boxTypePicker")
        }
    }
    
}

// MARK: - Setup & Helpers
private extension AddItemView {
    func setupView() {
        categories = (try? modelContext.fetch(FetchDescriptor<Category>())) ?? []
        rooms = (try? modelContext.fetch(FetchDescriptor<Room>())) ?? []
        sectors = (try? modelContext.fetch(FetchDescriptor<Sector>())) ?? []
        shelves = (try? modelContext.fetch(FetchDescriptor<Shelf>())) ?? []
        boxNames = (try? modelContext.fetch(FetchDescriptor<BoxName>())) ?? []
        boxTypes = (try? modelContext.fetch(FetchDescriptor<BoxType>())) ?? []

        tempSelectedCategoryID = item.category?.persistentModelID
        tempSelectedRoomID = item.room?.persistentModelID
        tempSelectedSectorID = item.sector?.persistentModelID
        tempSelectedSectorID = item.sector?.persistentModelID
        tempSelectedShelfID = item.shelf?.persistentModelID
        tempSelectedBoxNameID = item.boxNameRef?.persistentModelID
        tempSelectedBoxTypeID = item.boxTypeRef?.persistentModelID
        
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
            item.barcodeValue = "ITEM-\(UUID().uuidString.prefix(8))"
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
            if let selectedImage {
                item.imageData = selectedImage.jpegData(compressionQuality: 0.8)
            }
            dismiss()
        }
    }
    
}

