# Syntax Highlighter Migration — Handoff

## Goal

Replace the hand-rolled regex syntax highlighter in `Sources/Panels/SyntaxHighlighter.swift` with a tree-sitter–based implementation, and (in a second phase) replace the bespoke `NSTextView` wrapper in `Sources/Panels/FilePreviewTextEditor.swift` with the production-quality `CodeEditSourceEditor` view. The current implementation has known correctness bugs (multi-line strings/comments break on incremental edits) and an O(n²) per-pattern token-occupancy scan that degrades on files >5k lines. Both phases use the same vendor (ChimeHQ + CodeEditApp), so phase 2 is mostly a view swap, not a rewrite.

## Packages

All four are Swift Package Manager–compatible and ship on macOS 14+. Licenses are MIT or BSD-3, both compatible with cmux's MIT license.

- **Neon** — <https://github.com/ChimeHQ/Neon> — BSD-3. Tree-sitter ↔ `NSTextStorage` glue. Provides `TextViewHighlighter`, incremental highlight, theme switching. Used by both CodeEditSourceEditor and STTextView-Plugin-Neon in production.
- **SwiftTreeSitter** — <https://github.com/tree-sitter/swift-tree-sitter> — MIT. Low-level Swift bindings for the tree-sitter C runtime. Pulled in transitively by Neon; you will rarely call it directly.
- **CodeEditLanguages** — <https://github.com/CodeEditApp/CodeEditLanguages> — MIT. Bundles ~25 tree-sitter grammars (Swift, TS/JS, Python, Rust, Go, YAML, JSON, etc.) as a single `xcframework`. This is the reason to prefer CodeEditApp's grammars over assembling individual `tree-sitter-*` packages — SPM resolution stays fast and binary size is one ~15 MB hit instead of N small ones.
- **CodeEditSourceEditor** — <https://github.com/CodeEditApp/CodeEditSourceEditor> — MIT. Drop-in source editor `NSView` (also has a SwiftUI API). Built on Neon + CodeEditLanguages. Provides gutter, find/replace, multi-cursor, code folding, theming. 697★, actively maintained.

## Phase 1 — Tree-sitter highlighting on the existing `NSTextView`

**Scope:** Keep `SavingTextView` and `FilePreviewLineNumberRulerView`. Replace only the highlighter implementation. Net change: ~–600 LOC (delete `SyntaxHighlighter.swift` and its pattern library) + ~+60 LOC (Neon adapter).

### Add SPM dependencies

Edit `cmux.xcodeproj/project.pbxproj` (look at the existing `Sparkle`, `sentry-cocoa`, `posthog-ios`, `swift-markdown-ui` entries near line 2855 as a template) or — preferred — add them via Xcode's "Package Dependencies" UI and let Xcode rewrite the pbxproj. Add:

- `https://github.com/ChimeHQ/Neon` — main branch (no tagged release yet; the project README says main is the supported target).
- `https://github.com/CodeEditApp/CodeEditLanguages` — latest tagged release.

Add the `Neon` and `TreeSitterClient` library products to the `cmux` app target, and `CodeEditLanguages` to the same target.

### Add the adapter

Create `Sources/Panels/TreeSitterHighlighter.swift`. It should expose the same surface the existing `SyntaxHighlighter` does so call sites in `FilePreviewTextEditor.swift` change minimally:

```
init(language: SyntaxLanguage, defaultColor: NSColor)
func attach(to textStorage: NSTextStorage)
func highlightAll()
func updateDefaultColor(_ color: NSColor)
```

Inside the adapter, build a `Neon.TextViewHighlighter` (see Neon's `Projects/` examples in its repo) wired to a `CodeLanguage` resolved from `CodeEditLanguages`. Map the cmux `SyntaxLanguage` enum cases (see `Sources/Panels/SyntaxHighlighter.swift` lines 22–84 for the current cases and `SyntaxLanguage.from(filename:)`) to `CodeLanguage` constants — almost all 16 have direct equivalents in `CodeEditLanguages`.

For the theme, derive a light/dark palette from the `defaultColor.isLight` check the current implementation already uses (`SyntaxHighlighter.swift` line 537–538). Neon takes a closure that returns attributes per highlight name (`keyword`, `string`, `comment`, etc.) — define this once and call `invalidate()` when `updateDefaultColor` is invoked.

### Wire it up

In `Sources/Panels/FilePreviewTextEditor.swift`:

- Line 141: change `private let syntaxHighlighter: SyntaxHighlighter` to the new adapter type.
- Lines 144–146: keep the `SyntaxLanguage.from(filename:)` call — only the highlighter constructor changes.
- Lines 150–158: `attachHighlighter(to:)`, `highlightAll()`, `updateHighlighterDefaultColor(_:)` keep the same names.
- `updateNSView` (lines 74–95): no change needed; the adapter handles incremental updates internally via Neon's `NSTextStorageDelegate`.

### Delete

- `Sources/Panels/SyntaxHighlighter.swift` (591 lines)
- Any `SyntaxPatternLibrary` references it pulled in.
- Stop adding `Localizable.xcstrings` entries that only existed for the regex flow.

### Tests

The existing tests under `cmuxTests/` do not cover the highlighter directly; verify via runtime in the file preview panel for each supported extension. Use the `docs/` markdown files and a couple of `Sources/*.swift` files as smoke tests. Confirm light/dark theme switch re-paints colors (this was just fixed in `def8c716`).

### Update licenses

Append the Neon BSD-3 notice and CodeEditLanguages MIT notice to `THIRD_PARTY_LICENSES.md` (existing format starts at line 1).

## Phase 2 — Adopt `CodeEditSourceEditor` for the file preview view

**Scope:** Replace `SavingTextView` + `FilePreviewLineNumberRulerView` with `CodeEditSourceEditor`'s view. The Neon adapter from phase 1 is discarded because CodeEditSourceEditor wraps Neon internally. The `FilePreviewPanel` model API stays the same.

### Why phase 2 is a separate step

Phase 1 ships a correctness win without touching the view layer. Phase 2 is justified only when we want the preview to become a real editor: gutter, find/replace, code folding, search-and-replace, multi-cursor, line wrap toggles. Doing both in one PR conflates two reviews (highlighter correctness vs. editor UX behavior). Land phase 1, dogfood it for a release, then decide.

### Replace the view

Add `CodeEditSourceEditor` to the SPM deps from phase 1 (same project, separate library product).

In `Sources/Panels/FilePreviewTextEditor.swift`:

- Replace the `NSScrollView` + `SavingTextView` + `FilePreviewLineNumberRulerView` triple with `CodeEditSourceEditor`'s `SourceEditor` view (it provides its own gutter and scroll container).
- The current `FilePreviewTextEditingPanel` protocol (`Sources/Panels/FilePreviewTextEditor.swift` lines 5–13) is the right boundary — keep it; bridge `attachTextView`, `updateTextContent`, `saveTextContent` to the SourceEditor's text binding and undo manager.
- Preserve `SavingTextView` features that CodeEditSourceEditor does not give for free:
  - Pinch/scroll zoom (`magnify(with:)` line 297, `scrollWheel(with:)` line 303). CodeEditSourceEditor exposes a font configuration; wire the same zoom factor through that. Reference: `Sources/Panels/FilePreviewTextEditor.swift` lines 297–330.
  - Save shortcut (`performKeyEquivalent` line 284, `saveShortcutMatch` line 332). CodeEditSourceEditor lets you install key handlers via its `NSView` host; mirror the existing chord-prefix logic from `KeyboardShortcutSettings.shortcut(for: .saveFilePreview)`.
- Theme: route the existing `themeBackgroundColor` / `themeForegroundColor` props through CodeEditSourceEditor's theme configuration. There is no need for the `applyTheme(to:backgroundColor:foregroundColor:drawsBackground:)` static method anymore.
- Word wrap: CodeEditSourceEditor exposes a wrap setting; remove `applyWordWrap(_:to:in:)` (lines 116–134).
- Line numbers: remove `FilePreviewLineNumberRulerView` (lines 173–266). CodeEditSourceEditor has its own gutter and was the reference implementation for line-number logic anyway.

### Files to revisit when adopting phase 2

- `Sources/Panels/FilePreviewPanel.swift` — panel model is the boundary; verify `attachTextView(_:)` callers still receive an `NSTextView` (CodeEditSourceEditor exposes the underlying view) or refactor to expose only the operations the panel needs.
- `Sources/Panels/FilePreviewFocusCoordinator.swift` — focus retry path; CodeEditSourceEditor's view should be focusable via `makeFirstResponder`.
- `Sources/KeyboardShortcutSettings.swift` — save shortcut wiring stays the same; only the handler location changes.
- `Sources/Panels/FilePreviewModeSupport.swift` and `Sources/Panels/FilePreviewNativeBackground.swift` — these contribute to the chrome around the editor; verify they still composite correctly with CodeEditSourceEditor's own background.

## Reference files (read before starting)

Order them in this sequence — earlier files set context for later ones.

- `Sources/Panels/SyntaxHighlighter.swift` — current regex highlighter; this is what phase 1 replaces. Pay attention to `SyntaxLanguage.from(filename:)`, the per-language `*Patterns()` static methods, and `highlight(range:in:)` (the O(n²) hot path).
- `Sources/Panels/FilePreviewTextEditor.swift` — the only call site of `SyntaxHighlighter`. Look at `Coordinator` (lines 137–170), `makeNSView`/`updateNSView`, and `FilePreviewLineNumberRulerView`.
- `Sources/Panels/FilePreviewPanel.swift` — the panel model. The `FilePreviewTextEditingPanel` protocol (in `FilePreviewTextEditor.swift` lines 5–13) is implemented here.
- `Sources/FileTypeColor.swift` — icon-tinting; orthogonal to highlighting but referenced for filename-to-language hints.
- `cmux.xcodeproj/project.pbxproj` lines 2855–2900 — existing SPM dependency entries (Sparkle, Sentry, PostHog, swift-markdown-ui). New dependencies go here.
- `THIRD_PARTY_LICENSES.md` — append the Neon (BSD-3), SwiftTreeSitter (MIT), CodeEditLanguages (MIT), and — phase 2 only — CodeEditSourceEditor (MIT) notices.
- `CLAUDE.md` — project conventions. Note especially the "Test quality policy", "Typing-latency-sensitive paths", "Snapshot boundary for list subtrees", and the requirement that user-facing strings live in `Resources/Localizable.xcstrings` with all locales.

## Constraints and gotchas

- The build environment on macOS 26 cannot link the Ghostty CLI helper natively with zig 0.15.x. The documented escape hatch is `CMUX_SKIP_ZIG_BUILD=1 ./scripts/reload.sh --tag <slug>` (or the equivalent `xcodebuild` invocation). See the comment block at `scripts/build-ghostty-cli-helper.sh` line 117. Phase 1 and phase 2 work cleanly under that flag.
- Neon's `main` branch is the supported target — pin to a commit SHA in `Package.resolved` rather than tracking a moving ref so the build stays reproducible.
- `CodeEditLanguages` ships its grammars as a single `xcframework` (`CodeLanguagesContainer.xcframework`). This adds ~15 MB to the cmux bundle. Acceptable for a desktop app; flag it in the release notes for the version that adopts phase 1.
- `SyntaxLanguage` in cmux currently has cases that CodeEditLanguages may not have (verify each: Ruby, Kotlin, TOML, Markdown, shell). For any missing language, either (a) pull in `tree-sitter-<lang>` separately and feed Neon directly, or (b) fall back to no highlighting and surface that explicitly. Do not silently degrade to regex.
- Theme palette: the current implementation switches between two hard-coded palettes based on `defaultColor.isLight`. Replicate this with Neon's highlight-name → attributes mapping. The phase-1 adapter should accept a `defaultColor` so the existing call site contract is preserved.
- The regression-test commit policy in `CLAUDE.md` ("Add the failing test, then add the fix in a second commit") applies if any bug fix is bundled with this migration. The migration itself is not a bug fix and does not need that structure.

## Suggested PR shape

- **PR 1 (phase 1):** add SPM deps, add `TreeSitterHighlighter` adapter, swap call sites in `FilePreviewTextEditor.swift`, delete `SyntaxHighlighter.swift`, update `THIRD_PARTY_LICENSES.md`. One commit per logical step is fine.
- **PR 2 (phase 2):** replace the view. Only land after phase 1 has shipped at least one release tag.

## Open questions for the implementer

- Does `CodeEditLanguages` cover all 16 of cmux's current `SyntaxLanguage` cases? Verify against <https://github.com/CodeEditApp/CodeEditLanguages> README before estimating.
- Do we want the file preview to remain read-only after phase 2, or fully editable? CodeEditSourceEditor supports both via a single flag; the answer determines how aggressively to wire save-on-change and undo coalescing.
- Should the gutter background match the terminal background (current `sidebarMatchTerminalBackground` setting) or stay independent? Affects how CodeEditSourceEditor's theme is parameterized.
