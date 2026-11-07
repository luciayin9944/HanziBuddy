import SwiftUI
import UIKit

enum ScanViewState: Equatable {
    case requestingPermission
    case ready
    case capturing
    case recognizing
    case recognized(String)
    case noText
    case permissionDenied
    case cameraUnavailable
    case failed(String)

}

struct ScanView<CameraContent: View>: View {
    let state: ScanViewState
    let onCapture: () -> Void
    let onRetry: () -> Void
    let onOpenSettings: () -> Void
    let onContinue: (String) -> Void
    let cameraContent: CameraContent

    init(
        state: ScanViewState,
        onCapture: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onContinue: @escaping (String) -> Void,
        @ViewBuilder cameraContent: () -> CameraContent
    ) {
        self.state = state
        self.onCapture = onCapture
        self.onRetry = onRetry
        self.onOpenSettings = onOpenSettings
        self.onContinue = onContinue
        self.cameraContent = cameraContent()
    }

    var body: some View {
        VStack(spacing: 20) {
            switch state {
            case .ready, .capturing, .recognizing:
                cameraContent
                    .frame(height: 350)
                    .background(.black)

                if state == .ready {
                    Button(action: onCapture) {
                        Label("Take photo", systemImage: "camera.viewfinder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                } else {
                    ProgressView(state == .capturing ? "Taking photo…" : "Recognizing text…")
                }

            case .recognized(let text):
                Text("Recognized text")
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 12))
                Button("Continue") {
                    onContinue(text.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                Button("Rescan", action: onRetry)

            case .requestingPermission:
                ProgressView("Checking camera access…")

            case .permissionDenied:
                Text("Allow camera access in Settings to scan Chinese text.")
                Button("Open Settings", action: onOpenSettings)

            case .cameraUnavailable:
                Text("Camera unavailable")
                Button("Rescan", action: onRetry)

            case .noText:
                Text("No Chinese text found")
                Button("Rescan", action: onRetry)

            case .failed(let message):
                Text("Scan failed: \(message)")
                Button("Rescan", action: onRetry)
            }
        }
        .padding()
        .navigationTitle("Scan")
    }

}

/// Connects the scan screen to the camera and on-device text recognition.
struct ScanFlowView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.scenePhase) private var scenePhase

    @State private var camera = CameraService()
    @State private var recognizer = TextRecognitionService()
    @State private var state: ScanViewState = .requestingPermission
    @State private var isActive = false
    @State private var recognizedText = ""
    @State private var isShowingConfirmation = false
    @State private var cameraPreviewSize: CGSize = .zero

    var body: some View {
        ScanView(
            state: state,
            onCapture: capturePhoto,
            onRetry: startCamera,
            onOpenSettings: openSettings,
            onContinue: { text in
                recognizedText = text
                isShowingConfirmation = true
            }
        ) {
            CameraPreview(session: camera.session, previewSize: $cameraPreviewSize)
        }
        .navigationDestination(isPresented: $isShowingConfirmation) {
            ConfirmCharacterView(
                recognizedText: recognizedText,
                onRescan: { isShowingConfirmation = false }
            )
        }
        .onAppear {
            isActive = true
            startCamera()
        }
        .onDisappear {
            isActive = false
            camera.stop()
        }
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                if isActive && (state == .permissionDenied || state == .requestingPermission) {
                    startCamera()
                }
            case .background:
                if state == .ready || state == .capturing || state == .requestingPermission {
                    camera.stop()
                    state = .requestingPermission
                }
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }

    private func startCamera() {
        guard isActive else { return }
        state = .requestingPermission
        camera.start { result in
            guard isActive else { return }
            switch result {
            case .success:
                state = .ready
            case .failure(let error):
                if let cameraError = error as? CameraServiceError {
                    switch cameraError {
                    case .permissionDenied:
                        state = .permissionDenied
                    case .cameraUnavailable:
                        state = .cameraUnavailable
                    case .startCancelled:
                        return
                    default:
                        state = .failed(cameraError.localizedDescription)
                    }
                } else {
                    state = .failed(error.localizedDescription)
                }
            }
        }
    }

    private func capturePhoto() {
        guard state == .ready else { return }
        let previewSize = cameraPreviewSize
        state = .capturing
        camera.capturePhoto { result in
            guard isActive else { return }
            camera.stop()
            switch result {
            case .success(let imageData):
                recognizeText(in: imageData, previewSize: previewSize)
            case .failure(let error):
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func recognizeText(in imageData: Data, previewSize: CGSize) {
        state = .recognizing
        recognizer.recognizeText(in: imageData, previewSize: previewSize) { result in
            guard isActive else { return }
            switch result {
            case .success(let text):
                state = text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? .noText
                    : .recognized(text)
            case .failure(let error):
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        openURL(url)
    }
}
