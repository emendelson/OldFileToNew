import AppKit

/// Settings window: the default output format for each kind of document, plus the input
/// text encoding. Formats that need LibreOffice are disabled when it isn't installed.
@MainActor
final class SettingsWindowController: NSWindowController {

    private let docPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let sheetPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let presoPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let drawPopUp = NSPopUpButton(frame: .zero, pullsDown: false)
    private let encodingPopUp = NSPopUpButton(frame: .zero, pullsDown: false)

    /// The encoding names offered after "Automatic"; index 0 of the popup is Automatic.
    private let encodings = ConversionTools.listEncodings()

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 300),
            styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        self.init(window: window)
        buildContent()
    }

    private func buildContent() {
        guard let content = window?.contentView else { return }

        let intro = NSTextField(wrappingLabelWithString:
            "Choose what each kind of converted document becomes:")
        intro.font = .systemFont(ofSize: 12)
        intro.textColor = .secondaryLabelColor

        func label(_ s: String) -> NSTextField {
            let l = NSTextField(labelWithString: s); l.alignment = .right; return l
        }

        fill(docPopUp, DocTarget.allCases, selected: Settings.shared.documentTarget,
             action: #selector(docChanged))
        fill(sheetPopUp, SheetTarget.allCases, selected: Settings.shared.spreadsheetTarget,
             action: #selector(sheetChanged))
        fill(presoPopUp, PresoTarget.allCases, selected: Settings.shared.presentationTarget,
             action: #selector(presoChanged))
        fill(drawPopUp, DrawTarget.allCases, selected: Settings.shared.drawingTarget,
             action: #selector(drawChanged))

        // Input encoding: "Automatic" first (passes no --encoding), then wpft2odf's list.
        encodingPopUp.addItem(withTitle: "Automatic (default)")
        encodingPopUp.addItems(withTitles: encodings)
        if let i = encodings.firstIndex(of: Settings.shared.inputEncoding) {
            encodingPopUp.selectItem(at: i + 1)
        } else {
            encodingPopUp.selectItem(at: 0)
        }
        encodingPopUp.target = self
        encodingPopUp.action = #selector(encodingChanged)

        let grid = NSGridView(views: [
            [label("Word-processing documents →"), docPopUp],
            [label("Spreadsheets →"), sheetPopUp],
            [label("Presentations →"), presoPopUp],
            [label("Drawings →"), drawPopUp],
            [label("Input text encoding:"), encodingPopUp],
        ])
        grid.rowSpacing = 12
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing

        let footer = NSTextField(wrappingLabelWithString: ConversionTools.hasLibreOffice
            ? "Converting to a non-ODF format may lose some formatting."
            : "Some spreadsheet, presentation, and drawing formats need the free "
              + "LibreOffice (libreoffice.org) and are disabled until it is installed. "
              + "Converting to a non-ODF format may lose some formatting.")
        footer.font = .systemFont(ofSize: 11)
        footer.textColor = .secondaryLabelColor

        for v in [intro, grid, footer] {
            v.translatesAutoresizingMaskIntoConstraints = false
            content.addSubview(v)
        }
        NSLayoutConstraint.activate([
            intro.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            intro.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            intro.topAnchor.constraint(equalTo: content.topAnchor, constant: 18),
            grid.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            grid.topAnchor.constraint(equalTo: intro.bottomAnchor, constant: 16),
            footer.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 20),
            footer.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -20),
            footer.topAnchor.constraint(equalTo: grid.bottomAnchor, constant: 18),
        ])
    }

    /// Populate a popup from an OutputTarget enum, select the current value, and disable
    /// items whose engine needs LibreOffice when it isn't installed.
    private func fill<T: OutputTarget & Equatable>(_ popUp: NSPopUpButton, _ all: [T],
                                                   selected: T, action: Selector) {
        popUp.addItems(withTitles: all.map(\.menuTitle))
        let haveLO = ConversionTools.hasLibreOffice
        for (i, target) in all.enumerated() where target.engine.needsLibreOffice && !haveLO {
            popUp.item(at: i)?.isEnabled = false
        }
        if let i = all.firstIndex(of: selected) { popUp.selectItem(at: i) }
        popUp.target = self
        popUp.action = action
    }

    @objc private func docChanged() {
        Settings.shared.documentTarget = DocTarget.allCases[docPopUp.indexOfSelectedItem]
    }
    @objc private func sheetChanged() {
        Settings.shared.spreadsheetTarget = SheetTarget.allCases[sheetPopUp.indexOfSelectedItem]
    }
    @objc private func presoChanged() {
        Settings.shared.presentationTarget = PresoTarget.allCases[presoPopUp.indexOfSelectedItem]
    }
    @objc private func drawChanged() {
        Settings.shared.drawingTarget = DrawTarget.allCases[drawPopUp.indexOfSelectedItem]
    }
    @objc private func encodingChanged() {
        let i = encodingPopUp.indexOfSelectedItem
        Settings.shared.inputEncoding = (i <= 0) ? "" : encodings[i - 1]
    }

    func present() {
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
