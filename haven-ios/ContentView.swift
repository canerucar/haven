import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "house.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.tint)

                Text("Haven")
                    .font(.largeTitle.bold())

                Text("Your safe place.")
                    .foregroundStyle(.secondary)
            }
            .padding()
            .navigationTitle("Haven")
        }
    }
}

#Preview {
    ContentView()
}
