

import SwiftUI
import CoreImage.CIFilterBuiltins

struct ItemLabelView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.name)
                .font(.system(size: 36, weight: .bold, design: .default))

            if let barcodeImage = generateBarcode(from: item.barcodeValue) {
                Image(uiImage: barcodeImage)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 50)
            }

            if !item.itemDescription.isEmpty {
                Text(item.itemDescription)
                    .font(.body)
            }
        }
        .padding()
        .frame(width: 576, height: 288) // landscape 2.4"x4" at 300 DPI
        .background(Color.white)
    }

    func generateBarcode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            return UIImage(cgImage: cgImage)
        }
        return nil
    }
}
