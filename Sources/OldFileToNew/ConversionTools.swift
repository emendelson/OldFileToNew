import Foundation

/// Errors surfaced by a conversion step, each mapped to a user-facing message.
enum ConversionError: Error {
    case toolMissing(String)        // the bundled wpft2odf could not be located
    case unsupported                // wpft2odf did not recognize the input format
    case conversionFailed           // wpft2odf produced no output
    case needsLibreOffice(String)   // a non-ODF target needs LibreOffice, which is absent
    case postConvertFailed(String)  // textutil / soffice could not produce the final file

    var message: String {
        switch self {
        case .toolMissing(let t):
            return "“\(t)” could not be found inside the application bundle."
        case .unsupported:
            return "It isn’t one of the old formats I know how to convert."
        case .conversionFailed:
            return "The converter could not read it — the file may be damaged or unsupported."
        case .needsLibreOffice(let fmt):
            return "Converting to \(fmt.uppercased()) needs LibreOffice, which isn’t installed."
        case .postConvertFailed(let detail):
            return detail.isEmpty ? "The format converter could not produce the file." : detail
        }
    }
}

/// Runs the bundled `wpft2odf` and the system format converters (macOS `textutil`,
/// LibreOffice `soffice`). All methods are synchronous and may block on a child process,
/// so callers must invoke them off the main thread (detection excepted — it is quick).
enum ConversionTools {

    // MARK: - Bundled wpft2odf

    /// Locate the bundled wpft2odf. In the assembled .app it lives in
    /// `Contents/Resources/Files/`; for `swift run` during development we fall back to the
    /// package's `Resources/Files`.
    static func toolURL(_ name: String) -> URL? {
        var candidates: [URL] = []
        if let resourceURL = Bundle.main.resourceURL {
            candidates.append(resourceURL.appendingPathComponent("Files/\(name)"))
            candidates.append(resourceURL.appendingPathComponent(name))
        }
        let exe = URL(fileURLWithPath: CommandLine.arguments[0]).deletingLastPathComponent()
        candidates.append(exe.appendingPathComponent("Resources/Files/\(name)"))
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }

    /// The ODF category wpft2odf detects for `input`: "odt", "ods", "odp", "odg", or
    /// "unknown". (Detection ignores encoding, so no --encoding is passed here.)
    static func detectExtension(_ input: URL) throws -> String {
        guard let url = toolURL("wpft2odf") else { throw ConversionError.toolMissing("wpft2odf") }
        let out = try run(url, ["-x", input.path], label: "wpft2odf -x").out
        return String(data: out, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "unknown"
    }

    /// The input encodings wpft2odf accepts (for the Settings menu). Empty on failure.
    static func listEncodings() -> [String] {
        guard let url = toolURL("wpft2odf") else { return [] }
        guard let out = try? run(url, ["--list-encodings"], label: "wpft2odf --list-encodings").out,
              let text = String(data: out, encoding: .utf8) else { return [] }
        return text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Convert an old document to a flat/zipped ODF file at `output`, honoring an optional
    /// input `encoding`. wpft2odf exits non-zero on failure, and even on success writes
    /// nothing to stdout, so success is judged by a non-empty output file.
    static func wpftConvert(_ input: URL, to output: URL, encoding: String?) throws {
        guard let url = toolURL("wpft2odf") else { throw ConversionError.toolMissing("wpft2odf") }
        var args: [String] = []
        if let encoding, !encoding.isEmpty { args += ["--encoding", encoding] }
        args += [input.path, output.path]
        _ = try run(url, args, label: "wpft2odf")
        guard isNonEmptyFile(output) else { throw ConversionError.conversionFailed }
    }

    // MARK: - ODF → familiar formats

    /// Text (odt) → rtf/doc/docx/html/txt via macOS textutil (always available; no
    /// dependency). textutil reads ODF word-processing documents.
    static func textutilConvert(_ format: String, input: URL, output: URL) throws {
        let textutil = URL(fileURLWithPath: "/usr/bin/textutil")
        let result = try run(textutil,
                             ["-convert", format, "-output", output.path, input.path],
                             label: "textutil")
        guard isNonEmptyFile(output) else {
            throw ConversionError.postConvertFailed(
                String(data: result.err, encoding: .utf8) ?? "textutil produced no output")
        }
    }

    /// `/Applications/LibreOffice.app/Contents/MacOS/soffice`, if installed.
    static var libreOfficeURL: URL? {
        let url = URL(fileURLWithPath: "/Applications/LibreOffice.app/Contents/MacOS/soffice")
        return FileManager.default.isExecutableFile(atPath: url.path) ? url : nil
    }

    /// Whether the optional LibreOffice engine (for ods/odp/odg → familiar formats) exists.
    static var hasLibreOffice: Bool { libreOfficeURL != nil }

    /// Spreadsheet/presentation/drawing (ods/odp/odg) → xlsx/csv/pptx/pdf/svg/png via
    /// LibreOffice headless. Produces `<workDir>/<base>.<format>` and returns it.
    static func sofficeConvert(_ format: String, input: URL, workDir: URL) throws -> URL {
        guard let soffice = libreOfficeURL else { throw ConversionError.needsLibreOffice(format) }
        // A private, space-free UserInstallation dir: soffice crashes if the profile path
        // contains a space, and avoids the "already running" lock when the GUI is open.
        let profile = workDir.appendingPathComponent("loprofile")
        let result = try run(soffice, [
            "-env:UserInstallation=\(profile.absoluteString)",
            "--headless", "--convert-to", format, "--outdir", workDir.path, input.path
        ], label: "soffice")
        let produced = workDir.appendingPathComponent(
            input.deletingPathExtension().lastPathComponent + ".\(format)")
        guard isNonEmptyFile(produced) else {
            throw ConversionError.postConvertFailed(
                String(data: result.err, encoding: .utf8) ?? "LibreOffice produced no output")
        }
        return produced
    }

    // MARK: - Helpers

    static func isNonEmptyFile(_ url: URL) -> Bool {
        guard let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize else { return false }
        return size > 0
    }

    private struct Output { let out: Data; let err: Data }

    private static func run(_ url: URL, _ arguments: [String], label: String) throws -> Output {
        let process = Process()
        process.executableURL = url
        process.arguments = arguments

        let outPipe = Pipe(), errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe
        process.standardInput = FileHandle.nullDevice

        Log.write("run \(label): \(arguments.joined(separator: " "))")
        try process.run()
        // wpft2odf/textutil/soffice put payloads in files (or short stdout), so a blocking
        // read to EOF cannot deadlock; no run loop needed.
        let out = readAll(outPipe.fileHandleForReading)
        let err = readAll(errPipe.fileHandleForReading)
        process.waitUntilExit()
        Log.write("run \(label): status \(process.terminationStatus), "
                  + "\(out.count)B out, \(err.count)B err")
        return Output(out: out, err: err)
    }

    /// Blocking read of a file handle to EOF via raw `read()`; safe on any thread.
    private static func readAll(_ handle: FileHandle) -> Data {
        var data = Data()
        let bufSize = 1 << 16
        var buffer = [UInt8](repeating: 0, count: bufSize)
        while true {
            let n = buffer.withUnsafeMutableBytes { read(handle.fileDescriptor, $0.baseAddress, bufSize) }
            if n > 0 { data.append(buffer, count: n) } else { break }
        }
        return data
    }
}
