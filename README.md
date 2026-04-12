# 🐾 Watchdog

A Roblox exploit script that detects **script changes between game sessions** by hashing all scripts in the game, saving those hashes to disk, and letting you diff a later snapshot against the saved one to spot added, removed, or modified scripts.

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [How It Works](#how-it-works)
- [File Structure](#file-structure)
- [UI Reference](#ui-reference)
- [Known Limitations](#known-limitations)
- [Credits](#credits)

---

## Overview

Watchdog is designed for players and researchers who want to **monitor a Roblox game for script-level changes** across updates or sessions. It works by:

1. Snapshotting all script hashes in the current game and saving them to a `.txt` file.
2. On a later session, loading that snapshot and comparing it against the current state of the game.
3. Displaying a categorized diff — **added**, **removed**, and **changed** scripts — in a clean in-game UI.

This is useful for detecting when a game silently pushes new anti-cheat scripts, removes modules, or modifies existing ones between updates.

---

## Features

- 🔍 **Hash-based diffing** — uses `getscripthash()` to fingerprint every script, so even minor bytecode changes are detected.
- 💾 **Persistent snapshots** — saves hash files to the `Watchdog_Saves/` folder with the game name and date in the filename.
- 📂 **File browser** — built-in dropdown to select any previously saved hash file without leaving the game.
- 🎨 **Clean UI** — draggable, dark-themed window with categorized results and live counters for added/removed/changed scripts.
- 🛡️ **Exclusion system** — configurable lists to skip noisy or irrelevant scripts (e.g. `CoreGui`, `Animate`).
- 📅 **Auto-named saves** — files are named after the game and the current date, making it easy to track changes over time.

---

## Requirements

- A Roblox exploit executor that supports the following functions:
  - `getscripthash(script)`
  - `getscriptbytecode(script)`
  - `game:HttpGet(url)`
  - `loadstring(source)()`
  - `isfolder(path)` / `makefolder(path)`
  - `writefile(path, content)`
  - `readfile(path)`
  - `listfiles(path)`

Most level 7+ executors support all of these.

---

## Installation

1. Copy the full script source.
2. Paste it into your executor's script editor.
3. Execute it while in any Roblox game.

No additional setup is required. The `Watchdog_Saves/` folder is created automatically on first run.

---

## Usage

### Step 1 — Save a Snapshot

When you first join a game (or after an update), click **"Save Current Hashes"**. This:

- Iterates every `ModuleScript`, `LocalScript`, and non-empty `Script` in the game.
- Hashes each one with `getscripthash()`.
- Saves all hashes to a file in `Watchdog_Saves/` named like:
  ```
  MyGame_Hash_[12_06_2025].txt
  ```

### Step 2 — Select a Hash File

Click the file selector dropdown (or **🔄 Refresh** to repopulate the list). Choose the snapshot you want to compare against.

### Step 3 — Run a Diff

Click **"Run Diff Against Selected File"**. Watchdog will:

- Re-hash every script currently in the game.
- Compare against the loaded snapshot.
- Display every difference in the results panel, grouped by type:
  - `[+]` **Added** — scripts that exist now but weren't in the snapshot.
  - `[-]` **Removed** — scripts that were in the snapshot but are no longer present.
  - `[!]` **Changed** — scripts whose hash has changed since the snapshot.

If nothing changed, you'll see a **"No changes detected ✅"** message.

---

## Configuration

At the top of the script, the `Watchdog` table has two exclusion lists you can edit:

```lua
local Watchdog = {
    StartingExclusions = {
        CorePackages = true,
        CoreGui = true,
        Chat = true
    },
    EndingExclusions = {
        Animate = true,
    },
    ...
}
```

### `StartingExclusions`

Skips any script whose **full path starts with** the given root service name. Useful for ignoring Roblox's internal services that you don't control or care about.

| Key | What it excludes |
|---|---|
| `CorePackages` | Internal Roblox packages |
| `CoreGui` | Roblox's built-in UI scripts |
| `Chat` | Roblox's legacy chat system |

### `EndingExclusions`

Skips any script whose path contains a **segment matching** the given name, anywhere in the hierarchy. Useful for filtering out boilerplate scripts that are the same across all games.

| Key | What it excludes |
|---|---|
| `Animate` | Character animation scripts (`Players.X.Character.Animate`) |

To add more exclusions, just add a new `true` entry:

```lua
StartingExclusions = {
    CorePackages = true,
    CoreGui = true,
    Chat = true,
    RobloxGui = true,   -- add this
},
EndingExclusions = {
    Animate = true,
    RagdollController = true,  -- add this
},
```

---

## How It Works

### Hashing

Watchdog uses `getscripthash(script)` — an executor API that returns a consistent hash of a script's bytecode. This means:

- Whitespace-only changes in source **do** affect the hash (since it operates on bytecode).
- Two scripts with identical bytecode will have the same hash regardless of name.

For `Script` instances (server scripts, which are normally inaccessible), Watchdog first checks `#getscriptbytecode(v) > 1` to skip empty/inaccessible scripts before hashing.

### Saving

Hashes are serialized using the [LuaEncode](https://github.com/chadhyatt/LuaEncode) library into a valid Lua table, then written to disk with `writefile`. The file is loadable back with `loadstring(readfile(file))()`, meaning no JSON parser is needed.

Example save file format:

```lua
return {
    ["Workspace.MyModule"] = "a3f1bc92...",
    ["ReplicatedStorage.Utils.Math"] = "d72e4401...",
}
```

## File Structure

```
Watchdog_Saves/
├── MyGame_Hash_[12_06_2025].txt
├── MyGame_Hash_[19_06_2025].txt
└── AnotherGame_Hash_[01_07_2025].txt
```

File names are sanitized to strip non-ASCII characters and replace illegal filename characters with underscores, so special characters in game names won't cause write errors.

---

## UI Reference

| Element | Description |
|---|---|
| **Save Current Hashes** | Snapshots all current script hashes to disk |
| **File Dropdown** | Lists all saved hash files in `Watchdog_Saves/` |
| **🔄 Refresh** | Repopulates the dropdown with the latest files on disk |
| **Run Diff Against Selected File** | Compares the selected snapshot to the current game state |
| **➕ Added / ➖ Removed / ❗ Changed** | Live counters for each change category |
| **Results panel** | Scrollable list of all detected changes, color-coded by type |

The window is **draggable** by clicking and holding the title bar.

## Credits

| Contributor | Role |
|---|---|
| [_vezt](https://github.com/VeztWare) | Author — core logic and main code |
| [chadhyatt](https://github.com/chadhyatt/LuaEncode) | LuaEncode library (Lua table serialization) |
| [Claude](https://claude.ai) | UI design assistance |

> You are free to use and modify this code. Giving credit is appreciated. Do not remove the author comment at the top of the script.
