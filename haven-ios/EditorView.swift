import PhotosUI
import SwiftUI

struct EditorView: View {
    let format: HavenFormat
    let close: () -> Void
    @StateObject private var model = HavenEditorViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    canvas
                    toolPanel
                }
                .padding(20)
            }
            toolbar
        }
        .background(HavenPalette.paper)
        .onAppear { model.loadDraft() }
        .onChange(of: selectedPhoto) { _, item in
            Task { await model.importPhoto(item) }
        }
    }

    private var header: some View {
        HStack {
            Button(action: close) {
                Image(systemName: "chevron.left").frame(width: 40, height: 40)
            }
            Spacer()
            Text(format.rawValue).font(.headline)
            Spacer()
            Button(action: model.saveDraft) {
                Image(systemName: model.hasSavedDraft ? "checkmark" : "bookmark")
                    .frame(width: 40, height: 40)
            }
        }
        .foregroundStyle(HavenPalette.ink)
        .padding(.horizontal, 14)
    }

    private var canvas: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle().fill(HavenPalette.canvas)
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .scaleEffect(model.photoScale)
                        .offset(model.photoOffset)
                        .brightness(model.brightness)
                        .saturation(model.saturation)
                        .overlay {
                            if model.selectedFilter == .warm {
                                filterOverlay
                            }
                        }
                        .gesture(photoGesture)
                } else {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Choose photo", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 11)
                            .background(HavenPalette.ink)
                    }
                }
                if !model.text.isEmpty {
                    Text(model.text)
                        .font(.system(size: 28, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(radius: 3)
                }
            }
            .clipped()
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .aspectRatio(format.ratio, contentMode: .fit)
        .frame(maxWidth: 360)
    }

    private var filterOverlay: some View {
        Color.orange.opacity(model.selectedFilter == .warm ? 0.12 : 0)
    }

    private var photoGesture: some Gesture {
        SimultaneousGesture(
            DragGesture().onChanged { value in
                model.photoOffset = value.translation
            },
            MagnificationGesture().onChanged { value in
                model.photoScale = min(max(value, 0.7), 3)
            }
        )
    }

    @ViewBuilder
    private var toolPanel: some View {
        switch model.selectedTool {
        case .photo:
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label("Replace photo", systemImage: "photo")
                    .frame(maxWidth: .infinity)
                    .padding(12)
                    .background(HavenPalette.surface)
            }
        case .text:
            TextField("Type something...", text: $model.text)
                .textFieldStyle(.roundedBorder)
        case .filter:
            VStack(spacing: 12) {
                HStack {
                    Text("Presets").font(.subheadline.weight(.semibold))
                    Spacer()
                }
                HStack {
                    ForEach(HavenFilter.allCases) { filter in
                        Button(filter.rawValue) { model.apply(filter) }
                            .font(.caption)
                            .foregroundStyle(model.selectedFilter == filter ? .white : HavenPalette.ink)
                            .padding(9)
                            .background(model.selectedFilter == filter ? HavenPalette.accent : HavenPalette.surface)
                    }
                }
                Slider(value: $model.brightness, in: -0.5...0.5)
                Slider(value: $model.saturation, in: 0...2)
            }
            .padding(14)
            .background(HavenPalette.surface)
        case .background:
            Text("Canvas controls are coming next.")
                .font(.subheadline)
                .foregroundStyle(HavenPalette.secondary)
        }
    }

    private var toolbar: some View {
        HStack {
            ForEach(HavenTool.allCases) { tool in
                Button {
                    model.selectedTool = tool
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tool.icon)
                        Text(tool.rawValue).font(.caption2)
                    }
                    .foregroundStyle(model.selectedTool == tool ? HavenPalette.accent : HavenPalette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(HavenPalette.paper)
    }
}
