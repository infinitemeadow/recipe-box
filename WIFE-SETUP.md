# Recipe Box — setup on your Mac

A few one-time steps, then it's automatic forever (recipes sync both ways, and the
app updates itself).

## 0. Accept the invite
Check your email (or github.com → your notifications) for an invite to the
**recipes** repository and click **Accept**.

## 1. Install the GitHub tool
Open **Terminal** (⌘-Space, type "Terminal") and paste:

```bash
brew install gh
```

If it says `brew: command not found`, install Homebrew first from
[brew.sh](https://brew.sh), then run the line above. (Or download the GitHub CLI
directly from [cli.github.com](https://cli.github.com).)

## 2. Sign in to GitHub
```bash
gh auth login
```
Choose **GitHub.com → HTTPS → Login with a web browser**, and approve in the browser.

## 3. Install Recipe Box + your shared recipes
```bash
bash <(curl -fsSL https://raw.githubusercontent.com/infinitemeadow/recipe-box/main/install.sh)
```
This installs the app into your Applications and puts the shared recipe library in
`~/Recipes`.

## First launch
- If macOS says it can't verify the developer: **right-click the app → Open** (just
  once). It's safe — it was built by us, not signed through Apple's paid program.
- If a keychain box appears saying *git-credential-osxkeychain wants to use
  github.com*: click **Always Allow**. That lets recipe sync run quietly.

## That's it
- Recipes you or he add/edit sync automatically (on open, every ~90s, or the **Sync**
  button in the bottom-right).
- App updates arrive on their own — you'll get an **"Update available"** banner; click
  **Install & relaunch**.
- Leave notes on any recipe in the **Comments** box at the bottom of a recipe.
