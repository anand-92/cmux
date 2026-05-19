You are working on a fork of CMUX, a Ghostty-based macOS terminal app built in Swift/SwiftUI. The app currently has vertical tabs, split panes, notifications, and a built-in browser for managing AI coding agents.

Your task is to add a **file explorer sidebar** and a **file editor with markdown rendering** to CMUX. Here are the requirements:

### File Explorer Sidebar

- Add a toggleable sidebar panel (left side, similar to VS Code's file explorer) that shows the file tree of the current workspace's working directory.
- Use a standard macOS `NSOutlineView` or SwiftUI `List` with `DisclosureGroup` for the tree structure.
- Support expand/collapse of directories, single-click to preview, double-click to open in the editor.
- Show file icons based on file type (use SF Symbols or a lightweight icon set).
- Include a simple toolbar at the top of the sidebar with: refresh, collapse all, and a filter/search field.
- The file explorer should respect `.gitignore` patterns by default (with a toggle to show ignored files).
- When a workspace/pane is selected, the file explorer should automatically update to show that pane's worktree root.

### File Editor

- Add a tabbed editor panel that can be opened as a split (right pane) alongside the terminal, or as a replacement for the built-in browser panel.
- For plain text/code files: use a basic `NSTextView` or a lightweight Swift syntax highlighting library (e.g., Highlightr or TreeSitterSwift) — do NOT require vim keybindings or modal editing. Standard macOS text editing behavior (cmd+c, cmd+v, cmd+s, cmd+z, click to place cursor, shift+click to select).
- For markdown files: render the markdown as formatted HTML/attributed text (use a library like swift-markdown or Down). Include a toggle button to switch between "edit" and "preview" modes.
- Support basic features: line numbers, word wrap toggle, cmd+s to save, unsaved changes indicator (dot on tab).
- File tabs should show the filename and close button, matching the style of the existing CMUX vertical tabs.

### Integration Points

- The file explorer and editor should be accessible via:
  - A keyboard shortcut (e.g., `Cmd+Shift+E` for explorer, `Cmd+Shift+O` for open file)
  - The existing CMUX command palette
  - Right-click context menu in the terminal (e.g., "Open file at cursor path")
- When an agent references a file path in terminal output, it should be cmd-clickable to open in the editor (similar to how CMUX already handles cmd-click for URLs/files).

### Constraints

- Keep it native SwiftUI/AppKit — no Electron, no web views for the editor.
- Do not break any existing CMUX functionality (terminal, browser panes, notifications, CLI).
- Match the existing CMUX design language (colors, spacing, typography from the existing sidebar).
- The editor is intentionally simple — this is NOT a full IDE. Think "good enough to read agent output, make quick edits, and review diffs" not "replace VS Code."

### Getting Started

1. Read the project structure — it's an Xcode project with Swift/SwiftUI sources under `Sources/` and `CLI/`.
3. Look at how the existing browser pane and sidebar are implemented for patterns to follow.
4. Start with the file explorer sidebar, get it working, then add the editor as a second phase.

