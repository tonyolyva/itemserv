import SwiftData
import SwiftUI
import PhotosUI
import UIKit

struct EditItemView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Bindable var item: Item
    
    @State private var selectedCategory: Category?
    @State private var selectedBox: Box?
    
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
    
    @Query(filter: nil, sort: \Box.numberOrName) private var allBoxes: [Box]
    private var boxes: [Box] {
        let filtered = allBoxes.filter { $0.numberOrName != "None" }
        let deduped = Dictionary(grouping: filtered, by: { $0.numberOrName })
            .compactMap { $0.value.first }
        return deduped.sorted { $0.numberOrName.localizedStandardCompare($1.numberOrName) == .orderedAscending }
    }
    
    private enum ActivePicker: Identifiable {
        case category, box
        var id: String {
            switch self {
            case .category: return "category"
            case .box: return "box"
            }
        }
    }
    @State private var activePicker: ActivePicker?
    
    init(item: Item) {
        self.item = item
        _selectedCategory = State(initialValue: item.category)
        _selectedBox = State(initialValue: item.box)
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
                    
                    // Detect if box changed (move scenario)
                    let oldBox = item.box
                    let newBox = selectedBox
                    
                    item.category = selectedCategory
                    item.box = newBox
                    item.lastUpdated = Date()
                    
                    if oldBox?.id != newBox?.id {
                        // Update timestamps
                        if let oldBox {
                            oldBox.lastModified = Date()
                            print("Updated lastModified for old box: \(oldBox.numberOrName)")
                        }
                        if let newBox {
                            newBox.lastModified = Date()
                            print("Updated lastModified for new box: \(newBox.numberOrName)")
                        }
                        
                        // Post notification for LocationView to refresh
                        NotificationCenter.default.post(
                            name: Notification.Name("boxItemMoved"),
                            object: nil,
                            userInfo: ["oldBox": oldBox as Any, "newBox": newBox as Any]
                        )
                    }
                    
                    try? modelContext.save() // Persist changes
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
                        if let urlStr = result.images?.first,
                           let url = URL(string: urlStr),
                           let data = try? Data(contentsOf: url),
                           let uiImage = UIImage(data: data) {
                            let resized = uiImage.resizedAndCompressed(toMaxDimension: ImageCompressionConfig.maxDimension, compressionQuality: ImageCompressionConfig.quality)
                            if let resized {
                                item.imageData = resized
                                selectedImage = UIImage(data: resized)
                            }
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
            if selectedImage == nil, let data = item.imageData {
                selectedImage = UIImage(data: data)
            }
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
                }
            case .box:
                NavigationStack {
                    FullScreenPicker(
                        title: "Box",
                        items: boxes,
                        selected: selectedBox,
                        label: { box in
                            let count = box.items?.count ?? 0
                            return count > 0
                                ? "📦 \(box.numberOrName)    ✨ \(count)"
                                : "📦 \(box.numberOrName)"
                        },
                        onSelect: { selectedBox = $0 }
                    )
                }
            }
        }
    }
    
    private var contentView: some View {
        Form {
            Section(header: Text("Item Name")) {
                TextField("Name", text: $item.name)
            }
            Section(header: Text("Item Description")) {
                TextField("Description", text: $item.itemDescription)
            }
            Section(header: Text("Barcode")) {
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
            }
            HStack {
                Text("Category")
                Spacer()
                Text(selectedCategory?.categoryNameWrapped ?? "None")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { activePicker = .category }
            
            HStack {
                Text("Box")
                Spacer()
                Text(selectedBox?.numberOrName ?? "None")
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture { activePicker = .box }
            
            Section(header: Text("Photo")) {
                if let selectedImage {
                    Image(uiImage: selectedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 200)
                        .cornerRadius(12)
                }
            }
            Section(header: Text("Replace Photo")) {
                PhotoSourcePickerView(
                    onSelectLibrary: { pendingSourceType = .photoLibrary },
                    onSelectCamera: { pendingSourceType = .camera }
                )
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets())
            }
        }
    }
}
