import AVFoundation
import SwiftUI

struct CameraPreview: View {
    let session: AVCaptureSession
    @Binding var previewSize: CGSize

    var body: some View {
        GeometryReader { geometry in
            let scanFrame = ScanRegion.frame(in: geometry.size)

            PreviewLayerView(session: session)
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .strokeBorder(.white, lineWidth: 3)
                        .frame(width: scanFrame.width, height: scanFrame.height)
                        .position(x: scanFrame.midX, y: scanFrame.midY)
                }
                .overlay(alignment: .bottom) {
                    Text("Place Chinese text inside the frame.")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(.black.opacity(0.65), in: Capsule())
                        .padding(.bottom, 12)
                }
                .onAppear { previewSize = geometry.size }
                .onChange(of: geometry.size) { _, newSize in
                    previewSize = newSize
                }
        }
        .clipped()
    }
}

private struct PreviewLayerView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.videoGravity = .resizeAspectFill
        view.previewLayer.session = session
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer.session !== session {
            view.previewLayer.session = session
        }
    }

    static func dismantleUIView(_ view: PreviewView, coordinator: ()) {
        view.previewLayer.session = nil
    }

    final class PreviewView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
