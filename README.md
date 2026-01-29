# QuickLog (macOS)

QuickLog is a lightweight **menu-bar** app for fast capture.
It opens a top “drawer” panel (Unclutter/Raycast-style) with a **3-column** layout:

- **Left:** Clipboard history (text + image thumbnails)
- **Center:** Draft editor
- **Right:** Saved history (your past captures)

The goal is to make “copy → open panel → paste/type → save” frictionless.

---

## Features

### Panel
- Menu-bar icon toggles the panel
- **ESC** hides the panel
- Top-bar gesture (while the app is running):
  - cursor in the macOS menu bar
  - **two-finger scroll up** → show panel
  - **two-finger scroll down** → hide panel

### Draft editor
- Autosaves draft to disk
- Supports standard shortcuts (even as an accessory app):
  - Cmd+C / Cmd+V / Cmd+X / Cmd+A
  - Cmd+Z / Cmd+Shift+Z

### History (right panel)
- Shows your saved entries, sorted by last update time
- Clicking an entry loads it into the editor for updates
- While typing a fresh draft, the right panel shows a **highlighted pending entry** (not yet persisted)

### Clipboard history (left panel)
- Watches the system clipboard
- Keeps a bounded in-memory history (configurable)
- De-dupes identical items (re-copying moves the item to the top)
- Supports:
  - text items
  - image items (captures TIFF + shows a thumbnail)
- Actions per item:
  - copy back to system clipboard
  - insert text into the draft

---

## Data locations

- **Draft autosave**: `~/Library/Application Support/QuickLog/draft.json`
- **Saved history**: `~/Library/Application Support/QuickLog/entries.json`
- **Today’s Log** (append-only markdown): `~/Documents/QuickLog/logs/YYYY-MM-DD.md`

> Note: “notes” functionality was removed; the app currently focuses on Draft + History + Clipboard.

---

## Permissions / Authorization

### Main app (QuickLogMVP)
- Should work without Accessibility permission.
- Uses a **global scroll monitor** for the top-bar gesture (menu bar area).

### UI Automation Agent (for full-auto UI tests)
This repo includes a small **GUI helper app** used for automated UI smoke tests:

- `tools/QuickLogAutomationAgent.app`
- `tools/QuickLogAutomationAgentSwift.app`

Why: macOS UI automation permissions are granted **per GUI app**. Headless runners cannot be granted Accessibility.
So the agent is a stay-open GUI app that performs UI clicks on demand.

**One-time setup**
1. Open the agent app from `tools/`.
2. When prompted, allow:
   - **Accessibility** (required)
   - **Automation** → allow controlling **System Events** (required)
3. Keep the agent running (optional: add to Login Items).

**Trigger a UI smoke test**
Write the project path to:
```bash
printf %s "/Users/smile/Documents/coding/happy/QuickLog" > /tmp/QuickLogAutomationAgent.cmd
```
Then read the result:
```bash
cat /tmp/QuickLogAutomationAgent.result.json
```

More details: `tools/README_AUTOMATION.md`

---

## Build & Run

### Requirements
- macOS 13+
- Swift 6

### Run
```bash
cd /Users/smile/Documents/coding/happy/QuickLog
swift run -c debug QuickLogMVP
```

### Self-test
```bash
QUICKLOG_SELFTEST=1 swift run -c debug QuickLogMVP
```

### Debug logging
QuickLog can write debug logs to:
- `~/Library/Application Support/QuickLog/debug.log`

Enable with:
```bash
QUICKLOG_DEBUG=1 swift run -c debug QuickLogMVP
```

---

## Code structure

The app is a SwiftPM executable target under `QuickLog/`:

- `QuickLog/QuickLogApp.swift`
  - App delegate, status bar item, panel show/hide, global scroll gesture
- `QuickLog/Views/`
  - `MainPanelView.swift` — 3-column layout + splitters
  - `ClipboardHistoryView.swift` — clipboard history list UI
  - `DraftEditorView.swift` — center editor + autosave
  - `EntriesListView.swift` — right history list UI
  - `SettingsView.swift` — settings UI (panel size, clipboard history size, etc.)
- `QuickLog/Services/`
  - `ClipboardWatcher.swift` — polls NSPasteboard
  - `EntriesService.swift` — reads/writes entries index
  - `DraftService.swift` — reads/writes draft
  - `AppPaths.swift` — filesystem locations
  - `DebugLog.swift` — debug.log writer
  - `QuickLogPanel.swift` — NSPanel subclass allowing key focus
- `QuickLog/Models/`
  - `AppState.swift` — main state machine + autosave + history/clipboard behaviors
  - `Entry.swift` — saved history model
  - `ClipboardItem.swift` / `ClipboardContent.swift` — clipboard model (text/image)
  - `EditorContext.swift` — editor mode (draft/today/history)

---

## License

Apache-2.0 (see [`LICENSE`](./LICENSE)).

---

## Roadmap ideas
- Better image handling (PNG/JPEG detection, optional downscaling)
- Search/filter for clipboard/history
- Persist clipboard history (optional)
- Export history
