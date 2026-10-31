import SwiftUI

struct HomeView: View {
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
                    Image(systemName: "person.crop.circle")
                        .font(.title2)
                }
                .padding(.bottom, 34)

                Text("Create")
                    .font(.system(size: 42, design: .serif))
                Text("something beautiful.")
                    .font(.system(size: 42, design: .serif))
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
                        VStack(alignment: .leading, spacing: 8) {
                            Text("New story").font(.title2.weight(.semibold))
                            Text("Start with a blank canvas  →")
                                .font(.subheadline.weight(.medium))
                        }
                        .foregroundStyle(.white)
                        .padding(22)
                    }
                    .frame(height: 190)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 34)

                Text("Choose a format")
                    .font(.title3.weight(.semibold))
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
                                Text(format.rawValue).font(.subheadline.weight(.semibold))
                                Text(format.sizeLabel)
                                    .font(.caption)
                                    .foregroundStyle(HavenPalette.secondary)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(14)
                            .background(HavenPalette.surface)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.bottom, 34)

                Text("Inspiration")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 14)
                HStack(spacing: 10) {
                    InspirationTile(color: HavenPalette.olive, title: "Moods")
                    InspirationTile(color: HavenPalette.blue, title: "Layouts")
                    InspirationTile(color: HavenPalette.rose, title: "Type")
                }
            }
            .padding(20)
        }
        .background(HavenPalette.paper)
    }
}

private struct InspirationTile: View {
    let color: Color
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Rectangle().fill(color).frame(height: 82)
            Text(title).font(.subheadline.weight(.medium))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
