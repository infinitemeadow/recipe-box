import SwiftUI
import AppKit

// Invisible anchor placed behind a SwiftUI button via `.background`. When `present`
// flips true, it shows the native macOS share sheet (AirDrop / Messages / Mail / …)
// for `items`, popping out from the button's own frame.
struct ShareAnchor: NSViewRepresentable {
    @Binding var present: Bool
    let items: [Any]

    func makeNSView(context: Context) -> NSView { NSView() }

    func updateNSView(_ nsView: NSView, context: Context) {
        guard present else { return }
        DispatchQueue.main.async {
            present = false
            guard nsView.window != nil else { return }
            let picker = NSSharingServicePicker(items: items)
            picker.show(relativeTo: nsView.bounds, of: nsView, preferredEdge: .minY)
        }
    }
}
