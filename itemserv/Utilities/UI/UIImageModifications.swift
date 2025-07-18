import UIKit

enum ImageCompressionConfig {
    // === selected ===
    // 600 0.25 Good quality ~101 kB Camera
    // 600 0.25 Good quality ~225 kB Library
    // 600 0.25 OK quality ~8 kB Barcode Scanner
    
    // === tested, but skipped ===
    // 600 0.27 Good quality ~95 kB Camera
    // 670 0.25 Good quality ~115 kB Camera
    // 550 0.40 Good quality ~118 kB Camera
    // 600 0.27 Good quality ~132 kB Camera
    // 550 0.50 Good quality ~178 kB Camera
    // 600 0.45 Good quality ~193 kB Camera
    // 550 0.30 Good quality ~130 kB Camera
    // 530 0.28 Mediocre quality ~119 kB Camera
    // 650 0.24 Mediocre quality ~109 kB Camera
    // 570 0.25 Mediocre quality ~83 kB Camera
    // 580 0.26 Mediocre quality ~96 kB Camera
    // 500 0.55 Bad quality ~203 kB Camera
    
    static let maxDimension: CGFloat = 600 // 600 is OK ~100 kB
    static let quality: CGFloat = 0.25 // 0.25 is OK ~100 kB
}

extension UIImage {
    /// Resize image so that the longer side is at most `maxDimension`, preserving aspect ratio.
    func resized(toMaxDimension maxDimension: CGFloat) -> UIImage {
        let originalMax = max(size.width, size.height)
        guard originalMax > maxDimension else { return self } // Skip if no resize needed

        let aspectRatio = size.width / size.height
        let newSize: CGSize

        if aspectRatio > 1 {
            // Landscape
            newSize = CGSize(width: maxDimension, height: maxDimension / aspectRatio)
        } else {
            // Portrait
            newSize = CGSize(width: maxDimension * aspectRatio, height: maxDimension)
        }

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
    /// Resize and compress image to JPEG data.
    func resizedAndCompressed(
        toMaxDimension max: CGFloat = ImageCompressionConfig.maxDimension,
        compressionQuality: CGFloat = ImageCompressionConfig.quality
    ) -> Data? {
        let resizedImage = self.resized(toMaxDimension: max)
        return resizedImage.jpegData(compressionQuality: compressionQuality)
    }
}
