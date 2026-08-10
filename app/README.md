# Recipe Box — macOS app (M1)

Native SwiftUI app that reads a folder of Markdown recipes and renders them in a
dark, warm reading UI. Built as a Swift Package so it runs without any Xcode
project setup.

## Run it

Dev mode (fast iteration):

```sh
cd app
swift run
```

A window opens. Click into it once so it has keyboard focus.

Build a real double-clickable app:

```sh
cd app
./scripts/package.sh
open dist/RecipeBox.app      # or drag dist/RecipeBox.app into /Applications
```

The bundle is ad-hoc code-signed, uses the kanji (食) icon, and runs locally.
Regenerate the icon with `./scripts/make-icon.sh` (renders from `render_icon.swift`).

## Library folder

- Default: `~/Recipes` (created on first run if missing). It starts empty — the
  empty state has buttons to copy the formatting prompt and add your first recipe.
- Change it anytime with the folder button in the bottom-right of the library.
  The choice is remembered.
- The folder is the source of truth: drop a `.md` file in (e.g. one Claude wrote)
  and it appears. Recipe format is defined in `../CLAUDE_RECIPE_PROMPT.md`.

## What works

- **Library table** — Recipe / Serves / Time / Added / Tags, **grouped by origin**
  (the `cuisine` field, or a recognized origin tag; "Other" last), newest-first
  within each group. Pinned group headers.
- **Search + tag filter** — live.
- **Keyboard:** `↑↓` or `j/k` navigate, `↵` open, `/` search, `n` / `⌘N` add.
- **Paste-to-import** — the Add button (or `n`) opens a box; paste Claude's
  Markdown (fenced or not), it's saved as a `.md` and opened. Loose text gets a
  title inferred and minimal frontmatter wrapped around it.
- **Copy formatting prompt** — the Add sheet (and the empty state) has a button to
  copy the recipe-format prompt to the clipboard, ready to paste into Claude. The
  prompt lives in `RecipePrompt.swift`, kept in sync with `../CLAUDE_RECIPE_PROMPT.md`.
- **Cook Mode** (reading view) — big type, tap or `x` to check off a step, `space`
  to advance the current step.
- **Serving scaling** — `+` / `-`, decimals (e.g. `0.75 tsp`).
- **Unit selector** — a radio group (Original / Metric / US) picks how quantities
  display; `u` cycles it. Converts only within a dimension (ml↔cup, g↔oz) and rolls
  small units up (16 tbsp → 1 cup); weight↔volume is never faked.
- **Edit the source** — the pencil button (or `e`) opens the recipe's `.md` in your
  default editor; saving refreshes the app live (FSEvents). Files are the truth.
- **Per-quantity popover** — tap any amount to see it in every unit of its
  dimension, scaled to the current serving count.
- **Source link** — if a recipe's frontmatter has a `source_url`, Cook Mode shows a
  clickable "Source" link to the original page. Blank/omitted when there's no URL.
- **Share** — the Share button (or `s`) in Cook Mode opens the native macOS share
  sheet for the recipe's `.md` file (AirDrop / Messages / Mail). The recipient gets
  a plain-text-readable file they can drop into their own library.
- **Comments** — Cook Mode has a comments box; each is saved into the recipe's
  `## Comments` section (attributed + dated), so comments sync between Macs and
  travel with a shared `.md`.
- **Recipe sync** — if the library folder is a git clone of the shared private
  repo, the app commits/pulls/pushes automatically (on launch + every 90s + a
  manual Sync button). Two-way sharing with no server; auth uses your own git
  login. Conflicts (same recipe edited on both Macs) are surfaced, not clobbered.
- **Auto-update** — on launch the app checks the public repo's latest GitHub
  Release; if newer, a banner offers "Install & relaunch" (downloads, swaps itself
  in, clears Gatekeeper, relaunches). Also under the app menu → Check for Updates.
- **Keep-awake** — the display won't sleep while a recipe is open.
- **Folder watching (FSEvents)** — adds, removes, AND in-place edits to recipe
  files refresh the app live.

## Shipping an update

```sh
cd app
./scripts/release.sh 0.1.2      # bumps version, builds, zips, publishes a GitHub Release
```

Installed apps see it on next launch and offer to self-install. No manual reinstall,
no server. Recipes live in a separate **private** repo, shared with collaborators.

## Source layout

| File | Role |
|------|------|
| `RecipeBoxApp.swift` | App entry, window, activation |
| `Theme.swift` | Dark-warm palette + button style |
| `Models.swift` | `Recipe`, `Ingredient` |
| `Units.swift` | Unit table, conversion, number formatting |
| `MarkdownParser.swift` | Frontmatter + ingredients/steps/notes + quantity parsing |
| `Importer.swift` | Pasted-text → `.md` (fence strip, title infer, frontmatter) |
| `FolderWatcher.swift` | FSEvents directory-tree watcher |
| `RecipeStore.swift` | Loads + sorts recipes, persists folder choice |
| `RecipePrompt.swift` | The copy-paste formatting prompt + clipboard copy |
| `ContentView.swift` | Library ↔ Cook Mode switch, key-hint footer |
| `LibraryView.swift` | The table |
| `ReadingView.swift` | Cook Mode |
| `ImportView.swift` | Paste-to-import sheet |
| `scripts/package.sh` | Builds the double-clickable `.app` |
