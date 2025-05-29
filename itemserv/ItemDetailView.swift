import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if let imageData = item.imageData, let uiImage = UIImage(data: imageData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .cornerRadius(10)
                }
                Text(item.name)
                    .font(.largeTitle.bold())

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.body)
                }

                Divider()

                // Barcode Section
                VStack(alignment: .leading, spacing: 4) {
                    Text("Barcode:")
                        .fontWeight(.bold)
                    if item.barcodeValue.isEmpty {
                        Text("No Barcode")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    } else {
                        Text(item.barcodeValue)
                            .font(.subheadline)
                            .contextMenu {
                                Button(action: {
                                    UIPasteboard.general.string = item.barcodeValue
                                }) {
                                    Label("Copy", systemImage: "doc.on.doc")
                                }
                            }
                    }
                }

                // Category Section
                if let category = item.category {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Category:")
                            .fontWeight(.bold)
                        Text(category.categoryNameWrapped)
                            .font(.subheadline)
                    }
                }

                // Location & Box Section
                if let shelf = item.shelf {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Location:")
                            .fontWeight(.bold)
                        Text("\(item.room?.roomName ?? "No Room") / \(item.sector?.sectorName ?? "No Sector") / \(shelf.shelfName)")
                            .font(.subheadline)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Box:")
                            .fontWeight(.bold)
                        Text("\(item.boxNameRef?.boxNameText ?? "Unboxed") — \(item.boxTypeRef?.boxTypeText ?? "No Box Type")")
                            .font(.subheadline)
                    }
                }

                NavigationLink(destination: EditItemView(item: item)) {
                    Label("Edit Item", systemImage: "pencil")
                        .font(.headline)
                }
                .buttonStyle(.bordered)

                Button {
                    printItemLabel(item)
                } label: {
                    Label("Print Label", systemImage: "printer")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 12)
            }
            .padding()
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    func printItemLabel(_ item: Item) {
        let helper = ItemLabelPrintHelper()
        if let uiImage = helper.generateItemLabel(for: item) {
            let printInfo = UIPrintInfo(dictionary: nil)
            printInfo.outputType = .photo
            printInfo.jobName = item.name

            let controller = UIPrintInteractionController.shared
            controller.printInfo = printInfo
            controller.printingItem = uiImage
            controller.present(animated: true, completionHandler: nil)
        }
    }
}
