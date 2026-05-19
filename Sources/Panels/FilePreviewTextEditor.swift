import AppKit
import SwiftUI

@MainActor
protocol FilePreviewTextEditingPanel: AnyObject {
    var textContent: String { get }

    func attachTextView(_ textView: NSTextView)
    func retryPendingFocus()
    func updateTextContent(_ nextContent: String)
    @discardableResult
    func saveTextContent() -> Task<Void, Never>?
}

struct FilePreviewTextEditor<PanelModel>: NSViewRepresentable where PanelModel: ObservableObject & FilePreviewTextEditingPanel {
    @ObservedObject var panel: PanelModel
    let isVisibleInUI: Bool
    let themeBackgroundColor: NSColor
    let themeForegroundColor: NSColor
    let drawsBackground: Bool
    let wordWrapEnabled: Bool
    /// Filename (including extension) used to select the syntax-highlight language.
    var filename: String = ""

    func makeCoordinator() -> Coordinator {
        Coordinator(panel: panel, filename: filename, defaultColor: themeForegroundColor)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.isHidden = !isVisibleInUI
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = !wordWrapEnabled
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        scrollView.drawsBackground = drawsBackground
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        let textView = SavingTextView()
        textView.panel = panel
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.usesFindPanel = true
        textView.usesFontPanel = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.drawsBackground = drawsBackground
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = !wordWrapEnabled
        textView.autoresizingMask = [.width]
        Self.applyWordWrap(wordWrapEnabled, to: textView, in: scrollView)
        textView.applyFilePreviewTextEditorInsets()
        textView.string = panel.textContent
        panel.attachTextView(textView)

        scrollView.documentView = textView
        scrollView.verticalRulerView = FilePreviewLineNumberRulerView(textView: textView)
        Self.applyTheme(
            to: scrollView,
            backgroundColor: themeBackgroundColor,
            foregroundColor: themeForegroundColor,
            drawsBackground: drawsBackground
        )
        context.coordinator.attachHighlighter(to: textView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.panel = panel
        scrollView.isHidden = !isVisibleInUI
        Self.applyTheme(
            to: scrollView,
            backgroundColor: themeBackgroundColor,
            foregroundColor: themeForegroundColor,
            drawsBackground: drawsBackground
        )
        guard let textView = scrollView.documentView as? SavingTextView else { return }
        textView.panel = panel
        scrollView.hasHorizontalScroller = !wordWrapEnabled
        Self.applyWordWrap(wordWrapEnabled, to: textView, in: scrollView)
        textView.applyFilePreviewTextEditorInsets()
        (scrollView.verticalRulerView as? FilePreviewLineNumberRulerView)?.invalidateLineNumbers()
        panel.attachTextView(textView)
        guard textView.string != panel.textContent else { return }
        context.coordinator.isApplyingPanelUpdate = true
        textView.string = panel.textContent
        context.coordinator.isApplyingPanelUpdate = false
        context.coordinator.highlightAll()
    }

    static func applyTheme(
        to scrollView: NSScrollView,
        backgroundColor: NSColor,
        foregroundColor: NSColor,
        drawsBackground: Bool
    ) {
        let resolvedBackgroundColor = drawsBackground ? backgroundColor : .clear
        scrollView.drawsBackground = drawsBackground
        scrollView.backgroundColor = resolvedBackgroundColor
        scrollView.contentView.drawsBackground = drawsBackground
        scrollView.contentView.backgroundColor = resolvedBackgroundColor
        if let textView = scrollView.documentView as? NSTextView {
            textView.drawsBackground = drawsBackground
            textView.backgroundColor = resolvedBackgroundColor
            textView.textColor = foregroundColor
            textView.insertionPointColor = foregroundColor
        }
    }

    static func applyWordWrap(_ enabled: Bool, to textView: NSTextView, in scrollView: NSScrollView) {
        if enabled {
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.textContainer?.containerSize = NSSize(
                width: max(scrollView.contentSize.width, 1),
                height: CGFloat.greatestFiniteMagnitude
            )
        } else {
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = false
            textView.textContainer?.containerSize = NSSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var panel: PanelModel
        var isApplyingPanelUpdate = false
        private let syntaxHighlighter: SyntaxHighlighter

        init(panel: PanelModel, filename: String, defaultColor: NSColor) {
            self.panel = panel
            let language = SyntaxLanguage.from(filename: filename)
            self.syntaxHighlighter = SyntaxHighlighter(language: language, defaultColor: defaultColor)
        }

        deinit {}

        func attachHighlighter(to textView: NSTextView) {
            guard let storage = textView.textStorage else { return }
            syntaxHighlighter.attach(to: storage)
            syntaxHighlighter.highlightAll()
        }

        func highlightAll() {
            syntaxHighlighter.highlightAll()
        }

        nonisolated func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            let content = textView.string
            Task { @MainActor [weak self] in
                guard let self else { return }
                guard !self.isApplyingPanelUpdate else { return }
                self.panel.updateTextContent(content)
                textView.enclosingScrollView?.verticalRulerView?.needsDisplay = true
            }
        }
    }
}

final class FilePreviewLineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let gutterWidth: CGFloat = 44

    init(textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: textView.enclosingScrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = gutterWidth
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func invalidateLineNumbers() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView,
              let layoutManager = textView.layoutManager,
              let textContainer = textView.textContainer else {
            return
        }

        NSColor.textBackgroundColor.withAlphaComponent(0.35).setFill()
        rect.fill()

        let visibleRect = textView.visibleRect
        let glyphRange = layoutManager.glyphRange(
            forBoundingRect: visibleRect,
            in: textContainer
        )
        var lineNumber = lineNumberForGlyph(at: glyphRange.location, layoutManager: layoutManager)
        var glyphIndex = glyphRange.location
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
            .foregroundColor: NSColor.tertiaryLabelColor
        ]

        while glyphIndex < NSMaxRange(glyphRange) {
            var lineRange = NSRange(location: 0, length: 0)
            let lineRect = layoutManager.lineFragmentRect(
                forGlyphAt: glyphIndex,
                effectiveRange: &lineRange,
                withoutAdditionalLayout: true
            )
            let y = lineRect.minY + textView.textContainerOrigin.y - visibleRect.minY + 1
            let label = "\(lineNumber)" as NSString
            let size = label.size(withAttributes: attributes)
            label.draw(
                at: NSPoint(x: gutterWidth - size.width - 8, y: y),
                withAttributes: attributes
            )
            glyphIndex = NSMaxRange(lineRange)
            lineNumber += 1
            if lineRange.length == 0 {
                glyphIndex += 1
            }
        }
    }

    private func lineNumberForGlyph(at glyphIndex: Int, layoutManager: NSLayoutManager) -> Int {
        guard let text = textView?.string as NSString? else { return 1 }
        let characterIndex = layoutManager.characterIndexForGlyph(at: max(glyphIndex, 0))
        var line = 1
        text.enumerateSubstrings(
            in: NSRange(location: 0, length: min(characterIndex, text.length)),
            options: [.byLines, .substringNotRequired]
        ) { _, _, _, _ in
            line += 1
        }
        return line
    }
}

enum FilePreviewTextEditorLayout {
    static let textContainerInset = NSSize(width: 12, height: 10)
    static let lineFragmentPadding: CGFloat = 0
}

extension NSTextView {
    func applyFilePreviewTextEditorInsets() {
        let targetInset = FilePreviewTextEditorLayout.textContainerInset
        if textContainerInset.width != targetInset.width || textContainerInset.height != targetInset.height {
            textContainerInset = targetInset
        }
        if textContainer?.lineFragmentPadding != FilePreviewTextEditorLayout.lineFragmentPadding {
            textContainer?.lineFragmentPadding = FilePreviewTextEditorLayout.lineFragmentPadding
        }
    }
}

final class SavingTextView: NSTextView {
    private static let defaultPreviewFontSize: CGFloat = 13
    private static let minimumPreviewFontSize: CGFloat = 8
    private static let maximumPreviewFontSize: CGFloat = 36

    weak var panel: (any FilePreviewTextEditingPanel)?
    private var previewFontSize: CGFloat = 13
    private var pendingSaveShortcutChordPrefix: ShortcutStroke?

    deinit {}

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyFilePreviewTextEditorInsets()
        panel?.retryPendingFocus()
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.type == .keyDown else {
            return super.performKeyEquivalent(with: event)
        }
        guard let shouldSave = saveShortcutMatch(for: event) else {
            return super.performKeyEquivalent(with: event)
        }
        if shouldSave {
            panel?.saveTextContent()
        }
        return true
    }

    override func magnify(with event: NSEvent) {
        let factor = 1.0 + event.magnification
        guard factor.isFinite, factor > 0 else { return }
        adjustPreviewFontSize(by: factor)
    }

    override func scrollWheel(with event: NSEvent) {
        guard FilePreviewInteraction.hasZoomModifier(event) else {
            super.scrollWheel(with: event)
            return
        }
        adjustPreviewFontSize(by: FilePreviewInteraction.zoomFactor(forScroll: event))
    }

    override func smartMagnify(with event: NSEvent) {
        if previewFontSize == Self.defaultPreviewFontSize {
            setPreviewFontSize(18)
        } else {
            setPreviewFontSize(Self.defaultPreviewFontSize)
        }
    }

    private func adjustPreviewFontSize(by factor: CGFloat) {
        setPreviewFontSize(previewFontSize * factor)
    }

    private func setPreviewFontSize(_ nextFontSize: CGFloat) {
        let clamped = min(max(nextFontSize, Self.minimumPreviewFontSize), Self.maximumPreviewFontSize)
        guard clamped.isFinite else { return }
        previewFontSize = clamped
        let nextFont = NSFont.monospacedSystemFont(ofSize: clamped, weight: .regular)
        font = nextFont
        typingAttributes[.font] = nextFont
    }

    private func saveShortcutMatch(for event: NSEvent) -> Bool? {
        let shortcut = KeyboardShortcutSettings.shortcut(for: .saveFilePreview)
        guard shortcut.hasChord else {
            pendingSaveShortcutChordPrefix = nil
            return shortcut.matches(event: event) ? true : nil
        }

        if let pendingPrefix = pendingSaveShortcutChordPrefix {
            pendingSaveShortcutChordPrefix = nil
            guard pendingPrefix == shortcut.firstStroke,
                  let secondStroke = shortcut.secondStroke else {
                return nil
            }
            return secondStroke.matches(event: event) ? true : nil
        }

        if shortcut.firstStroke.matches(event: event) {
            pendingSaveShortcutChordPrefix = shortcut.firstStroke
            return false
        }
        return nil
    }
}
