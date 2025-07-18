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
        let barcodeHeight: CGFloat = labelHeight - descriptionY - descriptionSize.height - padding * 2 - 10

        // Draw barcode at the bottom
        if let barcodeImage = generateBarcode(from: item.barcodeValue) {
            let barcodeText = item.barcodeValue
            if barcodeText.count == 13 {
                let fullDigits = barcodeText
                let fullDigitsWithoutLeading = String(fullDigits.dropFirst()) // remove the first digit (e.g., "0")
                let firstDigit = String(fullDigitsWithoutLeading.prefix(1)) // use the next digit as the first visible digit
                let visibleDigits = String(fullDigitsWithoutLeading.dropFirst().dropLast())
                let leftGroup = String(visibleDigits.prefix(5))
                let rightGroup = String(visibleDigits.dropFirst(5))
                let trailingDigit = String(fullDigits.suffix(1)) // e.g., "9"

                let digitFont = UIFont.monospacedDigitSystemFont(ofSize: 48, weight: .regular)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: digitFont,
                    .foregroundColor: UIColor.black
                ]

                let leftSize = (leftGroup as NSString).size(withAttributes: attributes)

                // Updated: raise barcode and crop bottom to simulate digit gaps
                let digitHeight = leftSize.height
                let barcodeWidth: CGFloat = labelWidth * 0.9
                let barcodeX = (labelWidth - barcodeWidth) / 2
                let barcodeY = labelHeight - barcodeHeight - padding - digitHeight / 2 + digitHeight / 4

                // Draw barcode slightly taller to mimic full-height
                let barcodeRect = CGRect(x: barcodeX, y: barcodeY, width: barcodeWidth, height: barcodeHeight)
                barcodeImage.draw(in: barcodeRect)

                // Calculate digit Y position (overlap digits with barcode)
                let digitY = barcodeY + barcodeHeight - digitHeight / 2

                let firstDigitSize = (firstDigit as NSString).size(withAttributes: attributes)
                let firstX = barcodeX - firstDigitSize.width - 4
                let firstRect = CGRect(x: firstX - 2, y: digitY, width: firstDigitSize.width + 4, height: digitHeight)
                context.setFillColor(UIColor.white.cgColor)
                context.fill(firstRect)
                (firstDigit as NSString).draw(in: firstRect, withAttributes: attributes)

                // Position last digit to the right of the barcode
                let trailingDigitSize = (trailingDigit as NSString).size(withAttributes: attributes)
                let trailingX = barcodeX + barcodeWidth + 4
                let trailingRect = CGRect(x: trailingX - 2, y: digitY, width: trailingDigitSize.width + 4, height: digitHeight)
                context.setFillColor(UIColor.white.cgColor)
                context.fill(trailingRect)
                (trailingDigit as NSString).draw(in: trailingRect, withAttributes: attributes)

                let innerDigits = Array(leftGroup + rightGroup)
                let totalInnerDigits = innerDigits.count
                let innerDigitSpacing: CGFloat = 15.0 // To tune the spacing between the digits overlapping the barcode (both space before and after each digit, excluding the first and last)

                // Insert an extra space (with white background) between the left and right group
                let middleGap: CGFloat = innerDigitSpacing * 2
                let middleIndex = totalInnerDigits / 2

                // Compute total width for centering, including middle gap
                var totalWidth: CGFloat = 0
                var digitSizes: [CGSize] = []
                for char in innerDigits {
                    let size = (String(char) as NSString).size(withAttributes: attributes)
                    digitSizes.append(size)
                    totalWidth += size.width
                }
                totalWidth += CGFloat(totalInnerDigits - 1) * innerDigitSpacing + middleGap

                var currentX = barcodeX + (barcodeWidth - totalWidth) / 2

                for (index, char) in innerDigits.enumerated() {
                    if index == middleIndex {
                        // Add extra spacing in center
                        currentX += middleGap
                    }

                    let digitStr = String(char)
                    let digitSize = digitSizes[index]

                    // Apply white background (space before and after each digit)
                    let digitRect = CGRect(x: currentX - innerDigitSpacing / 2, y: digitY, width: digitSize.width + innerDigitSpacing, height: digitHeight)
                    context.setFillColor(UIColor.white.cgColor)
                    context.fill(digitRect)

                    // Draw digit centered in rect
                    let digitDrawX = currentX
                    let digitDrawRect = CGRect(x: digitDrawX, y: digitY, width: digitSize.width, height: digitHeight)
                    (digitStr as NSString).draw(in: digitDrawRect, withAttributes: attributes)

                    currentX += digitSize.width + innerDigitSpacing
                }
            }
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()?.withRenderingMode(.alwaysOriginal)
        UIGraphicsEndImageContext()
        return image
    }
    
    private func generateBarcode(from string: String) -> UIImage? {
        let data = string.data(using: .ascii)
        guard let filter = CIFilter(name: "CICode128BarcodeGenerator") else { return nil }
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue(0, forKey: "inputQuietSpace")

        if let outputImage = filter.outputImage {
            let scaleX = 3.0
            let scaleY = 2.0  // updated from 3.0 to 2.0
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            return UIImage(ciImage: transformedImage)
        }
        return nil
    }
}
