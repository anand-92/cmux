import AppKit
import CodeEditLanguages
import CodeEditSourceEditor
import CodeEditTextView
import SwiftUI

// MARK: - Public Surface

/// Panel-side contract for the file-preview text editor.
///
/// The editor is implemented on top of CodeEditSourceEditor, whose underlying view is
/// `CodeEditTextView.TextView` (an `NSView`, not an `NSTextView`). Callers therefore
/// receive an `NSView` plus an optional `FilePreviewTextInserter` for inserting text
/// at the current cursor (used for drop-as-text URL handling).
@MainActor
protocol FilePreviewTextEditingPanel: AnyObject {
    var textContent: String { get }

    func attachTextEditorView(_ view: NSView, access: FilePreviewTextEditorAccess?)
    func retryPendingFocus()
    func updateTextContent(_ nextContent: String)
    @discardableResult
    func saveTextContent() -> Task<Void, Never>?
}

/// Closure-based seam exposing the editor operations the panel models need without
/// leaking CodeEditTextView types into the panel layer.
@MainActor
struct FilePreviewTextEditorAccess {
    let insertText: (String) -> Void
    let selectRange: (NSRange) -> Void
    let scrollToRange: (NSRange) -> Void
}

// MARK: - Syntax Language

/// Source-code language used to pick a CodeEditLanguages grammar.
enum SyntaxLanguage {
    case swift
    case typeScript
    case python
    case ruby
    case go
    case rust
    case java
    case kotlin
    case css
    case html
    case json
    case yaml
    case toml
    case shell
    case cOrCpp
    case sql
    case markdown
    case plainText

    // swiftlint:disable:next cyclomatic_complexity
    static func from(filename: String) -> SyntaxLanguage {
        let lower = filename.lowercased()
        let ext = (lower as NSString).pathExtension

        switch lower {
        case "dockerfile", "dockerfile.dev", "dockerfile.prod", "dockerfile.staging",
             "makefile", "rakefile", "gemfile", "podfile":
            return .shell
        case "package.json", "tsconfig.json", "jsconfig.json", ".eslintrc.json",
             "bun.lockb":
            return .json
        case "docker-compose.yml", "docker-compose.yaml":
            return .yaml
        default:
            break
        }

        switch ext {
        case "swift":         return .swift
        case "ts", "tsx", "js", "jsx", "mjs", "cjs": return .typeScript
        case "py", "pyi":     return .python
        case "rb", "rake", "gemspec": return .ruby
        case "go":            return .go
        case "rs":            return .rust
        case "java":          return .java
        case "kt", "kts":     return .kotlin
        case "css", "scss", "sass", "less": return .css
        case "html", "htm", "xhtml", "svelte", "vue": return .html
        case "json":          return .json
        case "yaml", "yml":   return .yaml
        case "toml":          return .toml
        case "sh", "bash", "zsh", "fish", "command": return .shell
        case "c", "cc", "cpp", "cxx", "h", "hpp", "hh", "m", "mm": return .cOrCpp
        case "sql":           return .sql
        case "md", "mdx", "markdown": return .markdown
        default:              return .plainText
        }
    }

    var codeLanguage: CodeLanguage {
        switch self {
        case .swift:      return .swift
        case .typeScript: return .typescript
        case .python:     return .python
        case .ruby:       return .ruby
        case .go:         return .go
        case .rust:       return .rust
        case .java:       return .java
        case .kotlin:     return .kotlin
        case .css:        return .css
        case .html:       return .html
        case .json:       return .json
        case .yaml:       return .yaml
        case .toml:       return .toml
        case .shell:      return .bash
        case .cOrCpp:     return .cpp
        case .sql:        return .sql
        case .markdown:   return .markdown
        case .plainText:  return .default
        }
    }
}

// MARK: - Palette → EditorTheme

private extension NSColor {
    /// Whether this color is considered "light" (luminance > 0.5 in sRGB).
    var isLight: Bool {
        guard let rgb = usingColorSpace(.sRGB) else { return true }
        let r = rgb.redComponent, g = rgb.greenComponent, b = rgb.blueComponent
        let lum = 0.2126 * r + 0.7152 * g + 0.0722 * b
        return lum > 0.5
    }
}

/// cmux's hand-tuned light/dark token palette. Preserved verbatim from the previous
/// regex-based highlighter so the visual palette does not shift across this migration.
private struct CmuxFilePreviewPalette {
    let keyword: NSColor
    let string: NSColor
    let comment: NSColor
    let number: NSColor
    let typeIdent: NSColor
    let functionCall: NSColor
    let preprocessor: NSColor
    let xmlTag: NSColor
    let attribute: NSColor
    let htmlEntity: NSColor

    static func make(forDark isDark: Bool) -> CmuxFilePreviewPalette {
        if isDark {
            return CmuxFilePreviewPalette(
                keyword:      NSColor(red: 0.99, green: 0.45, blue: 0.44, alpha: 1),
                string:       NSColor(red: 0.70, green: 0.93, blue: 0.60, alpha: 1),
                comment:      NSColor(red: 0.48, green: 0.55, blue: 0.48, alpha: 1),
                number:       NSColor(red: 0.82, green: 0.70, blue: 0.99, alpha: 1),
                typeIdent:    NSColor(red: 0.35, green: 0.85, blue: 0.95, alpha: 1),
                functionCall: NSColor(red: 0.99, green: 0.83, blue: 0.52, alpha: 1),
                preprocessor: NSColor(red: 0.99, green: 0.65, blue: 0.35, alpha: 1),
                xmlTag:       NSColor(red: 0.38, green: 0.78, blue: 0.88, alpha: 1),
                attribute:    NSColor(red: 0.70, green: 0.82, blue: 0.45, alpha: 1),
                htmlEntity:   NSColor(red: 0.88, green: 0.57, blue: 0.40, alpha: 1)
            )
        } else {
            return CmuxFilePreviewPalette(
                keyword:      NSColor(red: 0.70, green: 0.10, blue: 0.45, alpha: 1),
                string:       NSColor(red: 0.17, green: 0.50, blue: 0.10, alpha: 1),
                comment:      NSColor(red: 0.40, green: 0.47, blue: 0.42, alpha: 1),
                number:       NSColor(red: 0.38, green: 0.20, blue: 0.73, alpha: 1),
                typeIdent:    NSColor(red: 0.10, green: 0.40, blue: 0.70, alpha: 1),
                functionCall: NSColor(red: 0.60, green: 0.40, blue: 0.00, alpha: 1),
                preprocessor: NSColor(red: 0.55, green: 0.25, blue: 0.00, alpha: 1),
                xmlTag:       NSColor(red: 0.13, green: 0.45, blue: 0.60, alpha: 1),
                attribute:    NSColor(red: 0.30, green: 0.50, blue: 0.10, alpha: 1),
                htmlEntity:   NSColor(red: 0.65, green: 0.30, blue: 0.10, alpha: 1)
            )
        }
    }
}

/// Build a CodeEditSourceEditor `EditorTheme` using cmux's palette. The CodeEditSourceEditor
/// theme has a fixed set of capture slots; cmux token kinds are mapped to the closest slot.
private func makeCmuxEditorTheme(
    forDark: Bool,
    foreground: NSColor,
    background: NSColor
) -> EditorTheme {
    let palette = CmuxFilePreviewPalette.make(forDark: forDark)
    let lineHighlight: NSColor = forDark
        ? NSColor.white.withAlphaComponent(0.04)
        : NSColor.black.withAlphaComponent(0.04)
    return EditorTheme(
        text: EditorTheme.Attribute(color: foreground),
        insertionPoint: foreground,
        invisibles: EditorTheme.Attribute(color: foreground.withAlphaComponent(0.2)),
        background: background,
        lineHighlight: lineHighlight,
        selection: NSColor.selectedTextBackgroundColor,
        keywords: EditorTheme.Attribute(color: palette.keyword),
        commands: EditorTheme.Attribute(color: palette.preprocessor),
        types: EditorTheme.Attribute(color: palette.typeIdent),
        attributes: EditorTheme.Attribute(color: palette.attribute),
        variables: EditorTheme.Attribute(color: palette.functionCall),
        values: EditorTheme.Attribute(color: palette.htmlEntity),
        numbers: EditorTheme.Attribute(color: palette.number),
        strings: EditorTheme.Attribute(color: palette.string),
        characters: EditorTheme.Attribute(color: palette.xmlTag),
        comments: EditorTheme.Attribute(color: palette.comment)
    )
}

// MARK: - Save shortcut matcher

/// Standalone chord matcher for the file-preview save shortcut. Extracted so it can be
/// unit-tested without instantiating the entire editor view stack.
@MainActor
final class FilePreviewSaveShortcutMatcher {
    private var pendingChordPrefix: ShortcutStroke?

    /// Returns `true` when the event triggers save, `false` to silently consume (chord
    /// prefix matched, awaiting suffix), or `nil` to forward to other handlers.
    func match(event: NSEvent) -> Bool? {
        let shortcut = KeyboardShortcutSettings.shortcut(for: .saveFilePreview)
        guard shortcut.hasChord else {
            pendingChordPrefix = nil
            return shortcut.matches(event: event) ? true : nil
        }

        if let pendingPrefix = pendingChordPrefix {
            pendingChordPrefix = nil
            guard pendingPrefix == shortcut.firstStroke,
                  let secondStroke = shortcut.secondStroke else {
                return nil
            }
            return secondStroke.matches(event: event) ? true : nil
        }

        if shortcut.firstStroke.matches(event: event) {
            pendingChordPrefix = shortcut.firstStroke
            return false
        }
        return nil
    }
}

// MARK: - Bridge Coordinator

/// `TextViewCoordinator` that wires the panel model into the underlying CodeEditSourceEditor
/// text view. Responsible for:
/// - Registering the text view with the panel's focus coordinator.
/// - Exposing an insert-at-cursor seam for the URL-drop handler.
/// - Forwarding the cmux save chord (Cmd+S by default) to `panel.saveTextContent()`.
/// - Translating pinch / `option+scroll` events into font-size updates.
/// - Pushing externally-driven content changes (file watcher reloads) back into the view.
@MainActor
final class FilePreviewBridgeCoordinator: NSObject, ObservableObject, TextViewCoordinator {
    static let defaultFontSize: CGFloat = 13
    static let minimumFontSize: CGFloat = 8
    static let maximumFontSize: CGFloat = 36

    // Closures populated from the SwiftUI body before SourceEditor's makeNSViewController runs.
    var onAttachEditorView: ((NSView, FilePreviewTextEditorAccess?) -> Void)?
    var onSaveRequested: (() -> Void)?
    var onRetryPendingFocus: (() -> Void)?
    var currentFontSize: () -> CGFloat = { FilePreviewBridgeCoordinator.defaultFontSize }
    var setFontSize: (CGFloat) -> Void = { _ in }

    private weak var textView: TextView?
    private let saveMatcher = FilePreviewSaveShortcutMatcher()
    private var keyMonitor: Any?
    private var scrollMonitor: Any?
    private var magnifyRecognizer: NSMagnificationGestureRecognizer?

    // MARK: TextViewCoordinator

    func prepareCoordinator(controller: TextViewController) {
        guard let view = controller.textView else { return }
        textView = view

        let access = FilePreviewTextEditorAccess(
            insertText: { [weak self] text in
                guard let textView = self?.textView else { return }
                let selection = textView.selectedRange()
                textView.insertText(text, replacementRange: selection)
            },
            selectRange: { [weak self] range in
                guard let textView = self?.textView else { return }
                textView.selectionManager.setSelectedRange(range)
            },
            scrollToRange: { [weak self] range in
                guard let textView = self?.textView else { return }
                textView.scrollToRange(range)
            }
        )
        onAttachEditorView?(view, access)

        installKeyMonitor(on: view)
        installScrollMonitor(on: view)
        installMagnifyRecognizer(on: view)
    }

    func controllerDidAppear(controller: TextViewController) {
        onRetryPendingFocus?()
    }

    func destroy() {
        removeMonitors()
        textView = nil
    }

    deinit {
        // Monitor handles are AnyObject; safe to remove from deinit even off-main.
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        if let scrollMonitor { NSEvent.removeMonitor(scrollMonitor) }
    }

    // MARK: External content

    /// Push externally-driven content into the underlying text view (e.g., file watcher
    /// reloads the file from disk).
    func applyExternalContent(_ newContent: String) {
        guard let textView else { return }
        guard textView.string != newContent else { return }
        textView.setText(newContent)
    }

    // MARK: Save chord

    private func installKeyMonitor(on textView: TextView) {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak textView] event in
            guard let self,
                  let textView,
                  let window = textView.window,
                  event.window === window,
                  self.isResponderDescendant(window.firstResponder, of: textView) else {
                return event
            }
            switch self.saveMatcher.match(event: event) {
            case .some(true):
                self.onSaveRequested?()
                return nil
            case .some(false):
                return nil
            case .none:
                return event
            }
        }
        keyMonitor = monitor
    }

    private func isResponderDescendant(_ responder: NSResponder?, of view: TextView) -> Bool {
        var current: NSResponder? = responder
        while let next = current {
            if next === view { return true }
            current = next.nextResponder
        }
        return false
    }

    // MARK: Zoom

    private func installScrollMonitor(on textView: TextView) {
        let monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self, weak textView] event in
            guard let self, let textView else { return event }
            guard FilePreviewInteraction.hasZoomModifier(event) else { return event }
            guard self.eventIsOverTextView(event, textView: textView) else { return event }
            let factor = FilePreviewInteraction.zoomFactor(forScroll: event)
            self.adjustFontSize(by: factor)
            return nil
        }
        scrollMonitor = monitor
    }

    private func installMagnifyRecognizer(on textView: TextView) {
        let recognizer = NSMagnificationGestureRecognizer(target: self, action: #selector(handleMagnify(_:)))
        textView.addGestureRecognizer(recognizer)
        magnifyRecognizer = recognizer
    }

    @objc private func handleMagnify(_ recognizer: NSMagnificationGestureRecognizer) {
        let factor = 1.0 + recognizer.magnification
        guard factor.isFinite, factor > 0 else { return }
        adjustFontSize(by: factor)
        recognizer.magnification = 0
    }

    private func eventIsOverTextView(_ event: NSEvent, textView: TextView) -> Bool {
        guard let window = textView.window, event.window === window else { return false }
        let windowPoint = event.locationInWindow
        let viewPoint = textView.convert(windowPoint, from: nil)
        return textView.bounds.contains(viewPoint)
    }

    private func adjustFontSize(by factor: CGFloat) {
        let current = currentFontSize()
        let next = current * factor
        let clamped = min(max(next, Self.minimumFontSize), Self.maximumFontSize)
        guard clamped.isFinite, clamped != current else { return }
        setFontSize(clamped)
    }

    // MARK: Cleanup

    private func removeMonitors() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        if let recognizer = magnifyRecognizer {
            textView?.removeGestureRecognizer(recognizer)
            self.magnifyRecognizer = nil
        }
    }
}

// MARK: - SwiftUI Editor View

struct FilePreviewTextEditor<PanelModel>: View where PanelModel: ObservableObject & FilePreviewTextEditingPanel {
    @ObservedObject var panel: PanelModel
    let isVisibleInUI: Bool
    let themeBackgroundColor: NSColor
    let themeForegroundColor: NSColor
    let drawsBackground: Bool
    let wordWrapEnabled: Bool
    var filename: String = ""

    @State private var editorState = SourceEditorState()
    @State private var fontSize: CGFloat = FilePreviewBridgeCoordinator.defaultFontSize
    @StateObject private var bridge = FilePreviewBridgeCoordinator()

    var body: some View {
        // Wire the bridge's closures before SourceEditor is constructed (and therefore
        // before TextViewController.init calls bridge.prepareCoordinator).
        let _ = wireBridge()

        return SourceEditor(
            Binding<String>(
                get: { panel.textContent },
                set: { newValue in
                    guard newValue != panel.textContent else { return }
                    panel.updateTextContent(newValue)
                }
            ),
            language: SyntaxLanguage.from(filename: filename).codeLanguage,
            configuration: configuration,
            state: $editorState,
            coordinators: [bridge]
        )
        .opacity(isVisibleInUI ? 1 : 0)
        .allowsHitTesting(isVisibleInUI)
        .accessibilityHidden(!isVisibleInUI)
        .onChange(of: panel.textContent) { newValue in
            bridge.applyExternalContent(newValue)
        }
    }

    private func wireBridge() {
        bridge.onAttachEditorView = { [weak panel] view, access in
            panel?.attachTextEditorView(view, access: access)
        }
        bridge.onSaveRequested = { [weak panel] in
            _ = panel?.saveTextContent()
        }
        bridge.onRetryPendingFocus = { [weak panel] in
            panel?.retryPendingFocus()
        }
        bridge.currentFontSize = { fontSize }
        bridge.setFontSize = { newSize in fontSize = newSize }
    }

    private var configuration: SourceEditorConfiguration {
        let isDark = !themeForegroundColor.isLight
        let resolvedBackground = drawsBackground ? themeBackgroundColor : .clear
        let theme = makeCmuxEditorTheme(
            forDark: isDark,
            foreground: themeForegroundColor,
            background: resolvedBackground
        )
        return SourceEditorConfiguration(
            appearance: SourceEditorConfiguration.Appearance(
                theme: theme,
                useThemeBackground: true,
                font: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular),
                wrapLines: wordWrapEnabled
            ),
            behavior: SourceEditorConfiguration.Behavior(
                isEditable: true,
                isSelectable: true
            ),
            layout: SourceEditorConfiguration.Layout(
                additionalTextInsets: NSEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
            ),
            peripherals: SourceEditorConfiguration.Peripherals(
                showGutter: true,
                showMinimap: false,
                showFoldingRibbon: false
            )
        )
    }
}
