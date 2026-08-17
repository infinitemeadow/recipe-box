import Foundation

enum MarkdownParser {
    static func parse(_ text: String, fileURL: URL, fileDate: Date?) -> Recipe {
        var lines = text.components(separatedBy: "\n")
        var front: [String: String] = [:]
        var tags: [String] = []

        // --- frontmatter ---
        if lines.first?.trimmingCharacters(in: .whitespaces) == "---" {
            lines.removeFirst()
            var fm: [String] = []
            while let l = lines.first, l.trimmingCharacters(in: .whitespaces) != "---" {
                fm.append(l)
                lines.removeFirst()
            }
            if !lines.isEmpty { lines.removeFirst() } // closing ---
            for l in fm {
                guard let idx = l.firstIndex(of: ":") else { continue }
                let key = String(l[l.startIndex..<idx]).trimmingCharacters(in: .whitespaces).lowercased()
                var val = String(l[l.index(after: idx)...]).trimmingCharacters(in: .whitespaces)
                if key == "tags" {
                    val = val.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
                    tags = val.split(separator: ",")
                        .map { $0.trimmingCharacters(in: .whitespaces) }
                        .filter { !$0.isEmpty }
                } else {
                    front[key] = val
                }
            }
        }

        // --- body sections ---
        var section = ""
        var ingredients: [Ingredient] = []
        var steps: [String] = []
        var notesLines: [String] = []
        var comments: [Comment] = []
        var titleFromBody: String?
        var currentGroup: String?

        for raw in lines {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                section = line.dropFirst(3).trimmingCharacters(in: .whitespaces).lowercased()
                currentGroup = nil     // subsections don't cross section boundaries
                continue
            }
            if line.hasPrefix("### ") {
                currentGroup = String(line.dropFirst(4)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.hasPrefix("# "), titleFromBody == nil {
                titleFromBody = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                continue
            }
            if line.isEmpty {
                if section == "notes" { notesLines.append("") }
                continue
            }
            switch section {
            case "ingredients":
                if line.hasPrefix("-") || line.hasPrefix("*") {
                    var ing = parseIngredient(line)
                    ing.group = currentGroup
                    ingredients.append(ing)
                }
            case "steps":
                let s = stripLeadingOrdinal(line)
                if !s.isEmpty { steps.append(s) }
            case "notes":
                notesLines.append(raw)
            case "comments":
                if line.hasPrefix("-") || line.hasPrefix("*") {
                    comments.append(parseComment(line))
                }
            default:
                break
            }
        }

        let title = front["title"]
            ?? titleFromBody
            ?? fileURL.deletingPathExtension().lastPathComponent
        let notes = notesLines.joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return Recipe(
            fileURL: fileURL,
            title: title,
            servings: front["servings"].flatMap { Int($0) },
            prepTime: front["prep_time"],
            cookTime: front["cook_time"],
            created: front["created"],
            addedDate: fileDate,
            cuisine: front["cuisine"],
            sourceURL: front["source_url"],
            tags: tags,
            ingredients: ingredients,
            steps: steps,
            notes: notes.isEmpty ? nil : notes,
            comments: comments
        )
    }

    // Comment line format: "- **Author** · 2026-08-10: text"
    private static let commentRe = try! NSRegularExpression(
        pattern: #"^\*\*(.+?)\*\*\s*·\s*(.+?):\s*(.*)$"#
    )

    static func parseComment(_ line: String) -> Comment {
        var s = line
        if s.hasPrefix("-") || s.hasPrefix("*") { s.removeFirst() }
        s = s.trimmingCharacters(in: .whitespaces)
        let ns = s as NSString
        if let m = commentRe.firstMatch(in: s, range: NSRange(location: 0, length: ns.length)),
           m.numberOfRanges == 4 {
            return Comment(author: ns.substring(with: m.range(at: 1)),
                           date: ns.substring(with: m.range(at: 2)),
                           text: ns.substring(with: m.range(at: 3)))
        }
        return Comment(author: nil, date: nil, text: s)
    }

    static func stripLeadingOrdinal(_ s: String) -> String {
        var str = s
        if let r = str.range(of: #"^\d+[\.\)]\s+"#, options: .regularExpression) {
            str.removeSubrange(r)
        } else if str.hasPrefix("-") || str.hasPrefix("*") {
            str.removeFirst()
        }
        return str.trimmingCharacters(in: .whitespaces)
    }

    static func parseIngredient(_ line: String) -> Ingredient {
        var s = line
        if s.hasPrefix("-") || s.hasPrefix("*") { s.removeFirst() }
        s = s.trimmingCharacters(in: .whitespaces)
        let raw = s

        var tokens = s.split(separator: " ", omittingEmptySubsequences: true).map(String.init)
        var qty: Double?

        if let first = tokens.first, let n = parseNumber(first) {
            var value = n
            tokens.removeFirst()
            // mixed number: "1 1/2"
            if n == n.rounded(), let next = tokens.first, next.contains("/"), let frac = parseNumber(next) {
                value += frac
                tokens.removeFirst()
            }
            qty = value
        }

        var unit: String?
        if tokens.count >= 2, let u = Units.canonicalUnit("\(tokens[0]) \(tokens[1])") {
            unit = u
            tokens.removeFirst()
            tokens.removeFirst()
        } else if let f = tokens.first, let u = Units.canonicalUnit(f) {
            unit = u
            tokens.removeFirst()
        }

        return Ingredient(quantity: qty, unit: unit, name: tokens.joined(separator: " "), raw: raw)
    }

    static func parseNumber(_ t: String) -> Double? {
        if t.contains("/") {
            let parts = t.split(separator: "/")
            if parts.count == 2, let a = Double(parts[0]), let b = Double(parts[1]), b != 0 {
                return a / b
            }
            return nil
        }
        return Double(t)
    }
}
