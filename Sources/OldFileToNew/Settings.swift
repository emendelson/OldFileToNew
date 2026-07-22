import Foundation

/// How the intermediate ODF is turned into the chosen output format.
enum ConversionEngine: Sendable {
    case odf                 // the ODF wpft2odf produced is already the target
    case textutil(String)    // macOS `textutil -convert <fmt>` (built-in; text only)
    case soffice(String)     // LibreOffice `soffice --convert-to <fmt>` (optional engine)

    var needsLibreOffice: Bool {
        if case .soffice = self { return true }
        return false
    }
}

/// A user-selectable output format for one input category. `fileExtension` is what the
/// output is named; `engine` is how we get there from the intermediate ODF.
protocol OutputTarget: CaseIterable, Sendable {
    var fileExtension: String { get }
    var menuTitle: String { get }
    var engine: ConversionEngine { get }
}

/// Word-processing documents (wpft2odf category `odt`). All targets are built-in
/// (textutil) — no LibreOffice needed.
enum DocTarget: String, OutputTarget {
    case odt, rtf, docx, doc, html, txt
    var fileExtension: String { rawValue }
    var engine: ConversionEngine {
        switch self {
        case .odt:  return .odf
        default:    return .textutil(rawValue)
        }
    }
    var menuTitle: String {
        switch self {
        case .odt:  return "OpenDocument Text (.odt)"
        case .rtf:  return "Rich Text (.rtf)"
        case .docx: return "Word (.docx)"
        case .doc:  return "Word 97–2004 (.doc)"
        case .html: return "Web Page (.html)"
        case .txt:  return "Plain Text (.txt)"
        }
    }
}

/// Spreadsheets (category `ods`). Non-ODF targets need LibreOffice.
enum SheetTarget: String, OutputTarget {
    case ods, xlsx, csv
    var fileExtension: String { rawValue }
    var engine: ConversionEngine {
        switch self {
        case .ods:  return .odf
        case .xlsx: return .soffice("xlsx")
        case .csv:  return .soffice("csv")
        }
    }
    var menuTitle: String {
        switch self {
        case .ods:  return "OpenDocument Spreadsheet (.ods)"
        case .xlsx: return "Excel (.xlsx) — needs LibreOffice"
        case .csv:  return "CSV (.csv) — needs LibreOffice"
        }
    }
}

/// Presentations (category `odp`). Non-ODF targets need LibreOffice.
enum PresoTarget: String, OutputTarget {
    case odp, pptx, pdf
    var fileExtension: String { rawValue }
    var engine: ConversionEngine {
        switch self {
        case .odp:  return .odf
        case .pptx: return .soffice("pptx")
        case .pdf:  return .soffice("pdf")
        }
    }
    var menuTitle: String {
        switch self {
        case .odp:  return "OpenDocument Presentation (.odp)"
        case .pptx: return "PowerPoint (.pptx) — needs LibreOffice"
        case .pdf:  return "PDF (.pdf) — needs LibreOffice"
        }
    }
}

/// Drawings (category `odg`). Non-ODF targets need LibreOffice.
enum DrawTarget: String, OutputTarget {
    case odg, pdf, svg, png
    var fileExtension: String { rawValue }
    var engine: ConversionEngine {
        switch self {
        case .odg:  return .odf
        case .pdf:  return .soffice("pdf")
        case .svg:  return .soffice("svg")
        case .png:  return .soffice("png")
        }
    }
    var menuTitle: String {
        switch self {
        case .odg:  return "OpenDocument Drawing (.odg)"
        case .pdf:  return "PDF (.pdf) — needs LibreOffice"
        case .svg:  return "SVG (.svg) — needs LibreOffice"
        case .png:  return "PNG image (.png) — needs LibreOffice"
        }
    }
}

/// User-preferred output targets and input encoding, persisted in UserDefaults.
@MainActor
final class Settings {
    static let shared = Settings()
    private let defaults = UserDefaults.standard

    private enum Key {
        static let doc = "documentTarget"
        static let sheet = "spreadsheetTarget"
        static let preso = "presentationTarget"
        static let draw = "drawingTarget"
        static let encoding = "inputEncoding"
        static let hideLONotice = "hideLibreOfficeNotice"
    }

    /// The wpft2odf `--encoding` value stored by name; empty string means "Automatic"
    /// (pass no flag — wpft2odf's own default, effectively MacRoman for classic Mac files).
    var inputEncoding: String {
        get { defaults.string(forKey: Key.encoding) ?? "" }
        set { defaults.set(newValue, forKey: Key.encoding) }
    }

    /// nil when the encoding is Automatic, otherwise the encoding name to pass.
    var inputEncodingArgument: String? {
        let value = inputEncoding
        return value.isEmpty ? nil : value
    }

    var documentTarget: DocTarget {
        get { DocTarget(rawValue: defaults.string(forKey: Key.doc) ?? "") ?? .odt }
        set { defaults.set(newValue.rawValue, forKey: Key.doc) }
    }
    var spreadsheetTarget: SheetTarget {
        get { SheetTarget(rawValue: defaults.string(forKey: Key.sheet) ?? "") ?? .ods }
        set { defaults.set(newValue.rawValue, forKey: Key.sheet) }
    }
    var presentationTarget: PresoTarget {
        get { PresoTarget(rawValue: defaults.string(forKey: Key.preso) ?? "") ?? .odp }
        set { defaults.set(newValue.rawValue, forKey: Key.preso) }
    }
    var drawingTarget: DrawTarget {
        get { DrawTarget(rawValue: defaults.string(forKey: Key.draw) ?? "") ?? .odg }
        set { defaults.set(newValue.rawValue, forKey: Key.draw) }
    }

    /// Whether the one-time "this format needs LibreOffice" notice has been dismissed.
    var hideLibreOfficeNotice: Bool {
        get { defaults.bool(forKey: Key.hideLONotice) }
        set { defaults.set(newValue, forKey: Key.hideLONotice) }
    }
}
