//
// LabelPreviewView.swift
//
// This view is the definitive rendering and printing interface for box labels.
// It uses Core Graphics via LabelCanvasRenderer to generate accurate, device-independent output.
//

import SwiftUI


struct LabelPreviewView: View {
    var box: BoxName
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack {
            Image(uiImage: LabelCanvasRenderer.renderLabel(box: box))
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .frame(width: 280, height: 288)
                .border(Color.gray)

            Button("Print Label") {
                printBoxLabel(box: box)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top)

            Button("Share as PDF") {
                LabelRenderer.sharePDF(box: box)
            }
            .buttonStyle(.bordered)
            .padding(.bottom)
        }
        .padding()
        .navigationTitle("Label Preview")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }
    // Print label using the fixed-resolution label renderer
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
}

// ----- DK1202 -----
// for Brother Brother QL-1110NWB / QL-1110NWBc
// Shipping White Paper Labels (300 Labels) DK1202 2.4 in x 3.9 in (62 mm x 100 mm)
// Mark on the tape: 202
struct LabelCanvasRenderer {
    static let dpi: CGFloat = 300
    static let mmToInch: CGFloat = 1 / 25.4
    static let labelWidthMM: CGFloat = 100
    static let labelHeightMM: CGFloat = 62

    static var labelSizePixels: CGSize {
        let width = labelWidthMM * mmToInch * dpi
        let height = labelHeightMM * mmToInch * dpi
        return CGSize(width: width.rounded(), height: height.rounded())
    }

    static func renderLabel(box: BoxName) -> UIImage {
        let size = labelSizePixels

        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            let ctx = context.cgContext
            ctx.setFillColor(UIColor.white.cgColor)
            ctx.fill(CGRect(origin: .zero, size: size))

            // Layout constants
            let padding: CGFloat = 24
            let labelHeight = size.height

            let maxBoxWidth = size.width * 0.40
            var fontSize: CGFloat = labelHeight * 0.48
            if box.boxNameText.count >= 3 {
                var testFont = UIFont.boldSystemFont(ofSize: fontSize)
                var testSize = (box.boxNameText as NSString).size(withAttributes: [.font: testFont])
                while testSize.width > maxBoxWidth && fontSize > 24 {
                    fontSize -= 4
                    testFont = UIFont.boldSystemFont(ofSize: fontSize)
                    testSize = (box.boxNameText as NSString).size(withAttributes: [.font: testFont])
                }
            }
            let boxNumberFont = UIFont.boldSystemFont(ofSize: fontSize)
            let numberSize = (box.boxNameText as NSString).size(withAttributes: [.font: boxNumberFont])

            // --- Category calculation ---
            let sortedItems = box.items?.sorted(by: { $0.name < $1.name }) ?? []
            let itemCountsByCategory = Dictionary(grouping: sortedItems, by: { $0.category?.categoryName ?? "Uncategorized" })
                .mapValues { $0.count }

            let topCategories = itemCountsByCategory
                .sorted { $0.value > $1.value }
                .prefix(3)
                .map { $0.key }

            let categoryFont = UIFont.systemFont(ofSize: 40)
            let categoryAttributes: [NSAttributedString.Key: Any] = [.font: categoryFont, .foregroundColor: UIColor.black]

            var categoryY = padding
            for category in topCategories {
                var truncatedCategory = category
                let maxCharCount = 28
                if truncatedCategory.count > maxCharCount {
                    truncatedCategory = String(truncatedCategory.prefix(maxCharCount - 1)) + "…"
                }

                let attrString = NSAttributedString(string: truncatedCategory, attributes: categoryAttributes)
                attrString.draw(at: CGPoint(x: padding, y: categoryY))
                categoryY += categoryFont.lineHeight
            }
            // --- End Category drawing ---

            let numberAttributes: [NSAttributedString.Key: Any] = [.font: boxNumberFont, .foregroundColor: UIColor.black]
            let numberString = NSAttributedString(string: box.boxNameText, attributes: numberAttributes)
            let leftColumnX: CGFloat = padding - 8
            let barcodeHeight = labelHeight * 0.26
            let boxTextRect = CGRect(
                x: leftColumnX,
                y: categoryY - 18,
                width: maxBoxWidth,
                height: numberSize.height
            )
            numberString.draw(in: boxTextRect)

            let barcodeY = size.height - padding - barcodeHeight
            // The item list should start at the top of the label (padding), not below the box number/barcode.
            var itemY = padding

            // Ensure rightColumnX still provides sufficient spacing from the box number/barcode.
            let rightColumnX = leftColumnX + max(boxTextRect.width, size.width * 0.35) + 36

            let itemNameFont = UIFont.systemFont(ofSize: 40)
            let itemDescFont = UIFont.systemFont(ofSize: 36)

            let availableHeight = size.height - padding

            for item in sortedItems {
                let requiredHeight = itemNameFont.lineHeight + (item.itemDescription.isEmpty ? 12 : (itemDescFont.lineHeight + 12))
                guard itemY + requiredHeight <= availableHeight else { break }

                let nameAttr: [NSAttributedString.Key: Any] = [.font: itemNameFont, .foregroundColor: UIColor.black]
                let nameStr = NSAttributedString(string: item.name, attributes: nameAttr)
                nameStr.draw(at: CGPoint(x: rightColumnX, y: itemY))
                itemY += itemNameFont.lineHeight

                if !item.itemDescription.isEmpty {
                    let descAttr: [NSAttributedString.Key: Any] = [.font: itemDescFont, .foregroundColor: UIColor.darkGray]
                    let descStr = NSAttributedString(string: item.itemDescription, attributes: descAttr)
                    descStr.draw(at: CGPoint(x: rightColumnX, y: itemY))
                    itemY += itemDescFont.lineHeight + 12
                } else {
                    itemY += 12
                }
            }

            if let barcode = LabelRenderer.generateBarcode(from: box.boxNameText) {
                let barcodeWidth = size.width * 0.42
                let barcodeRect = CGRect(
                    x: 0,
                    y: barcodeY,
                    width: barcodeWidth,
                    height: barcodeHeight
                )
                // Clear background behind barcode
                ctx.setFillColor(UIColor.white.cgColor)
                ctx.fill(barcodeRect)
                barcode.draw(in: barcodeRect)
            }
        }
    }
}

enum LabelRenderer {
    static func generateBarcode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(2.0, forKey: "inputQuietSpace") // Reduced quiet space

        guard let outputImage = filter.outputImage else { return nil }

        // Scale barcode to fixed width
        let scaleX: CGFloat = 2.5 // Scale factor (adjust for sharpness)
        let scaleY: CGFloat = 2.5

        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        let context = CIContext()
        if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }

    static func sharePDF(box: BoxName) {
        let image = LabelCanvasRenderer.renderLabel(box: box)
        let size = LabelCanvasRenderer.labelSizePixels
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: size))
        let data = renderer.pdfData { ctx in
            ctx.beginPage()
            image.draw(in: CGRect(origin: .zero, size: size))
        }

        let filename = "BoxLabel-\(box.boxNameText).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? data.write(to: url)

        let controller = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let root = scene.windows.first?.rootViewController {
            root.present(controller, animated: true)
        }
    }
}
