import AppKit
import WebKit

/// A window that displays the bundled `Help.html` (the supported-formats reference) in a
/// web view. The app delegate keeps one instance, so choosing Help again brings it forward.
@MainActor
final class HelpWindowController: NSWindowController {

    private let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 760, height: 820))

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 820),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false)
        let appName = Bundle.main.bundleURL.deletingPathExtension().lastPathComponent
        window.title = "\(appName) Help"
        window.setFrameAutosaveName("OldFileToNewHelpWindow")
        window.isReleasedWhenClosed = false
        self.init(window: window)

        webView.autoresizingMask = [.width, .height]
        window.contentView = webView
        loadHelp()
    }

    private func loadHelp() {
        guard let url = Self.helpURL() else {
            webView.loadHTMLString("<html><body style='font:16px -apple-system;padding:2em'>"
                + "Help file not found.</body></html>", baseURL: nil)
            return
        }
        webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
    }

    static func helpURL() -> URL? {
        if let url = Bundle.main.url(forResource: "Help", withExtension: "html") { return url }
        let dev = URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Help.html")
        return FileManager.default.fileExists(atPath: dev.path) ? dev : nil
    }

    func present() {
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
