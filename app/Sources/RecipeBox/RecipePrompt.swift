import AppKit

// The copy-paste prompt that makes Claude emit app-ready recipe Markdown.
// Keep in sync with ../CLAUDE_RECIPE_PROMPT.md.
enum RecipePrompt {
    static let text = """
    You are generating a recipe for my Recipe Box app. Output ONLY a single Markdown file in a code block, with no commentary before or after. Follow this format exactly:

    ---
    title: <Recipe Name>
    servings: <integer>
    prep_time: <e.g. 10 min>
    cook_time: <e.g. 25 min>
    cuisine: <origin, e.g. Chinese, Italian, Mexican>
    tags: [<comma-separated lowercase tags>]
    source: Claude
    source_url: <original recipe URL if it came from one; otherwise omit this line>
    created: <YYYY-MM-DD>
    ---

    ## Ingredients

    - <quantity> <unit> <ingredient>, <optional prep note>
    - ...

    ## Steps

    1. <step>
    2. <step>

    ## Notes

    <Optional. Tips, substitutions, make-ahead, doneness cues. Omit the section if empty.>

    FORMAT RULES:
    - Frontmatter keys must appear exactly as above. `title` is required; omit any key you don't have a value for. `servings` is needed for scaling — infer a sensible integer if unstated. `cuisine` is the single origin the app groups by (e.g. Chinese, Italian) — set it when you can. `source_url` should be the original recipe's URL ONLY if this recipe came from a specific web page; otherwise omit the line entirely (do not invent a link).
    - KEEP THE RECIPE'S NATIVE UNITS. Do NOT convert between metric and US — the app does that at display time. Only normalize the spelling to the canonical forms below.
    - Every ingredient is one `-` bullet, QUANTITY first, then UNIT, then name. Example: `- 1 1/2 cups flour` or `- 60 g black beans`.
    - Canonical units (singular): tsp, tbsp, cup, fl oz, oz, lb, g, kg, ml, l, clove, can, pinch. Countable items take just a number: `- 2 eggs`.
    - Quantities: plain numbers, decimals, or simple fractions (`1.5`, `1/2`, `1 1/2`). No ranges in the ingredient line. No unicode fractions (½) — write `1/2`.
    - Steps: ordered `1.` list, one action each, imperative voice. Do NOT repeat ingredient quantities inside steps — refer to ingredients by name.
    - Temperatures in steps: write as `<number>°F` or `<number>°C`.
    - Do NOT include a `## Comments` section — that's reserved and managed by the app.
    - Keep the whole thing in ONE markdown code block.
    """

    static func copyToClipboard() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
    }
}
