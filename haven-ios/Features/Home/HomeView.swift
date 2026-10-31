import SwiftUI

struct HomeView: View {
    let startEditing: (HavenFormat) -> Void
    @State private var showOnboarding = false
    @AppStorage("hasCompletedHavenOnboarding") private var hasCompletedOnboarding = false

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
                    Button {
                        HavenHaptics.light()
                        showOnboarding = true
                    } label: {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(HavenPalette.ink)
                            .frame(width: 38, height: 38)
                            .background(HavenPalette.surface)
                            .clipShape(Circle())
                    }
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
                .padding(.bottom, 30)

                // Recent Drafts section
                recentDraftsSection
                    .padding(.bottom, 30)


                Text("Inspiration")
                    .font(.title3.weight(.semibold))
                    .padding(.bottom, 14)
                HStack(spacing: 10) {
                    Button {
                        startEditing(.story)
                    } label: {
                        InspirationTile(color: HavenPalette.olive, title: "Moods", subtitle: "Story 9:16")
                    }
                    .buttonStyle(.plain)

                    Button {
                        startEditing(.post)
                    } label: {
                        InspirationTile(color: HavenPalette.blue, title: "Layouts", subtitle: "Post 1:1")
                    }
                    .buttonStyle(.plain)

                    Button {
                        startEditing(.portrait)
                    } label: {
                        InspirationTile(color: HavenPalette.rose, title: "Type", subtitle: "Portrait 4:5")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(20)
        }
        .background(HavenPalette.paper)
        .sheet(isPresented: $showOnboarding) {
            HavenOnboardingView {
                showOnboarding = false
            }
        }
        .onAppear {
            if !hasCompletedOnboarding {
                showOnboarding = true
            }
        }
    }

    @ViewBuilder
    private var recentDraftsSection: some View {
        let activeDrafts = HavenFormat.allCases.filter { format in
            UserDefaults.standard.data(forKey: "haven.editor.draft.\(format.rawValue.lowercased())") != nil
        }

        if !activeDrafts.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Recent Drafts")
                        .font(.title3.weight(.semibold))
                    Spacer()
                    Text("\(activeDrafts.count) saved")
                        .font(.caption)
                        .foregroundStyle(HavenPalette.secondary)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(activeDrafts) { format in
                            Button {
                                startEditing(format)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "photo.stack")
                                        .font(.title2)
                                        .foregroundStyle(HavenPalette.accent)
                                        .frame(width: 44, height: 44)
                                        .background(HavenPalette.surface)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))

                                    VStack(alignment: .leading, spacing: 3) {
                                        Text("\(format.rawValue) Draft")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(HavenPalette.ink)
                                        Text("Tap to continue editing →")
                                            .font(.caption2)
                                            .foregroundStyle(HavenPalette.secondary)
                                    }
                                }
                                .padding(12)
                                .background(HavenPalette.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
}

private struct InspirationTile: View {
    let color: Color
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(height: 82)
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HavenPalette.ink)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(HavenPalette.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
