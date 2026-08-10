import SwiftUI

struct ImportView: View {
    let directory: URL
    var onImported: (URL) -> Void
    var onCancel: () -> Void

    @State private var text = ""
    @State private var copied = false
    @State private var showPrompt = false
    @FocusState private var editorFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Add a recipe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Button { showPrompt.toggle() } label: {
                    Label(showPrompt ? "Hide prompt" : "View prompt",
                          systemImage: "chevron.right")
                }
                .buttonStyle(PillButton())
                Button { copyPrompt() } label: {
                    Label(copied ? "Copied" : "Copy formatting prompt",
                          systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(PillButton(active: copied))
            }
            .padding(16)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }

            if showPrompt {
                ScrollView {
                    Text(RecipePrompt.text)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.muted)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                }
                .frame(height: 150)
                .background(Theme.surface2)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
            }

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .focused($editorFocused)
                .padding(12)
                .overlay(alignment: .topLeading) {
                    if text.isEmpty {
                        Text("---\ntitle: …\n---\n\n## Ingredients\n- …")
                            .font(.system(size: 13, design: .monospaced))
                            .foregroundStyle(Theme.faint.opacity(0.6))
                            .padding(.horizontal, 17)
                            .padding(.vertical, 20)
                            .allowsHitTesting(false)
                    }
                }

            HStack(spacing: 10) {
                Text(text.isEmpty ? "" : "Saves a .md file into \(directory.lastPathComponent)")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(PillButton())
                    .keyboardShortcut(.cancelAction)
                Button("Save recipe") { save() }
                    .buttonStyle(PillButton(active: true))
                    .keyboardShortcut(.return, modifiers: .command)
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(16)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        }
        .frame(width: 560, height: 460)
        .background(Theme.bg)
        .onAppear { editorFocused = true }
    }

    private func save() {
        guard let url = Importer.importPasted(text, into: directory) else { return }
        onImported(url)
    }

    private func copyPrompt() {
        RecipePrompt.copyToClipboard()
        copied = true
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            copied = false
        }
    }
}
