import SwiftUI

struct ItemDetailView: View {
    let item: Item
    @Environment(\.dismiss) private var dismiss
    @State private var processedUIImage: UIImage?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                itemImageView

                Text(item.name)
                    .font(.largeTitle.bold())

                if !item.itemDescription.isEmpty {
                    Text(item.itemDescription)
                        .font(.body)
                }

                // Status info section (added/updated)
                Text(relativeUpdateText(for: item))
                    .font(.subheadline)
                    .foregroundColor(.blue)

                Divider()
                barcodeSection
                categorySection
                locationAndBoxSection

                HStack {
                    NavigationLink(destination: EditItemView(item: item)) {
                        Label("Edit Item", systemImage: "pencil")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)

                    Spacer()

                    Button {
                        printItemLabel(item)
                    } label: {
                        Label("Print Label", systemImage: "printer")
                            .font(.headline)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                }
                .padding(.top, 12)
            }
            .padding()
        }
        .navigationTitle("Item Details")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            processItemImageIfNeeded()
        }
    }

private func relativeUpdateText(for item: Item) -> String {
    let now = Date()
    let interval: TimeInterval
    let prefix: String

    if abs(item.lastUpdated.timeIntervalSince(item.dateAdded)) > 5 {
        interval = now.timeIntervalSince(item.lastUpdated)
        prefix = "✏️"
    } else {
        interval = now.timeIntervalSince(item.dateAdded)
        prefix = "🆕"
    }

    let seconds = Int(interval)
    let minutes = seconds / 60
    let hours = minutes / 60
    let days = hours / 24
    let months = days / 30
    let years = days / 365

    let formatted: String
    if seconds < 60 {
        formatted = "\(seconds)s"
    } else if minutes < 60 {
        formatted = "\(minutes)m"
    } else if hours < 24 {
        formatted = "\(hours)h"
    } else if days < 30 {
        formatted = "\(days)d"
    } else if months < 12 {
        formatted = "\(months)mo"
    } else {
        formatted = "\(years)y"
    }

    return "\(prefix) \(formatted) ago"
}

    private func processItemImageIfNeeded() {
        guard processedUIImage == nil,
              let imageData = item.imageData,
              let originalUIImage = UIImage(data: imageData),
              let compressedData = originalUIImage.resizedAndCompressed(
                  toMaxDimension: ImageCompressionConfig.maxDimension,
                  compressionQuality: ImageCompressionConfig.quality),
              let uiImage = UIImage(data: compressedData) else {
            return
        }
        processedUIImage = uiImage
    }

    private var itemImageView: some View {
        if let uiImage = processedUIImage {
            return AnyView(
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .cornerRadius(10)
            )
        } else {
            return AnyView(EmptyView())
        }
    }

    private var barcodeSection: some View {
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
    }

    private var categorySection: some View {
        Group {
            if let category = item.category {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Category:")
                        .fontWeight(.bold)
                    Text(category.categoryNameWrapped)
                        .font(.subheadline)
                }
            }
        }
    }

    private var locationAndBoxSection: some View {
        Group {
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
        }
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
