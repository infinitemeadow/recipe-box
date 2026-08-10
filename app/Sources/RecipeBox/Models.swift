import Foundation

struct Ingredient: Hashable {
    var quantity: Double?   // parsed leading amount, if any
    var unit: String?       // canonical unit ("g", "tbsp", …) or nil
    var name: String        // remainder of the line
    var raw: String         // original text, used when nothing parses
}

struct Comment: Hashable {
    var author: String?
    var date: String?
    var text: String
}

struct Recipe: Identifiable, Hashable {
    var id: URL { fileURL }
    let fileURL: URL
    var title: String
    var servings: Int?
    var prepTime: String?
    var cookTime: String?
    var created: String?    // raw frontmatter value, e.g. "2026-06-13"
    var addedDate: Date?    // filesystem date, fallback for sorting/display
    var cuisine: String?    // explicit origin, e.g. "Chinese"
    var sourceURL: String?  // reference link, if the recipe came from a URL
    var tags: [String]
    var ingredients: [Ingredient]
    var steps: [String]
    var notes: String?
    var comments: [Comment]

    // Recipes keep native units; the dominant system decides the convert target.
    var dominantSystem: MeasureSystem {
        var us = 0, metric = 0
        for ing in ingredients {
            guard let u = ing.unit, let def = Units.defs[u] else { continue }
            if def.system == .us { us += 1 } else { metric += 1 }
        }
        return metric > us ? .metric : .us
    }

    // Origin used for grouping: the explicit `cuisine`, else the first tag that
    // looks like an origin, else "Other".
    var origin: String {
        if let c = cuisine?.trimmingCharacters(in: .whitespaces), !c.isEmpty {
            return c
        }
        for t in tags where Recipe.knownOrigins.contains(t.lowercased()) {
            return t.capitalized
        }
        return "Other"
    }

    static let knownOrigins: Set<String> = [
        // East & Southeast Asia
        "chinese", "cantonese", "sichuan", "hunan", "taiwanese", "hong kong",
        "japanese", "korean", "thai", "vietnamese", "filipino", "malaysian",
        "indonesian", "singaporean", "burmese", "cambodian", "laotian",
        // South & Central Asia
        "indian", "pakistani", "sri lankan", "nepali", "bangladeshi", "afghan",
        // Middle East & North Africa
        "middle eastern", "lebanese", "turkish", "persian", "iranian", "israeli",
        "syrian", "moroccan", "egyptian", "tunisian", "algerian",
        // Africa
        "ethiopian", "nigerian", "west african", "south african", "african",
        // Europe
        "greek", "italian", "french", "spanish", "portuguese", "german",
        "austrian", "swiss", "belgian", "dutch", "british", "english", "irish",
        "scottish", "polish", "russian", "ukrainian", "hungarian", "czech",
        "romanian", "georgian", "nordic", "scandinavian", "swedish", "norwegian",
        "danish", "finnish", "mediterranean", "eastern european",
        // Americas & Oceania
        "american", "southern", "cajun", "creole", "tex-mex", "mexican",
        "peruvian", "brazilian", "argentine", "colombian", "caribbean",
        "jamaican", "cuban", "hawaiian", "australian",
    ]

    // A displayable/openable link only if it's a real http(s) URL.
    var sourceLink: URL? {
        guard let s = sourceURL?.trimmingCharacters(in: .whitespaces), !s.isEmpty,
              let url = URL(string: s), let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else { return nil }
        return url
    }

    var sortDate: Date? {
        if let c = created, let d = Recipe.isoFormatter.date(from: c) { return d }
        return addedDate
    }

    var addedDisplay: String {
        if let c = created, let d = Recipe.isoFormatter.date(from: c) {
            return Recipe.shortFormatter.string(from: d)
        }
        if let d = addedDate { return Recipe.shortFormatter.string(from: d) }
        return created ?? "—"
    }

    static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    static let shortFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
