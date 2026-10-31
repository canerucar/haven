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

    // Text Editing Modal (Instagram / Unfold style)
    @State private var isTextModalPresented = false
    @State private var tempText = ""

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
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Spacer(minLength: 0)
            canvasContainer
            Spacer(minLength: 0)
            toolPanel
            toolbar
        }
        .background(HavenPalette.paper.ignoresSafeArea())
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
        .sheet(isPresented: $isTextModalPresented) {
            textEditSheet
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

            // Interactive Format Switcher Menu
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
                .background(HavenPalette.ink.opacity(0.04))
                .clipShape(Capsule())
            }

            Spacer()

            HStack(spacing: 6) {
                // Before / After Compare Button
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

                // 35mm Analog Viewfinder Camera Button
                Button {
                    HavenHaptics.medium()
                    showCameraView = true
                } label: {
                    Image(systemName: "camera")
                        .font(.system(size: 15))
                        .foregroundStyle(HavenPalette.ink)
                        .frame(width: 36, height: 36)
                }

                // Save Draft Button
                Button {
                    model.saveDraft(format: currentFormat)
                } label: {
                    Image(systemName: model.hasSavedDraft ? "checkmark.circle.fill" : "bookmark")
                        .font(.body)
                        .foregroundStyle(model.hasSavedDraft ? HavenPalette.accent : HavenPalette.ink)
                        .frame(width: 36, height: 36)
                }

                // Export Button
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

    // MARK: - Canvas Container
    private var canvasContainer: some View {
        GeometryReader { outerProxy in
            let availableWidth = max(outerProxy.size.width - 32, 100)
            let availableHeight = max(outerProxy.size.height - 24, 100)
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
                    .shadow(color: HavenPalette.ink.opacity(0.12), radius: 14, x: 0, y: 7)

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
                                .padding(12)
                            Spacer()
                        }
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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

            // 5. Text Overlay
            if !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isComparingOriginal {
                let currentTextPos = CGPoint(
                    x: (model.textPosition == .zero ? size.width / 2 : model.textPosition.x) + textDragTranslation.width,
                    y: (model.textPosition == .zero ? (model.frameStyle == .polaroid ? size.height - 35 : size.height / 2) : model.textPosition.y) + textDragTranslation.height
                )

                Text(model.text)
                    .font(model.fontFamily.font(size: model.textSize, weight: .semibold))
                    .foregroundStyle(model.textColor.color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                    .shadow(color: .black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .position(currentTextPos)
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
                        tempText = model.text
                        isTextModalPresented = true
                    }
            }
        }
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { location in
            if model.selectedTool == .text {
                model.textPosition = location
                tempText = model.text
                isTextModalPresented = true
            } else {
                selectedStickerId = nil
            }
        }
    }

    // MARK: - Single Photo Layer
    @ViewBuilder
    private func singlePhotoLayer(size: CGSize) -> some View {
        let currentScale = min(max(model.photoScale * photoPinchMagnification, 0.4), 4.0)
        let currentOffset = CGSize(
            width: model.photoOffset.width + photoDragTranslation.width,
            height: model.photoOffset.height + photoDragTranslation.height
        )

        if let image = model.image {
            ZStack {
                // Photo
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
                    // Analog Vignette
                    if model.vignetteIntensity > 0 {
                        vignetteOverlay(intensity: model.vignetteIntensity)
                    }

                    // Film Grain Overlay
                    if model.grainIntensity > 0 {
                        filmGrainOverlay(intensity: model.grainIntensity)
                    }

                    // Light Leak Overlay
                    if model.lightLeak != .none {
                        lightLeakOverlay(type: model.lightLeak)
                    }
                }
            }
            .frame(
                width: max(size.width - photoPaddingHorizontal(for: size), 50),
                height: max(size.height - photoPaddingVertical(for: size), 50)
            )
            .clipShape(RoundedRectangle(cornerRadius: model.frameStyle == .polaroid ? 2 : 0))
            .overlay(!isComparingOriginal ? frameOverlay(for: size) : nil)
            .shadow(color: model.canvasPadding > 0 ? Color.black.opacity(0.15) : Color.clear, radius: 8, x: 0, y: 4)
            .offset(y: model.frameStyle == .polaroid ? -18 : 0)
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
        } else {
            addPhotoPlaceholder(isSecondary: false)
        }
    }

    // MARK: - Diptych (2-Split) Collage Layer
    @ViewBuilder
    private func diptychCollageLayer(size: CGSize) -> some View {
        let padding: CGFloat = model.canvasPadding > 0 ? model.canvasPadding : 12
        let spacing: CGFloat = 8
        let availableWidth = size.width - (padding * 2) - spacing
        let slotWidth = availableWidth / 2
        let slotHeight = size.height - (padding * 2)

        HStack(spacing: spacing) {
            // Slot 1
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

            // Slot 2
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

    // MARK: - Split (Top/Bottom) Collage Layer
    @ViewBuilder
    private func splitCollageLayer(size: CGSize) -> some View {
        let padding: CGFloat = model.canvasPadding > 0 ? model.canvasPadding : 12
        let spacing: CGFloat = 8
        let availableHeight = size.height - (padding * 2) - spacing
        let slotHeight = availableHeight / 2
        let slotWidth = size.width - (padding * 2)

        VStack(spacing: spacing) {
            // Slot 1 (Top)
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

            // Slot 2 (Bottom)
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
                        .frame(width: 54, height: 54)
                        .shadow(color: HavenPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)

                    Image(systemName: "plus")
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(HavenPalette.ink)
                }

                VStack(spacing: 3) {
                    Text(isSecondary ? "Add Second Photo" : "Add Photo")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .foregroundStyle(HavenPalette.ink)

                    Text("Tap to import from library")
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
                    .padding(14)
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
                // Translucent kraft washi tape
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
                .background(Color.white.opacity(0.9))
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
            // Delete handle if selected
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

    // MARK: - Tool Panel
    @ViewBuilder
    private var toolPanel: some View {
        VStack(spacing: 0) {
            Divider().background(HavenPalette.ink.opacity(0.1))

            switch model.selectedTool {
            case .photo:
                photoToolPanel
            case .text:
                textToolPanel
            case .filter:
                adjustToolPanel
            case .collage:
                collageToolPanel
            case .stickers:
                stickersToolPanel
            case .background:
                canvasToolPanel
            }
        }
        .frame(minHeight: 145)
        .background(HavenPalette.surface)
    }

    // MARK: 1. Photo Panel
    private var photoToolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Photo Actions")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)
                Spacer()
                if model.image != nil {
                    Button(role: .destructive) {
                        model.removePhoto()
                    } label: {
                        Label("Remove", systemImage: "trash")
                            .font(.caption)
                    }
                }
            }

            HStack(spacing: 10) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(model.image == nil ? "Choose Photo" : "Replace Photo", systemImage: "photo.on.rectangle")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(HavenPalette.paper)
                        .foregroundStyle(HavenPalette.ink)
                        .clipShape(Capsule())
                }

                Button {
                    HavenHaptics.medium()
                    showCameraView = true
                } label: {
                    Label("35mm Camera", systemImage: "camera")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(HavenPalette.paper)
                        .foregroundStyle(HavenPalette.ink)
                        .clipShape(Capsule())
                }

                if model.image != nil {
                    Button("Reset") {
                        withAnimation { model.resetPhotoTransform() }
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(HavenPalette.paper)
                    .foregroundStyle(HavenPalette.ink)
                    .clipShape(Capsule())
                }
            }
        }
        .padding(16)
    }

    // MARK: 2. Text Panel
    private var textToolPanel: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    tempText = model.text
                    isTextModalPresented = true
                } label: {
                    HStack {
                        Image(systemName: "pencil.line")
                        Text(model.text.isEmpty ? "Tap to write text..." : model.text)
                            .lineLimit(1)
                            .truncationMode(.tail)
                        Spacer()
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption)
                    }
                    .font(.subheadline)
                    .foregroundStyle(model.text.isEmpty ? HavenPalette.secondary : HavenPalette.ink)
                    .padding(10)
                    .background(HavenPalette.paper)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if !model.text.isEmpty {
                    Button {
                        model.text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(HavenPalette.secondary)
                    }
                }
            }

            // Badges Carousel & '90s Date Stamp Toggle
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Button {
                        HavenHaptics.selection()
                        model.showDateStamp.toggle()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                            Text("Date Stamp")
                        }
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(model.showDateStamp ? Color(red: 0.98, green: 0.55, blue: 0.12) : HavenPalette.paper)
                        .foregroundStyle(model.showDateStamp ? .white : HavenPalette.ink)
                        .clipShape(Capsule())
                    }

                    ForEach(HavenEditorialBadge.allCases) { badge in
                        Button {
                            model.applyBadge(badge)
                        } label: {
                            Text(badge.rawValue)
                                .font(.caption2.weight(.medium))
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(HavenPalette.paper)
                                .foregroundStyle(HavenPalette.ink)
                                .clipShape(Capsule())
                        }
                    }
                }
            }

            // Font & Size Controls
            HStack(spacing: 12) {
                Picker("Font", selection: $model.fontFamily) {
                    ForEach(HavenFontFamily.allCases) { family in
                        Text(family.rawValue).tag(family)
                    }
                }
                .pickerStyle(.segmented)

                HStack(spacing: 4) {
                    Text("A").font(.caption2.weight(.bold))
                    Slider(value: $model.textSize, in: 16...48)
                    Text("A").font(.body.weight(.bold))
                }
                .frame(maxWidth: 120)
            }
        }
        .padding(14)
    }

    // MARK: 3. Adjust Panel (Presets vs Fine Tune)
    private var adjustToolPanel: some View {
        VStack(spacing: 10) {
            // Sub-tab Picker
            Picker("Mode", selection: $model.adjustSubTab) {
                ForEach(HavenEditorViewModel.AdjustSubTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.top, 8)

            if model.adjustSubTab == .presets {
                // Presets Mode
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 12) {
                        // Filters
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(HavenFilter.allCases) { filter in
                                    Button {
                                        model.apply(filter)
                                    } label: {
                                        Text(filter.rawValue)
                                            .font(.caption.weight(.medium))
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 6)
                                            .background(model.selectedFilter == filter ? HavenPalette.ink : HavenPalette.paper)
                                            .foregroundStyle(model.selectedFilter == filter ? .white : HavenPalette.ink)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                        }

                        // Light Leak Selection
                        HStack(spacing: 8) {
                            Text("Light Leak:")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(HavenPalette.secondary)
                                .padding(.leading, 16)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(HavenLightLeak.allCases) { leak in
                                        Button {
                                            HavenHaptics.selection()
                                            model.lightLeak = leak
                                        } label: {
                                            Text(leak.rawValue)
                                                .font(.caption2.weight(.medium))
                                                .lineLimit(1)
                                                .fixedSize(horizontal: true, vertical: false)
                                                .padding(.horizontal, 10)
                                                .padding(.vertical, 5)
                                                .background(model.lightLeak == leak ? HavenPalette.accent : HavenPalette.paper)
                                                .foregroundStyle(model.lightLeak == leak ? .white : HavenPalette.ink)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal, 2)
                            }
                        }
                    }
                    .padding(.bottom, 12)
                }
            } else {
                // Fine Tune Sliders
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 7) {
                        adjustSlider(icon: "camera.filters", label: "Film Grain", value: $model.grainIntensity, range: 0.0...0.6, format: "%.0f%%", multiplier: 166)
                        adjustSlider(icon: "sun.max.fill", label: "Warmth", value: $model.warmth, range: -1.0...1.0, format: "%+.0f", multiplier: 100)
                        adjustSlider(icon: "plusminus.circle", label: "Exposure", value: $model.exposure, range: -1.0...1.0, format: "%+.0f", multiplier: 100)
                        adjustSlider(icon: "circle.circle", label: "Vignette", value: $model.vignetteIntensity, range: 0.0...0.8, format: "%.0f%%", multiplier: 125)
                        adjustSlider(icon: "circle.righthalf.filled", label: "Contrast", value: $model.contrast, range: 0.6...1.4, format: "%.1f", multiplier: 1)
                        adjustSlider(icon: "drop", label: "Saturation", value: $model.saturation, range: 0.0...2.0, format: "%.1f", multiplier: 1)

                        HStack {
                            Spacer()
                            Button("Reset all to natural") {
                                model.resetAdjustments()
                            }
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(HavenPalette.accent)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
                }
            }
        }
    }

    private func adjustSlider(icon: String, label: String, value: Binding<Double>, range: ClosedRange<Double>, format: String, multiplier: Double) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(HavenPalette.secondary)
                .frame(width: 18)
            Text(label)
                .font(.caption2)
                .foregroundStyle(HavenPalette.secondary)
                .frame(width: 65, alignment: .leading)
            Slider(value: value, in: range)
            Text(String(format: format, value.wrappedValue * multiplier))
                .font(.caption2.monospacedDigit())
                .frame(width: 34)
        }
    }

    // MARK: 4. Collage Panel
    private var collageToolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Editorial Collage Layouts")
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
                        VStack(spacing: 6) {
                            Image(systemName: layout.icon)
                                .font(.system(size: 22))
                            Text(layout.title)
                                .font(.caption2.weight(.medium))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(model.collageLayout == layout ? HavenPalette.ink : HavenPalette.paper)
                        .foregroundStyle(model.collageLayout == layout ? .white : HavenPalette.ink)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                }
            }

            if model.collageLayout != .single {
                HStack {
                    Text("Slot 2 Photo:")
                        .font(.caption2)
                        .foregroundStyle(HavenPalette.secondary)

                    PhotosPicker(selection: $selectedSecondaryPhotoItem, matching: .images) {
                        Text(model.secondaryImage == nil ? "Add Photo" : "Replace Photo")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(HavenPalette.accent)
                    }

                    if model.secondaryImage != nil {
                        Spacer()
                        Button("Remove") {
                            model.removeSecondaryPhoto()
                        }
                        .font(.caption2)
                        .foregroundStyle(Color.red)
                    }
                }
            }
        }
        .padding(16)
    }

    // MARK: 5. Stickers & Stamps Panel
    private var stickersToolPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Archival Stamps & Washi Tape")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)
                Spacer()
                if !model.stickers.isEmpty {
                    Text("\(model.stickers.count) added")
                        .font(.caption2)
                        .foregroundStyle(HavenPalette.secondary)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(HavenStickerType.allCases) { type in
                        Button {
                            model.addSticker(type)
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundStyle(HavenPalette.accent)
                                Text(type.label)
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(HavenPalette.ink)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(HavenPalette.paper)
                            .clipShape(Capsule())
                            .shadow(color: HavenPalette.ink.opacity(0.04), radius: 2, y: 1)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }

            Text("Tip: Tap added stamp to delete, drag to reposition.")
                .font(.system(size: 10))
                .foregroundStyle(HavenPalette.secondary)
        }
        .padding(14)
    }

    // MARK: 6. Canvas Panel (Frames + Background Colors)
    private var canvasToolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Text("Frame")
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
                                .padding(.vertical, 7)
                                .background(model.frameStyle == style ? HavenPalette.ink : HavenPalette.paper)
                                .foregroundStyle(model.frameStyle == style ? .white : HavenPalette.ink)
                                .clipShape(Capsule())
                                .shadow(color: HavenPalette.ink.opacity(0.04), radius: 2, y: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
            }

            // Inset / Padding Slider
            HStack(spacing: 8) {
                Text("Border Inset")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(HavenPalette.secondary)
                    .frame(width: 72, alignment: .leading)

                Slider(value: $model.canvasPadding, in: 0...40)

                Text("\(Int(model.canvasPadding))pt")
                    .font(.caption2.monospacedDigit())
                    .frame(width: 32)
            }

            // Background Color Swatches
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
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle()
                                            .stroke(model.canvasBackground == bg ? HavenPalette.accent : HavenPalette.ink.opacity(0.25), lineWidth: model.canvasBackground == bg ? 2.5 : 1)
                                    )
                                Text(bg.rawValue)
                                    .font(.system(size: 10))
                                    .foregroundStyle(HavenPalette.ink)
                            }
                            .frame(width: 52)
                        }
                    }
                }
                .padding(.horizontal, 2)
            }
        }
        .padding(14)
    }

    // MARK: - Toolbar
    private var toolbar: some View {
        HStack(spacing: 0) {
            ForEach(HavenTool.allCases) { tool in
                Button {
                    HavenHaptics.selection()
                    model.selectedTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 18))
                        Text(tool.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(model.selectedTool == tool ? HavenPalette.accent : HavenPalette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(HavenPalette.paper)
    }

    // MARK: - Text Editing Sheet
    private var textEditSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                TextField("Write your story...", text: $tempText, axis: .vertical)
                    .font(model.fontFamily.font(size: 32, weight: .semibold))
                    .foregroundStyle(model.textColor.color)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)

                Spacer()

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
                                        .stroke(model.textColor == colorItem ? HavenPalette.accent : HavenPalette.ink.opacity(0.2), lineWidth: 2)
                                )
                        }
                    }
                }
                .padding(.bottom, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.black.opacity(0.85).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isTextModalPresented = false
                    }
                    .foregroundStyle(.white)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        HavenHaptics.light()
                        model.text = tempText
                        isTextModalPresented = false
                    }
                    .font(.body.weight(.bold))
                    .foregroundStyle(HavenPalette.orange)
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
