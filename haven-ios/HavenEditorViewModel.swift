import PhotosUI
import SwiftUI
import UIKit

@MainActor
final class HavenEditorViewModel: ObservableObject {
    @Published var image: UIImage?
    @Published var selectedTool: HavenTool = .photo
    @Published var selectedFilter: HavenFilter = .natural
    @Published var brightness = 0.0
    @Published var saturation = 1.0
    @Published var text = ""
    @Published var photoOffset = CGSize.zero
    @Published var photoScale = 1.0
    @Published private(set) var hasSavedDraft = false

    private let draftKey = "haven.editor.draft"

    func importPhoto(_ item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        self.image = image
    }

    func apply(_ filter: HavenFilter) {
        selectedFilter = filter
        brightness = filter.brightness
        saturation = filter.saturation
    }

    func saveDraft() {
        let draft = HavenDraft(
            text: text,
            filter: selectedFilter,
            brightness: brightness,
            saturation: saturation,
            imageData: image?.jpegData(compressionQuality: 0.9)
        )
        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: draftKey)
        hasSavedDraft = true
    }

    func loadDraft() {
        guard let data = UserDefaults.standard.data(forKey: draftKey),
              let draft = try? JSONDecoder().decode(HavenDraft.self, from: data) else { return }
        text = draft.text
        selectedFilter = draft.filter
        brightness = draft.brightness
        saturation = draft.saturation
        if let imageData = draft.imageData {
            image = UIImage(data: imageData)
        }
    }
}
