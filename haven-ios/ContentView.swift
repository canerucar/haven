import PhotosUI
import SwiftUI
import UIKit

private enum HavenFormat: String, CaseIterable, Identifiable {
    case story = "Story"
    case post = "Post"
    case portrait = "Portrait"

    var id: String { rawValue }
    var ratio: CGFloat {
        switch self {
        case .story: 9 / 16
        case .post: 1
        case .portrait: 4 / 5
        }
    }
    var sizeLabel: String {
        switch self {
        case .story: "9:16"
        case .post: "1:1"
        case .portrait: "4:5"
        }
    }
}

private enum HavenTool: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case text = "Text"
    case filter = "Adjust"
    case background = "Canvas"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .photo: "photo"
        case .text: "textformat"
        case .filter: "slider.horizontal.3"
        case .background: "circle.lefthalf.filled"
        }
    }
}

struct ContentView: View {
    @State private var selectedFormat: HavenFormat?

    var body: some View {
        ZStack {
            HavenPalette.paper.ignoresSafeArea()
            if let selectedFormat {
                EditorView(format: selectedFormat) {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        self.selectedFormat = nil
                    }
                }
                .transition(.move(edge: .trailing))
            } else {
                HomeView { format in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedFormat = format
                    }
                }
                .transition(.move(edge: .leading))
            }
        }
        .preferredColorScheme(.light)
    }
}

private struct HomeView: View {
    let startEditing: (HavenFormat) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("haven")
                            .font(.system(size: 34, weight: .semibold, design: .serif))
                        Text("Make room for your story.")
                            .font(.subheadline)
                            .foregroundStyle(HavenPalette.secondary)
                    }
                    Spacer()
                    Button {} label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)
                            .foregroundStyle(HavenPalette.ink)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 34)

                Text("Create")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                Text("something beautiful.")
                    .font(.system(size: 42, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(HavenPalette.accent)
                    .padding(.bottom, 26)

                Button {
                    startEditing(.story)
                } label: {
                    ZStack(alignment: .bottomLeading) {
                        LinearGradient(
                            colors: [HavenPalette.accent, HavenPalette.orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .overlay {
                            Image(systemName: "camera.aperture")
                                .font(.system(size: 100, weight: .ultraLight))
                                .foregroundStyle(.white.opacity(0.35))
                                .offset(x: 90, y: -4)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("New story")
                                .font(.title2.weight(.semibold))
                            Text("Start with a blank canvas  →")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(22)
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 34)

                HStack(alignment: .firstTextBaseline) {
                    Text("Choose a format")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("01")
                        .font(.caption.monospaced())
                        .foregroundStyle(HavenPalette.secondary)
                }
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    ForEach(HavenFormat.allCases) { format in
                        Button {
                            startEditing(format)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                RoundedRectangle(cornerRadius: 2)
                                    .stroke(HavenPalette.ink.opacity(0.35), lineWidth: 1)
                                    .frame(width: 30, height: format == .story ? 46 : (format == .portrait ? 38 : 30))
                                Text(format.rawValue)
                                    .font(.subheadline.weight(.semibold))
                                Text(format.sizeLabel)
                                    .font(.caption)
                                    .foregroundStyle(HavenPalette.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(HavenPalette.surface)
                            .overlay(alignment: .topTrailing) {
                                Image(systemName: "arrow.up.right")
                                    .font(.caption.weight(.bold))
                                    .padding(14)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 34)

                HStack(alignment: .firstTextBaseline) {
                    Text("Inspiration")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("Coming next")
                        .font(.caption)
                        .foregroundStyle(HavenPalette.secondary)
                }
                .padding(.bottom, 14)

                HStack(spacing: 10) {
                    InspirationTile(color: HavenPalette.olive, title: "Moods")
                    InspirationTile(color: HavenPalette.blue, title: "Layouts")
                    InspirationTile(color: HavenPalette.rose, title: "Type")
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 22)
            .padding(.bottom, 30)
        }
    }
}

private struct InspirationTile: View {
    let color: Color
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle()
                .fill(color)
                .frame(height: 82)
            Text(title)
                .font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EditorView: View {
    let format: HavenFormat
    let close: () -> Void

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var image: Image?
    @State private var selectedTool: HavenTool = .photo
    @State private var brightness = 0.0
    @State private var saturation = 1.0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: close) {
                    Image(systemName: "chevron.left")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                }
                .buttonStyle(.plain)
                Spacer()
                Text(format.rawValue)
                    .font(.headline)
                Spacer()
                ShareLink(item: "Made with haven") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                        .frame(width: 40, height: 40)
                }
            }
            .foregroundStyle(HavenPalette.ink)
            .padding(.horizontal, 14)
            .padding(.top, 8)

            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    ZStack {
                        Rectangle()
                            .fill(HavenPalette.canvas)
                        if let image {
                            image
                                .resizable()
                                .scaledToFill()
                                .brightness(brightness)
                                .saturation(saturation)
                                .clipped()
                        } else {
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 30, weight: .light))
                                Text("Your canvas")
                                    .font(.subheadline)
                            }
                            .foregroundStyle(HavenPalette.secondary)
                        }
                    }
                    .aspectRatio(format.ratio, contentMode: .fit)
                    .frame(maxWidth: 360)
                    .clipped()
                    .overlay(alignment: .bottom) {
                        if image == nil {
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Label("Choose photo", systemImage: "plus")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 11)
                                    .background(HavenPalette.ink)
                            }
                            .padding(.bottom, 16)
                        }
                    }

                    if selectedTool == .filter {
                        FilterPanel(brightness: $brightness, saturation: $saturation)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 14)
            }

            Divider().overlay(HavenPalette.ink.opacity(0.12))

            HStack(spacing: 0) {
                ForEach(HavenTool.allCases) { tool in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTool = tool
                        }
                    } label: {
                        VStack(spacing: 5) {
                            Image(systemName: tool.icon)
                                .font(.headline)
                            Text(tool.rawValue)
                                .font(.caption2)
                        }
                        .foregroundStyle(selectedTool == tool ? HavenPalette.accent : HavenPalette.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(HavenPalette.paper)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    await MainActor.run {
                        image = Image(uiImage: uiImage)
                    }
                }
            }
        }
    }
}

private struct FilterPanel: View {
    @Binding var brightness: Double
    @Binding var saturation: Double

    var body: some View {
        VStack(spacing: 14) {
            HStack {
                Text("Adjust")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text("Natural")
                    .font(.caption)
                    .foregroundStyle(HavenPalette.secondary)
            }
            HStack {
                Image(systemName: "sun.max")
                    .frame(width: 24)
                Slider(value: $brightness, in: -0.5...0.5)
                    .tint(HavenPalette.accent)
            }
            HStack {
                Image(systemName: "drop")
                    .frame(width: 24)
                Slider(value: $saturation, in: 0...2)
                    .tint(HavenPalette.accent)
            }
        }
        .foregroundStyle(HavenPalette.secondary)
        .padding(16)
        .background(HavenPalette.surface)
    }
}

private enum HavenPalette {
    static let paper = Color(red: 0.95, green: 0.93, blue: 0.89)
    static let surface = Color(red: 0.91, green: 0.88, blue: 0.82)
    static let canvas = Color(red: 0.86, green: 0.83, blue: 0.77)
    static let ink = Color(red: 0.11, green: 0.10, blue: 0.09)
    static let secondary = Color(red: 0.38, green: 0.36, blue: 0.33)
    static let accent = Color(red: 0.74, green: 0.24, blue: 0.18)
    static let orange = Color(red: 0.84, green: 0.49, blue: 0.22)
    static let olive = Color(red: 0.46, green: 0.50, blue: 0.32)
    static let blue = Color(red: 0.35, green: 0.48, blue: 0.54)
    static let rose = Color(red: 0.70, green: 0.40, blue: 0.40)
}

#Preview {
    ContentView()
}
