import AppKit

/// Decides where a converted file is written: same folder as the original, same base
/// name, new extension. When that name already exists the user is asked whether to
/// replace it or keep both; "Keep Both" writes "name (1).ext", "name (2).ext", … .
@MainActor
enum Destination {

    enum Choice { case use(URL), cancel }

    static func resolve(for source: URL, ext: String) -> Choice {
        let dir = source.deletingLastPathComponent()
        // Old Mac files usually have no extension ("WriteNow Sample"); when one is present
        // it's the legacy type, so strip it so we don't get "report.cwk.odt".
        let base = source.deletingPathExtension().lastPathComponent
        let primary = dir.appendingPathComponent("\(base).\(ext)")

        guard FileManager.default.fileExists(atPath: primary.path) else {
            return .use(primary)
        }

        let alert = NSAlert()
        alert.messageText = "A file named “\(primary.lastPathComponent)” already exists."
        alert.informativeText = "Do you want to replace it, or keep both files?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Keep Both")
        alert.addButton(withTitle: "Replace")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:  return .use(keepBoth(dir: dir, base: base, ext: ext))
        case .alertSecondButtonReturn: return .use(primary)
        default:                       return .cancel
        }
    }

    /// First non-colliding "base (n).ext".
    private static func keepBoth(dir: URL, base: String, ext: String) -> URL {
        var n = 1
        while true {
            let candidate = dir.appendingPathComponent("\(base) (\(n)).\(ext)")
            if !FileManager.default.fileExists(atPath: candidate.path) { return candidate }
            n += 1
        }
    }
}
