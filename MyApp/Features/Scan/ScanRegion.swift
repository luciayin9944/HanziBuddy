import CoreGraphics

/// The same one-line area is drawn over the preview and used for OCR.
enum ScanRegion {
    static let previewRect = CGRect(x: 0.06, y: 0.41, width: 0.88, height: 0.18)

    static func frame(in previewSize: CGSize) -> CGRect {
        CGRect(
            x: previewRect.minX * previewSize.width,
            y: previewRect.minY * previewSize.height,
            width: previewRect.width * previewSize.width,
            height: previewRect.height * previewSize.height
        )
    }

    /// Maps the visible frame through the preview's aspect-fill crop into Vision coordinates.
    static func visionRect(previewSize: CGSize, imageSize: CGSize) -> CGRect {
        guard previewSize.width > 0, previewSize.height > 0,
              imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(
                x: previewRect.minX,
                y: 1 - previewRect.maxY,
                width: previewRect.width,
                height: previewRect.height
            )
        }

        let scale = max(
            previewSize.width / imageSize.width,
            previewSize.height / imageSize.height
        )
        let cropX = (imageSize.width * scale - previewSize.width) / 2
        let cropY = (imageSize.height * scale - previewSize.height) / 2
        let visibleFrame = frame(in: previewSize)

        return CGRect(
            x: (visibleFrame.minX + cropX) / (imageSize.width * scale),
            y: 1 - (visibleFrame.maxY + cropY) / (imageSize.height * scale),
            width: visibleFrame.width / (imageSize.width * scale),
            height: visibleFrame.height / (imageSize.height * scale)
        )
    }
}
