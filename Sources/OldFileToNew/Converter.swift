import Foundation

/// The conversion pipeline for one file: old document → intermediate ODF (via wpft2odf) →
/// chosen output format (via textutil or LibreOffice). Synchronous; call off the main
/// thread. Writes the result to `dest` and returns it.
enum Converter {

    /// - Parameters:
    ///   - input:       the dropped/picked file.
    ///   - categoryExt: the ODF category wpft2odf detected (odt/ods/odp/odg).
    ///   - outExt:      the final output extension.
    ///   - engine:      how to turn the intermediate ODF into the output.
    ///   - encoding:    optional wpft2odf `--encoding` value.
    ///   - dest:        already-resolved destination URL (collision handled by caller).
    static func run(input: URL, categoryExt: String, outExt: String,
                    engine: ConversionEngine, encoding: String?, dest: URL) -> Result<URL, Error> {
        // A private, space-free working directory (LibreOffice cannot cope with a space in
        // its profile path). Cleaned up on the way out.
        let work = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("oldfiletonew-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: work) }

        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let base = input.deletingPathExtension().lastPathComponent

            // 1. old document → intermediate ODF
            let intermediate = work.appendingPathComponent("\(base).\(categoryExt)")
            try ConversionTools.wpftConvert(input, to: intermediate, encoding: encoding)

            // 2. intermediate ODF → chosen output
            let produced: URL
            switch engine {
            case .odf:
                produced = intermediate
            case .textutil(let fmt):
                let out = work.appendingPathComponent("\(base).\(outExt)")
                try ConversionTools.textutilConvert(fmt, input: intermediate, output: out)
                produced = out
            case .soffice(let fmt):
                produced = try ConversionTools.sofficeConvert(fmt, input: intermediate, workDir: work)
            }

            // 3. place the result at the destination (caller already resolved collisions)
            let fm = FileManager.default
            if fm.fileExists(atPath: dest.path) { try fm.removeItem(at: dest) }
            try fm.copyItem(at: produced, to: dest)
            Log.write("converted \(input.lastPathComponent) → \(dest.lastPathComponent)")
            return .success(dest)
        } catch {
            return .failure(error)
        }
    }
}
