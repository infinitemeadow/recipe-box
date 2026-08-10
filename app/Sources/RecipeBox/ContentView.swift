import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.scenePhase) private var scenePhase
    @State private var open: Recipe?

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if let recipe = open {
                ReadingView(recipe: recipe) { open = nil }
                    .transition(.opacity)
            } else {
                LibraryView { open = $0 }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        // If the open recipe disappears from disk, fall back to the library.
        .onReceive(store.$recipes) { list in
            if let o = open, !list.contains(where: { $0.id == o.id }) { open = nil }
        }
    }
}

// Shared keyboard-hint footer.
struct KeyHintBar: View {
    let hints: [(String, String)]
    var trailing: AnyView?

    init(_ hints: [(String, String)], trailing: AnyView? = nil) {
        self.hints = hints
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            ForEach(Array(hints.enumerated()), id: \.offset) { _, hint in
                HStack(spacing: 5) {
                    Text(hint.0)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Theme.surface2)
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(RoundedRectangle(cornerRadius: 5).stroke(Theme.line, lineWidth: 0.5))
                    Text(hint.1).font(.system(size: 12)).foregroundStyle(Theme.faint)
                }
            }
            Spacer()
            if let trailing { trailing }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(hex: 0x201D18))
        .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }
}

func sectionLabel(_ text: String) -> some View {
    Text(text.uppercased())
        .font(.system(size: 12))
        .tracking(0.8)
        .foregroundStyle(Theme.faint)
        .padding(.top, 18)
        .padding(.bottom, 4)
}
