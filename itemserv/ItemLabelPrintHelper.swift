import UIKit

class ItemLabelPrintHelper {
    
    func generateItemLabel(for item: Item) -> UIImage? {
        let labelWidth: CGFloat = 696  // 2.4" at 300 DPI
        let labelHeight: CGFloat = 360 // 1.2" at 300 DPI
        let padding: CGFloat = 10
        let barcodeHeight: CGFloat = 200

        UIGraphicsBeginImageContextWithOptions(CGSize(width: labelWidth, height: labelHeight), false, 1.0)
        guard let context = UIGraphicsGetCurrentContext() else { return nil }

        // White background
        UIColor.white.setFill()
        context.fill(CGRect(x: 0, y: 0, width: labelWidth, height: labelHeight))

        // Draw item name and description at the top
        let nameFont = UIFont.systemFont(ofSize: 50, weight: .bold)
        let descFont = UIFont.systemFont(ofSize: 44, weight: .regular)

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

        let descriptionY = nameY + nameSize.height + 4
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

        // Draw barcode at the bottom
        if let barcodeImage = generateBarcode(from: item.barcodeValue) {
            let barcodeY = labelHeight - barcodeHeight - padding
            let barcodeRect = CGRect(x: padding, y: barcodeY, width: labelWidth - 2 * padding, height: barcodeHeight)
            barcodeImage.draw(in: barcodeRect)
        }

        let image = UIGraphicsGetImageFromCurrentImageContext()
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
            let scaleY = 3.0
            let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))
            return UIImage(ciImage: transformedImage)
        }
        return nil
    }
}
