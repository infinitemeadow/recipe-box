import SwiftUI

// In-app raw Markdown editor for a recipe's .md source. Save writes the file
// (which reloads + syncs); Cancel discards.
struct EditRecipeView: View {
    let title: String
    @State var text: String
    var onSave: (String) -> Void
    var onCancel: () -> Void
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Edit \(title)")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                Spacer()
                Text("Markdown source")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
            }
            .padding(16)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }

            TextEditor(text: $text)
                .font(.system(size: 13, design: .monospaced))
                .foregroundStyle(Theme.text)
                .scrollContentBackground(.hidden)
                .background(Theme.surface)
                .focused($focused)
                .padding(12)

            HStack(spacing: 10) {
                Text("Saves to the .md file and syncs.")
                    .font(.system(size: 12)).foregroundStyle(Theme.faint)
                Spacer()
                Button("Cancel", action: onCancel)
                    .buttonStyle(PillButton())
                    .keyboardShortcut(.cancelAction)
                Button("Save") { onSave(text) }
                    .buttonStyle(PillButton(active: true))
                    .keyboardShortcut(.return, modifiers: .command)
            }
            .padding(16)
            .overlay(alignment: .top) { Rectangle().fill(Theme.line).frame(height: 0.5) }
        }
        .frame(width: 640, height: 580)
        .background(Theme.bg)
        .onAppear { focused = true }
    }
}
