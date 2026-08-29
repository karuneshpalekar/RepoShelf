# RepoShelf

A native macOS app that keeps a small floating panel on your screen for
pulling GitHub projects onto your Mac **only when you need them** — and
removing the local copy (to the Trash) when you're done, to reclaim disk.
Built as a companion to the Kanban Timeline widget and sharing its look.

## Why

If your projects all live on GitHub and you rarely touch them, keeping
every checkout on a small SSD is wasteful. RepoShelf lists your repos,
clones one on demand (blobless by default, so it's a fraction of the full
size), and trashes the working copy with one click when you're finished —
everything's already pushed, so nothing is lost.

It also handles **multiple GitHub accounts** without the sign-out/sign-in
dance: it reads whatever accounts `gh` knows about, scopes every operation
to the chosen account by injecting that account's token (never running
`gh auth switch`, so your terminal's active account is left alone), and
writes the right `user.name` / `user.email` into each clone's local git
config.

## What's here

- **The panel** — a borderless floating `NSPanel` that stays on the Space
  it was opened on, doesn't steal focus, and doesn't sit above
  full-screen apps. Drag it by the header. Collapse it to a pill showing
  "N on disk / free space"; click the pill to expand.
- **Menu bar icon** (tray glyph) — Show/Hide, Refresh, Open Workspace
  Folder, Quit.
- **Repos tab** — your repos for the active account (`gh repo list`),
  searchable, with an "On disk" filter. Clone opens a strategy picker
  (blobless / shallow / full, each with a size estimate). Cloned rows
  show size + strategy and get Open-in-VS-Code / Reveal-in-Finder /
  Delete buttons. **+** adds a repo by URL or `owner/name` for anything
  outside your own list (orgs, forks, collaborators).
- **Cleanup tab** — cloned repos (any account) you haven't opened in 3+
  weeks, with per-repo Remove and a "remove all / reclaim X" button.
- **Accounts tab** — every account `gh` knows, which is active, and an
  editable commit identity per account. **Add account** opens
  `gh auth login` in Terminal.
- **Activity tab** — a running trail of clones, removals and account
  switches with timestamps.
- **Appearance** — System / Light / Dark toggle, same hand-tuned palette
  as the Kanban widget.

All state is a local JSON file at
`~/Library/Application Support/RepoShelf/state.json` (identities,
per-repo clone strategy, last-opened times, added repos, activity log,
scan folders). New clones land in `~/Code/<account>/<repo>`.

### Existing clones

RepoShelf **maps clones you already have** wherever they live. On first
launch it scans a default set of folders (`~/Code`, `~/Downloads`,
`~/Documents/GitHub`, `~/Developer`, `~/Projects`, …) — whichever exist —
plus your workspace root, recursively (bounded depth, skipping
`node_modules` and friends). Each working copy is matched to its GitHub
repo by its `origin` remote, not by folder name, so
`~/Downloads/some-old-checkout` shows up as `owner/some-old-checkout` and
lines up with the same repo in your list. Clones under an account/org
that isn't your active one show tagged **DETECTED**; git working copies
with no GitHub origin show as **LOCAL ONLY** (Reveal / open / remove, but
no clone). Manage the folder list from the **sliders** button in the
header.

## Clone strategies

| Strategy | git flags | On disk | Trade-off |
|---|---|---|---|
| **Blobless** (default) | `--filter=blob:none` | ~1/5–1/3 | Full history and `git log` offline; old file *contents* are fetched on demand the first time `blame`/`diff` needs them. |
| **Shallow** | `--depth=1` | smallest | Latest commit only — no history, no `blame`, awkward to deepen later. |
| **Full** | — | largest | Everything, offline forever. |

## Requirements

- macOS 14 (Sonoma) or later
- Xcode 15+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)
- [GitHub CLI](https://cli.github.com) (`brew install gh`), logged in
  (`gh auth login`) — RepoShelf shells out to `gh` and `git`
- Optional: the `code` command (VS Code → *Shell Command: Install 'code'
  in PATH*) so "Open in editor" works; otherwise it falls back to opening
  `/Applications/Visual Studio Code.app`.

A GUI app doesn't inherit your shell's `PATH`, so RepoShelf looks for
`gh` / `git` / `code` in `/opt/homebrew/bin`, `/usr/local/bin`,
`/usr/bin`, and then asks a login shell.

## Build & run

```bash
./install.sh
```

Regenerates the project, builds Release, installs to
`/Applications/RepoShelf.app`, and launches it. Re-run after any code
change. Look for the tray icon in the menu bar; the panel appears
top-right on first launch.

### First launch

- If `gh` isn't found or isn't logged in, the Repos tab shows an error
  banner — run `gh auth login` and hit **Refresh** in the menu.
- Adding an account: **Accounts → Add account** launches `gh auth login`
  in Terminal (macOS will ask once to let RepoShelf control Terminal).
  Finish signing in there, then **Refresh**.

### Notes on the build setup

`generate.sh` downgrades the generated `.xcodeproj` to `objectVersion 56`
because XcodeGen writes the Xcode 16 format (`objectVersion 77`), which
crashes Xcode 15.x when you open Signing & Capabilities. `install.sh`
builds from the command line and sidesteps the Xcode GUI entirely. On a
newer Xcode you can open `RepoShelf.xcodeproj` directly.

## Project layout

```
RepoShelfApp/
  RepoShelfApp.swift     @main entry point, menu bar
  AppDelegate.swift       owns the floating panel
  FloatingPanel.swift     NSPanel subclass (floating, single-Space, collapsible)
  DragHandle.swift        scoped window-drag for the header
  PanelState.swift        collapsed/hidden state
  Theme.swift             light/dark palette + appearance mode
  ContentView.swift       header, tabs, footer, pill, overlay host
  Views/
    ReposView.swift       repo list, filter, rows
    CleanupView.swift     stale clones
    AccountsView.swift    accounts + editable commit identity
    ActivityView.swift    event trail
    CloneSheet.swift      strategy picker
    AddRepoSheet.swift    add by URL
    AddAccountSheet.swift  gh auth login launcher
Shared/
  Models.swift            data types + formatting
  Store.swift             @MainActor ObservableObject — state, persistence, orchestration
  GitHub.swift            gh / git wrappers, local clone scan
  Shell.swift             Process helpers + tool location
  SharedStorage.swift     app-support paths
project.yml               XcodeGen spec
generate.sh / install.sh  build scripts
```
