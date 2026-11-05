import AVFoundation
import Foundation

enum CameraServiceError: LocalizedError {
    case permissionDenied
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput
    case sessionDidNotStart
    case startCancelled
    case sessionNotRunning
    case captureInProgress
    case noImageData

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            "Camera access is off. Allow it in Settings to scan text."
        case .cameraUnavailable:
            "No camera is available on this device."
        case .cannotAddInput, .cannotAddOutput, .sessionDidNotStart:
            "The camera could not start. Try again."
        case .startCancelled:
            "Camera startup was cancelled."
        case .sessionNotRunning:
            "The camera is not ready yet."
        case .captureInProgress:
            "A photo is already being captured."
        case .noImageData:
            "The camera did not return a photo. Try again."
        }
    }
}

/// Mutable capture state is confined to `sessionQueue`. The session is also
/// exposed to CameraPreview so AVFoundation can display it on the main thread.
nonisolated class CameraService: @unchecked Sendable {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "ChineseScanner.CameraSession")
    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private var shouldRun = false
    private var captureDelegate: PhotoCaptureDelegate?

    /// Requests permission when needed, then starts the camera off the main thread.
    /// The completion always runs on the main queue.
    func start(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [self] in
            shouldRun = true
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startAuthorizedSession(completion: completion)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                if granted {
                    self.startAuthorizedSession(completion: completion)
                } else {
                    DispatchQueue.main.async {
                        completion(.failure(CameraServiceError.permissionDenied))
                    }
                }
            }
        case .denied, .restricted:
            DispatchQueue.main.async {
                completion(.failure(CameraServiceError.permissionDenied))
            }
        @unknown default:
            DispatchQueue.main.async {
                completion(.failure(CameraServiceError.permissionDenied))
            }
        }
    }

    func stop() {
        sessionQueue.async { [self] in
            shouldRun = false
            if session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Returns encoded image data without saving the photo to the library.
    /// The completion always runs on the main queue.
    func capturePhoto(completion: @escaping (Result<Data, Error>) -> Void) {
        sessionQueue.async { [self] in
            guard session.isRunning else {
                completeOnMain(.failure(CameraServiceError.sessionNotRunning), completion)
                return
            }
            guard captureDelegate == nil else {
                completeOnMain(.failure(CameraServiceError.captureInProgress), completion)
                return
            }

            let delegate = PhotoCaptureDelegate { [weak self] result in
                guard let self else {
                    DispatchQueue.main.async { completion(result) }
                    return
                }
                self.sessionQueue.async {
                    self.captureDelegate = nil
                    self.completeOnMain(result, completion)
                }
            }
            captureDelegate = delegate
            photoOutput.capturePhoto(with: AVCapturePhotoSettings(), delegate: delegate)
        }
    }

    private func startAuthorizedSession(completion: @escaping (Result<Void, Error>) -> Void) {
        sessionQueue.async { [self] in
            do {
                guard shouldRun else {
                    throw CameraServiceError.startCancelled
                }
                try configureIfNeeded()
                if !session.isRunning {
                    session.startRunning()
                }
                guard session.isRunning else {
                    throw CameraServiceError.sessionDidNotStart
                }
                completeOnMain(.success(()), completion)
            } catch {
                completeOnMain(.failure(error), completion)
            }
        }
    }

    private func configureIfNeeded() throws {
        guard !isConfigured else { return }
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) else {
            throw CameraServiceError.cameraUnavailable
        }

        let input = try AVCaptureDeviceInput(device: camera)
        session.beginConfiguration()
        if session.canSetSessionPreset(.photo) {
            session.sessionPreset = .photo
        }
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            throw CameraServiceError.cannotAddInput
        }
        session.addInput(input)
        guard session.canAddOutput(photoOutput) else {
            session.removeInput(input)
            session.commitConfiguration()
            throw CameraServiceError.cannotAddOutput
        }
        session.addOutput(photoOutput)
        session.commitConfiguration()
        isConfigured = true
    }

    private func completeOnMain<Value>(
        _ result: Result<Value, Error>,
        _ completion: @escaping (Result<Value, Error>) -> Void
    ) {
        DispatchQueue.main.async {
            completion(result)
        }
    }
}

nonisolated private class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let onFinish: (Result<Data, Error>) -> Void
    private var processedResult: Result<Data, Error>?

    init(onFinish: @escaping (Result<Data, Error>) -> Void) {
        self.onFinish = onFinish
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            processedResult = .failure(error)
        } else if let data = photo.fileDataRepresentation() {
            processedResult = .success(data)
        } else {
            processedResult = .failure(CameraServiceError.noImageData)
        }
    }

    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings,
        error: Error?
    ) {
        onFinish(processedResult ?? .failure(error ?? CameraServiceError.noImageData))
    }
}
