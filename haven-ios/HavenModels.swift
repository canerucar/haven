import SwiftUI

enum HavenFormat: String, CaseIterable, Identifiable {
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

enum HavenFilter: String, CaseIterable, Identifiable, Codable {
    case natural = "Natural"
    case warm = "Warm"
    case cool = "Cool"
    case mono = "Mono"

    var id: String { rawValue }
    var brightness: Double {
        switch self {
        case .natural: 0
        case .warm: 0.04
        case .cool, .mono: 0.02
        }
    }
    var saturation: Double {
        switch self {
        case .natural: 1
        case .warm: 1.18
        case .cool: 0.9
        case .mono: 0
        }
    }
}

struct HavenDraft: Codable {
    var text: String
    var filter: HavenFilter
    var brightness: Double
    var saturation: Double
    var imageData: Data?
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
