# Claude Recipe Prompt

Copy the block below and paste it at the top of any chat where you want Claude to
generate a recipe for Recipe Box. It pins the Markdown format so the app parses
quantities, units, and metadata reliably.

Key principle: **recipes keep their native units. The app converts US ↔ metric at
display time.** Do NOT ask Claude to convert — that loses accuracy (weight↔volume
guessing, arithmetic slips) and duplicates a feature the app already has.

---

## Copy-paste prompt

````
You are generating a recipe for my Recipe Box app. Output ONLY a single Markdown
file in a code block, with no commentary before or after. Follow this format exactly:

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

<Optional. Tips, substitutions, make-ahead, doneness cues. Free prose. Omit the
whole section if there's nothing useful to add.>

FORMAT RULES:
- Frontmatter keys must appear exactly as above. `title` is required; omit any
  other key you don't have a value for (do not leave it blank). `servings` is
  needed for scaling — infer a sensible integer if the recipe doesn't state one.
- KEEP THE RECIPE'S NATIVE UNITS. Do NOT convert between metric and US — the app
  does that at display time, accurately. If the recipe is in grams and ml, leave
  it in grams and ml. Only normalize the SPELLING to the canonical forms below.
- Every ingredient is one `-` bullet. Put the QUANTITY FIRST, then the UNIT, then
  the ingredient name. Example: `- 1 1/2 cups flour` or `- 60 g black beans`.
- Canonical unit spellings (singular): tsp, tbsp, cup, fl oz, oz, lb, g, kg, ml,
  l, clove, can, pinch. For countable items with no unit (e.g. eggs, chillies),
  just write the number: `- 2 eggs`, `- 2 red chillies`.
- Ingredient quantities: plain numbers, decimals, or simple fractions (`1.5`,
  `1/2`, `1 1/2`). No ranges in the ingredient line ("2-3") — pick one number.
  No unicode fractions (½) — write `1/2`. (Time ranges inside step text like
  "4–5 min" are fine; the parser only reads the ingredient lines.)
- Steps: ordered `1.` list, one action per step, imperative voice. Do NOT repeat
  ingredient quantities inside steps — the app scales/converts the ingredient
  list, so inline amounts would go stale. Refer to ingredients by name.
- Temperatures in steps: write as `<number>°F` or `<number>°C` (whichever the
  recipe uses) so the app can convert them.
- Do NOT include a `## Comments` section — that's reserved and managed by the app.
- Keep the whole thing in ONE ```markdown code block so I can copy it to a file.
````

---

## Why each rule exists

| Rule | Enables |
|------|---------|
| Frontmatter keys fixed | Library table: title, serves, time, added, tags |
| `servings` always present | Serving scaler |
| Native units, app converts | Accurate US ↔ metric without weight↔volume guessing |
| Quantity-first ingredient lines | Conversion + scaling parser |
| Canonical unit spellings | Reliable unit lookup |
| `1/2` not `½`, no ranges in qty | Clean numeric parsing for scaling |
| Clean steps, no inline amounts | Scaled/converted numbers never go stale |
| `375°F` / `175°C` temp format | Temperature conversion in steps |
| Optional `## Notes` | Keeps the cooking knowledge (tips, doneness, subs) |

## Even simpler: let Claude write the file directly

If you're in Claude Code (or any chat with file access to your library folder),
you can skip copy-paste entirely:

> Using the Recipe Box format, write a recipe for <dish> as a `.md` file in
> `~/Recipes/`.

The format rules above still apply — the app picks the file up via folder watch.

## Graceful degradation

If a recipe doesn't perfectly follow the rules, it still displays. You just lose
the *automatic* features on the offending lines: an unparseable quantity simply
won't scale or convert, but the text renders fine. The prompt exists to maximize
how often those features "just work," not to gate recipes from showing up.
