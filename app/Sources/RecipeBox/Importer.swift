import Foundation

// Turns pasted text into a .md file in the library folder. Handles the common
// cases: a fenced ```markdown block, a recipe that already has frontmatter, or
// loose markdown where we infer a title and wrap minimal frontmatter.
enum Importer {
    @discardableResult
    static func importPasted(_ text: String, into dir: URL) -> URL? {
        var content = stripCodeFence(text.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !content.isEmpty else { return nil }

        let title: String
        if content.hasPrefix("---") {
            title = frontmatterTitle(content) ?? "Untitled Recipe"
        } else {
            let (inferred, body) = inferTitle(content)
            title = inferred
            content = wrapFrontmatter(title: inferred, body: body)
        }

        let url = uniqueURL(for: slugify(title), in: dir)
        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return url
        } catch {
            return nil
        }
    }

    static func stripCodeFence(_ s: String) -> String {
        var lines = s.components(separatedBy: "\n")
        guard let first = lines.first, first.trimmingCharacters(in: .whitespaces).hasPrefix("```") else {
            return s
        }
        lines.removeFirst()
        if let last = lines.last, last.trimmingCharacters(in: .whitespaces) == "```" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func frontmatterTitle(_ s: String) -> String? {
        let lines = s.components(separatedBy: "\n")
        for line in lines.dropFirst() {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            if let r = line.range(of: #"^\s*title\s*:"#, options: .regularExpression) {
                return String(line[r.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        return nil
    }

    // Pull a title from a leading "# Heading" or the first non-empty line.
    static func inferTitle(_ s: String) -> (title: String, body: String) {
        var lines = s.components(separatedBy: "\n")
        if let idx = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let line = lines[idx].trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("# ") {
                let title = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                lines.remove(at: idx)
                return (title, lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines))
            }
            // Plain first line with no markdown heading: keep it as the title,
            // leave the body intact so nothing is lost.
            if !line.hasPrefix("#"), !line.hasPrefix("-"), !line.hasPrefix("##") {
                return (line, s)
            }
        }
        return ("Untitled Recipe", s)
    }

    static func wrapFrontmatter(title: String, body: String) -> String {
        let today = isoToday()
        return """
        ---
        title: \(title)
        source: Pasted
        created: \(today)
        ---

        \(body)
        """
    }

    static func slugify(_ s: String) -> String {
        let lowered = s.lowercased()
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
        var out = ""
        var lastDash = false
        for scalar in lowered.unicodeScalars {
            if allowed.contains(scalar) {
                out.unicodeScalars.append(scalar)
                lastDash = false
            } else if !lastDash {
                out.append("-")
                lastDash = true
            }
        }
        let trimmed = out.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "recipe" : trimmed
    }

    static func uniqueURL(for slug: String, in dir: URL) -> URL {
        let fm = FileManager.default
        var candidate = dir.appendingPathComponent("\(slug).md")
        var n = 2
        while fm.fileExists(atPath: candidate.path) {
            candidate = dir.appendingPathComponent("\(slug)-\(n).md")
            n += 1
        }
        return candidate
    }

    static func isoToday() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
    }
}
