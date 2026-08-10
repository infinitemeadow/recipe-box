import Foundation

enum MeasureSystem { case us, metric }
enum MeasureDimension { case volume, weight }

struct UnitDef {
    let dimension: MeasureDimension
    let system: MeasureSystem
    let toBase: Double   // base unit: ml for volume, g for weight
}

enum Units {
    // Only convertible units appear here. Countable units (clove, can, pinch)
    // are intentionally absent so they pass through unchanged.
    static let defs: [String: UnitDef] = [
        "tsp":   UnitDef(dimension: .volume, system: .us,     toBase: 4.92892),
        "tbsp":  UnitDef(dimension: .volume, system: .us,     toBase: 14.7868),
        "cup":   UnitDef(dimension: .volume, system: .us,     toBase: 236.588),
        "fl oz": UnitDef(dimension: .volume, system: .us,     toBase: 29.5735),
        "ml":    UnitDef(dimension: .volume, system: .metric, toBase: 1),
        "l":     UnitDef(dimension: .volume, system: .metric, toBase: 1000),
        "oz":    UnitDef(dimension: .weight, system: .us,     toBase: 28.3495),
        "lb":    UnitDef(dimension: .weight, system: .us,     toBase: 453.592),
        "g":     UnitDef(dimension: .weight, system: .metric, toBase: 1),
        "kg":    UnitDef(dimension: .weight, system: .metric, toBase: 1000),
    ]

    // Maps real-world spellings (incl. the Claude widget's verbose ones) to canonical.
    static let aliases: [String: String] = [
        "tsp": "tsp", "teaspoon": "tsp", "teaspoons": "tsp",
        "tbsp": "tbsp", "tbs": "tbsp", "tablespoon": "tbsp", "tablespoons": "tbsp",
        "cup": "cup", "cups": "cup",
        "fl oz": "fl oz", "fluid ounce": "fl oz", "fluid ounces": "fl oz",
        "oz": "oz", "ounce": "oz", "ounces": "oz",
        "lb": "lb", "lbs": "lb", "pound": "lb", "pounds": "lb",
        "g": "g", "gram": "g", "grams": "g",
        "kg": "kg", "kilogram": "kg", "kilograms": "kg",
        "ml": "ml", "milliliter": "ml", "milliliters": "ml", "millilitre": "ml", "millilitres": "ml",
        "l": "l", "liter": "l", "liters": "l", "litre": "l", "litres": "l",
        "clove": "clove", "cloves": "clove",
        "can": "can", "cans": "can",
        "pinch": "pinch", "pinches": "pinch",
    ]

    static func canonicalUnit(_ token: String) -> String? {
        let t = token.lowercased().trimmingCharacters(in: CharacterSet(charactersIn: ".,;:"))
        return aliases[t]
    }

    // Render a quantity in the most readable unit *within* `system`, rolling small
    // units up to larger ones once there's enough (e.g. 16 tbsp → 1 cup, 8 tbsp →
    // 0.5 cup, 1500 g → 1.5 kg). Used for both native display (system = the unit's
    // own system) and the convert toggle (system = the other one). Unknown/countable
    // units pass through unchanged. Display-only; the source file is never rewritten.
    static func render(_ qty: Double, unit: String, in system: MeasureSystem) -> (Double, String) {
        guard let def = defs[unit] else { return (qty, unit) }
        let base = qty * def.toBase
        switch def.dimension {
        case .volume:
            if system == .metric {
                return base >= 1000 ? (base / 1000, "l") : (base, "ml")
            } else {
                let cup = base / 236.588
                if cup >= 0.25 { return (cup, "cup") }
                let tbsp = base / 14.7868
                if tbsp >= 1 { return (tbsp, "tbsp") }
                return (base / 4.92892, "tsp")
            }
        case .weight:
            if system == .metric {
                return base >= 1000 ? (base / 1000, "kg") : (base, "g")
            } else {
                let oz = base / 28.3495
                return oz >= 16 ? (base / 453.592, "lb") : (oz, "oz")
            }
        }
    }

    static func format(_ n: Double) -> String {
        let r = (n * 100).rounded() / 100
        if abs(r - r.rounded()) < 1e-9 { return String(Int(r.rounded())) }
        return String(format: "%g", r)
    }
}
