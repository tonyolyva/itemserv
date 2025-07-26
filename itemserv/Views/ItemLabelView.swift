import SwiftUI
import CoreImage.CIFilterBuiltins

struct ItemLabelView: View {
    let item: Item

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(item.name)
                .font(.system(size: 36, weight: .bold, design: .default))

            Text("DEBUG: barcodeValue = \(item.barcodeValue)")
                .font(.caption2)
                .foregroundColor(.gray)

            if let barcodeImage = generateBarcode(from: item.barcodeValue) {
                VStack(spacing: 4) {
                    Image(uiImage: barcodeImage)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 250, height: 50)
                        .border(Color.red, width: 2)
                    Text(item.barcodeValue)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            } else {
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(Color.yellow.opacity(0.3))
                        .frame(width: 250, height: 50)
                        .overlay(Text("NO BARCODE IMAGE")
                                    .foregroundColor(.red)
                                    .font(.caption)
                                    .bold()
                        )
                    Text("BARCODE VALUE: \(item.barcodeValue)")
                        .font(.caption)
                        .foregroundColor(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
            }
            
            if !item.itemDescription.isEmpty {
                Text(item.itemDescription)
                    .font(.body)
            }
        }
        .background(Color.white)
        .frame(width: 576, height: 288) // landscape 2.4"x4" at 300 DPI
        .border(Color.green)
        .overlay(Text("RENDERED").font(.caption).foregroundColor(.red).padding(4), alignment: .topTrailing)
        .padding()
    }

    func generateBarcode(from string: String) -> UIImage? {
        let context = CIContext()
        let filter = CIFilter.code128BarcodeGenerator()
        filter.message = Data(string.utf8)

        if let outputImage = filter.outputImage,
           let cgImage = context.createCGImage(outputImage, from: outputImage.extent) {
            print("✅ Barcode generated successfully for string: \(string)")
            return UIImage(cgImage: cgImage)
        }
        print("❌ Failed to generate barcode for string: \(string)")
        return nil
    }
}
