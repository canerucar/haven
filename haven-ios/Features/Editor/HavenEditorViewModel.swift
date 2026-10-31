import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class HavenEditorViewModel: ObservableObject {
    // Primary Photo
    @Published var image: UIImage?
    @Published var photoOffset: CGSize = .zero
    @Published var photoScale: CGFloat = 1.0

    // Secondary Photo (for Diptych & Split Collages)
    @Published var secondaryImage: UIImage?
    @Published var secondaryPhotoOffset: CGSize = .zero
    @Published var secondaryPhotoScale: CGFloat = 1.0
    @Published var collageLayout: HavenCollageLayout = .single

    // Tool & Mode
    @Published var selectedTool: HavenTool = .photo
    @Published var selectedFilter: HavenFilter = .natural
    @Published var adjustSubTab: AdjustSubTab = .presets

    enum AdjustSubTab: String, CaseIterable, Identifiable {
        case presets = "Presets"
        case manual = "Fine Tune"
        var id: String { rawValue }
    }

    // Manual Adjustments
    @Published var brightness: Double = 0.0
    @Published var saturation: Double = 1.0
    @Published var contrast: Double = 1.0
    @Published var warmth: Double = 0.0        // -1.0 (cool) to +1.0 (warm/amber)
    @Published var exposure: Double = 0.0      // -1.0 to +1.0

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

    // Typography
    @Published var text: String = ""
    @Published var textPosition: CGPoint = .zero
    @Published var textColor: HavenTextColor = .white
    @Published var fontFamily: HavenFontFamily = .serif
    @Published var textSize: CGFloat = 26

    // Archival Stickers & Tape
    @Published var stickers: [HavenStickerItem] = []

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

    private func draftSecondaryImageUrl(for format: HavenFormat) -> URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?
            .appendingPathComponent("haven_draft_sec_\(format.rawValue.lowercased()).jpg")
    }

    // MARK: - Photos
    func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        self.image = uiImage
        self.resetPhotoTransform()
        HavenHaptics.light()
    }

    func setCapturedPhoto(_ uiImage: UIImage) {
        self.image = uiImage
        self.resetPhotoTransform()
        HavenHaptics.success()
    }

    func removePhoto() {
        self.image = nil
        self.resetPhotoTransform()
        HavenHaptics.light()
    }

    func importSecondaryPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let uiImage = UIImage(data: data) else { return }
        self.secondaryImage = uiImage
        self.secondaryPhotoOffset = .zero
        self.secondaryPhotoScale = 1.0
        HavenHaptics.light()
    }

    func removeSecondaryPhoto() {
        self.secondaryImage = nil
        self.secondaryPhotoOffset = .zero
        self.secondaryPhotoScale = 1.0
        HavenHaptics.light()
    }

    // MARK: - Filters & Adjustments
    func apply(_ filter: HavenFilter) {
        selectedFilter = filter
        brightness = filter.brightness
        saturation = filter.saturation
        contrast = filter.contrast
        HavenHaptics.selection()
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
        HavenHaptics.selection()
    }

    func applyBadge(_ badge: HavenEditorialBadge) {
        text = badge.rawValue
        fontFamily = .serif
        textSize = 20
        textColor = .white
        HavenHaptics.light()
    }

    func resetAdjustments() {
        selectedFilter = .natural
        brightness = 0.0
        saturation = 1.0
        contrast = 1.0
        warmth = 0.0
        exposure = 0.0
        grainIntensity = 0.0
        vignetteIntensity = 0.0
        lightLeak = .none
        HavenHaptics.light()
    }

    func resetPhotoTransform() {
        photoOffset = .zero
        photoScale = 1.0
    }

    // MARK: - Stickers
    func addSticker(_ type: HavenStickerType) {
        let randomAngle = Double.random(in: -4.0...4.0)
        let item = HavenStickerItem(type: type, x: 0, y: 0, rotationDegrees: randomAngle)
        stickers.append(item)
        HavenHaptics.medium()
    }

    func removeSticker(id: UUID) {
        stickers.removeAll(where: { $0.id == id })
        HavenHaptics.light()
    }

    // MARK: - Persistence
    func saveDraft(format: HavenFormat) {
        let hasImage = image != nil
        let hasSecondary = secondaryImage != nil

        if let image, let url = draftImageUrl(for: format) {
            if let jpeg = image.jpegData(compressionQuality: 0.85) {
                try? jpeg.write(to: url)
            }
        }

        if let secondaryImage, let url = draftSecondaryImageUrl(for: format) {
            if let jpeg = secondaryImage.jpegData(compressionQuality: 0.85) {
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
            warmth: warmth,
            exposure: exposure,
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
            hasImage: hasImage,
            collageLayout: collageLayout,
            hasSecondaryImage: hasSecondary,
            stickers: stickers
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey(for: format))
        hasSavedDraft = true
        HavenHaptics.success()
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
        warmth = draft.warmth
        exposure = draft.exposure
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
        collageLayout = draft.collageLayout
        stickers = draft.stickers

        if draft.hasImage, let url = draftImageUrl(for: format),
           let data = try? Data(contentsOf: url),
           let loadedImage = UIImage(data: data) {
            image = loadedImage
        }

        if draft.hasSecondaryImage, let url = draftSecondaryImageUrl(for: format),
           let data = try? Data(contentsOf: url),
           let loadedSec = UIImage(data: data) {
            secondaryImage = loadedSec
        }
    }

    func saveToPhotosAlbum(_ uiImage: UIImage) {
        UIImageWriteToSavedPhotosAlbum(uiImage, nil, nil, nil)
        HavenHaptics.success()
        triggerAlert("Saved to your Photos album! ✨")
    }

    func triggerAlert(_ message: String) {
        alertMessage = message
        showAlert = true
    }
}
