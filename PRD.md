# QuickLog (macOS) — PRD (V1)

## 1. Summary
QuickLog is a macOS menu-bar app that toggles a centered floating panel for rapid logging. The panel provides:
- **Left:** in-memory clipboard (paste) history.
- **Center:** a **current draft** editor supporting **Markdown** and **Rich Text**.
- **Right:** notes list (local).

Primary workflow: open panel → type in current draft → **Save & Next** to append/save, then automatically start a new draft.

## 2. Goals
- Capture quick logs with minimal friction.
- Provide fast access to recent clipboard items for inserting into the draft.
- Provide a simple notes list for saving drafts into named notes.
- Keep the panel lightweight: **not full screen**, floating, centered.

## 3. Non-goals (V1)
- Cloud sync.
- Multi-device sync.
- Persistent clipboard history (V1 is **memory-only**).
- Advanced global gesture triggers beyond menu-bar click (two-finger swipe is V2/experimental).

## 4. Target Platform
- macOS 13+ (Ventura) recommended.
- Apple Silicon + Intel (if possible), but prioritize Apple Silicon.

## 5. Core UX
### 5.1 Triggering
- **Menu bar icon click:** toggle show/hide of the main panel.
- **ESC** hides the panel.

### 5.2 Panel placement & size
- Panel is a **floating** centered panel (Raycast-like), not full screen.
- Default height: **~33% of the current screen height**.
- Default width: ~1000 px.
- Settings allow adjusting height ratio and width.

### 5.3 Three-column layout (center is widest)
- Suggested default split: **22% / 56% / 22%** (Left / Center / Right).

### 5.4 Draft behavior
- The center editor always shows **CURRENT DRAFT**.
- **Save target rule:**
  - If a note is selected in the Notes List, saving writes to that note.
  - Otherwise, saving writes to **Today’s Log**.
- **Draft persistence:** draft content is auto-saved locally to restore after app restart/crash (not counted as “history”).

### 5.5 Save behaviors
- **Save & Next (Option+Enter)**: write to target, then clear editor to a new draft.
- **Save (Cmd+S)**: write to target but keep current draft (no auto-clear).

### 5.6 Editor modes
- Markdown mode:
  - Raw markdown editing.
  - Optional Preview toggle.
- Rich Text mode:
  - Basic rich text editing.
  - No preview necessary (optional).

### 5.7 Clipboard history (memory only)
- Listen to system clipboard changes.
- Keep a bounded list in memory (default 50 items, configurable).
- Show timestamp + truncated preview.
- Actions:
  - Copy
  - Insert into editor at cursor
  - Pin (optional V1; can be deferred)

### 5.8 Notes list
- Notes are local.
- List shows note titles.
- Actions:
  - New note
  - Rename
  - Delete
  - Select note (sets save target)

## 6. Data Model (V1)
### 6.1 Today’s Log
- A single per-day log.
- Storage option V1: local markdown file:
  - `~/Documents/QuickLog/logs/YYYY-MM-DD.md`

### 6.2 Notes
- Storage option V1: local files:
  - `~/Documents/QuickLog/notes/<uuid>.md` (or .rtf for rich-text notes)
  - Index: `notes.json` mapping uuid → title → updatedAt → format.

### 6.3 Draft autosave
- `~/Library/Application Support/QuickLog/draft.json` (or similar).

### 6.4 Clipboard history
- In-memory only (not persisted).

## 7. Settings (V1)
- Panel height ratio (min 25% / max 60%).
- Panel width (e.g., 800–1400 px).
- Clipboard history size (e.g., 20/50/100).
- Default editor mode (Markdown or Rich Text).
- Markdown preview default on/off.

## 8. Accessibility/Permissions
- V1 should not require Accessibility permissions.
- If V2 adds global gesture triggers, may require Accessibility permissions and event taps.

## 9. Quality Bar / Acceptance Criteria
- Menu bar icon toggles panel reliably.
- Panel always appears centered on current display.
- Save & Next appends content to the correct target and clears for a new draft.
- Clipboard history updates as clipboard changes, bounded to the configured size.
- Notes list can create/select/rename/delete notes; saving to selected note works.
- Draft is restored after app restart (autosave).

## 10. Open Questions (track)
- Rich Text storage format: store as RTF per note, or unify as markdown only with a rich-text editor front-end.
- Pinning clipboard items in V1 vs V2.
- Markdown preview rendering (WebView vs native rendering).
