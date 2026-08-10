import SwiftUI
import AppKit

private enum Col {
    static let serves: CGFloat = 60
    static let time: CGFloat = 84
    static let added: CGFloat = 74
    static let tags: CGFloat = 170
}

struct LibraryView: View {
    @EnvironmentObject var store: RecipeStore
    var onOpen: (Recipe) -> Void

    @State private var query = ""
    @State private var activeTag: String?
    @State private var selected = 0
    @State private var showImport = false
    @FocusState private var focus: Field?

    private enum Field { case list, search }

    private var filtered: [Recipe] {
        store.recipes.filter { r in
            let okTag = activeTag == nil || r.tags.contains(activeTag!)
            let q = query.lowercased()
            let okQ = q.isEmpty
                || r.title.lowercased().contains(q)
                || r.tags.contains { $0.lowercased().contains(q) }
            return okTag && okQ
        }
    }

    private var allTags: [String] {
        var seen: [String] = []
        for r in store.recipes {
            for t in r.tags where !seen.contains(t) { seen.append(t) }
        }
        return seen
    }

    // Recipes grouped by origin: groups alphabetical ("Other" last), newest-first
    // within each group.
    private var groups: [(origin: String, recipes: [Recipe])] {
        let dict = Dictionary(grouping: filtered) { $0.origin }
        let keys = dict.keys.sorted { a, b in
            if a == "Other" { return false }
            if b == "Other" { return true }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
        return keys.map { key in
            (key, dict[key]!.sorted { ($0.sortDate ?? .distantPast) > ($1.sortDate ?? .distantPast) })
        }
    }

    // Flattened display order, so ↑↓ move through rows across group boundaries.
    private var flat: [Recipe] { groups.flatMap { $0.recipes } }

    var body: some View {
        VStack(spacing: 0) {
            header
            columnsHeader
            Rectangle().fill(Theme.line).frame(height: 0.5)
            listOrEmpty
            footer
        }
        .background(Theme.bg)
        .onAppear { focus = .list; clamp() }
        .onChange(of: query) { _, _ in selected = 0 }
        .onChange(of: activeTag) { _, _ in selected = 0 }
        .sheet(isPresented: $showImport) {
            ImportView(directory: store.directory) { url in
                showImport = false
                store.reload()
                if let r = store.recipes.first(where: { $0.fileURL == url }) { onOpen(r) }
            } onCancel: {
                showImport = false
            }
        }
    }

    // MARK: search + tags

    private var header: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                    TextField("Search recipes…", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.text)
                        .focused($focus, equals: .search)
                        .onSubmit { focus = .list }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))

                Button { showImport = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(PillButton())
                .keyboardShortcut("n", modifiers: .command)
            }

            if !allTags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(allTags, id: \.self) { tag in
                            let on = activeTag == tag
                            Text(tag)
                                .font(.system(size: 12))
                                .foregroundStyle(on ? Theme.amber : Theme.muted)
                                .padding(.horizontal, 11)
                                .padding(.vertical, 5)
                                .background(on ? Theme.amber.opacity(0.14) : Color.clear)
                                .clipShape(Capsule())
                                .overlay(Capsule().stroke(on ? Theme.amberDim : Theme.line, lineWidth: 0.5))
                                .onTapGesture { activeTag = on ? nil : tag }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(16)
    }

    private var columnsHeader: some View {
        HStack(spacing: 12) {
            colLabel("Recipe", maxWidth: .infinity)
            colLabel("Serves", width: Col.serves)
            colLabel("Time", width: Col.time)
            colLabel("Added", width: Col.added)
            colLabel("Tags", width: Col.tags)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 9)
    }

    private func colLabel(_ text: String, width: CGFloat? = nil, maxWidth: CGFloat? = nil) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11))
            .tracking(0.7)
            .foregroundStyle(Theme.faint)
            .frame(width: width, alignment: .leading)
            .frame(maxWidth: maxWidth, alignment: .leading)
    }

    // MARK: list

    @ViewBuilder
    private var listOrEmpty: some View {
        if filtered.isEmpty {
            if store.recipes.isEmpty {
                emptyLibrary
            } else {
                VStack {
                    Spacer()
                    Text("No recipes match.")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.faint)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        } else {
            let flatIndex = Dictionary(uniqueKeysWithValues: flat.enumerated().map { ($0.element.id, $0.offset) })
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: [.sectionHeaders]) {
                        ForEach(groups, id: \.origin) { group in
                            Section {
                                ForEach(group.recipes, id: \.id) { r in
                                    let idx = flatIndex[r.id] ?? 0
                                    row(idx: idx, r: r)
                                        .id(idx)
                                        .contentShape(Rectangle())
                                        .onTapGesture { selected = idx; focus = .list }
                                        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen(r) })
                                }
                            } header: {
                                groupHeader(group.origin, count: group.recipes.count)
                            }
                        }
                    }
                }
                .onChange(of: selected) { _, v in
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(v, anchor: .center) }
                }
            }
            .focusable()
            .focused($focus, equals: .list)
            .onKeyPress { handleKey($0) }
        }
    }

    private func groupHeader(_ origin: String, count: Int) -> some View {
        HStack(spacing: 8) {
            Text(origin)
                .font(.system(size: 12, weight: .medium))
                .tracking(0.4)
                .foregroundStyle(Theme.amber)
            Text("\(count)")
                .font(.system(size: 11))
                .foregroundStyle(Theme.faint)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 7)
        .background(Theme.bg)
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }

    private var emptyLibrary: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "fork.knife")
                .font(.system(size: 34))
                .foregroundStyle(Theme.faint)
            VStack(spacing: 5) {
                Text("No recipes yet")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("Generate one with Claude, then paste it in — or drop a .md file into your library folder.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.faint)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            HStack(spacing: 10) {
                Button { RecipePrompt.copyToClipboard() } label: {
                    Label("Copy formatting prompt", systemImage: "doc.on.doc")
                }
                .buttonStyle(PillButton())
                Button { showImport = true } label: {
                    Label("Add recipe", systemImage: "plus")
                }
                .buttonStyle(PillButton(active: true))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func row(idx: Int, r: Recipe) -> some View {
        let isSel = idx == selected
        return HStack(spacing: 12) {
            Text(r.title)
                .foregroundStyle(isSel ? Theme.amber : Theme.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(r.servings.map(String.init) ?? "—")
                .foregroundStyle(Theme.muted).frame(width: Col.serves, alignment: .leading)
            Text(r.cookTime ?? "—")
                .foregroundStyle(Theme.muted).frame(width: Col.time, alignment: .leading)
            Text(r.addedDisplay)
                .foregroundStyle(Theme.muted).frame(width: Col.added, alignment: .leading)
            Text(r.tags.joined(separator: " · "))
                .foregroundStyle(Theme.muted).lineLimit(1).frame(width: Col.tags, alignment: .leading)
        }
        .font(.system(size: 14))
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
        .background(isSel ? Theme.surface : Color.clear)
        .overlay(alignment: .leading) {
            if isSel { Rectangle().fill(Theme.amber).frame(width: 3) }
        }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }

    private var footer: some View {
        KeyHintBar(
            [("↑↓", "navigate"), ("↵", "open"), ("/", "search")],
            trailing: AnyView(
                Button {
                    chooseFolder()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder")
                        Text("\(store.directory.lastPathComponent) · \(store.recipes.count) recipes")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.faint)
                }
                .buttonStyle(.plain)
            )
        )
    }

    // MARK: keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let rows = flat
        switch press.key {
        case .upArrow:   selected = max(0, selected - 1); return .handled
        case .downArrow: selected = min(rows.count - 1, selected + 1); return .handled
        case .return:
            if rows.indices.contains(selected) { onOpen(rows[selected]) }
            return .handled
        default: break
        }
        switch press.characters {
        case "k": selected = max(0, selected - 1); return .handled
        case "j": selected = min(rows.count - 1, selected + 1); return .handled
        case "/": focus = .search; return .handled
        case "n": showImport = true; return .handled
        default: return .ignored
        }
    }

    private func clamp() {
        if selected >= flat.count { selected = max(0, flat.count - 1) }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = store.directory
        if panel.runModal() == .OK, let url = panel.url {
            store.setDirectory(url)
        }
    }
}
