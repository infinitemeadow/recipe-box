# Recipe Box — PRD

A local macOS app for storing, reading, and cooking from Claude-generated recipes.

**Owner:** Basil
**Status:** Draft v1
**Last updated:** 2026-06-13

---

## 1. Problem

Claude is great at generating recipes, but they currently live in throwaway chat
transcripts. There's no durable, browsable, kitchen-friendly home for them. I want
a place that is:

- **Trivial for Claude to write to** — no API, no special format gymnastics.
- **Trivial for me to load** — drop a file or paste text.
- **Pleasant to actually cook from** — readable at arm's length, controllable with
  messy/wet hands, with the unit conversions I always end up Googling.

## 2. Goals

1. Store a personal library of recipes locally, no cloud or account required.
2. Make adding a recipe a 5-second action (file drop OR paste).
3. A clean, large-type reading view optimized for the counter while cooking.
4. Keyboard-first controls so I can navigate without touching the trackpad.
5. Inline unit conversion (US volume ↔ metric, common kitchen units).

## 3. Non-Goals (v1)

- No meal planning, shopping lists, or grocery integration.
- No multi-user, sharing, or sync.
- No nutrition calculation.
- No recipe editing UI beyond what a text editor already gives me (files are the
  source of truth; edit in any editor and the app re-reads).
- No iOS/iPad app (macOS only for v1).

## 4. Users

Just me. Single-user, single-machine. Optimized for one person who reads recipes
from Claude and cooks at home.

## 5. Core Concept: Recipes Are Markdown Files

The library is a **folder of `.md` files**. Each file is one recipe. This is the
whole storage model — no database, no proprietary format.

- Claude can produce a recipe by writing a single Markdown file.
- I can back up / version / sync the library with anything (Git, iCloud, Dropbox).
- The app is a *reader and organizer* over that folder, not a gatekeeper.

### 5.1 Recipe File Format

YAML frontmatter for structured metadata + Markdown body for the human-readable
recipe. All frontmatter fields optional except `title`.

```markdown
---
title: Weeknight Miso Salmon
servings: 2
prep_time: 10 min
cook_time: 15 min
tags: [seafood, weeknight, japanese]
source: Claude
created: 2026-06-13
---

## Ingredients

- 2 salmon fillets (~6 oz each)
- 2 tbsp white miso
- 1 tbsp mirin
- 1 tsp soy sauce
- 1/2 tsp grated ginger

## Steps

1. Whisk miso, mirin, soy, and ginger into a glaze.
2. Coat the salmon and rest 10 min.
3. Broil 8–10 min until caramelized.
```

The format is intentionally just "nice Markdown." Ingredient quantities are parsed
opportunistically for conversion (see §6.3) but a recipe never *requires* special
syntax to display correctly. An optional `## Notes` section (tips, substitutions,
doneness cues) is preserved and shown at the bottom of the reading view. Steps do
*not* repeat ingredient amounts — inline numbers would go stale when the recipe is
scaled or unit-converted. The full format contract lives in
[CLAUDE_RECIPE_PROMPT.md](CLAUDE_RECIPE_PROMPT.md).

## 6. Features

### 6.1 Library View
- **Table layout** (not cards) — one row per recipe, columns:
  `Recipe · Serves · Time · Added · Tags`.
- **Grouped by origin** (the `cuisine` field, or a recognized origin tag as
  fallback, else "Other" last). Groups are alphabetical with pinned headers;
  within a group, newest first (by `Added` / `created`).
- Keyboard row navigation; selected row gets an ochre accent.
- Filter by tag (tag chips above the table).
- Live search across title, tags, and body text.
- Empty state explains how to add the first recipe.
- No column sorting in v1 (table order is newest-first; search/filter cover the
  real "find a recipe" need).

### 6.2 Reading View ("Cook Mode")
- Large, high-contrast typography tuned for ~2–3 ft viewing distance.
- Ingredients and steps clearly sectioned; generous line height.
- **Step check-off:** tap or keypress to dim completed steps.
- **Screen stays awake** while a recipe is open (no sleep mid-cook).
- Optional serving-size scaler that multiplies parsed quantities (e.g. 2 → 4).
  Scaled values display as decimals (e.g. 0.75 cup); no fraction rounding in v1.
- *(Future)* "live step quantities": since steps don't embed amounts, Cook Mode
  could surface the relevant ingredient's *current* scaled/converted quantity
  inline beside a step on demand — convenience without stale numbers.

### 6.3 Unit Conversion
- **Recipes store their native units** (a metric recipe stays metric on disk). The
  app converts at *display* time — Claude is never asked to convert, which avoids
  inaccurate weight↔volume guesses and arithmetic slips.
- **Unit selector** (radio group): **Original / Metric / US** picks how the whole
  recipe's quantities display; `u` cycles it. Small units roll up to larger ones
  (e.g. 16 tbsp → 1 cup, 1500 g → 1.5 kg).
- Tap/select any quantity to see conversions in a small popover.
- Conversions happen **only within a dimension**: volume↔volume (ml↔tsp/tbsp/cup/
  fl oz), weight↔weight (g/kg↔oz/lb), temp (°F↔°C). Weight↔volume is never
  attempted (needs density) — those quantities just display as written.
- Supported units: tsp, tbsp, cup, fl oz, oz, lb, g, kg, ml, l, °F, °C.
- Conversions are display-only; the source file is never rewritten.

| From | To | Example |
|------|-----|---------|
| 1 cup | 240 ml | volume |
| 1 tbsp | 15 ml | volume |
| 1 tsp | 5 ml | volume |
| 1 oz | 28 g | weight |
| 350 °F | 175 °C | temp |

### 6.4 Adding Recipes (two paths, per decision)
1. **Folder watch (primary):** anything dropped into the library folder appears
   automatically. This is how Claude adds recipes — it writes a `.md` file.
2. **Paste to import (convenience):** an "Add Recipe" box where I paste raw text or
   Markdown; the app saves it as a new `.md` file in the library folder. If there's
   no frontmatter, it infers a title from the first heading and stamps `created`.

### 6.5 Keyboard Controls (messy hands)
Big targets, no precision required. Proposed bindings:

| Key | Action |
|-----|--------|
| `↑ / ↓` or `j / k` | Move between recipes (library) |
| `Return` | Open selected recipe |
| `Esc` | Back to library |
| `Space` | Next step / scroll down in Cook Mode |
| `Shift+Space` | Previous step / scroll up |
| `x` | Check off current step |
| `u` | Toggle US ↔ Metric |
| `+ / -` | Scale servings up/down |
| `/` | Focus search |
| `g` | Keep-awake toggle |

All actions are also reachable by mouse; keyboard is an accelerator, not a
requirement.

## 7. UX Principles
- **Readability over density.** Default font large; whitespace is a feature.
- **One recipe, one screen focus.** Cook Mode hides chrome.
- **Forgiving input.** Any reasonable Markdown renders well; bad frontmatter
  degrades gracefully (recipe still shows, just with less metadata).
- **The folder is the truth.** Delete a file → it's gone. Edit a file → app updates.

## 8. Technical Approach
- **Platform:** Native macOS app, **SwiftUI**.
- **Min OS:** macOS 14+ (Sonoma).
- **Storage:** user-chosen library folder (default `~/Recipes`), watched via
  `FSEvents` / `DispatchSource`.
- **Markdown rendering:** `swift-markdown` (or AttributedString Markdown) for body;
  custom YAML frontmatter parse.
- **Conversion engine:** small pure-Swift module; regex-based quantity detection
  over ingredient lines, with a unit lookup table.
- **Keep-awake:** `NSProcessInfo` activity assertion while Cook Mode is active.
- **No network.** Fully offline. No account.
- **Distribution:** local build / signed `.app`; no App Store requirement for v1.

## 9. Milestones
- **M1 — Reader:** ✅ watch a folder, list recipes (table), render reading view.
  *(Built in `app/` as a SwiftUI Swift Package.)*
- **M2 — Cook Mode + keyboard:** ✅ large-type view, step check-off, keep-awake,
  key bindings. *(Landed alongside M1.)*
- **M3 — Conversions:** ✅ US↔metric toggle + serving scaler + per-quantity tap
  popover (every unit in the dimension, scaled to current servings).
- **M4 — Import + packaging:** ✅ paste-to-import (`⌘N` / `n`), in-app "copy
  formatting prompt", FSEvents live content-edit watching, kanji (食) app icon,
  double-clickable `.app` (`scripts/package.sh`). No sample seeding — fresh
  installs start empty with a guided empty state. Column sort intentionally
  skipped (search + newest-first cover the need).

## 10. Decisions & Open Questions

**Decided:**
- Serving scaling shows **decimals** (e.g. 0.75 cup); no fraction rounding in v1.
- A **Claude output contract** exists — see [CLAUDE_RECIPE_PROMPT.md](CLAUDE_RECIPE_PROMPT.md).
  Recipes follow a pinned Markdown format so quantities, units, and metadata parse
  reliably; the format also defines what the conversion/scaling engine must support.

**Still open:**
- Default library location: `~/Recipes` vs a folder I pick on first launch?
- Tag source: only from frontmatter, or also inferred from folders/subfolders?

## 11. Success Criteria
- Adding a Claude recipe takes < 10 seconds end to end.
- I can navigate and cook a full recipe without touching the trackpad.
- I never leave the app to convert a unit.
