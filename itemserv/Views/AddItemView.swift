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
    @State private var tempSelectedBoxID: PersistentIdentifier?
    // Picker sheet states
    @State private var showCategoryPicker = false
    @State private var showBoxPicker = false

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
    @State private var boxNames: [Box] = []
    @State private var boxTypes: [BoxType] = []

    // Barcode manual entry toggle
    @State private var showManualBarcodeEntry: Bool = false

    // Picker enum for full-screen selection
    // (Removed ActivePicker since we now use independent sheet states)

    init(item: Item) {
        self._item = Bindable(wrappedValue: item)
    }

    public var body: some View {
        contentBody
    }

    private var contentBody: some View {
        var scannerSheet: some View {
            BarcodeScannerView(completion: handleScannedBarcode)
        }

        // Compute selected names for pickers
        let selectedCategory = categories.first { $0.persistentModelID == tempSelectedCategoryID }
        let selectedCategoryName = selectedCategory?.categoryNameWrapped ?? "None"
        let selectedBox = boxNames.first { $0.persistentModelID == tempSelectedBoxID }
        let selectedBoxName = selectedBox?.numberOrName ?? "None"

        return NavigationStack {
            ScrollViewReader { proxy in
//                VStack(spacing: -8) {
                VStack(spacing: -8) {
                    VStack(spacing: 0) {
                        // --- itemInfoSection content ---
                        if let selectedImage {
                            Image(uiImage: selectedImage)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 200)
                                .cornerRadius(12)
                                .padding(.bottom, 8)
                                .transition(.opacity)
                                .animation(.easeInOut(duration: 0.35), value: selectedImage)
                        }
                        // 1. Name
                        VStack(alignment: .leading, spacing: 4) { // Control spacing between a title ITEM NAME and Name field
//                            VStack(alignment: .leading, spacing: 8) { // Control spacing between a title ITEM NAME and Name field
                            Text("ITEM NAME")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            TextField("Name", text: $item.name)
                                .focused($nameFieldFocused)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.bottom, 12) // Control spacing between name field and a title ITEM DESCRIPTION
                        .padding(.horizontal)
                        .id("name")

                        // 2. Description
                        VStack(alignment: .leading, spacing: 4) { // Control spacing between a title ITEM DESCRIPTION and Description field
//                            VStack(alignment: .leading, spacing: 8) { // Control spacing between a title ITEM NAME and Name field
                            Text("ITEM DESCRIPTION")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
//                                .padding(.bottom, -6) // Reduce gap before Category
//                                .padding(.bottom, 4) // Control spacing between a title ITEM DESCRIPTION and Description field
                            TextField("Description", text: $item.itemDescription)
                                .focused($nameFieldFocused)
                                .textFieldStyle(.roundedBorder)
                        }
                        .padding(.bottom, 12) // Control spacing between Description field and Category
                        .padding(.horizontal)
                    }

                    // 3. Category Picker Button
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showCategoryPicker = true
                        }
                    } label: {
                        HStack {
                            Text("Category")
                            Spacer()
                            Text(selectedCategoryName)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .frame(height: 44)
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showCategoryPicker) {
                        NavigationStack {
                            FullScreenPicker(
                                title: "Category",
                                items: categories,
                                selected: categories.first(where: { $0.persistentModelID == tempSelectedCategoryID }),
                                label: { $0.categoryNameWrapped },
                                onSelect: { tempSelectedCategoryID = $0?.persistentModelID }
                            )
                        }
                    }
                    .padding(.bottom, 12) // Control spacing between Category nnd Box name

                    // 4. Box Picker Button
                    Button {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            showBoxPicker = true
                        }
                    } label: {
                        HStack {
                            Text("Box Name")
                            Spacer()
                            Text(selectedBoxName)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                        .frame(height: 44)
                        .background(Color(.systemBackground))
                    }
                    .buttonStyle(.plain)
                    .sheet(isPresented: $showBoxPicker) {
                        NavigationStack {
                            let groupedBoxes = Dictionary(grouping: boxNames, by: \.numberOrName)
                            let dedupedBoxes = groupedBoxes.compactMap { $0.value.first }
                            let uniqueBoxes = dedupedBoxes.sorted {
                                if $0.numberOrName == "Unboxed" { return true }
                                if $1.numberOrName == "Unboxed" { return false }
                                if let lhsInt = Int($0.numberOrName), let rhsInt = Int($1.numberOrName) {
                                    return lhsInt < rhsInt
                                }
                                return $0.numberOrName.localizedCompare($1.numberOrName) == .orderedAscending
                            }
                            FullScreenPicker(
                                title: "Box Name",
                                items: uniqueBoxes,
                                selected: uniqueBoxes.first(where: { $0.persistentModelID == tempSelectedBoxID }),
                                label: { box in
                                    let count = box.items?.count ?? 0
                                    return count > 0
                                        ? "📦 \(box.numberOrName)  ✨ \(count)"
                                        : "📦 \(box.numberOrName)"
                                },
                                onSelect: { tempSelectedBoxID = $0?.persistentModelID }
                            )
                        }
                    }
                    .padding(.bottom, 12) // Control spacing between Box name and a title ADD PHOTO

                    // 5. Photo Library / Camera
                    Form {
                        Section(header: Text("Add Photo").font(.caption).foregroundStyle(.secondary)) {
                            VStack {
                                PhotoSourcePickerView(
                                    onSelectLibrary: { pendingSourceType = .photoLibrary },
                                    onSelectCamera: { pendingSourceType = .camera }
                                )
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: showImagePicker)
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                    .scrollContentBackground(.hidden)

                    // 6. Barcode Scanner Button & Manual Entry Inline
                    // 6. Barcode Scanner Button & Manual Entry Inline
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            // Scan Barcode Button (Compact)
                            Button {
                                let impact = UIImpactFeedbackGenerator(style: .medium)
                                impact.impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    isShowingScanner = true
                                }
                            } label: {
                                HStack {
                                    Image(systemName: "barcode.viewfinder")
                                    Text("Barcode")
                                }
                                .frame(maxWidth: 120) // Compact width for Scan button
                                .frame(height: 44)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                            }

                            // Enter Barcode Manually Button
                            if !showManualBarcodeEntry {
                                Button {
                                    withAnimation {
                                        showManualBarcodeEntry = true
                                    }
                                } label: {
                                    HStack {
                                        Image(systemName: "keyboard")
                                        Text("Enter Manually")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 44)
                                    .background(Color(.secondarySystemBackground))
                                    .cornerRadius(8)
                                }
                            } else {
//                                TextField("Enter Barcode", text: $item.barcodeValue)
//                                    .textInputAutocapitalization(.never)
//                                    .autocorrectionDisabled(true)
//                                    .textFieldStyle(.roundedBorder)
//                                    .padding(.horizontal, 4)
//                                    .overlay(
//                                        RoundedRectangle(cornerRadius: 6)
//                                            .stroke(Color(.separator), lineWidth: 0.5)
//                                    )
//                                    .frame(height: 44)
//                                    .transition(.opacity)
                                TextField("Enter Barcode", text: $item.barcodeValue)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled(true)
                                    .padding(.horizontal, 10)
                                    .frame(height: 44)
                                    .background(Color(.black))
                                    // Overlay for top & bottom borders
                                    .overlay(
                                        VStack(spacing: 0) {
                                            Rectangle()
//                                                .fill(Color.gray.opacity(0.6))
                                                .fill(Color.gray.opacity(0.3))
//                                                .frame(height: 2) // Top border (thicker)
                                                .frame(height: 6) // Top border (thicker)
                                            Spacer()
                                            Rectangle()
//                                                .fill(Color.gray.opacity(0.6))
                                                .fill(Color.gray.opacity(0.3))
//                                                .frame(height: 2) // Bottom border (thicker)
                                                .frame(height: 6) // Bottom border (thicker)
                                        }
                                    )
                                    // Overlay for thin left/right borders
                                    .overlay(
                                        HStack {
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 0.5) // Left border (thin)
                                            Spacer()
                                            Rectangle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 0.5) // Right border (thin)
                                        }
                                    )
                                    .cornerRadius(6)
                                    .foregroundColor(.white)
                                    .transition(.opacity)
                                
                                
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .onChange(of: scrollTarget) { target in
                    guard let target = target else { return }
                    withAnimation(.easeInOut(duration: 0.5)) {
                        proxy.scrollTo(target, anchor: .top)
                    }
                    scrollTarget = nil
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Label("Back", systemImage: "chevron.backward")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Add Item")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: saveItem) {
                        Label("Save", systemImage: "checkmark.circle")
                    }
                }
            }
            .overlay(alignment: .top) {
                if showSaveToast {
                    Text("Item saved!")
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(.ultraThinMaterial)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                        .padding(.top, 20)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(1)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showSaveToast)
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
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: showImagePicker)
            .onChange(of: selectedImage) {
                guard let newImage = selectedImage else { return }
                Task { await applyResizedImage(newImage) }
            }
            .sheet(isPresented: $isShowingScanner) {
                scannerSheet
            }
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.6, blendDuration: 0.25), value: isShowingScanner)
            .onChange(of: pendingSourceType) {
                guard let source = pendingSourceType else { return }
                imageSourceType = source
                showImagePicker = true
                pendingSourceType = nil
            }
            // (Removed old picker presentation using activePicker)
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

}

// MARK: - Sections
private extension AddItemView {
    func itemInfoSection() -> some View {
        // Not used, see contentBody for new implementation.
        EmptyView()
    }
}

// MARK: - Setup & Helpers
private extension AddItemView {
    func setupView() {
        // Fetch and deduplicate categories
        let fetchedCategories = (try? modelContext.fetch(
            FetchDescriptor<Category>(
                sortBy: [SortDescriptor(\.categoryName, order: .forward)]
            )
        )) ?? []
        categories = Dictionary(grouping: fetchedCategories, by: \.categoryNameWrapped)
            .compactMap { $0.value.first }
            .sorted { $0.categoryNameWrapped < $1.categoryNameWrapped }

        // Fetch boxes
        let fetchedBoxes = (try? modelContext.fetch(FetchDescriptor<Box>(sortBy: [SortDescriptor(\.numberOrName, order: .forward)]))) ?? []
        boxNames = fetchedBoxes

        tempSelectedCategoryID = item.category?.persistentModelID
        tempSelectedBoxID = item.box?.persistentModelID
        // Removed initial scroll/focus to avoid interfering with picker tap gestures
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

    func updateSelectedBox(id: PersistentIdentifier?) {
        tempSelectedBoxID = id
    }

    func saveItem() {
        if item.barcodeValue.trimmingCharacters(in: .whitespaces).isEmpty {
            item.barcodeValue = generateRandomEAN13()
        }
        if let selectedID = tempSelectedCategoryID {
            item.category = categories.first(where: { $0.persistentModelID == selectedID })
        }
        if let selectedID = tempSelectedBoxID {
            item.box = boxNames.first(where: { $0.persistentModelID == selectedID })
        }

        if item.modelContext == nil {
            modelContext.insert(item)
        }
        try? modelContext.save()
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            showSaveToast = true
        }
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
}

// MARK: - Full-Screen Picker View
struct FullScreenPicker<T: Identifiable & Equatable>: View {
    let title: String
    let items: [T]
    let selected: T?
    let label: (T) -> String
    let onSelect: (T?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var searchText: String = ""

    var body: some View {
        List {
            Section {
                ForEach(items.filter { searchText.isEmpty || label($0).localizedCaseInsensitiveContains(searchText) }) { item in
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
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always))
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

// (Removed pickerView(for:) helper and ActivePicker enum, now handled by individual sheet states)
