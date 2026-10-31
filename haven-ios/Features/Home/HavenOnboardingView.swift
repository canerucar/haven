import SwiftUI

struct HavenOnboardingView: View {
    let onDismiss: () -> Void

    @State private var currentStep = 0
    @State private var selectedPurpose = "Kişisel kullanım ve anılar için"

    let purposes = [
        ("Kişisel kullanım ve anılar için", "Analog günlük, nostaljik kareler ve anılar"),
        ("Profesyonel & Kreatif işler için", "Moda, portfolyo ve editoryal mizanpajlar"),
        ("Sosyal Medya & İçerik üretimi", "Estetik Instagram hikayeleri ve albümler")
    ]

    var body: some View {
        ZStack {
            // Deep luxury background
            Color(red: 0.08, green: 0.08, blue: 0.09).ignoresSafeArea()

            VStack(spacing: 0) {
                // Top close button
                HStack {
                    Spacer()
                    Button {
                        HavenHaptics.light()
                        onDismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.6))
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.08))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                TabView(selection: $currentStep) {
                    // Step 1: Welcome & Editorial Showcase
                    welcomeStep
                        .tag(0)

                    // Step 2: Personalize Experience
                    personalizeStep
                        .tag(1)

                    // Step 3: Studio Ready
                    readyStep
                        .tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Bottom Step Controls
                bottomControls
                    .padding(.horizontal, 24)
                    .padding(.bottom, 34)
            }
        }
    }

    // MARK: - Step 1: Welcome
    private var welcomeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            // Brand Header
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "camera.aperture")
                        .font(.title2)
                        .foregroundStyle(Color(red: 0.88, green: 0.45, blue: 0.18))
                    Text("haven")
                        .font(.system(size: 38, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                }

                Text("Fotoğraflarınız için sıcak editoryal atölye")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }

            // Layered Magazine Story Cards
            HStack(spacing: -18) {
                // Card 1
                VStack {
                    ZStack {
                        Color(red: 0.85, green: 0.80, blue: 0.72)
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.title3)
                                .foregroundStyle(Color.black.opacity(0.4))
                            Text("35MM FILM")
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color.black.opacity(0.6))
                        }
                    }
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 10, x: -4, y: 6)
                }
                .rotationEffect(.degrees(-8))

                // Card 2 (Center Hero)
                VStack {
                    ZStack {
                        LinearGradient(
                            colors: [Color(red: 0.94, green: 0.72, blue: 0.58), Color(red: 0.78, green: 0.42, blue: 0.32)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        VStack(spacing: 6) {
                            Text("JOURNAL")
                                .font(.system(size: 13, weight: .bold, design: .serif))
                            Text("// VOL. 1")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                        }
                        .foregroundStyle(.white)
                    }
                    .frame(width: 130, height: 185)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: .black.opacity(0.5), radius: 14, x: 0, y: 8)
                }
                .zIndex(1)

                // Card 3
                VStack {
                    ZStack {
                        Color(red: 0.22, green: 0.25, blue: 0.28)
                        VStack(spacing: 4) {
                            Image(systemName: "sun.haze.fill")
                                .font(.title3)
                                .foregroundStyle(Color.orange.opacity(0.8))
                            Text("KINFOLK")
                                .font(.system(size: 9, weight: .bold, design: .serif))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                    .frame(width: 110, height: 160)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .shadow(color: .black.opacity(0.4), radius: 10, x: 4, y: 6)
                }
                .rotationEffect(.degrees(8))
            }
            .padding(.vertical, 16)

            VStack(spacing: 8) {
                Text("Milyonlarca anıyı sanata dönüştürün")
                    .font(.system(size: 22, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text("Analog film dokuları, paspartu çerçeveler ve dergi mizanpajlarıyla hikayenize alan açın.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 28)
            }

            Spacer()
        }
    }

    // MARK: - Step 2: Personalize Experience
    private var personalizeStep: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 8) {
                Text("Deneyiminizi kişiselleştirin")
                    .font(.system(size: 24, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("Haven'ı nasıl kullanmayı planlıyorsunuz?")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
            }

            VStack(spacing: 12) {
                ForEach(purposes, id: \.0) { title, desc in
                    let isSelected = selectedPurpose == title
                    Button {
                        HavenHaptics.selection()
                        selectedPurpose = title
                    } label: {
                        HStack(spacing: 14) {
                            ZStack {
                                Circle()
                                    .strokeBorder(isSelected ? Color.black : Color.white.opacity(0.4), lineWidth: 2)
                                    .frame(width: 24, height: 24)

                                if isSelected {
                                    Circle()
                                        .fill(Color.black)
                                        .frame(width: 24, height: 24)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }

                            VStack(alignment: .leading, spacing: 3) {
                                Text(title)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(isSelected ? Color.black : Color.white)
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(isSelected ? Color.black.opacity(0.7) : Color.white.opacity(0.5))
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 16)
                        .background(isSelected ? Color.white : Color.white.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    // MARK: - Step 3: Ready
    private var readyStep: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 100, height: 100)

                Image(systemName: "sparkles")
                    .font(.system(size: 42))
                    .foregroundStyle(Color(red: 0.95, green: 0.75, blue: 0.25))
            }

            VStack(spacing: 10) {
                Text("Atölyeniz Hazır")
                    .font(.system(size: 26, weight: .bold, design: .serif))
                    .foregroundStyle(.white)

                Text("35mm vizör kameranız, editoryal mizanpajlarınız ve arşiv damgalarınız parmaklarınızın ucunda.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Controls
    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Step Indicators
            HStack(spacing: 6) {
                ForEach(0..<3) { idx in
                    Capsule()
                        .fill(currentStep == idx ? Color.white : Color.white.opacity(0.25))
                        .frame(width: currentStep == idx ? 24 : 6, height: 5)
                        .animation(.spring(response: 0.3), value: currentStep)
                }
            }

            // Action Button
            Button {
                HavenHaptics.medium()
                if currentStep < 2 {
                    withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                        currentStep += 1
                    }
                } else {
                    UserDefaults.standard.set(true, forKey: "hasCompletedHavenOnboarding")
                    onDismiss()
                }
            } label: {
                Text(currentStep == 0 ? "Başlayın" : (currentStep == 1 ? "Devam et" : "Atölyeyi Aç"))
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.15), radius: 10, y: 4)
            }
        }
    }
}
