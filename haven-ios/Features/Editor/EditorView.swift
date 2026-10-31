import PhotosUI
import SwiftUI
import UIKit

struct EditorView: View {
    let format: HavenFormat
    let close: () -> Void
    @StateObject private var model = HavenEditorViewModel()

    @State private var selectedPhotoItem: PhotosPickerItem?

    // Text Editing Modal (Instagram / Unfold style - solves all keyboard glitches)
    @State private var isTextModalPresented = false
    @State private var tempText = ""

    // Gesture states for smooth transformations without snap glitches
    @State private var photoDragTranslation: CGSize = .zero
    @State private var photoPinchMagnification: CGFloat = 1.0
    @State private var textDragTranslation: CGSize = .zero

    // Export & Sharing
    @State private var showExportActionSheet = false

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
            model.loadDraft(format: format)
        }
        .onChange(of: selectedPhotoItem) { _, item in
            Task { await model.importPhoto(item) }
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
            Button(action: close) {
                Image(systemName: "chevron.left")
                    .font(.body.weight(.semibold))
                    .frame(width: 40, height: 40)
            }

            Spacer()

            VStack(spacing: 2) {
                Text(format.rawValue)
                    .font(.system(.headline, design: .serif))
                Text(format.sizeLabel)
                    .font(.caption2)
                    .foregroundStyle(HavenPalette.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                Button {
                    model.saveDraft(format: format)
                } label: {
                    Image(systemName: model.hasSavedDraft ? "checkmark.circle.fill" : "bookmark")
                        .font(.body)
                        .foregroundStyle(model.hasSavedDraft ? HavenPalette.accent : HavenPalette.ink)
                        .frame(width: 38, height: 38)
                }

                Button {
                    showExportActionSheet = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                        Text("Export")
                            .font(.caption.weight(.semibold))
                    }
                    .padding(.horizontal, 12)
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
            let targetRatio = format.ratio

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
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Canvas View
    @ViewBuilder
    private func canvasContent(size: CGSize) -> some View {
        let currentScale = min(max(model.photoScale * photoPinchMagnification, 0.4), 4.0)
        let currentOffset = CGSize(
            width: model.photoOffset.width + photoDragTranslation.width,
            height: model.photoOffset.height + photoDragTranslation.height
        )

        ZStack {
            // 1. Canvas Background Color
            Rectangle().fill(model.canvasBackground.color)

            // Paper texture subtle overlay
            if model.hasPaperTexture {
                paperTextureOverlay
            }

            // 2. Photo Layer with Frame Styles
            if let image = model.image {
                ZStack {
                    // Photo
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(currentScale)
                        .offset(currentOffset)
                        .brightness(model.brightness)
                        .saturation(model.saturation)
                        .contrast(model.contrast)
                        .overlay(model.selectedFilter.overlayColor)
                        .clipped()

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
                .frame(
                    width: max(size.width - photoPaddingHorizontal(for: size), 50),
                    height: max(size.height - photoPaddingVertical(for: size), 50)
                )
                .clipShape(RoundedRectangle(cornerRadius: model.frameStyle == .polaroid ? 2 : 0))
                .overlay(frameOverlay(for: size))
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
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(HavenPalette.surface)
                                .frame(width: 58, height: 58)
                                .shadow(color: HavenPalette.ink.opacity(0.08), radius: 6, x: 0, y: 3)

                            Image(systemName: "plus")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(HavenPalette.ink)
                        }

                        VStack(spacing: 3) {
                            Text("Add Photo")
                                .font(.system(size: 15, weight: .semibold, design: .serif))
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
                            .padding(20)
                    )
                }
                .buttonStyle(.plain)
            }

            // 3. '90s Amber Date Stamp
            if model.showDateStamp {
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

            // 4. Text Overlay
            if !model.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
            }
        }
    }

    // MARK: - Frame Calculations
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
        ZStack {
            LinearGradient(
                colors: [Color.white.opacity(0.04), Color.black.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
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
        // High frequency micro-pattern simulation
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

            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                    Label(model.image == nil ? "Choose Photo" : "Replace Photo", systemImage: "arrow.triangle.2.circlepath")
                        .font(.caption.weight(.medium))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(HavenPalette.paper)
                        .foregroundStyle(HavenPalette.ink)
                        .clipShape(Capsule())
                }

                if model.image != nil {
                    Button("Reset Position") {
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
            // Main Text action row
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
                    // Date Stamp Button
                    Button {
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

                    // Editorial Badges
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

    // MARK: 3. Adjust Panel (Filters + Analog Effects)
    private var adjustToolPanel: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 12) {
                // Preset filters
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
                }

                // Light Leak Selection
                HStack(spacing: 8) {
                    Text("Light Leak:")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(HavenPalette.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(HavenLightLeak.allCases) { leak in
                                Button {
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

                // Sliders
                VStack(spacing: 7) {
                    adjustSlider(icon: "sun.max", label: "Brightness", value: $model.brightness, range: -0.4...0.4, format: "%+.0f", multiplier: 100)
                    adjustSlider(icon: "drop", label: "Saturation", value: $model.saturation, range: 0.0...2.0, format: "%.1f", multiplier: 1)
                    adjustSlider(icon: "circle.righthalf.filled", label: "Contrast", value: $model.contrast, range: 0.6...1.4, format: "%.1f", multiplier: 1)
                    adjustSlider(icon: "camera.filters", label: "Film Grain", value: $model.grainIntensity, range: 0.0...0.5, format: "%.0f%%", multiplier: 200)
                    adjustSlider(icon: "circle.circle", label: "Vignette", value: $model.vignetteIntensity, range: 0.0...0.8, format: "%.0f%%", multiplier: 125)
                }

                HStack {
                    Spacer()
                    Button("Reset adjustments") {
                        model.resetAdjustments()
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(HavenPalette.secondary)
                }
            }
            .padding(14)
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
                .frame(width: 32)
        }
    }

    // MARK: 4. Canvas Panel (Frames + Background Colors)
    private var canvasToolPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Frame Style Picker (Scrollable to the right without breaking words)
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
                    .padding(.vertical, 2)
                }
            }

            // Inset / Padding Slider (Allows instant visual background reveal!)
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
                                // If padding is 0, reveal the background automatically!
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
                    model.selectedTool = tool
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 19))
                        Text(tool.rawValue)
                            .font(.caption2.weight(.medium))
                    }
                    .foregroundStyle(model.selectedTool == tool ? HavenPalette.accent : HavenPalette.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(HavenPalette.paper)
    }

    // MARK: - Text Editing Sheet (Glitch-Free Unfold/Instagram style)
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

                // Color picker inside modal
                HStack(spacing: 14) {
                    ForEach(HavenTextColor.allCases) { colorItem in
                        Button {
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
        let renderHeight = renderWidth / format.ratio
        let targetSize = CGSize(width: renderWidth, height: renderHeight)

        let renderer = ImageRenderer(content:
            canvasContent(size: targetSize)
                .frame(width: targetSize.width, height: targetSize.height)
        )
        // High density 3.0x retina render (e.g. 1080 x 1920)
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


