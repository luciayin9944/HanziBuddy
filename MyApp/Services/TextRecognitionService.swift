import Foundation
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
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        recognitionQueue.async {
            do {
                let request = VNRecognizeTextRequest()
                request.recognitionLevel = .accurate
                request.usesLanguageCorrection = false

                let supported = try request.supportedRecognitionLanguages()
                let languages = ["zh-Hans", "zh-Hant"].filter(supported.contains)
                guard !languages.isEmpty else {
                    throw TextRecognitionError.chineseRecognitionUnavailable
                }
                request.recognitionLanguages = languages

                let handler = VNImageRequestHandler(data: imageData, options: [:])
                try handler.perform([request])

                let lines = (request.results ?? [])
                    .compactMap { observation -> (text: String, x: CGFloat, y: CGFloat)? in
                        guard let text = observation.topCandidates(1).first?.string else {
                            return nil
                        }
                        return (
                            text: text,
                            x: observation.boundingBox.minX,
                            y: observation.boundingBox.midY
                        )
                    }
                    .sorted { left, right in
                        if left.y != right.y { return left.y > right.y }
                        return left.x < right.x
                    }

                let text = lines.map(\.text).joined(separator: "\n")
                DispatchQueue.main.async { completion(.success(text)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }
    }
}
