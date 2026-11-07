import Foundation
import ImageIO
import Vision

enum TextRecognitionError: LocalizedError {
    case chineseRecognitionUnavailable

    var errorDescription: String? {
        switch self {
        case .chineseRecognitionUnavailable:
            "Chinese text recognition is unavailable on this device."
        }
    }
}

/// Runs Vision OCR away from the main thread and returns editable text.
nonisolated final class TextRecognitionService: @unchecked Sendable {
    private let recognitionQueue = DispatchQueue(
        label: "ChineseScanner.TextRecognition",
        qos: .userInitiated
    )

    func recognizeText(
        in imageData: Data,
        previewSize: CGSize,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        recognitionQueue.async {
            do {
                let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil)
                let properties = imageSource.flatMap {
                    CGImageSourceCopyPropertiesAtIndex($0, 0, nil) as? [String: Any]
                }
                let width = (properties?[kCGImagePropertyPixelWidth as String] as? NSNumber)?.doubleValue ?? 0
                let height = (properties?[kCGImagePropertyPixelHeight as String] as? NSNumber)?.doubleValue ?? 0
                let orientationValue = (properties?[kCGImagePropertyOrientation as String] as? NSNumber)?.uint32Value ?? 1
                let orientation = CGImagePropertyOrientation(rawValue: orientationValue) ?? .up
                let isRotated = (5...8).contains(orientationValue)
                let imageSize = CGSize(
                    width: isRotated ? height : width,
                    height: isRotated ? width : height
                )
                let scanRect = ScanRegion.visionRect(previewSize: previewSize, imageSize: imageSize)

                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false
                request.regionOfInterest = scanRect

                let supported = try request.supportedRecognitionLanguages()
                let languages = ["zh-Hans", "zh-Hant"].filter(supported.contains)
                guard !languages.isEmpty else {
                    throw TextRecognitionError.chineseRecognitionUnavailable
                }
                request.recognitionLanguages = languages

                let handler = VNImageRequestHandler(
                    data: imageData,
                    orientation: orientation,
                    options: [:]
                )
                try handler.perform([request])

                let closestLine = (request.results ?? [])
                    .compactMap { observation -> (text: String, y: CGFloat)? in
                        guard let text = observation.topCandidates(1).first?.string else {
                            return nil
                        }
                        return (text: text, y: observation.boundingBox.midY)
                    }
                    .min { left, right in
                        abs(left.y - scanRect.midY) < abs(right.y - scanRect.midY)
                    }

                let text = closestLine?.text ?? ""
                DispatchQueue.main.async { completion(.success(text)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}
