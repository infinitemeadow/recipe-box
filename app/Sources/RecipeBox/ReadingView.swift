import SwiftUI
import AppKit

// How ingredient quantities are shown: as written, forced metric, or forced US.
enum UnitDisplay: String, CaseIterable {
    case original = "Original"
    case metric = "Metric"
    case us = "US"
}

struct ReadingView: View {
    @EnvironmentObject var store: RecipeStore
    let recipe: Recipe
    var onBack: () -> Void

    @State private var servings: Int
    @State private var unitMode: UnitDisplay = .original
    @State private var done: Set<Int> = []
    @State private var current = 0
    @State private var popoverIndex: Int?
    @State private var presentShare = false
    @State private var localComments: [Comment]
    @State private var newComment = ""
    @State private var activity: NSObjectProtocol?
    @FocusState private var focused: Bool
    @FocusState private var commentFocused: Bool

    private let baseServings: Int

    init(recipe: Recipe, onBack: @escaping () -> Void) {
        self.recipe = recipe
        self.onBack = onBack
        let base = max(recipe.servings ?? 1, 1)
        self.baseServings = base
        _servings = State(initialValue: base)
        _localComments = State(initialValue: recipe.comments)
    }

    private var factor: Double {
        Double(servings) / Double(baseServings)
    }

    private func displayQty(_ ing: Ingredient) -> String {
        guard let q = ing.quantity else { return "" }
        let scaled = q * factor
        guard let u = ing.unit else { return Units.format(scaled) }
        guard let def = Units.defs[u] else { return "\(Units.format(scaled)) \(u)" }
        let system: MeasureSystem
        switch unitMode {
        case .original: system = def.system   // as written, still rolled up
        case .metric:   system = .metric
        case .us:       system = .us
        }
        let (v, label) = Units.render(scaled, unit: u, in: system)
        return "\(Units.format(v)) \(label)"
    }

    private func cycleUnits() {
        let all = UnitDisplay.allCases
        let idx = all.firstIndex(of: unitMode) ?? 0
        unitMode = all[(idx + 1) % all.count]
    }

    private func openInEditor() {
        NSWorkspace.shared.open(recipe.fileURL)
    }

    private func isConvertible(_ ing: Ingredient) -> Bool {
        ing.quantity != nil && ing.unit.flatMap { Units.defs[$0] } != nil
    }

    // All units in the ingredient's dimension, scaled to current servings.
    private func conversions(for ing: Ingredient) -> [(unit: String, value: String, current: Bool)] {
        guard let q = ing.quantity, let u = ing.unit, let def = Units.defs[u] else { return [] }
        let base = q * factor * def.toBase
        let volume: [(String, Double)] = [("tsp", 4.92892), ("tbsp", 14.7868), ("fl oz", 29.5735), ("cup", 236.588), ("ml", 1), ("l", 1000)]
        let weight: [(String, Double)] = [("g", 1), ("oz", 28.3495), ("lb", 453.592), ("kg", 1000)]
        let table = def.dimension == .volume ? volume : weight
        return table.map { (name, toBase) in (name, Units.format(base / toBase), name == u) }
    }

    @ViewBuilder
    private func quantityView(idx: Int, ing: Ingredient) -> some View {
        let label = Text(displayQty(ing))
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Theme.amber)
            .frame(width: 100, alignment: .leading)

        if isConvertible(ing) {
            label
                .contentShape(Rectangle())
                .onTapGesture { popoverIndex = idx }
                .onHover { inside in
                    if inside { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
                .popover(isPresented: Binding(
                    get: { popoverIndex == idx },
                    set: { if !$0 { popoverIndex = nil } }
                ), arrowEdge: .trailing) {
                    conversionPopover(for: ing)
                }
        } else {
            label
        }
    }

    private func conversionPopover(for ing: Ingredient) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(ing.name.isEmpty ? ing.raw : ing.name)
                .font(.system(size: 12))
                .foregroundStyle(Theme.faint)
                .lineLimit(1)
                .padding(.bottom, 8)
            ForEach(conversions(for: ing), id: \.unit) { row in
                HStack(spacing: 8) {
                    Text(row.value)
                        .font(.system(size: 15, weight: row.current ? .medium : .regular))
                        .foregroundStyle(row.current ? Theme.amber : Theme.text)
                        .frame(width: 64, alignment: .trailing)
                    Text(row.unit)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.muted)
                    Spacer()
                }
                .padding(.vertical, 3)
            }
        }
        .padding(14)
        .frame(width: 190)
        .background(Theme.surface)
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    Text(recipe.title)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Theme.text)
                    metaRow.padding(.top, 4)

                    sectionLabel("Ingredients")
                    ForEach(Array(recipe.ingredients.enumerated()), id: \.offset) { idx, ing in
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            quantityView(idx: idx, ing: ing)
                            Text(ing.name.isEmpty ? ing.raw : ing.name)
                                .font(.system(size: 17))
                                .foregroundStyle(Theme.text)
                            Spacer()
                        }
                        .padding(.vertical, 9)
                        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
                    }

                    sectionLabel("Steps")
                    ForEach(Array(recipe.steps.enumerated()), id: \.offset) { idx, step in
                        stepRow(idx: idx, step: step)
                    }

                    if let notes = recipe.notes {
                        sectionLabel("Notes")
                        Text(notes)
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.muted)
                            .lineSpacing(4)
                            .padding(.top, 4)
                            .padding(.bottom, 8)
                    }

                    if let link = recipe.sourceLink {
                        sectionLabel("Source")
                        Link(destination: link) {
                            HStack(spacing: 6) {
                                Image(systemName: "link").font(.system(size: 12))
                                Text(link.host ?? link.absoluteString).lineLimit(1)
                            }
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.amber)
                        }
                        .padding(.top, 4)
                        .padding(.bottom, 8)
                    }

                    commentsSection
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            footer
        }
        .background(Theme.bg)
        .focusable()
        .focused($focused)
        .onKeyPress { handleKey($0) }
        .onAppear {
            focused = true
            activity = ProcessInfo.processInfo.beginActivity(
                options: [.idleDisplaySleepDisabled, .userInitiated],
                reason: "Recipe Box — cooking"
            )
        }
        .onDisappear {
            if let a = activity { ProcessInfo.processInfo.endActivity(a); activity = nil }
        }
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Label("Library", systemImage: "chevron.left")
            }
            .buttonStyle(PillButton())

            Button { openInEditor() } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(PillButton())
            .help("Edit the .md file (e)")

            Button { presentShare = true } label: {
                Image(systemName: "square.and.arrow.up")
            }
            .buttonStyle(PillButton())
            .background(ShareAnchor(present: $presentShare, items: [recipe.fileURL]))
            .help("Share the .md file (s)")

            Spacer()

            unitSelector

            HStack(spacing: 2) {
                stepButton("minus") { if servings > 1 { servings -= 1 } }
                    .disabled(servings <= 1)
                Text("\(servings) serv")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .frame(width: 64)
                stepButton("plus") { servings += 1 }
            }
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 4)
            .padding(.vertical, 3)
            .background(Theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: 0x201D18))
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }

    private var unitSelector: some View {
        HStack(spacing: 0) {
            ForEach(UnitDisplay.allCases, id: \.self) { mode in
                let on = unitMode == mode
                Button { unitMode = mode } label: {
                    Text(mode.rawValue)
                        .font(.system(size: 12, weight: on ? .medium : .regular))
                        .foregroundStyle(on ? Theme.amber : Theme.muted)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .background(on ? Theme.amber.opacity(0.14) : Color.clear)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Show quantities in \(mode.rawValue.lowercased()) units")
            }
        }
        .fixedSize(horizontal: true, vertical: false)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))
    }

    private func stepButton(_ symbol: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .medium))
                .frame(width: 30, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var metaRow: some View {
        HStack(spacing: 12) {
            if let p = recipe.prepTime { Text("Prep \(p)") }
            if let c = recipe.cookTime { Text("Cook \(c)") }
            if factor != 1 {
                Text("scaled \(Units.format(factor))×").foregroundStyle(Theme.amber)
            }
        }
        .font(.system(size: 13))
        .foregroundStyle(Theme.faint)
    }

    private func stepRow(idx: Int, step: String) -> some View {
        let isDone = done.contains(idx)
        let isCur = idx == current && !isDone
        return HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(isDone ? Theme.green : (isCur ? Theme.amber : Color.clear))
                    .frame(width: 26, height: 26)
                    .overlay(Circle().stroke(Theme.line, lineWidth: (isDone || isCur) ? 0 : 0.5))
                if isDone {
                    Image(systemName: "checkmark").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.bg)
                } else {
                    Text("\(idx + 1)").font(.system(size: 13))
                        .foregroundStyle(isCur ? Theme.bg : Theme.muted)
                }
            }
            Text(step)
                .font(.system(size: 17))
                .foregroundStyle(Theme.text)
                .strikethrough(isDone)
                .opacity(isDone ? 0.4 : 1)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 13)
        .contentShape(Rectangle())
        .onTapGesture { current = idx; toggle(idx) }
        .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
    }

    private var footer: some View {
        KeyHintBar(
            [("esc", "back"), ("space", "next"), ("x", "check"), ("u", "units"),
             ("+ -", "scale"), ("e", "edit"), ("s", "share")]
        )
    }

    private var commentsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Comments")
            if localComments.isEmpty {
                Text("No comments yet.")
                    .font(.system(size: 14)).foregroundStyle(Theme.faint)
                    .padding(.vertical, 6)
            }
            ForEach(Array(localComments.enumerated()), id: \.offset) { _, c in
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(c.author ?? "Someone")
                            .font(.system(size: 13, weight: .medium)).foregroundStyle(Theme.amber)
                        if let d = c.date {
                            Text(d).font(.system(size: 12)).foregroundStyle(Theme.faint)
                        }
                    }
                    Text(c.text).font(.system(size: 15)).foregroundStyle(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
                .overlay(alignment: .bottom) { Rectangle().fill(Theme.line).frame(height: 0.5) }
            }
            HStack(spacing: 8) {
                TextField("Add a comment…", text: $newComment, axis: .vertical)
                    .textFieldStyle(.plain)
                    .foregroundStyle(Theme.text)
                    .focused($commentFocused)
                    .lineLimit(1...4)
                    .onSubmit { addComment() }
                    .padding(.horizontal, 12).padding(.vertical, 9)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.line, lineWidth: 0.5))
                Button("Post") { addComment() }
                    .buttonStyle(PillButton(active: true))
                    .disabled(newComment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.top, 10)
            .padding(.bottom, 8)
        }
    }

    private func addComment() {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        if let written = store.addComment(to: recipe.fileURL, text: text) {
            localComments.append(written)
            newComment = ""
            commentFocused = false
        }
    }

    private func toggle(_ i: Int) {
        if done.contains(i) { done.remove(i) } else { done.insert(i) }
    }

    private func handleKey(_ press: KeyPress) -> KeyPress.Result {
        if commentFocused { return .ignored }   // let the comment field handle typing
        let lastStep = max(recipe.steps.count - 1, 0)
        switch press.key {
        case .escape: onBack(); return .handled
        case .space:  current = min(lastStep, current + 1); return .handled
        default: break
        }
        switch press.characters {
        case "x": toggle(current); return .handled
        case "u": cycleUnits(); return .handled
        case "e": openInEditor(); return .handled
        case "s": presentShare = true; return .handled
        case "+", "=": servings += 1; return .handled
        case "-": if servings > 1 { servings -= 1 }; return .handled
        case "j": current = min(lastStep, current + 1); return .handled
        case "k": current = max(0, current - 1); return .handled
        default: return .ignored
        }
    }
}
