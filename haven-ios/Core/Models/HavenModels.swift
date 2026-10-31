import SwiftUI

enum HavenFormat: String, CaseIterable, Identifiable, Codable {
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

    var exportSize: CGSize {
        switch self {
        case .story: CGSize(width: 1080, height: 1920)
        case .post: CGSize(width: 1080, height: 1080)
        case .portrait: CGSize(width: 1080, height: 1350)
        }
    }
}

enum HavenTool: String, CaseIterable, Identifiable {
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

enum HavenCanvasBackground: String, CaseIterable, Identifiable, Codable {
    case paper = "Paper"
    case white = "White"
    case sand = "Sand"
    case blush = "Blush"
    case sage = "Sage"
    case terracotta = "Terracotta"
    case charcoal = "Charcoal"
    case black = "Black"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .paper: HavenPalette.paper
        case .white: .white
        case .sand: HavenPalette.canvas
        case .blush: Color(red: 0.88, green: 0.72, blue: 0.68)
        case .sage: Color(red: 0.65, green: 0.70, blue: 0.62)
        case .terracotta: Color(red: 0.78, green: 0.44, blue: 0.35)
        case .charcoal: Color(red: 0.22, green: 0.22, blue: 0.24)
        case .black: Color(red: 0.11, green: 0.10, blue: 0.09)
        }
    }
}

enum HavenFrameStyle: String, CaseIterable, Identifiable, Codable {
    case none = "Full"
    case matte = "Matte"
    case polaroid = "Polaroid"
    case film = "35mm Film"
    case minimalLine = "Border"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .none: "rectangle"
        case .matte: "rectangle.inset.filled"
        case .polaroid: "camera.macro"
        case .film: "film"
        case .minimalLine: "square.dashed"
        }
    }
}

enum HavenLightLeak: String, CaseIterable, Identifiable, Codable {
    case none = "None"
    case sunset = "Sunset"
    case prism = "Prism"
    case warmGlow = "Warm"

    var id: String { rawValue }
}

enum HavenFontFamily: String, CaseIterable, Identifiable, Codable {
    case serif = "Serif"
    case sans = "Sans"
    case rounded = "Rounded"
    case mono = "Mono"

    var id: String { rawValue }

    func font(size: CGFloat, weight: Font.Weight = .regular) -> Font {
        switch self {
        case .serif:
            return .system(size: size, weight: weight, design: .serif)
        case .sans:
            return .system(size: size, weight: weight, design: .default)
        case .rounded:
            return .system(size: size, weight: weight, design: .rounded)
        case .mono:
            return .system(size: size, weight: weight, design: .monospaced)
        }
    }
}

enum HavenTextColor: String, CaseIterable, Identifiable, Codable {
    case white = "White"
    case ink = "Ink"
    case cream = "Cream"
    case accent = "Terracotta"
    case olive = "Olive"
    case amber = "Amber 90s"
    case slate = "Slate"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: .white
        case .ink: HavenPalette.ink
        case .cream: HavenPalette.paper
        case .accent: HavenPalette.accent
        case .olive: HavenPalette.olive
        case .amber: Color(red: 0.98, green: 0.58, blue: 0.12)
        case .slate: HavenPalette.blue
        }
    }
}

enum HavenFilter: String, CaseIterable, Identifiable, Codable {
    case natural = "Natural"
    case warm = "Warm"
    case vintage = "Vintage"
    case cool = "Cool"
    case mono = "Mono"
    case noir = "Noir"
    case cinema = "Cinema"

    var id: String { rawValue }

    var brightness: Double {
        switch self {
        case .natural: 0.0
        case .warm: 0.03
        case .vintage: 0.05
        case .cool: 0.02
        case .mono: 0.02
        case .noir: -0.05
        case .cinema: -0.02
        }
    }

    var saturation: Double {
        switch self {
        case .natural: 1.0
        case .warm: 1.15
        case .vintage: 0.75
        case .cool: 0.88
        case .mono: 0.0
        case .noir: 0.0
        case .cinema: 0.85
        }
    }

    var contrast: Double {
        switch self {
        case .natural: 1.0
        case .warm: 1.05
        case .vintage: 0.95
        case .cool: 1.02
        case .mono: 1.08
        case .noir: 1.35
        case .cinema: 1.15
        }
    }

    var overlayColor: Color {
        switch self {
        case .natural: .clear
        case .warm: Color.orange.opacity(0.10)
        case .vintage: Color(red: 0.82, green: 0.65, blue: 0.45).opacity(0.14)
        case .cool: Color.blue.opacity(0.10)
        case .mono: Color.gray.opacity(0.15)
        case .noir: Color.black.opacity(0.12)
        case .cinema: Color(red: 0.15, green: 0.35, blue: 0.40).opacity(0.12)
        }
    }
}

enum HavenEditorialBadge: String, CaseIterable, Identifiable {
    case journal = "JOURNAL // VOL. 1"
    case minimal = "MINIMAL ARCHIVE"
    case golden = "GOLDEN HOUR"
    case paris = "PARIS, 35MM"
    case silence = "SILENCE & SPACE"
    case moments = "MOMENTS LIKE THIS"

    var id: String { rawValue }
}

struct HavenDraft: Codable {
    var format: HavenFormat
    var text: String
    var filter: HavenFilter
    var brightness: Double
    var saturation: Double
    var contrast: Double
    var canvasBackground: HavenCanvasBackground
    var frameStyle: HavenFrameStyle
    var canvasPadding: CGFloat
    var grainIntensity: Double
    var vignetteIntensity: Double
    var lightLeak: HavenLightLeak
    var showDateStamp: Bool
    var textPosition: CGPoint
    var textColor: HavenTextColor
    var fontFamily: HavenFontFamily
    var textSize: CGFloat
    var photoScale: CGFloat
    var photoOffsetX: CGFloat
    var photoOffsetY: CGFloat
    var hasImage: Bool

    init(
        format: HavenFormat,
        text: String = "",
        filter: HavenFilter = .natural,
        brightness: Double = 0.0,
        saturation: Double = 1.0,
        contrast: Double = 1.0,
        canvasBackground: HavenCanvasBackground = .paper,
        frameStyle: HavenFrameStyle = .none,
        canvasPadding: CGFloat = 0,
        grainIntensity: Double = 0.0,
        vignetteIntensity: Double = 0.0,
        lightLeak: HavenLightLeak = .none,
        showDateStamp: Bool = false,
        textPosition: CGPoint = .zero,
        textColor: HavenTextColor = .white,
        fontFamily: HavenFontFamily = .serif,
        textSize: CGFloat = 26,
        photoScale: CGFloat = 1.0,
        photoOffsetX: CGFloat = 0,
        photoOffsetY: CGFloat = 0,
        hasImage: Bool = false
    ) {
        self.format = format
        self.text = text
        self.filter = filter
        self.brightness = brightness
        self.saturation = saturation
        self.contrast = contrast
        self.canvasBackground = canvasBackground
        self.frameStyle = frameStyle
        self.canvasPadding = canvasPadding
        self.grainIntensity = grainIntensity
        self.vignetteIntensity = vignetteIntensity
        self.lightLeak = lightLeak
        self.showDateStamp = showDateStamp
        self.textPosition = textPosition
        self.textColor = textColor
        self.fontFamily = fontFamily
        self.textSize = textSize
        self.photoScale = photoScale
        self.photoOffsetX = photoOffsetX
        self.photoOffsetY = photoOffsetY
        self.hasImage = hasImage
    }
}

enum HavenPalette {
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


