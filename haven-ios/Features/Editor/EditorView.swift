import PhotosUI
import SwiftUI
import UIKit

struct EditorView: View {
    let format: HavenFormat
    let close: () -> Void

    @State private var currentFormat: HavenFormat
    @StateObject private var model = HavenEditorViewModel()

    // Photo pickers
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedSecondaryPhotoItem: PhotosPickerItem?

    // Camera View modal
    @State private var showCameraView = false

    // Before / After Compare
    @State private var isComparingOriginal = false
    @State private var activeTool: HavenTool? = .text

    // Photo selection state
    @State private var isPhotoSelected = false

    // Text field focus state
    @FocusState private var isTextEditorFocused: Bool

    // Gesture states
    @State private var photoDragTranslation: CGSize = .zero
    @State private var photoPinchMagnification: CGFloat = 1.0
    @State private var secPhotoDragTranslation: CGSize = .zero
    @State private var secPhotoPinchMagnification: CGFloat = 1.0
    @State private var textDragTranslation: CGSize = .zero
    @State private var selectedStickerId: UUID?

    // Export & Sharing
    @State private var showExportActionSheet = false

    init(format: HavenFormat, close: @escaping () -> Void) {
        self.format = format
        self.close = close
        _currentFormat = State(initialValue: format)
        _activeTool = State(initialValue: nil)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Main Content: Photo-First Full Screen
            VStack(spacing: 0) {
                header
                canvasContainer
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                bottomBar
            }
            .background(HavenPalette.paper.ignoresSafeArea())

            // Warm Dim Overlay when drawer is open
            if activeTool != nil {
                Color.black.opacity(0.16)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        hideKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            activeTool = nil
                        }
                    }
            }

            // Haven Upward Sliding Bottom Sheet
            if let tool = activeTool {
                slidingDrawer(for: tool)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: activeTool) { _, newTool in
            if newTool == .text {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                    isTextEditorFocused = true
                }
            } else {
                isTextEditorFocused = false
                hideKeyboard()
            }
        }
        .onAppear {
            model.loadDraft(format: currentFormat)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await model.importPhoto(item) }
        }
        .onChange(of: selectedSecondaryPhotoItem) { _, item in
            Task { await model.importSecondaryPhoto(item) }
        }
        .alert(
            model.alertMessage ?? "",
            isPresented: $model.showAlert
        ) {
            Button("OK", role: .cancel) {}
        }
        .sheet(isPresented: $model.showShareSheet) {
            if let exportImage = model.exportImage {
                ActivityView(activityItems: [exportImage])
            }
        }
        .fullScreenCover(isPresented: $showCameraView) {
            HavenCameraView { capturedImage in
                model.setCapturedPhoto(capturedImage)
                showCameraView = false
            } onClose: {
                showCameraView = false
            }
        }
        .confirmationDialog("Export Artwork", isPresented: $showExportActionSheet, titleVisibility: .visible) {
            Button("Save to Photos") {
                exportCanvas(action: .save)
            }
            Button("Share...") {
                exportCanvas(action: .share)
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Header
    private var header: some View {
        HStack {
            Button {
                HavenHaptics.light()
                close()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }

            Spacer()

            // Format Switcher Menu
            Menu {
                ForEach(HavenFormat.allCases) { f in
                    Button {
                        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                            currentFormat = f
                            HavenHaptics.selection()
                            model.loadDraft(format: f)
                        }
                    } label: {
                        HStack {
                            Text(f.rawValue)
                            Spacer()
                            Text(f.sizeLabel)
                            if currentFormat == f {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 5) {
                    VStack(spacing: 1) {
                        Text(currentFormat.rawValue)
                            .font(.system(.headline, design: .serif))
                        Text(currentFormat.sizeLabel)
                            .font(.caption2)
                            .foregroundStyle(HavenPalette.secondary)
                    }
                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(HavenPalette.secondary)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(HavenPalette.ink.opacity(0.05))
                .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 5) {
                // Before / After Compare
                if model.image != nil {
                    Button {
                        HavenHaptics.light()
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isComparingOriginal.toggle()
                        }
                    } label: {
                        Image(systemName: isComparingOriginal ? "eye.fill" : "eye")
                            .font(.system(size: 15))
                            .foregroundStyle(isComparingOriginal ? HavenPalette.accent : HavenPalette.ink)
                            .frame(width: 36, height: 36)
                            .background(isComparingOriginal ? HavenPalette.accent.opacity(0.12) : Color.clear)
                            .clipShape(Circle())
                    }
                }

                // 35mm Analog Viewfinder Camera
                Button {
                    HavenHaptics.medium()
                    showCameraView = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 15))
                        .foregroundStyle(HavenPalette.ink)
                        .frame(width: 36, height: 36)
                }

                // Save Draft
                Button {
                    model.saveDraft(format: currentFormat)
                } label: {
                    Image(systemName: model.hasSavedDraft ? "checkmark.circle.fill" : "bookmark")
                        .font(.body)
                        .foregroundStyle(model.hasSavedDraft ? HavenPalette.accent : HavenPalette.ink)
                        .frame(width: 36, height: 36)
                }

                // Export
                Button {
                    HavenHaptics.light()
                    showExportActionSheet = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.caption2.weight(.semibold))
                        Text("Export")
                            .font(.caption2.weight(.semibold))
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(HavenPalette.ink)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                }
            }
        }
        .foregroundStyle(HavenPalette.ink)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Canvas Container (Photo Hero - Fills Available Space)
    private var canvasContainer: some View {
        GeometryReader { outerProxy in
            // Take full viewport width and height with elegant margins
            let availableWidth = max(outerProxy.size.width - 28, 100)
            let availableHeight = max(outerProxy.size.height - 20, 100)
            let targetRatio = currentFormat.ratio

            let computedWidth: CGFloat = {
                if availableWidth / availableHeight > targetRatio {
                    return availableHeight * targetRatio
                } else {
                    return availableWidth
                }
            }()
            let computedHeight = computedWidth / targetRatio

            ZStack {
                canvasContent(size: CGSize(width: computedWidth, height: computedHeight))
                    .frame(width: computedWidth, height: computedHeight)
                    .clipShape(RoundedRectangle(cornerRadius: 3))
                    .shadow(color: HavenPalette.ink.opacity(0.12), radius: 16, x: 0, y: 8)

                // "ORIGINAL" Badge during Before/After Compare
                if isComparingOriginal {
                    VStack {
                        HStack {
                            Spacer()
                            Text("ORIGINAL")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(Color.black.opacity(0.75))
                                .clipShape(Capsule())
                                .padding(14)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
    }

    // MARK: - Canvas View
    @ViewBuilder
    private func canvasContent(size: CGSize) -> some View {
        ZStack {
            // 1. Canvas Background Color
            Rectangle().fill(model.canvasBackground.color)

            // Paper texture subtle overlay
            if model.hasPaperTexture && !isComparingOriginal {
                paperTextureOverlay
            }

            // 2. Photo Layer (Single or Collage)
            switch model.collageLayout {
            case .single:
                singlePhotoLayer(size: size)
            case .diptych:
                diptychCollageLayer(size: size)
            case .split:
                splitCollageLayer(size: size)
            }

            // 3. '90s Amber Date Stamp
            if model.showDateStamp && !isComparingOriginal {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Text(model.dateStampFormatted)
                            .font(.system(size: 14, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color(red: 0.98, green: 0.55, blue: 0.12))
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 1, y: 1)
                            .padding(model.canvasPadding > 0 ? model.canvasPadding + 10 : 16)
                    }
                }
            }

            // 4. Archival Stickers / Washi Tape
            if !isComparingOriginal {
                ForEach(model.stickers) { sticker in
                    stickerView(sticker: sticker, canvasSize: size)
                }
            }

            // 5. Text Overlay (Persistent view node prevents focus drop on typing)
            let currentTextPos = CGPoint(
                x: (model.textPosition == .zero ? size.width / 2 : model.textPosition.x) + textDragTranslation.width,
                y: (model.textPosition == .zero ? (model.frameStyle == .polaroid ? size.height - 35 : size.height / 2) : model.textPosition.y) + textDragTranslation.height
            )

            Text(model.text.isEmpty ? " " : model.text)
                .font(model.fontFamily.font(size: model.textSize, weight: .semibold))
                .foregroundStyle(model.textColor.color)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
                .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                .position(currentTextPos)
                .opacity(!model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isComparingOriginal ? 1.0 : 0.0)
                .allowsHitTesting(!model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .gesture(
                    DragGesture()
                        .onChanged { v in
                            textDragTranslation = v.translation
                        }
                        .onEnded { v in
                            let initial = model.textPosition == .zero ? CGPoint(x: size.width / 2, y: size.height / 2) : model.textPosition
                            model.textPosition = CGPoint(x: initial.x + v.translation.width, y: initial.y + v.translation.height)
                            textDragTranslation = .zero
                        }
                )
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        activeTool = .text
                        isTextEditorFocused = true
                    }
                }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { location in
            if activeTool == .text {
                model.textPosition = location
            } else {
                withAnimation {
                    isPhotoSelected.toggle()
                    selectedStickerId = nil
                }
            }
        }
    }

    // MARK: - Single Photo Layer with Selection Handles
    @ViewBuilder
    private func singlePhotoLayer(size: CGSize) -> some View {
        let currentScale = min(max(model.photoScale * photoPinchMagnification, 0.4), 4.0)
        let currentOffset = CGSize(
            width: model.photoOffset.width + photoDragTranslation.width,
            height: model.photoOffset.height + photoDragTranslation.height
        )

        let photoW = max(size.width - photoPaddingHorizontal(for: size), 50)
        let photoH = max(size.height - photoPaddingVertical(for: size), 50)

        if let image = model.image {
            ZStack {
                // Photo Image & Effects
                ZStack {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                        .brightness(isComparingOriginal ? 0 : (model.brightness + model.exposure * 0.25))
                        .saturation(isComparingOriginal ? 1.0 : model.saturation)
                        .contrast(isComparingOriginal ? 1.0 : model.contrast)
                        .overlay {
                            if !isComparingOriginal {
                                model.selectedFilter.overlayColor
                                warmthOverlay
                            }
                        }
                        .clipped()

                    if !isComparingOriginal {
                        if model.vignetteIntensity > 0 {
                            vignetteOverlay(intensity: model.vignetteIntensity)
                        }
                        if model.grainIntensity > 0 {
                            filmGrainOverlay(intensity: model.grainIntensity)
                        }
                        if model.lightLeak != .none {
                            lightLeakOverlay(type: model.lightLeak)
                        }
                    }
                }
                .frame(width: photoW, height: photoH)
                .clipShape(RoundedRectangle(cornerRadius: model.frameStyle == .polaroid ? 2 : 0))
                .overlay(!isComparingOriginal ? frameOverlay(for: size) : nil)
                .shadow(color: model.canvasPadding > 0 ? Color.black.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
                .offset(y: model.frameStyle == .polaroid ? -18 : 0)

                // Photo Selection Handles
                if isPhotoSelected && !isComparingOriginal {
                    ZStack {
                        // Corner Anchors
                        RoundedRectangle(cornerRadius: 4)
                            .strokeBorder(HavenPalette.accent.opacity(0.8), lineWidth: 1.5)
                            .shadow(color: .black.opacity(0.15), radius: 2)

                        // 4 Corner Pill Anchors
                        VStack {
                            HStack {
                                cornerAnchor
                                Spacer()
                                cornerAnchor
                            }
                            Spacer()
                            HStack {
                                cornerAnchor
                                Spacer()
                                cornerAnchor
                            }
                        }
                        .padding(-5)

                        // Floating Quick Action Toolbar
                        VStack {
                            HStack(spacing: 8) {
                                Button {
                                    HavenHaptics.light()
                                    withAnimation { model.resetPhotoTransform() }
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: "arrow.counterclockwise")
                                        Text("Sıfırla")
                                    }
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(HavenPalette.ink)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(HavenPalette.paper)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
                                }

                                Button {
                                    HavenHaptics.light()
                                    model.removePhoto()
                                    isPhotoSelected = false
                                } label: {
                                    Image(systemName: "trash")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.red)
                                        .padding(7)
                                        .background(HavenPalette.paper)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(Color.red.opacity(0.2), lineWidth: 1))
                                }
                            }
                            .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
                            .padding(.top, -26)

                            Spacer()
                        }
                    }
                    .frame(width: photoW, height: photoH)
                    .offset(y: model.frameStyle == .polaroid ? -18 : 0)
                }
            }
            .contentShape(Rectangle())
            .gesture(
                SimultaneousGesture(
                    DragGesture()
                        .onChanged { v in
                            photoDragTranslation = v.translation
                        }
                        .onEnded { v in
                            model.photoOffset.width += v.translation.width
                            model.photoOffset.height += v.translation.height
                            photoDragTranslation = .zero
                        },
                    MagnificationGesture()
                        .onChanged { v in
                            photoPinchMagnification = v
                        }
                        .onEnded { v in
                            model.photoScale = min(max(model.photoScale * v, 0.4), 4.0)
                            photoPinchMagnification = 1.0
                        }
                )
            )
            .onTapGesture {
                HavenHaptics.light()
                withAnimation {
                    isPhotoSelected.toggle()
                }
            }
        } else {
            addPhotoPlaceholder(isSecondary: false)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private var cornerAnchor: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(HavenPalette.paper)
            .overlay(RoundedRectangle(cornerRadius: 2).stroke(HavenPalette.ink, lineWidth: 1))
            .frame(width: 9, height: 9)
            .shadow(color: .black.opacity(0.15), radius: 2)
    }

    // MARK: - Diptych & Split Collages
    @ViewBuilder
    private func diptychCollageLayer(size: CGSize) -> some View {
        let padding: CGFloat = model.canvasPadding > 0 ? model.canvasPadding : 12
        let spacing: CGFloat = 8
        let availableWidth = size.width - (padding * 2) - spacing
        let slotWidth = availableWidth / 2
        let slotHeight = size.height - (padding * 2)

        HStack(spacing: spacing) {
            ZStack {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(model.photoScale * photoPinchMagnification)
                        .offset(CGSize(
                            width: model.photoOffset.width + photoDragTranslation.width,
                            height: model.photoOffset.height + photoDragTranslation.height
                        ))
                        .brightness(isComparingOriginal ? 0 : (model.brightness + model.exposure * 0.25))
                        .saturation(isComparingOriginal ? 1.0 : model.saturation)
                        .contrast(isComparingOriginal ? 1.0 : model.contrast)
                        .overlay {
                            if !isComparingOriginal {
                                model.selectedFilter.overlayColor
                                warmthOverlay
                            }
                        }
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { photoDragTranslation = $0.translation }
                                .onEnded {
                                    model.photoOffset.width += $0.translation.width
                                    model.photoOffset.height += $0.translation.height
                                    photoDragTranslation = .zero
                                }
                        )
                } else {
                    addPhotoPlaceholder(isSecondary: false)
                }
            }
            .frame(width: slotWidth, height: slotHeight)
            .clipped()
            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)

            ZStack {
                if let sec = model.secondaryImage {
                    Image(uiImage: sec)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(model.secondaryPhotoScale * secPhotoPinchMagnification)
                        .offset(CGSize(
                            width: model.secondaryPhotoOffset.width + secPhotoDragTranslation.width,
                            height: model.secondaryPhotoOffset.height + secPhotoDragTranslation.height
                        ))
                        .brightness(isComparingOriginal ? 0 : (model.brightness + model.exposure * 0.25))
                        .saturation(isComparingOriginal ? 1.0 : model.saturation)
                        .contrast(isComparingOriginal ? 1.0 : model.contrast)
                        .overlay {
                            if !isComparingOriginal {
                                model.selectedFilter.overlayColor
                                warmthOverlay
                            }
                        }
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { secPhotoDragTranslation = $0.translation }
                                .onEnded {
                                    model.secondaryPhotoOffset.width += $0.translation.width
                                    model.secondaryPhotoOffset.height += $0.translation.height
                                    secPhotoDragTranslation = .zero
                                }
                        )
                } else {
                    addPhotoPlaceholder(isSecondary: true)
                }
            }
            .frame(width: slotWidth, height: slotHeight)
            .clipped()
            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
        }
        .padding(padding)
    }

    @ViewBuilder
    private func splitCollageLayer(size: CGSize) -> some View {
        let padding: CGFloat = model.canvasPadding > 0 ? model.canvasPadding : 12
        let spacing: CGFloat = 8
        let availableHeight = size.height - (padding * 2) - spacing
        let slotHeight = availableHeight / 2
        let slotWidth = size.width - (padding * 2)

        VStack(spacing: spacing) {
            ZStack {
                if let image = model.image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(model.photoScale * photoPinchMagnification)
                        .offset(CGSize(
                            width: model.photoOffset.width + photoDragTranslation.width,
                            height: model.photoOffset.height + photoDragTranslation.height
                        ))
                        .brightness(isComparingOriginal ? 0 : (model.brightness + model.exposure * 0.25))
                        .saturation(isComparingOriginal ? 1.0 : model.saturation)
                        .contrast(isComparingOriginal ? 1.0 : model.contrast)
                        .overlay {
                            if !isComparingOriginal {
                                model.selectedFilter.overlayColor
                                warmthOverlay
                            }
                        }
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { photoDragTranslation = $0.translation }
                                .onEnded {
                                    model.photoOffset.width += $0.translation.width
                                    model.photoOffset.height += $0.translation.height
                                    photoDragTranslation = .zero
                                }
                        )
                } else {
                    addPhotoPlaceholder(isSecondary: false)
                }
            }
            .frame(width: slotWidth, height: slotHeight)
            .clipped()
            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)

            ZStack {
                if let sec = model.secondaryImage {
                    Image(uiImage: sec)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(model.secondaryPhotoScale * secPhotoPinchMagnification)
                        .offset(CGSize(
                            width: model.secondaryPhotoOffset.width + secPhotoDragTranslation.width,
                            height: model.secondaryPhotoOffset.height + secPhotoDragTranslation.height
                        ))
                        .brightness(isComparingOriginal ? 0 : (model.brightness + model.exposure * 0.25))
                        .saturation(isComparingOriginal ? 1.0 : model.saturation)
                        .contrast(isComparingOriginal ? 1.0 : model.contrast)
                        .overlay {
                            if !isComparingOriginal {
                                model.selectedFilter.overlayColor
                                warmthOverlay
                            }
                        }
                        .clipped()
                        .gesture(
                            DragGesture()
                                .onChanged { secPhotoDragTranslation = $0.translation }
                                .onEnded {
                                    model.secondaryPhotoOffset.width += $0.translation.width
                                    model.secondaryPhotoOffset.height += $0.translation.height
                                    secPhotoDragTranslation = .zero
                                }
                        )
                } else {
                    addPhotoPlaceholder(isSecondary: true)
                }
            }
            .frame(width: slotWidth, height: slotHeight)
            .clipped()
            .shadow(color: Color.black.opacity(0.1), radius: 6, y: 3)
        }
        .padding(padding)
    }

    // MARK: - Add Photo Placeholder
    private func addPhotoPlaceholder(isSecondary: Bool) -> some View {
        PhotosPicker(selection: isSecondary ? $selectedSecondaryPhotoItem : $selectedPhotoItem, matching: .images) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(HavenPalette.surface)
                        .frame(width: 56, height: 56)
                        .shadow(color: HavenPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(HavenPalette.ink)
                }

                VStack(spacing: 3) {
                    Text(isSecondary ? "İkinci Fotoğrafı Ekle" : "Fotoğraf Ekle")
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(HavenPalette.ink)

                    Text("Galeriden seçmek için dokunun")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(HavenPalette.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(
                        HavenPalette.ink.opacity(0.18),
                        style: StrokeStyle(lineWidth: 1.2, dash: [6, 5])
                    )
                    .padding(16)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sticker View
    @ViewBuilder
    private func stickerView(sticker: HavenStickerItem, canvasSize: CGSize) -> some View {
        let posX = (canvasSize.width / 2) + sticker.x
        let posY = (canvasSize.height / 2) + sticker.y

        Group {
            switch sticker.type {
            case .washiTape:
                Rectangle()
                    .fill(Color(red: 0.88, green: 0.82, blue: 0.72).opacity(0.85))
                    .frame(width: 90, height: 26)
                    .overlay(
                        Rectangle().strokeBorder(Color.black.opacity(0.08), lineWidth: 0.5)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 2, y: 1)

            case .archiveStamp:
                VStack(spacing: 2) {
                    Text("HAVEN ARCHIVE")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                    Text("NO. 042 // PARIS ATELIER")
                        .font(.system(size: 7, weight: .medium, design: .monospaced))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.92))
                .border(HavenPalette.ink.opacity(0.8), width: 1)
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)

            case .filmCode:
                HStack(spacing: 4) {
                    Text("▶")
                        .font(.system(size: 8))
                    Text("KODAK PORTRA 400 • 35MM EXP 24")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                }
                .foregroundStyle(Color(red: 0.95, green: 0.65, blue: 0.2))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.85))
                .clipShape(RoundedRectangle(cornerRadius: 2))

            case .barcode:
                VStack(spacing: 2) {
                    HStack(spacing: 2) {
                        ForEach(0..<20, id: \.self) { i in
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: (i % 3 == 0) ? 2.5 : 1, height: 22)
                        }
                    }
                    Text("8 41295 03194 7")
                        .font(.system(size: 7, design: .monospaced))
                        .foregroundStyle(Color.black)
                }
                .padding(6)
                .background(Color.white.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 2))
                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)

            case .atelier:
                ZStack {
                    Circle()
                        .strokeBorder(HavenPalette.accent, lineWidth: 1.5)
                        .frame(width: 58, height: 58)
                    Circle()
                        .strokeBorder(HavenPalette.accent.opacity(0.5), lineWidth: 0.8)
                        .frame(width: 50, height: 50)
                    VStack(spacing: 1) {
                        Text("HAVEN")
                            .font(.system(size: 8, weight: .bold, design: .serif))
                        Text("ATELIER")
                            .font(.system(size: 6, weight: .medium, design: .monospaced))
                        Text("2026")
                            .font(.system(size: 6, weight: .bold, design: .serif))
                    }
                    .foregroundStyle(HavenPalette.accent)
                }
                .background(Color.white.opacity(0.85))
                .clipShape(Circle())
            }
        }
        .rotationEffect(.degrees(sticker.rotationDegrees))
        .position(x: posX, y: posY)
        .overlay(
            selectedStickerId == sticker.id ?
            Button {
                model.removeSticker(id: sticker.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.red)
                    .background(Circle().fill(Color.white))
            }
            .position(x: posX + 45, y: posY - 20) : nil
        )
        .gesture(
            DragGesture()
                .onChanged { v in
                    if let index = model.stickers.firstIndex(where: { $0.id == sticker.id }) {
                        selectedStickerId = sticker.id
                        model.stickers[index].x += v.translation.width * 0.1
                        model.stickers[index].y += v.translation.height * 0.1
                    }
                }
        )
        .onTapGesture {
            HavenHaptics.selection()
            selectedStickerId = selectedStickerId == sticker.id ? nil : sticker.id
        }
    }

    // MARK: - Overlays
    private var warmthOverlay: some View {
        Group {
            if model.warmth > 0 {
                Color(red: 0.98, green: 0.65, blue: 0.2)
                    .opacity(model.warmth * 0.28)
                    .blendMode(.overlay)
            } else if model.warmth < 0 {
                Color(red: 0.3, green: 0.6, blue: 0.9)
                    .opacity(abs(model.warmth) * 0.25)
                    .blendMode(.overlay)
            }
        }
        .allowsHitTesting(false)
    }

    private func photoPaddingHorizontal(for size: CGSize) -> CGFloat {
        if model.frameStyle == .polaroid {
            return 36
        }
        return model.canvasPadding * 2
    }

    private func photoPaddingVertical(for size: CGSize) -> CGFloat {
        if model.frameStyle == .polaroid {
            return 80
        }
        return model.canvasPadding * 2
    }

    @ViewBuilder
    private func frameOverlay(for size: CGSize) -> some View {
        switch model.frameStyle {
        case .none, .matte, .polaroid:
            EmptyView()
        case .minimalLine:
            RoundedRectangle(cornerRadius: 0)
                .stroke(HavenPalette.ink.opacity(0.3), lineWidth: 1)
                .padding(-8)
        case .film:
            VStack {
                filmSprocketsRow
                Spacer()
                filmSprocketsRow
            }
            .padding(.vertical, -14)
        }
    }

    private var filmSprocketsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<10, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(HavenPalette.ink.opacity(0.7))
                    .frame(width: 7, height: 10)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.2))
    }

    private var paperTextureOverlay: some View {
        LinearGradient(
            colors: [Color.white.opacity(0.04), Color.black.opacity(0.04)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .allowsHitTesting(false)
    }

    private func vignetteOverlay(intensity: Double) -> some View {
        RadialGradient(
            colors: [Color.clear, Color.black.opacity(intensity * 0.85)],
            center: .center,
            startRadius: 80,
            endRadius: 280
        )
        .allowsHitTesting(false)
    }

    private func filmGrainOverlay(intensity: Double) -> some View {
        Rectangle()
            .fill(Color.white.opacity(intensity * 0.18))
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func lightLeakOverlay(type: HavenLightLeak) -> some View {
        switch type {
        case .none:
            EmptyView()
        case .sunset:
            LinearGradient(
                colors: [Color.orange.opacity(0.35), Color.pink.opacity(0.18), Color.clear],
                startPoint: .topLeading,
                endPoint: .center
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        case .prism:
            LinearGradient(
                colors: [Color.blue.opacity(0.25), Color.purple.opacity(0.2), Color.clear],
                startPoint: .bottomTrailing,
                endPoint: .topLeading
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        case .warmGlow:
            RadialGradient(
                colors: [Color.yellow.opacity(0.35), Color.orange.opacity(0.15), Color.clear],
                center: .topTrailing,
                startRadius: 20,
                endRadius: 220
            )
            .blendMode(.screen)
            .allowsHitTesting(false)
        }
    }

    // MARK: - Bottom Bar (Dock)
    private var bottomBar: some View {
        HStack(spacing: 0) {
            ForEach(HavenTool.allCases) { tool in
                Button {
                    HavenHaptics.selection()
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                        if activeTool == tool {
                            activeTool = nil
                        } else {
                            activeTool = tool
                            model.selectedTool = tool
                        }
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18, weight: activeTool == tool ? .bold : .regular))
                        Text(tool.rawValue)
                            .font(.system(size: 10, weight: activeTool == tool ? .bold : .medium))
                    }
                    .foregroundStyle(activeTool == tool ? HavenPalette.accent : HavenPalette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .padding(.horizontal, 10)
        .background(HavenPalette.paper)
    }

    // MARK: - Haven Upward Sliding Bottom Sheet
    @ViewBuilder
    private func slidingDrawer(for tool: HavenTool) -> some View {
        VStack(spacing: 0) {
            // Drawer Grabber & Header
            VStack(spacing: 12) {
                Capsule()
                    .fill(HavenPalette.ink.opacity(0.2))
                    .frame(width: 36, height: 4)
                    .padding(.top, 10)

                HStack {
                    Text(drawerTitle(for: tool))
                        .font(.system(size: 17, weight: .bold, design: .serif))
                        .foregroundStyle(HavenPalette.ink)

                    Spacer()

                    // Close Button
                    Button {
                        HavenHaptics.light()
                        hideKeyboard()
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.82)) {
                            activeTool = nil
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(HavenPalette.ink)
                            .frame(width: 28, height: 28)
                            .background(HavenPalette.paper)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.bottom, 12)

            Divider()
                .background(HavenPalette.ink.opacity(0.08))

            // Tool Drawer Content
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    switch tool {
                    case .photo:
                        photoDrawerContent
                    case .text:
                        textDrawerContent
                    case .filter:
                        adjustDrawerContent
                    case .collage:
                        collageDrawerContent
                    case .stickers:
                        stickersDrawerContent
                    case .background:
                        canvasDrawerContent
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 340)
        }
        .background(
            HavenPalette.surface
                .ignoresSafeArea(edges: .bottom)
        )
        .clipShape(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
        )
        .overlay(
            UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24)
                .strokeBorder(HavenPalette.ink.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 20, x: 0, y: -6)
    }

    private func drawerTitle(for tool: HavenTool) -> String {
        switch tool {
        case .photo: return "Fotoğraf İşlemleri"
        case .text: return "Editoryal Metin & Başlık"
        case .filter: return "Filtreler & İnce Ayarlar"
        case .collage: return "Mizanpaj & Kolaj"
        case .stickers: return "Arşiv Damgaları & Bant"
        case .background: return "Tuval & Çerçeve Stili"
        }
    }

    // MARK: - 1. Photo Drawer Content
    private var photoDrawerContent: some View {
        VStack(spacing: 16) {
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    HStack(spacing: 6) {
                        Image(systemName: "photo.on.rectangle")
                        Text(model.image == nil ? "Fotoğraf Seç" : "Fotoğrafı Değiştir")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(HavenPalette.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button {
                    HavenHaptics.medium()
                    activeTool = nil
                    showCameraView = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "camera")
                        Text("35mm Vizör")
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HavenPalette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(HavenPalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
                }
            }

            if model.image != nil {
                HStack(spacing: 12) {
                    Button {
                        withAnimation { model.resetPhotoTransform() }
                    } label: {
                        Label("Pozisyonu Sıfırla", systemImage: "arrow.counterclockwise")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(HavenPalette.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(HavenPalette.paper)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
                    }

                    Spacer()

                    Button(role: .destructive) {
                        model.removePhoto()
                        activeTool = nil
                    } label: {
                        Label("Fotoğrafı Kaldır", systemImage: "trash")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Color.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(HavenPalette.paper)
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.red.opacity(0.2), lineWidth: 1))
                    }
                }
            }
        }
    }

    // MARK: - 2. Text Drawer Content
    private var textDrawerContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Direct interactive text field with instant typing on canvas
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Metin İçeriği")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HavenPalette.secondary)

                    Spacer()

                    if isTextEditorFocused {
                        Button("Bitti") {
                            HavenHaptics.selection()
                            isTextEditorFocused = false
                        }
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HavenPalette.accent)
                    }
                }

                HStack(spacing: 8) {
                    TextField("Hikayenizi buraya yazın...", text: $model.text)
                        .font(model.fontFamily.font(size: 16, weight: .medium))
                        .foregroundStyle(HavenPalette.ink)
                        .focused($isTextEditorFocused)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(HavenPalette.paper)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(isTextEditorFocused ? HavenPalette.accent : HavenPalette.ink.opacity(0.12), lineWidth: 1.5)
                        )

                    if !model.text.isEmpty {
                        Button {
                            HavenHaptics.light()
                            model.text = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title3)
                                .foregroundStyle(HavenPalette.secondary.opacity(0.6))
                        }
                    }
                }
            }

            // Quick Editorial Preset Badges
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Hazır Başlıklar")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HavenPalette.secondary)

                    Spacer()

                    // '90s Amber Date Stamp Button
                    Button {
                        HavenHaptics.selection()
                        model.showDateStamp.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("Tarih Damgası")
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(model.showDateStamp ? HavenPalette.orange : HavenPalette.paper)
                        .foregroundStyle(model.showDateStamp ? .white : HavenPalette.ink)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(model.showDateStamp ? Color.clear : HavenPalette.ink.opacity(0.12), lineWidth: 1))
                    }
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HavenEditorialBadge.allCases) { badge in
                            Button {
                                HavenHaptics.light()
                                model.applyBadge(badge)
                            } label: {
                                Text(badge.rawValue)
                                    .font(.caption2.weight(.medium))
                                    .foregroundStyle(HavenPalette.ink)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(HavenPalette.paper)
                                    .clipShape(Capsule())
                                    .overlay(Capsule().stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
                            }
                        }
                    }
                }
            }

            // Font Family & Size
            VStack(alignment: .leading, spacing: 8) {
                Text("Tipografi & Boyut")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)

                HStack(spacing: 12) {
                    Picker("Font", selection: $model.fontFamily) {
                        ForEach(HavenFontFamily.allCases) { family in
                            Text(family.rawValue).tag(family)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack(spacing: 4) {
                        Text("A").font(.caption2.weight(.bold)).foregroundStyle(HavenPalette.secondary)
                        Slider(value: $model.textSize, in: 16...56)
                            .tint(HavenPalette.ink)
                        Text("A").font(.body.weight(.bold)).foregroundStyle(HavenPalette.ink)
                    }
                    .frame(maxWidth: 130)
                }
            }

            // Text Color Swatches
            VStack(alignment: .leading, spacing: 8) {
                Text("Renk")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)

                HStack(spacing: 14) {
                    ForEach(HavenTextColor.allCases) { colorItem in
                        Button {
                            HavenHaptics.selection()
                            model.textColor = colorItem
                        } label: {
                            Circle()
                                .fill(colorItem.color)
                                .frame(width: 28, height: 28)
                                .overlay(
                                    Circle()
                                        .stroke(model.textColor == colorItem ? HavenPalette.accent : HavenPalette.ink.opacity(0.15), lineWidth: model.textColor == colorItem ? 2.5 : 1)
                                )
                                .shadow(color: Color.black.opacity(0.08), radius: 2, y: 1)
                        }
                    }
                }
            }
        }
    }

    // MARK: - 3. Adjust Drawer Content
    private var adjustDrawerContent: some View {
        VStack(spacing: 16) {
            // Presets vs Fine Tune Segment
            Picker("Mode", selection: $model.adjustSubTab) {
                ForEach(HavenEditorViewModel.AdjustSubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            if model.adjustSubTab == .presets {
                // Preset Filters
                VStack(alignment: .leading, spacing: 14) {
                    Text("Analog & Editoryal Filtreler")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HavenPalette.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(HavenFilter.allCases) { filter in
                                Button {
                                    model.apply(filter)
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(model.selectedFilter == filter ? Color.white : HavenPalette.ink)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 9)
                                        .background(model.selectedFilter == filter ? HavenPalette.ink : HavenPalette.paper)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(model.selectedFilter == filter ? Color.clear : HavenPalette.ink.opacity(0.12), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }

                    Text("Işık Sızıntıları (Light Leaks)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HavenPalette.secondary)
                        .padding(.top, 4)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(HavenLightLeak.allCases) { leak in
                                Button {
                                    HavenHaptics.selection()
                                    model.lightLeak = leak
                                } label: {
                                    Text(leak.rawValue)
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(model.lightLeak == leak ? Color.white : HavenPalette.ink)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 7)
                                        .background(model.lightLeak == leak ? HavenPalette.accent : HavenPalette.paper)
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule()
                                                .stroke(model.lightLeak == leak ? Color.clear : HavenPalette.ink.opacity(0.12), lineWidth: 1)
                                        )
                                }
                            }
                        }
                    }
                }
            } else {
                // Haven Editorial Sliders
                VStack(spacing: 14) {
                    havenSlider(label: "Film Grain", value: $model.grainIntensity, range: 0.0...0.6, format: "%.0f%%", multiplier: 166)
                    havenSlider(label: "Sıcaklık (Warmth)", value: $model.warmth, range: -1.0...1.0, format: "%+.0f", multiplier: 100)
                    havenSlider(label: "Pozlama (Exposure)", value: $model.exposure, range: -1.0...1.0, format: "%+.0f", multiplier: 100)
                    havenSlider(label: "Kenar Karartma", value: $model.vignetteIntensity, range: 0.0...0.8, format: "%.0f%%", multiplier: 125)
                    havenSlider(label: "Kontrast", value: $model.contrast, range: 0.6...1.4, format: "%.1f", multiplier: 1)
                    havenSlider(label: "Doygunluk", value: $model.saturation, range: 0.0...2.0, format: "%.1f", multiplier: 1)

                    HStack {
                        Spacer()
                        Button("Tümünü Doğala Sıfırla") {
                            model.resetAdjustments()
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HavenPalette.accent)
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    // Haven Editorial Slider View
    private func havenSlider(label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, multiplier: Double) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HavenPalette.ink)
                .frame(width: 120, alignment: .leading)

            Slider(value: value, in: range)
                .tint(HavenPalette.ink)

            Text(String(format: format, value.wrappedValue * multiplier))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(HavenPalette.ink)
                .frame(width: 52, height: 26)
                .background(HavenPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
        }
    }

    private func havenSlider(label: String, value: Binding<CGFloat>, range: ClosedRange<CGFloat>, format: String, multiplier: CGFloat = 1) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(HavenPalette.ink)
                .frame(width: 120, alignment: .leading)

            Slider(value: Binding<Double>(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = CGFloat($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
                .tint(HavenPalette.ink)

            Text(String(format: format, Double(value.wrappedValue * multiplier)))
                .font(.caption.monospacedDigit().weight(.semibold))
                .foregroundStyle(HavenPalette.ink)
                .frame(width: 52, height: 26)
                .background(HavenPalette.paper)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1))
        }
    }

    // MARK: - 4. Collage Drawer Content
    private var collageDrawerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Editoryal Mizanpaj Seçimi")
                .font(.caption.weight(.semibold))
                .foregroundStyle(HavenPalette.secondary)

            HStack(spacing: 12) {
                ForEach(HavenCollageLayout.allCases) { layout in
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            model.collageLayout = layout
                            HavenHaptics.selection()
                        }
                    } label: {
                        VStack(spacing: 8) {
                            Image(systemName: layout.icon)
                                .font(.system(size: 26))
                            Text(layout.title)
                                .font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(model.collageLayout == layout ? HavenPalette.ink : HavenPalette.paper)
                        .foregroundStyle(model.collageLayout == layout ? Color.white : HavenPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(model.collageLayout == layout ? Color.clear : HavenPalette.ink.opacity(0.12), lineWidth: 1)
                        )
                    }
                }
            }

            if model.collageLayout != .single {
                HStack {
                    Text("İkinci Fotoğraf:")
                        .font(.subheadline)
                        .foregroundStyle(HavenPalette.ink)

                    Spacer()

                    PhotosPicker(selection: $selectedSecondaryPhotoItem, matching: .images) {
                        Text(model.secondaryImage == nil ? "Fotoğraf Ekle" : "Değiştir")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(HavenPalette.ink)
                            .clipShape(Capsule())
                    }

                    if model.secondaryImage != nil {
                        Button("Kaldır") {
                            model.removeSecondaryPhoto()
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Color.red)
                        .padding(.leading, 8)
                    }
                }
                .padding(.top, 4)
            }
        }
    }

    // MARK: - 5. Stickers & Stamps Drawer Content
    private var stickersDrawerContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Tuvale Damga veya Bant Ekle")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)
                Spacer()
                if !model.stickers.isEmpty {
                    Text("\(model.stickers.count) eklendi")
                        .font(.caption2)
                        .foregroundStyle(HavenPalette.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(HavenStickerType.allCases) { type in
                        Button {
                            model.addSticker(type)
                        } label: {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(HavenPalette.accent)
                                Text(type.label)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(HavenPalette.ink)
                            }
                            .frame(width: 105, height: 75)
                            .background(HavenPalette.paper)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(HavenPalette.ink.opacity(0.12), lineWidth: 1)
                            )
                        }
                    }
                }
            }

            Text("İpucu: Tuvale eklenen damgayı parmağınızla sürükleyebilir, seçip 'X' butonuyla silebilirsiniz.")
                .font(.caption2)
                .foregroundStyle(HavenPalette.secondary)
        }
    }

    // MARK: - 6. Canvas Drawer Content
    private var canvasDrawerContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            // Frame Style
            VStack(alignment: .leading, spacing: 8) {
                Text("Çerçeve Stili")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HavenFrameStyle.allCases) { style in
                            Button {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    model.applyFrameStyle(style)
                                }
                            } label: {
                                HStack(spacing: 5) {
                                    Image(systemName: style.icon)
                                        .font(.system(size: 11))
                                    Text(style.rawValue)
                                        .font(.caption2.weight(.medium))
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(model.frameStyle == style ? HavenPalette.ink : HavenPalette.paper)
                                .foregroundStyle(model.frameStyle == style ? Color.white : HavenPalette.ink)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(model.frameStyle == style ? Color.clear : HavenPalette.ink.opacity(0.12), lineWidth: 1)
                                )
                            }
                        }
                    }
                }
            }

            // Inset Slider
            havenSlider(label: "Paspartu Kenar", value: $model.canvasPadding, range: 0...40, format: "%.0f pt", multiplier: 1)

            // Paper Background Colors
            VStack(alignment: .leading, spacing: 8) {
                Text("Kağıt & Zemin Rengi")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(HavenCanvasBackground.allCases) { bg in
                            Button {
                                withAnimation {
                                    model.canvasBackground = bg
                                    HavenHaptics.selection()
                                    if model.canvasPadding == 0 && model.frameStyle == .none {
                                        model.canvasPadding = 22
                                        model.frameStyle = .matte
                                    }
                                }
                            } label: {
                                VStack(spacing: 5) {
                                    Circle()
                                        .fill(bg.color)
                                        .frame(width: 32, height: 32)
                                        .overlay(
                                            Circle()
                                                .stroke(model.canvasBackground == bg ? HavenPalette.accent : HavenPalette.ink.opacity(0.15), lineWidth: model.canvasBackground == bg ? 2.5 : 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.06), radius: 2, y: 1)
                                    Text(bg.rawValue)
                                        .font(.system(size: 10))
                                        .foregroundStyle(HavenPalette.secondary)
                                }
                                .frame(width: 54)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Export Logic
    private enum ExportAction {
        case save
        case share
    }

    @MainActor
    private func exportCanvas(action: ExportAction) {
        let renderWidth: CGFloat = 360
        let renderHeight = renderWidth / currentFormat.ratio
        let targetSize = CGSize(width: renderWidth, height: renderHeight)

        let renderer = ImageRenderer(content:
            canvasContent(size: targetSize)
                .frame(width: targetSize.width, height: targetSize.height)
        )
        renderer.scale = 3.0

        if let image = renderer.uiImage {
            model.exportImage = image
            switch action {
            case .save:
                model.saveToPhotosAlbum(image)
            case .share:
                model.showShareSheet = true
            }
        } else {
            model.triggerAlert("Could not export the canvas. Please try again.")
        }
    }
}

// MARK: - ActivityView for Sharing
private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
