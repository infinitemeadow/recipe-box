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
    @State private var selectedTags: Set<String> = []
    @State private var selectedCuisines: Set<String> = []
    @State private var showFilters = false
    @State private var selected = 0
    @State private var scrollOnSelect = false   // only auto-scroll for keyboard nav
    @State private var showImport = false
    @FocusState private var focus: Field?

    private enum Field { case list, search }

    private var filtered: [Recipe] {
        let q = query.lowercased()
        return store.recipes.filter { r in
            let okQ = q.isEmpty || matches(r, q)
            let okCuisine = selectedCuisines.isEmpty || selectedCuisines.contains(r.origin)
            let okTags = selectedTags.isEmpty || !selectedTags.isDisjoint(with: Set(r.tags))
            return okQ && okCuisine && okTags
        }
    }

    // Search across everything useful, not just the title.
    private func matches(_ r: Recipe, _ q: String) -> Bool {
        if r.title.lowercased().contains(q) { return true }
        if r.origin.lowercased().contains(q) { return true }
        if r.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
        if r.ingredients.contains(where: { $0.name.lowercased().contains(q) }) { return true }
        if let notes = r.notes, notes.lowercased().contains(q) { return true }
        return false
    }

    private var allTags: [String] {
        var set = Set<String>()
        for r in store.recipes { for t in r.tags { set.insert(t) } }
        return set.sorted()
    }

    private var allCuisines: [String] {
        var set = Set<String>()
        for r in store.recipes { set.insert(r.origin) }
        return set.sorted { a, b in
            if a == "Other" { return false }
            if b == "Other" { return true }
            return a.localizedCaseInsensitiveCompare(b) == .orderedAscending
        }
    }

    private var activeFilterCount: Int { selectedTags.count + selectedCuisines.count }

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
        .onChange(of: selectedTags) { _, _ in selected = 0 }
        .onChange(of: selectedCuisines) { _, _ in selected = 0 }
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
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.faint)
                    TextField("Search recipes, ingredients, cuisine…", text: $query)
                        .textFieldStyle(.plain)
                        .foregroundStyle(Theme.text)
                        .focused($focus, equals: .search)
                        .onSubmit { focus = .list }
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill") }
                            .buttonStyle(.plain).foregroundStyle(Theme.faint)
                    }
                }
                .padding(.horizontal, 12)
                .frame(height: 38)
                .background(Theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))

                Button { showFilters.toggle() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text("Filter")
                        if activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 11, weight: .medium))
                                .padding(.horizontal, 6).padding(.vertical, 1)
                                .background(Theme.amber.opacity(0.22))
                                .foregroundStyle(Theme.amber)
                                .clipShape(Capsule())
                        }
                    }
                }
                .buttonStyle(PillButton(active: activeFilterCount > 0 || showFilters))
                .popover(isPresented: $showFilters, arrowEdge: .bottom) { filterPopover }

                Button { showImport = true } label: {
                    Label("Add", systemImage: "plus")
                }
                .buttonStyle(PillButton())
                .keyboardShortcut("n", modifiers: .command)
            }

            if activeFilterCount > 0 {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(allCuisines.filter { selectedCuisines.contains($0) }, id: \.self) { c in
                            removablePill(c) { selectedCuisines.remove(c) }
                        }
                        ForEach(allTags.filter { selectedTags.contains($0) }, id: \.self) { t in
                            removablePill(t) { selectedTags.remove(t) }
                        }
                        Button("Clear all") { selectedTags = []; selectedCuisines = [] }
                            .buttonStyle(.plain)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.faint)
                            .padding(.leading, 4)
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(16)
    }

    private func removablePill(_ label: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack(spacing: 5) {
                Text(label).font(.system(size: 12))
                Image(systemName: "xmark").font(.system(size: 9))
            }
            .foregroundStyle(Theme.amber)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(Theme.amber.opacity(0.14))
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.amberDim, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var filterPopover: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Filters").font(.system(size: 14, weight: .medium)).foregroundStyle(Theme.text)
                Spacer()
                if activeFilterCount > 0 {
                    Button("Clear") { selectedTags = []; selectedCuisines = [] }
                        .buttonStyle(.plain).font(.system(size: 12)).foregroundStyle(Theme.amber)
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if !allCuisines.isEmpty {
                        filterGroupTitle("Cuisine")
                        ForEach(allCuisines, id: \.self) { c in
                            filterRow(c, on: selectedCuisines.contains(c)) { toggle(&selectedCuisines, c) }
                        }
                    }
                    if !allTags.isEmpty {
                        filterGroupTitle("Tags")
                        ForEach(allTags, id: \.self) { t in
                            filterRow(t, on: selectedTags.contains(t)) { toggle(&selectedTags, t) }
                        }
                    }
                }
                .padding(.vertical, 6)
            }
            .frame(maxHeight: 340)
        }
        .frame(width: 240)
        .background(Theme.bg)
    }

    private func filterGroupTitle(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11)).tracking(0.7).foregroundStyle(Theme.faint)
            .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)
    }

    private func filterRow(_ label: String, on: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: on ? "checkmark.square.fill" : "square")
                    .font(.system(size: 14))
                    .foregroundStyle(on ? Theme.amber : Theme.faint)
                Text(label).font(.system(size: 13)).foregroundStyle(Theme.text)
                Spacer()
            }
            .contentShape(Rectangle())
            .padding(.horizontal, 14).padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ set: inout Set<String>, _ v: String) {
        if set.contains(v) { set.remove(v) } else { set.insert(v) }
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
                                        .onTapGesture { scrollOnSelect = false; selected = idx; focus = .list }
                                        .simultaneousGesture(TapGesture(count: 2).onEnded { onOpen(r) })
                                }
                            } header: {
                                groupHeader(group.origin, count: group.recipes.count)
                            }
                        }
                    }
                }
                .onChange(of: selected) { _, v in
                    guard scrollOnSelect else { return }
                    withAnimation(.easeOut(duration: 0.12)) { proxy.scrollTo(v, anchor: .center) }
                    scrollOnSelect = false
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
                HStack(spacing: 14) {
                    if store.canSync {
                        Button { store.syncNow() } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(store.isSyncing ? "Syncing…"
                                     : (store.syncStatus.isEmpty ? "Sync" : store.syncStatus))
                            }
                            .font(.system(size: 12))
                            .foregroundStyle(syncColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(store.isSyncing)
                    }
                    Button { chooseFolder() } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "folder")
                            Text("\(store.directory.lastPathComponent) · \(store.recipes.count) recipes")
                        }
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.faint)
                    }
                    .buttonStyle(.plain)
                }
            )
        )
    }

    private var syncColor: Color {
        let s = store.syncStatus
        if s.contains("conflict") || s.contains("issue") { return Theme.amber }
        return Theme.faint
    }

    // MARK: keyboard

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        let rows = flat
        switch press.key {
        case .upArrow:   scrollOnSelect = true; selected = max(0, selected - 1); return .handled
        case .downArrow: scrollOnSelect = true; selected = min(rows.count - 1, selected + 1); return .handled
        case .return:
            if rows.indices.contains(selected) { onOpen(rows[selected]) }
            return .handled
        default: break
        }
        switch press.characters {
        case "k": scrollOnSelect = true; selected = max(0, selected - 1); return .handled
        case "j": scrollOnSelect = true; selected = min(rows.count - 1, selected + 1); return .handled
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
