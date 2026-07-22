import AppKit

/// The ODF category wpft2odf reports for an input, which selects the Settings target.
/// The raw value is the intermediate ODF extension.
enum Category: String {
    case text = "odt", spreadsheet = "ods", presentation = "odp", drawing = "odg"
}

/// OldFileToNew — a drop-target / open-panel app that converts legacy documents (old Mac,
/// WordPerfect, iWork, CorelDRAW, …) to modern formats. Each dropped or chosen file is
/// converted with the bundled `wpft2odf` and written next to the original; the result is
/// revealed in the Finder. It never opens a viewer window.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let appName = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
    private var didOpen = false
    private var helpController: HelpWindowController?
    private var settingsController: SettingsWindowController?

    /// Off-main queue for child processes (wpft2odf / textutil / soffice).
    private let work = DispatchQueue(label: "org.wpdos.oldfiletonew.work", qos: .userInitiated)

    /// Conversions in flight — used only for logging; the app stays alive regardless
    /// (see `applicationShouldTerminateAfterLastWindowClosed`).
    private var pending = 0

    // MARK: - Launch

    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.write("launch: didFinishLaunching (bundle=\(Bundle.main.bundlePath))")
        buildMenu()
        // If the app was launched by opening files, `application(_:open:)` fires first and
        // sets didOpen; otherwise present the open panel so a plain launch is useful.
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.didOpen else { return }
            self.chooseAndConvert(nil)
        }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        Log.write("openEvent: \(urls.map { $0.lastPathComponent })")
        didOpen = true
        handle(urls)
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    // A converter stays open as a drop target rather than quitting when the open panel
    // (its only "window") closes — the WP Converter bug was the app terminating here.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Menu actions

    @objc func showHelp(_ sender: Any?) {
        if helpController == nil { helpController = HelpWindowController() }
        helpController?.present()
    }

    @objc func showSettings(_ sender: Any?) {
        if settingsController == nil { settingsController = SettingsWindowController() }
        settingsController?.present()
    }

    @objc func chooseAndConvert(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.message = "Choose one or more old files to convert:"
        panel.prompt = "Convert"
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false           // files only — no folders
        panel.canChooseFiles = true
        // Modeless (begin, not runModal) so the menu bar stays live and dismissing the
        // panel doesn't race app teardown.
        panel.begin { [weak self] result in
            guard let self, result == .OK, !panel.urls.isEmpty else { return }
            self.didOpen = true
            self.handle(panel.urls)
        }
    }

    // MARK: - Intake

    /// Convert the given files, ignoring folders. If *only* folders were given, explain.
    private func handle(_ urls: [URL]) {
        let files = urls.filter { !isFolder($0) }
        guard !files.isEmpty else {
            if !urls.isEmpty {
                warn("\(appName) converts files, not folders.",
                     "Drop or choose one or more old document files instead.")
            }
            return
        }
        for url in files { convert(url) }
    }

    private func isFolder(_ url: URL) -> Bool {
        let values = try? url.resourceValues(forKeys: [.isDirectoryKey])
        return values?.isDirectory == true      // packages (e.g. .pages bundles) count as folders
    }

    // MARK: - Conversion

    private func convert(_ url: URL) {
        Log.write("convert: \(url.path)")
        pending += 1
        // 1. Detect the format off-main (a quick wpft2odf -x).
        work.async { [weak self] in
            let detected = (try? ConversionTools.detectExtension(url)) ?? "unknown"
            DispatchQueue.main.async {
                guard let self else { return }
                guard let category = Category(rawValue: detected) else {
                    self.pending -= 1
                    self.warn("I can’t recognize “\(url.lastPathComponent)”.",
                              ConversionError.unsupported.message)
                    return
                }
                // 2. Pick the output format and resolve the destination (may prompt) on main.
                let (outExt, engine) = self.target(for: category)
                guard case let .use(dest) = Destination.resolve(for: url, ext: outExt) else {
                    self.pending -= 1
                    return
                }
                let encoding = Settings.shared.inputEncodingArgument
                // 3. Run the conversion off-main, then reveal / report on main.
                self.work.async {
                    let result = Converter.run(input: url, categoryExt: category.rawValue,
                                               outExt: outExt, engine: engine,
                                               encoding: encoding, dest: dest)
                    DispatchQueue.main.async {
                        self.pending -= 1
                        switch result {
                        case .success(let out):
                            NSWorkspace.shared.activateFileViewerSelecting([out])
                        case .failure(let error):
                            let detail = (error as? ConversionError)?.message ?? error.localizedDescription
                            self.warn("I could not convert “\(url.lastPathComponent)”.", detail)
                        }
                    }
                }
            }
        }
    }

    /// The output extension and engine for a category, honoring Settings. If the chosen
    /// format needs LibreOffice and it isn't installed, fall back to ODF (with a one-time
    /// notice) so the conversion still succeeds.
    private func target(for category: Category) -> (ext: String, engine: ConversionEngine) {
        let target: any OutputTarget
        switch category {
        case .text:         target = Settings.shared.documentTarget
        case .spreadsheet:  target = Settings.shared.spreadsheetTarget
        case .presentation: target = Settings.shared.presentationTarget
        case .drawing:      target = Settings.shared.drawingTarget
        }
        if target.engine.needsLibreOffice && !ConversionTools.hasLibreOffice {
            showLibreOfficeNoticeIfNeeded()
            return (category.rawValue, .odf)
        }
        return (target.fileExtension, target.engine)
    }

    /// One-time notice (with "Don't show again") shown if a chosen non-ODF format needs
    /// LibreOffice but it isn't installed, so the app quietly falls back to ODF.
    private func showLibreOfficeNoticeIfNeeded() {
        guard !Settings.shared.hideLibreOfficeNotice else { return }
        let alert = NSAlert()
        alert.messageText = "Saved as OpenDocument instead"
        alert.informativeText = """
            The format you chose for this kind of document needs LibreOffice, which isn’t \
            installed, so the file was saved as OpenDocument (ODF) instead.

            Installing the free LibreOffice (libreoffice.org) lets OldFileToNew also write \
            Excel, PowerPoint, PDF, and image formats.
            """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don’t show this again"
        alert.runModal()
        if alert.suppressionButton?.state == .on { Settings.shared.hideLibreOfficeNotice = true }
    }

    // MARK: - Alerts

    private func warn(_ message: String, _ info: String) {
        let alert = NSAlert()
        alert.messageText = message
        alert.informativeText = info
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    // MARK: - Menu

    private func buildMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem(); mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About \(appName)",
                        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showSettings(_:)), keyEquivalent: ",")
            .target = self
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit \(appName)",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let fileItem = NSMenuItem(); mainMenu.addItem(fileItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "Open…", action: #selector(chooseAndConvert(_:)), keyEquivalent: "o")
            .target = self
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w")
        fileItem.submenu = fileMenu

        let helpItem = NSMenuItem(); mainMenu.addItem(helpItem)
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "\(appName) Help", action: #selector(showHelp(_:)), keyEquivalent: "?")
            .target = self
        helpItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu

        NSApp.mainMenu = mainMenu
    }
}
