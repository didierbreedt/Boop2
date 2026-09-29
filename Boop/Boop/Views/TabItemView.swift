import Cocoa

final class TabItemView: NSView {
    let selectButton: NSButton
    let closeButton: NSButton
    let index: Int
    var onSelect: ((Int) -> Void)?
    var onClose: ((Int) -> Void)?

    var title: String {
        didSet { updateTitle() }
    }

    private let selected: Bool

    init(index: Int, title: String, selected: Bool) {
        self.index = index
        self.title = title
        self.selected = selected
        selectButton = NSButton()
        closeButton = NSButton()
        super.init(frame: NSRect(x: 0, y: 0, width: 140, height: 24))

        translatesAutoresizingMaskIntoConstraints = false
        widthAnchor.constraint(equalToConstant: 140).isActive = true
        heightAnchor.constraint(equalToConstant: 24).isActive = true

        selectButton.isBordered = false
        selectButton.alignment = .left
        selectButton.cell?.lineBreakMode = .byTruncatingTail
        selectButton.target = self
        selectButton.action = #selector(selectTab)
        selectButton.refusesFirstResponder = true
        selectButton.identifier = NSUserInterfaceItemIdentifier("tab.select.\(index)")
        selectButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(selectButton)

        closeButton.isBordered = false
        closeButton.title = "×"
        closeButton.font = NSFont.systemFont(ofSize: 15)
        closeButton.target = self
        closeButton.action = #selector(closeTab)
        closeButton.refusesFirstResponder = true
        closeButton.identifier = NSUserInterfaceItemIdentifier("tab.close.\(index)")
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        addSubview(closeButton)

        NSLayoutConstraint.activate([
            selectButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 10),
            selectButton.trailingAnchor.constraint(equalTo: closeButton.leadingAnchor, constant: -2),
            selectButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
            closeButton.centerYAnchor.constraint(equalTo: centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 18),
            closeButton.heightAnchor.constraint(equalToConstant: 20),
        ])
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("Use init(index:title:selected:)")
    }

    override func draw(_ dirtyRect: NSRect) {
        let shape = NSBezierPath(roundedRect: bounds, xRadius: 6, yRadius: 6)
        (selected ? NSColor.controlAccentColor : NSColor.controlBackgroundColor).setFill()
        shape.fill()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateTitle()
        needsDisplay = true
    }

    private func updateTitle() {
        let color = selected ? NSColor.white : NSColor.labelColor
        selectButton.attributedTitle = NSAttributedString(
            string: "\(index + 1)  \(title)",
            attributes: [.font: NSFont.systemFont(ofSize: 12, weight: .medium),
                         .foregroundColor: color]
        )
        selectButton.toolTip = index < 9 ? "⌘\(index + 1) · \(title)" : title
        closeButton.toolTip = "Close \(title)"
        closeButton.contentTintColor = selected ? .white : .secondaryLabelColor
    }

    @objc private func selectTab() { onSelect?(index) }
    @objc private func closeTab() { onClose?(index) }
}
