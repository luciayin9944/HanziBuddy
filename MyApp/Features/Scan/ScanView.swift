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

    var recognizedText: String? {
        if case .recognized(let text) = self { return text }
        return nil
    }
}

struct ScanView<CameraContent: View>: View {
    let state: ScanViewState
    let onCapture: () -> Void
    let onRetry: () -> Void
    let onOpenSettings: () -> Void
    let onContinue: (String) -> Void
    let onUseSampleImage: (() -> Void)?
    let cameraContent: CameraContent

    @State private var editedText: String

    init(
        state: ScanViewState,
        onCapture: @escaping () -> Void,
        onRetry: @escaping () -> Void,
        onOpenSettings: @escaping () -> Void,
        onContinue: @escaping (String) -> Void,
        onUseSampleImage: (() -> Void)? = nil,
        @ViewBuilder cameraContent: () -> CameraContent
    ) {
        self.state = state
        self.onCapture = onCapture
        self.onRetry = onRetry
        self.onOpenSettings = onOpenSettings
        self.onContinue = onContinue
        self.onUseSampleImage = onUseSampleImage
        self.cameraContent = cameraContent()
        _editedText = State(initialValue: state.recognizedText ?? "")
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

            case .recognized:
                Text("Recognized text")
                TextEditor(text: $editedText)
                    .frame(height: 150)
                    .border(.gray)
                Button("Continue") {
                    onContinue(editedText.trimmingCharacters(in: .whitespacesAndNewlines))
                }
                .disabled(editedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button("Rescan", action: onRetry)

            case .requestingPermission:
                ProgressView("Checking camera access…")

            case .permissionDenied:
                Text("Allow camera access in Settings to scan Chinese text.")
                Button("Open Settings", action: onOpenSettings)

            case .cameraUnavailable:
                Text("Camera unavailable")
                Button("Rescan", action: onRetry)
#if DEBUG
                if let onUseSampleImage {
                    Button("Try sample image", action: onUseSampleImage)
                }
#endif

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
        .onChange(of: state) { _, newState in
            if let text = newState.recognizedText {
                editedText = text
            }
        }
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
    @State private var correctedText = ""
    @State private var isShowingText = false

    var body: some View {
        ScanView(
            state: state,
            onCapture: capturePhoto,
            onRetry: startCamera,
            onOpenSettings: openSettings,
            onContinue: { text in
                correctedText = text
                isShowingText = true
            },
            onUseSampleImage: useSampleImage
        ) {
            CameraPreview(session: camera.session)
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
        .alert("Text ready", isPresented: $isShowingText) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(correctedText)
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
        state = .capturing
        camera.capturePhoto { result in
            guard isActive else { return }
            camera.stop()
            switch result {
            case .success(let imageData):
                recognizeText(in: imageData)
            case .failure(let error):
                state = .failed(error.localizedDescription)
            }
        }
    }

    private func recognizeText(in imageData: Data) {
        state = .recognizing
        recognizer.recognizeText(in: imageData) { result in
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

    private func useSampleImage() {
#if DEBUG
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 400)).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 400))
            ("大树真高" as NSString).draw(
                at: CGPoint(x: 80, y: 100),
                withAttributes: [
                    .font: UIFont.systemFont(ofSize: 140),
                    .foregroundColor: UIColor.black
                ]
            )
        }
        guard let imageData = image.pngData() else {
            state = .failed("The sample image could not be created.")
            return
        }
        recognizeText(in: imageData)
#endif
    }
}

#Preview("Camera") {
    NavigationStack {
        ScanView(
            state: .ready,
            onCapture: {},
            onRetry: {},
            onOpenSettings: {},
            onContinue: { _ in }
        ) {
            Color.black
        }
    }
}

#Preview("Recognized text") {
    NavigationStack {
        ScanView(
            state: .recognized("大树真高"),
            onCapture: {},
            onRetry: {},
            onOpenSettings: {},
            onContinue: { _ in }
        ) {
            Color.black
        }
    }
}

#Preview("Permission denied") {
    NavigationStack {
        ScanView(
            state: .permissionDenied,
            onCapture: {},
            onRetry: {},
            onOpenSettings: {},
            onContinue: { _ in }
        ) {
            Color.black
        }
    }
}
