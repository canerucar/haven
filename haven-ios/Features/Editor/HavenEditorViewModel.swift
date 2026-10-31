import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class HavenEditorViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var selectedTool: HavenTool = .photo
    @Published var selectedFilter: HavenFilter = .natural

    // Adjustments
    @Published var brightness: Double = 0.0
    @Published var saturation: Double = 1.0
    @Published var contrast: Double = 1.0

    // Analog & Film Effects
    @Published var grainIntensity: Double = 0.0
    @Published var vignetteIntensity: Double = 0.0
    @Published var lightLeak: HavenLightLeak = .none
    @Published var showDateStamp: Bool = false

    // Canvas & Frames
    @Published var canvasBackground: HavenCanvasBackground = .paper
    @Published var frameStyle: HavenFrameStyle = .none
    @Published var canvasPadding: CGFloat = 0.0
    @Published var hasPaperTexture: Bool = true

    // Transforms
    @Published var photoOffset: CGSize = .zero
    @Published var photoScale: CGFloat = 1.0

    // Typography
    @Published var text: String = ""
    @Published var textPosition: CGPoint = .zero
    @Published var textColor: HavenTextColor = .white
    @Published var fontFamily: HavenFontFamily = .serif
    @Published var textSize: CGFloat = 26

    // Saved state
    @Published private(set) var hasSavedDraft = false

    // Alerts & Export
    @Published var alertMessage: String?
    @Published var showAlert: Bool = false
    @Published var exportImage: UIImage?
    @Published var showShareSheet: Bool = false

    var dateStampFormatted: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "' 'yy  M  d"
        return formatter.string(from: Date())
    }

    private func draftKey(for format: HavenFormat) -> String {
        "haven.editor.draft.\(format.rawValue.lowercased())"
    }

    private func draftImageUrl(for format: HavenFormat) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("haven_draft_\(format.rawValue.lowercased()).jpg")
    }

    func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        self.image = uiImage
        self.resetPhotoTransform()
    }

    func removePhoto() {
        self.image = nil
        self.resetPhotoTransform()
    }

    func apply(_ filter: HavenFilter) {
        selectedFilter = filter
        brightness = filter.brightness
        saturation = filter.saturation
        contrast = filter.contrast
    }

    func applyFrameStyle(_ style: HavenFrameStyle) {
        frameStyle = style
        switch style {
        case .none:
            canvasPadding = 0
        case .matte:
            canvasPadding = 24
        case .polaroid:
            canvasPadding = 18
        case .film:
            canvasPadding = 16
        case .minimalLine:
            canvasPadding = 14
        }
    }

    func applyBadge(_ badge: HavenEditorialBadge) {
        text = badge.rawValue
        fontFamily = .serif
        textSize = 20
        textColor = .white
    }

    func resetAdjustments() {
        selectedFilter = .natural
        brightness = 0.0
        saturation = 1.0
        contrast = 1.0
        grainIntensity = 0.0
        vignetteIntensity = 0.0
        lightLeak = .none
    }

    func resetPhotoTransform() {
        photoOffset = .zero
        photoScale = 1.0
    }

    func saveDraft(format: HavenFormat) {
        let hasImage = image != nil

        if let image, let url = draftImageUrl(for: format) {
            if let jpeg = image.jpegData(compressionQuality: 0.85) {
                try? jpeg.write(to: url)
            }
        }

        let draft = HavenDraft(
            format: format,
            text: text,
            filter: selectedFilter,
            brightness: brightness,
            saturation: saturation,
            contrast: contrast,
            canvasBackground: canvasBackground,
            frameStyle: frameStyle,
            canvasPadding: canvasPadding,
            grainIntensity: grainIntensity,
            vignetteIntensity: vignetteIntensity,
            lightLeak: lightLeak,
            showDateStamp: showDateStamp,
            textPosition: textPosition,
            textColor: textColor,
            fontFamily: fontFamily,
            textSize: textSize,
            photoScale: photoScale,
            photoOffsetX: photoOffset.width,
            photoOffsetY: photoOffset.height,
            hasImage: hasImage
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey(for: format))
        hasSavedDraft = true
        triggerAlert("Draft saved successfully.")
    }

    func loadDraft(format: HavenFormat) {
        guard let data = UserDefaults.standard.data(forKey: draftKey(for: format)),
              let draft = try? JSONDecoder().decode(HavenDraft.self, from: data) else { return }

        text = draft.text
        selectedFilter = draft.filter
        brightness = draft.brightness
        saturation = draft.saturation
        contrast = draft.contrast
        canvasBackground = draft.canvasBackground
        frameStyle = draft.frameStyle
        canvasPadding = draft.canvasPadding
        grainIntensity = draft.grainIntensity
        vignetteIntensity = draft.vignetteIntensity
        lightLeak = draft.lightLeak
        showDateStamp = draft.showDateStamp
        textPosition = draft.textPosition
        textColor = draft.textColor
        fontFamily = draft.fontFamily
        textSize = draft.textSize
        photoScale = draft.photoScale
        photoOffset = CGSize(width: draft.photoOffsetX, height: draft.photoOffsetY)

        if draft.hasImage, let url = draftImageUrl(for: format),
           let data = try? Data(contentsOf: url),
           let loadedImage = UIImage(data: data) {
            image = loadedImage
        }
    }

    func saveToPhotosAlbum(_ uiImage: UIImage) {
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        triggerAlert("Saved to your Photos album! ✨")
    }

    func triggerAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}


