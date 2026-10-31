import PhotosUI
import SwiftUI
import UIKit

private enum HavenFormat: String, CaseIterable, Identifiable {
    case story = "Story"
    case post = "Post"
    case portrait = "Portrait"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .story: "9:16 • Instagram Story"
        case .post: "1:1 • Square post"
        case .portrait: "4:5 • Portrait post"
        }
    }

    var ratio: CGFloat {
        switch self {
        case .story: 9 / 16
        case .post: 1
        case .portrait: 4 / 5
        }
    }

    var icon: String {
        switch self {
        case .story: "rectangle.portrait"
        case .post: "square"
        case .portrait: "rectangle"
        }
    }
}

private enum HavenTool: String, CaseIterable, Identifiable {
    case photo = "Photo"
    case text = "Text"
    case filter = "Filter"
    case background = "Background"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .photo: "photo.on.rectangle.angled"
        case .text: "textformat"
        case .filter: "wand.and.stars"
        case .background: "paintpalette"
        }
    }
}

struct ContentView: View {
    @State private var selectedFormat: HavenFormat?

    var body: some View {
        ZStack {
            HavenColors.ink.ignoresSafeArea()

            if let selectedFormat {
                EditorView(format: selectedFormat) {
                    self.selectedFormat = nil
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
        .preferredColorScheme(.dark)
    }
}

private struct HomeView: View {
    let startEditing: (HavenFormat) -> Void

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 28) {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Haven")
                            .font(.system(size: 32, weight: .black, design: .rounded))
                        Text("Make something worth sharing.")
                            .font(.subheadline)
                            .foregroundStyle(HavenColors.muted)
                    }

                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.title3.bold())
                        .foregroundStyle(HavenColors.sun)
                        .padding(14)
                        .background(HavenColors.card, in: Circle())
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Create a new story")
                        .font(.title2.bold())

                    Button {
                        startEditing(.story)
                    } label: {
                        HStack(spacing: 18) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 18)
                                    .fill(
                                        LinearGradient(
                                            colors: [HavenColors.coral, HavenColors.sun],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                Image(systemName: "plus")
                                    .font(.title.bold())
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 68, height: 82)

                            VStack(alignment: .leading, spacing: 5) {
                                Text("Start from a blank canvas")
                                    .font(.headline)
                                Text("Story • 9:16")
                                    .font(.subheadline)
                                    .foregroundStyle(HavenColors.muted)
                            }

                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.headline.bold())
                                .foregroundStyle(HavenColors.sun)
                        }
                        .padding(14)
                        .background(HavenColors.card, in: RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                }

                VStack(alignment: .leading, spacing: 14) {
                    Text("Choose your format")
                        .font(.title2.bold())

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(HavenFormat.allCases) { format in
                            FormatCard(format: format) {
                                startEditing(format)
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Your drafts")
                            .font(.title2.bold())
                        Spacer()
                        Text("Coming soon")
                            .font(.caption.bold())
                            .foregroundStyle(HavenColors.muted)
                    }

                    HStack(spacing: 12) {
                        Image(systemName: "square.and.pencil")
                            .font(.title2)
                            .foregroundStyle(HavenColors.lilac)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Your creative space is ready")
                                .font(.subheadline.bold())
                            Text("Projects you save will appear here.")
                                .font(.caption)
                                .foregroundStyle(HavenColors.muted)
                        }
                        Spacer()
                    }
                    .padding(18)
                    .background(HavenColors.card, in: RoundedRectangle(cornerRadius: 22))
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 24)
            .padding(.bottom, 30)
        }
    }
}

private struct FormatCard: View {
    let format: HavenFormat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 13) {
                Image(systemName: format.icon)
                    .font(.title2)
                    .foregroundStyle(HavenColors.mint)
                Text(format.rawValue)
                    .font(.headline)
                Text(format.subtitle)
                    .font(.caption)
                    .foregroundStyle(HavenColors.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(HavenColors.card, in: RoundedRectangle(cornerRadius: 22))
        }
        .buttonStyle(.plain)
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
                        .font(.headline.bold())
                        .frame(width: 40, height: 40)
                        .background(HavenColors.card, in: Circle())
                }
                .buttonStyle(.plain)

                Spacer()
                Text(format.rawValue)
                    .font(.headline.bold())
                Spacer()

                ShareLink(item: "Create something worth sharing with Haven") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline.bold())
                        .frame(width: 40, height: 40)
                        .background(HavenColors.coral, in: Circle())
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 12)

            Spacer(minLength: 10)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(
                        LinearGradient(
                            colors: [HavenColors.lilac.opacity(0.7), HavenColors.coral.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        .brightness(brightness)
                        .saturation(saturation)
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                } else {
                    VStack(spacing: 14) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 42, weight: .medium))
                        Text("Add your first photo")
                            .font(.headline)
                        Text("Your canvas is ready")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.75))
                    }
                    .foregroundStyle(.white)
                }
            }
            .aspectRatio(format.ratio, contentMode: .fit)
            .padding(.horizontal, 24)
            .shadow(color: HavenColors.coral.opacity(0.25), radius: 24, y: 12)

            Spacer(minLength: 24)

            if selectedTool == .filter {
                FilterPanel(brightness: $brightness, saturation: $saturation)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }

            HStack(spacing: 8) {
                ForEach(HavenTool.allCases) { tool in
                    ToolButton(tool: tool, isSelected: selectedTool == tool) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            selectedTool = tool
                        }
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(HavenColors.card, in: Capsule())
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
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
        .overlay(alignment: .bottom) {
            if selectedTool == .photo {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label("Choose photo", systemImage: "photo.on.rectangle")
                        .font(.headline)
                        .foregroundStyle(HavenColors.ink)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 13)
                        .background(HavenColors.sun, in: Capsule())
                }
                .padding(.bottom, 78)
            }
        }
    }
}

private struct ToolButton: View {
    let tool: HavenTool
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: tool.icon)
                    .font(.headline)
                Text(tool.rawValue)
                    .font(.caption2.bold())
            }
            .foregroundStyle(isSelected ? HavenColors.sun : HavenColors.muted)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 5)
        }
        .buttonStyle(.plain)
    }
}

private struct FilterPanel: View {
    @Binding var brightness: Double
    @Binding var saturation: Double

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Tune your photo")
                    .font(.subheadline.bold())
                Spacer()
                Image(systemName: "wand.and.stars")
                    .foregroundStyle(HavenColors.sun)
            }
            HStack {
                Image(systemName: "sun.max")
                    .foregroundStyle(HavenColors.muted)
                Slider(value: $brightness, in: -0.5...0.5)
                    .tint(HavenColors.sun)
            }
            HStack {
                Image(systemName: "drop")
                    .foregroundStyle(HavenColors.muted)
                Slider(value: $saturation, in: 0...2)
                    .tint(HavenColors.mint)
            }
        }
        .padding(16)
        .background(HavenColors.card, in: RoundedRectangle(cornerRadius: 20))
        .padding(.horizontal, 18)
        .padding(.bottom, 10)
    }
}

private enum HavenColors {
    static let ink = Color(red: 0.08, green: 0.07, blue: 0.12)
    static let card = Color(red: 0.15, green: 0.13, blue: 0.21)
    static let muted = Color(red: 0.67, green: 0.64, blue: 0.75)
    static let coral = Color(red: 1.0, green: 0.35, blue: 0.39)
    static let sun = Color(red: 1.0, green: 0.76, blue: 0.20)
    static let mint = Color(red: 0.24, green: 0.88, blue: 0.72)
    static let lilac = Color(red: 0.56, green: 0.39, blue: 1.0)
}

#Preview {
    ContentView()
}
