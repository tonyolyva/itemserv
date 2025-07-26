import UIKit

class ItemLabelPrintHelper {
    func generateItemLabel(for item: Item) -> UIImage? {

        // block DK1204 is for smaller label size
        // block DK1205 is for bigger label size
        // uncomment a block DK1205 & comment DK1204
 
        // ----- DK1204 begin -----
        // for Brother Brother QL-1110NWB / QL-1110NWBc
        // DK1204 0.66 in x 2.1 in (17 mm x 54.3 mm) Multipurpose Labels (400 White Paper Labels)
        // Mark on the tape: 204
        let labelWidth: CGFloat = 800  // 0.66" x 2.1"
        let labelHeight: CGFloat = 230 //
        let padding: CGFloat = 3
        // ----- DK1204 end -----

        /*
        // ----- DK1205 begin -----
        // for Brother Brother QL-1110NWB / QL-1110NWBc
        // Black on White Continuous Length Paper Tape DK2205 2.4 in x 100 ft (62 mm x 30.4 m)
        // Mark on the tape: 205
        let labelWidth: CGFloat = 696  // 2.4" at 300 DPI
        let labelHeight: CGFloat = 460 // updated from 420 to 460
        let padding: CGFloat = 10
        // ----- DK1205 end -----
        */
        
        print("🖨️ Preparing to generate label for item: \(item.name), barcode: \(item.barcodeValue)")
        UIGraphicsBeginImageContextWithOptions(CGSize(width: labelWidth, height: labelHeight), false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // White background
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight))


        // Draw item name and description at the top
        let nameFont = UIFont.systemFont(ofSize: 45, weight: .bold)
        let descFont = UIFont.systemFont(ofSize: 45, weight: .regular)

        let nameAttributes: [NSAttributedString.Key: Any] = [
            .font: nameFont,
            .foregroundColor: UIColor.black
        ]

        let descAttributes: [NSAttributedString.Key: Any] = [
            .font: descFont,
            .foregroundColor: UIColor.black
        ]

        let nameSize = (item.name as NSString).size(withAttributes: nameAttributes)
        let nameY = padding
        let nameX = padding
        let nameMaxWidth = labelWidth - 2 * padding
        let nameRect = CGRect(x: nameX, y: nameY, width: nameMaxWidth, height: nameSize.height)
        // Draw truncated name, left-aligned, with ellipsis if needed
        let nameParagraphStyle = NSMutableParagraphStyle()
        nameParagraphStyle.lineBreakMode = .byTruncatingTail
        var nameAttrs = nameAttributes
        nameAttrs[.paragraphStyle] = nameParagraphStyle
        (item.name as NSString).draw(in: nameRect, withAttributes: nameAttrs)
        let descriptionY = nameY + nameSize.height + 1 // + 4
        let descriptionSize = (item.itemDescription as NSString).size(withAttributes: descAttributes)
        let descriptionX = padding
        let descriptionMaxWidth = labelWidth - 2 * padding
        let descriptionRect = CGRect(x: descriptionX, y: descriptionY, width: descriptionMaxWidth, height: descriptionSize.height)
        // Draw truncated description, left-aligned, with ellipsis if needed
        let descParagraphStyle = NSMutableParagraphStyle()
        descParagraphStyle.lineBreakMode = .byTruncatingTail
        var descAttrs = descAttributes
        descAttrs[.paragraphStyle] = descParagraphStyle
        (item.itemDescription as NSString).draw(in: descriptionRect, withAttributes: descAttrs)
        let barcodeHeight: CGFloat = labelHeight * 0.35

        // Draw barcode at the bottom
        print("⚠️ barcodeValue: [\(item.barcodeValue)]")
        let barcodeImage = generateBarcode(from: item.barcodeValue)
        if let barcodeImage = barcodeImage {
            print("✅ Barcode generated successfully")
        } else {
            print("❌ Barcode generation failed")
        }
        if let barcodeImage = barcodeImage, !item.barcodeValue.isEmpty {
            let barcodeWidth: CGFloat = labelWidth * 0.9
            let barcodeX = (labelWidth - barcodeWidth) / 2
            let barcodeY = descriptionY + descriptionSize.height + 4

            let barcodeRect = CGRect(x: barcodeX, y: barcodeY, width: barcodeWidth, height: barcodeHeight)
            barcodeImage.draw(in: barcodeRect)

            // Draw barcode digits, grouped and extended slightly beyond the barcode image
            let barcodeFont = UIFont.monospacedDigitSystemFont(ofSize: 42, weight: .medium)
            let digitAttributes: [NSAttributedString.Key: Any] = [
                .font: barcodeFont,
                .foregroundColor: UIColor.black
            ]

            let digitHeight = ("0" as NSString).size(withAttributes: digitAttributes).height
            let digitY = barcodeY + barcodeHeight - digitHeight + 30

            // Define digit groups (e.g., 6 39277 67064 9)
            let groups = [1, 5, 5, 1] // 6       39277 67064       9
            let extraSpacingIndexes: Set<Int> = [0, 10, 11, 12] // before 3, after 4, before 9, after 9
            var digitIndex = item.barcodeValue.startIndex
            var digitX = barcodeX - 37  // start slightly before barcode

            for groupSize in groups {
                let groupEnd = item.barcodeValue.index(digitIndex, offsetBy: groupSize, limitedBy: item.barcodeValue.endIndex) ?? item.barcodeValue.endIndex
                let group = String(item.barcodeValue[digitIndex..<groupEnd])
                let groupWidth = CGFloat(group.count) * 32

                for (i, char) in group.enumerated() {
                    let digit = String(char) as NSString
                    let digitSize = digit.size(withAttributes: digitAttributes)
                    let horizontalPadding: CGFloat = 22  // 11pt on each side

                    // Compute background rect centered at digit center
                    let digitCenterX = digitX + digitSize.width / 2
                    let backgroundWidth: CGFloat = digitSize.width + horizontalPadding
                    let backgroundRect = CGRect(
                        x: digitCenterX - backgroundWidth / 2,
                        y: digitY,
                        width: backgroundWidth,
                        height: digitSize.height
                    )

                    // Fill white background and draw digit
                    UIColor.white.setFill()
                    context.fill(backgroundRect)

                    // Draw digit centered within its backgroundRect
                    let digitDrawX = backgroundRect.midX - digitSize.width / 2
                    let digitDrawRect = CGRect(x: digitDrawX, y: digitY, width: digitSize.width, height: digitSize.height)
                    digit.draw(in: digitDrawRect, withAttributes: digitAttributes)

                    // Index arithmetic to determine first and last digits
                    let isFirstDigit = digitIndex == item.barcodeValue.startIndex && i == 0
                    let isLastGroup = groupEnd == item.barcodeValue.endIndex
                    let isLastDigit = isLastGroup && i == group.count - 1

                    let globalIndex = item.barcodeValue.distance(from: item.barcodeValue.startIndex, to: item.barcodeValue.index(digitIndex, offsetBy: i))
                    let extraSpace: CGFloat
                    if extraSpacingIndexes.contains(globalIndex) {
                        extraSpace = 110
                    } else {
                        extraSpace = 11 // space between digits
                    }
                    digitX = backgroundRect.maxX + extraSpace
                }

                digitX += 12  // spacing between groups
                digitIndex = groupEnd
            }
        } else {
            // fallback: draw red "No barcode" text at the bottom
            let fallbackText = item.barcodeValue.isEmpty ? "No barcode value" : "Barcode generation failed"
            print("🚫 Fallback text will be drawn: \(fallbackText)")
            let fallbackFont = UIFont.systemFont(ofSize: 32, weight: .semibold)
            let fallbackAttributes: [NSAttributedString.Key: Any] = [
                .font: fallbackFont,
                .foregroundColor: UIColor.red
            ]
            let fallbackSize = (fallbackText as NSString).size(withAttributes: fallbackAttributes)
            let fallbackX = (labelWidth - fallbackSize.width) / 2
            let fallbackY = labelHeight - fallbackSize.height - padding
            let fallbackRect = CGRect(x: fallbackX, y: fallbackY, width: fallbackSize.width, height: fallbackSize.height)
            (fallbackText as NSString).draw(in: fallbackRect, withAttributes: fallbackAttributes)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
        var finalImage: UIImage? = nil
        if let image = image, let cgImage = image.cgImage {
            finalImage = UIImage(cgImage: cgImage)
        }
        UIGraphicsEndImageContext()
        print("🏁 Finished generating label image for: \(item.name)")
        return finalImage
    }
    
    private func generateBarcode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputQuietSpace")

        guard let outputImage = filter.outputImage else { return nil }

        // Scale factors
        let scaleX: CGFloat = 4.0
        let scaleY: CGFloat = 4.0

        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        // Render into a UIImage context with no interpolation
        let extent = transformedImage.extent.integral
        let size = CGSize(width: extent.width, height: extent.height)

        let rendererFormat = UIGraphicsImageRendererFormat()
        rendererFormat.scale = 1
        rendererFormat.opaque = true
        let renderer = UIGraphicsImageRenderer(size: size, format: rendererFormat)

        let uiImage = renderer.image { context in
            let cgContext = context.cgContext
            let ciContext = CIContext()
            if let cgImage = ciContext.createCGImage(transformedImage, from: extent) {
                cgContext.interpolationQuality = .none
                cgContext.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }
        }

        return uiImage
    }
}
