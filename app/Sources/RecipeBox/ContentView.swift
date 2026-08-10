import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: RecipeStore
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject private var updater = Updater.shared
    @State private var open: Recipe?

    var body: some View {
        VStack(spacing: 0) {
            updateBanner
            ZStack {
                Theme.bg.ignoresSafeArea()
                if let recipe = open {
                    ReadingView(recipe: recipe) { open = nil }
                        .transition(.opacity)
                } else {
                    LibraryView { open = $0 }
                }
            }
        }
        .onAppear { updater.check() }               // silent check on launch
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { store.reload() }
        }
        // If the open recipe disappears from disk, fall back to the library.
        .onReceive(store.$recipes) { list in
            if let o = open, !list.contains(where: { $0.id == o.id }) { open = nil }
        }
    }

    @ViewBuilder
    private var updateBanner: some View {
        if case let .available(version, url) = updater.state {
            HStack(spacing: 10) {
                Image(systemName: "arrow.down.circle").foregroundStyle(Theme.amber)
                Text("Version \(version) is available.")
                    .font(.system(size: 13)).foregroundStyle(Theme.text)
                Spacer()
                Button("Install & relaunch") { updater.installUpdate(from: url) }
                    .buttonStyle(PillButton(active: true))
                Button { updater.state = .idle } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.amber.opacity(0.12))
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        } else if updater.state == .downloading {
            HStack(spacing: 10) {
                ProgressView().controlSize(.small)
                Text("Downloading update…").font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        } else if let msg = updater.transientMessage {
            HStack(spacing: 10) {
                Text(msg).font(.system(size: 13)).foregroundStyle(Theme.muted)
                Spacer()
                Button { updater.transientMessage = nil } label: { Image(systemName: "xmark") }
                    .buttonStyle(.plain).foregroundStyle(Theme.faint)
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
            .background(Theme.surface)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
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
