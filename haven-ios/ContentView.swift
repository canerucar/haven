import SwiftUI

struct ContentView: View {
    @State private var selectedFormat: HavenFormat?

    var body: some View {
        Group {
            if let selectedFormat {
                EditorView(format: selectedFormat) {
                    self.selectedFormat = nil
                }
            } else {
                HomeView { format in
                    selectedFormat = format
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

#Preview {
    ContentView()
}
