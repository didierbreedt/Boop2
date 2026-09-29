import Cocoa

class BoopEditorView: NSView {
    let scrollView = NSScrollView()
    let contentTextView = NSTextView(frame: .zero)
    private var lineNumberRuler: LineNumberRulerView?

    var text: String {
        get { contentTextView.string }
        set { contentTextView.string = newValue }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    private func setup() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder

        contentTextView.isRichText = false
        contentTextView.isEditable = true
        contentTextView.allowsUndo = true
        contentTextView.isAutomaticQuoteSubstitutionEnabled = false
        contentTextView.isAutomaticDashSubstitutionEnabled = false
        contentTextView.isAutomaticSpellingCorrectionEnabled = false
        contentTextView.isAutomaticTextReplacementEnabled = false
        contentTextView.font = NSFont(name: "Menlo", size: 15)
            ?? NSFont.systemFont(ofSize: 15)
        contentTextView.textContainerInset = NSSize(width: 12, height: 12)
        contentTextView.minSize = .zero
        contentTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude,
                                         height: CGFloat.greatestFiniteMagnitude)
        contentTextView.isVerticallyResizable = true
        contentTextView.isHorizontallyResizable = false
        contentTextView.autoresizingMask = [.width]
        contentTextView.textContainer?.widthTracksTextView = true
        scrollView.documentView = contentTextView
        let ruler = LineNumberRulerView(scrollView: scrollView, textView: contentTextView)
        lineNumberRuler = ruler
        scrollView.verticalRulerView = ruler
        scrollView.hasVerticalRuler = true
        scrollView.rulersVisible = true

        addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
        updateColors()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateColors()
    }

    private func updateColors() {
        contentTextView.backgroundColor = NSColor.textBackgroundColor
        contentTextView.textColor = NSColor.textColor
        contentTextView.insertionPointColor = NSColor.textColor
        scrollView.backgroundColor = NSColor.textBackgroundColor
        lineNumberRuler?.needsDisplay = true
    }
}

final class LineNumberRulerView: NSRulerView {
    private weak var textView: NSTextView?
    private let padding: CGFloat = 8

    init(scrollView: NSScrollView, textView: NSTextView) {
        self.textView = textView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView
        ruleThickness = 42
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                               name: NSView.boundsDidChangeNotification,
                                               object: scrollView.contentView)
        NotificationCenter.default.addObserver(self, selector: #selector(redraw),
                                               name: NSText.didChangeNotification,
                                               object: textView)
    }

    required init(coder: NSCoder) {
        fatalError("Use init(scrollView:textView:)")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func redraw() {
        needsDisplay = true
    }

    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let textView = textView,
              let container = textView.textContainer,
              let layout = textView.layoutManager else { return }

        NSColor.textBackgroundColor.setFill()
        bounds.fill()

        let font = textView.font ?? NSFont.systemFont(ofSize: 15)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.secondaryLabelColor
        ]
        let text = textView.string as NSString
        let origin = textView.textContainerOrigin
        let visible = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let glyphs = layout.glyphRange(forBoundingRect: visible, in: container)

        if text.length == 0 {
            drawNumber(1, at: origin.y, attributes: attributes)
            return
        }

        var previousLineStart: Int?
        var line = 1
        layout.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, glyphRange, _ in
            let character = layout.characterIndexForGlyph(at: glyphRange.location)
            let lineStart = text.lineRange(for: NSRange(location: character, length: 0)).location
            if let previous = previousLineStart, lineStart != previous {
                line += 1
            } else if previousLineStart == nil {
                line = self.lineNumber(at: lineStart, in: text)
            }
            previousLineStart = lineStart
            guard character == lineStart else { return }
            self.drawNumber(line, at: fragment.minY + origin.y, attributes: attributes)
        }
        let last = text.character(at: text.length - 1)
        if (last == 10 || last == 13),
           layout.extraLineFragmentRect.intersects(visible) {
            drawNumber(lineNumber(at: text.length, in: text),
                       at: layout.extraLineFragmentRect.minY + origin.y,
                       attributes: attributes)
        }
    }

    func lineNumber(at index: Int, in text: NSString) -> Int {
        var line = 1
        var offset = 0
        while offset < min(index, text.length) {
            let character = text.character(at: offset)
            if character == 10 || character == 13 {
                line += 1
                if character == 13 && offset + 1 < index && text.character(at: offset + 1) == 10 {
                    offset += 1
                }
            }
            offset += 1
        }
        return line
    }

    private func drawNumber(_ number: Int, at textY: CGFloat,
                            attributes: [NSAttributedString.Key: Any]) {
        guard let textView = textView else { return }
        let label = NSString(string: String(number))
        let size = label.size(withAttributes: attributes)
        let requiredThickness = size.width + padding * 2
        if requiredThickness > ruleThickness {
            ruleThickness = requiredThickness
        }
        let point = convert(NSPoint(x: 0, y: textY), from: textView)
        label.draw(at: NSPoint(x: ruleThickness - padding - size.width,
                               y: point.y), withAttributes: attributes)
    }
}
