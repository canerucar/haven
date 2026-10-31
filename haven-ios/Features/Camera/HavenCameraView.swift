import AVFoundation
import SwiftUI
import UIKit

struct HavenCameraView: View {
    let onCapture: (UIImage) -> Void
    let onClose: () -> Void

    @StateObject private var camera = HavenCameraService()
    @State private var shutterFlash = false
    @State private var selectedLens = "35mm"
    @State private var flashMode: AVCaptureDevice.FlashMode = .auto
    @State private var frameCount = 24

    var body: some View {
        ZStack {
            // Dark Analog Camera Body
            Color(red: 0.10, green: 0.09, blue: 0.08).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top Camera Bar
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 10)

                // Viewfinder Area
                viewfinder
                    .padding(.horizontal, 16)

                Spacer(minLength: 10)

                // Bottom Controls & Shutter
                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }

            // Shutter Flash Effect
            if shutterFlash {
                Color.black
                    .ignoresSafeArea()
                    .transition(.opacity)
            }
        }
        .onAppear {
            camera.start()
        }
        .onDisappear {
            camera.stop()
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }

            Spacer()

            // Retro Film Counter
            HStack(spacing: 6) {
                Image(systemName: "film")
                    .font(.caption2)
                    .foregroundStyle(Color(red: 0.88, green: 0.45, blue: 0.18))
                Text("EXP \(String(format: "%02d", frameCount)) / 36")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.45))
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )

            Spacer()

            // Flash Mode Toggle
            Button {
                HavenHaptics.selection()
                flashMode = flashMode == .auto ? .on : (flashMode == .on ? .off : .auto)
            } label: {
                Image(systemName: flashMode == .on ? "bolt.fill" : (flashMode == .auto ? "bolt.badge.a.fill" : "bolt.slash.fill"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(flashMode == .off ? .white.opacity(0.4) : Color(red: 0.95, green: 0.75, blue: 0.25))
                    .frame(width: 40, height: 40)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Viewfinder
    private var viewfinder: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            let height = min(proxy.size.height, width * (4 / 3))

            ZStack {
                // Live Camera or Simulator Fallback
                if camera.isSimulator || !camera.isAuthorized {
                    simulatorViewfinderPreview
                } else {
                    CameraPreviewView(session: camera.session)
                }

                // Analog Viewfinder Reticle & Grid
                VStack {
                    HStack {
                        reticleCorner(angle: 0)
                        Spacer()
                        reticleCorner(angle: 90)
                    }
                    Spacer()
                    // Center Focus Crosshair
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.45), lineWidth: 1)
                            .frame(width: 50, height: 50)
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 10, height: 1)
                        Rectangle()
                            .fill(Color.white.opacity(0.6))
                            .frame(width: 1, height: 10)
                    }
                    Spacer()
                    HStack {
                        reticleCorner(angle: 270)
                        Spacer()
                        reticleCorner(angle: 180)
                    }
                }
                .padding(24)

                // Lens Badge Overlay
                VStack {
                    Spacer()
                    HStack {
                        Text("HAVEN 35MM ATELIER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                        Spacer()
                        Text("ƒ/1.8 • \(selectedLens)")
                            .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.25))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Capsule())
                    }
                    .padding(16)
                }
            }
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.white.opacity(0.18), lineWidth: 1.5)
            )
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func reticleCorner(angle: Double) -> some View {
        Path { path in
            path.move(to: CGPoint(x: 0, y: 14))
            path.addLine(to: CGPoint(x: 0, y: 0))
            path.addLine(to: CGPoint(x: 14, y: 0))
        }
        .stroke(Color.white.opacity(0.7), lineWidth: 2)
        .frame(width: 14, height: 14)
        .rotationEffect(.degrees(angle))
    }

    // MARK: - Simulator Fallback View
    private var simulatorViewfinderPreview: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.22, green: 0.20, blue: 0.18),
                    Color(red: 0.14, green: 0.13, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 12) {
                Image(systemName: "camera.aperture")
                    .font(.system(size: 48, weight: .ultraLight))
                    .foregroundStyle(Color(red: 0.88, green: 0.45, blue: 0.18))

                Text("35mm Analog Viewfinder")
                    .font(.system(size: 16, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)

                Text("Tap the shutter button to take a sample photo")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    // MARK: - Bottom Controls & Shutter
    private var bottomBar: some View {
        VStack(spacing: 20) {
            // Focal Length Dial
            HStack(spacing: 20) {
                ForEach(["28mm", "35mm", "50mm"], id: \.self) { lens in
                    Button {
                        HavenHaptics.selection()
                        selectedLens = lens
                    } label: {
                        Text(lens)
                            .font(.system(size: 13, weight: selectedLens == lens ? .bold : .medium, design: .monospaced))
                            .foregroundStyle(selectedLens == lens ? Color(red: 0.95, green: 0.75, blue: 0.25) : .white.opacity(0.45))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(selectedLens == lens ? Color.white.opacity(0.12) : Color.clear)
                            .clipShape(Capsule())
                    }
                }
            }

            // Shutter Button Row
            HStack {
                // Switch Camera (Front / Back)
                Button {
                    HavenHaptics.light()
                    camera.switchCamera()
                } label: {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .frame(width: 52, height: 52)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }

                Spacer()

                // Mechanical Shutter Button
                Button {
                    triggerShutter()
                } label: {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.white.opacity(0.25), lineWidth: 4)
                            .frame(width: 82, height: 82)

                        Circle()
                            .fill(Color.white)
                            .frame(width: 66, height: 66)
                            .shadow(color: .white.opacity(0.2), radius: 8, x: 0, y: 0)

                        Circle()
                            .fill(Color(red: 0.88, green: 0.45, blue: 0.18))
                            .frame(width: 14, height: 14)
                    }
                }

                Spacer()

                // Decorative balancing spacer or gallery hint
                Color.clear
                    .frame(width: 52, height: 52)
            }
        }
    }

    private func triggerShutter() {
        HavenHaptics.medium()
        withAnimation(.easeIn(duration: 0.08)) {
            shutterFlash = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            withAnimation(.easeOut(duration: 0.18)) {
                shutterFlash = false
            }
        }

        frameCount = max(frameCount - 1, 1)

        camera.takePhoto { capturedImage in
            HavenHaptics.success()
            onCapture(capturedImage)
        }
    }
}

// MARK: - Camera Service & Simulator Mock
final class HavenCameraService: NSObject, ObservableObject {
    @Published var isAuthorized = false
    @Published var isSimulator = false

    let session = AVCaptureSession()
    private var photoOutput = AVCapturePhotoOutput()
    private var photoCompletion: ((UIImage) -> Void)?
    private var currentPosition: AVCaptureDevice.Position = .back

    override init() {
        super.init()
        #if targetEnvironment(simulator)
        isSimulator = true
        #else
        checkPermission()
        #endif
    }

    func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupSession()
                    }
                }
            }
        default:
            isAuthorized = false
        }
    }

    private func setupSession() {
        guard !isSimulator else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo

        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func start() {
        guard !isSimulator, isAuthorized else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.startRunning()
        }
    }

    func stop() {
        guard !isSimulator, session.isRunning else { return }
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.session.stopRunning()
        }
    }

    func switchCamera() {
        guard !isSimulator else { return }
        currentPosition = currentPosition == .back ? .front : .back
        session.beginConfiguration()
        session.inputs.forEach { session.removeInput($0) }
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: currentPosition),
           let input = try? AVCaptureDeviceInput(device: device),
           session.canAddInput(input) {
            session.addInput(input)
        }
        session.commitConfiguration()
    }

    func takePhoto(completion: @escaping (UIImage) -> Void) {
        #if targetEnvironment(simulator)
        // Generate a rich aesthetic sample photo for simulator testing
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            let sample = Self.renderSimulatorAestheticImage()
            completion(sample)
        }
        #else
        guard session.isRunning else {
            let sample = Self.renderSimulatorAestheticImage()
            completion(sample)
            return
        }
        photoCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
        #endif
    }

    static func renderSimulatorAestheticImage() -> UIImage {
        let size = CGSize(width: 1200, height: 1600)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            // Warm sunset gradient
            let colors = [
                UIColor(red: 0.94, green: 0.72, blue: 0.58, alpha: 1.0).cgColor,
                UIColor(red: 0.78, green: 0.42, blue: 0.32, alpha: 1.0).cgColor,
                UIColor(red: 0.32, green: 0.22, blue: 0.24, alpha: 1.0).cgColor
            ]
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let locations: [CGFloat] = [0.0, 0.5, 1.0]
            if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) {
                ctx.cgContext.drawLinearGradient(
                    gradient,
                    start: CGPoint(x: size.width * 0.2, y: 0),
                    end: CGPoint(x: size.width * 0.8, y: size.height),
                    options: []
                )
            }

            // Minimal sun circle
            ctx.cgContext.setFillColor(UIColor(red: 0.98, green: 0.92, blue: 0.82, alpha: 0.85).cgColor)
            ctx.cgContext.fillEllipse(in: CGRect(x: size.width * 0.35, y: size.height * 0.25, width: 360, height: 360))
        }
    }
}

extension HavenCameraService: AVCapturePhotoCaptureDelegate {
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else { return }
        photoCompletion?(image)
        photoCompletion = nil
    }
}

// MARK: - Camera Preview Layer Wrapper
struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewUIView, context: Context) {}

    class PreviewUIView: UIView {
        override class var layerClass: AnyClass {
            AVCaptureVideoPreviewLayer.self
        }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }
    }
}
