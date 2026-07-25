//
//  ExportService.swift
//  StoryLoom
//
//  Export is a reproducible publication boundary, not an afterthought (16-Export).
//  It reads a consistent snapshot, never mutates the project, and never leaks
//  internal material: no ids, no intentions, no comments, no story records, no
//  continuity findings. What leaves is the prose, and only the prose.
//
//  Every export is previewed first, with warnings about what will be left out —
//  because discovering that a chapter was silently dropped, after sending the
//  file to an editor, is the kind of failure that ends trust in a tool.
//

import AppKit
import CryptoKit
import Foundation

// MARK: - Formats and profiles

nonisolated enum ExportFormat: String, CaseIterable, Identifiable, Sendable {
    case markdown
    case plainText
    case rtf
    case docx
    case pdf

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .markdown: "Markdown"
        case .plainText: "Plain Text"
        case .rtf: "Rich Text"
        case .docx: "Word (DOCX)"
        case .pdf: "PDF"
        }
    }

    var detail: String {
        switch self {
        case .markdown: "Durable interchange. The source you could rebuild from."
        case .plainText: "Deterministic and plain. For submissions that demand it."
        case .rtf: "Formatted text every word processor can open."
        case .docx: "What an editor will ask you for."
        case .pdf: "Paged, for reading and proofing."
        }
    }

    var fileExtension: String {
        switch self {
        case .markdown: "md"
        case .plainText: "txt"
        case .rtf: "rtf"
        case .docx: "docx"
        case .pdf: "pdf"
        }
    }

    var symbolName: String {
        switch self {
        case .markdown: "chevron.left.forwardslash.chevron.right"
        case .plainText: "doc.plaintext"
        case .rtf: "doc.richtext"
        case .docx: "doc.text"
        case .pdf: "doc.viewfinder"
        }
    }

    /// Formats that carry typography rather than markup.
    var isRich: Bool {
        switch self {
        case .markdown, .plainText: false
        case .rtf, .docx, .pdf: true
        }
    }
}

nonisolated enum SceneSeparator: String, CaseIterable, Identifiable, Sendable {
    case blank
    case asterisks
    case hash

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .blank: "Blank line"
        case .asterisks: "* * *"
        case .hash: "#"
        }
    }

    var mark: String? {
        switch self {
        case .blank: nil
        case .asterisks: "* * *"
        case .hash: "#"
        }
    }
}

/// A profile is the whole of an export's meaning: repeating the same revision
/// with the same profile must produce the same document.
nonisolated struct ExportProfile: Equatable, Sendable {
    var format: ExportFormat = .markdown
    var includesTitlePage = true
    var includesChapterHeadings = true
    var includesSceneTitles = false
    var separator: SceneSeparator = .asterisks
    var includesNotes = false
    /// Outline-status scenes are usually placeholders. Excluding them is the
    /// default, but silently doing so is not — the preview names every omission.
    var excludesOutlines = true

    var proseFace: ProseFace = .newYork
    var proseSize: Double = 12
    var doubleSpaced = false
}

// MARK: - Preview

nonisolated struct ExportPreview: Sendable {
    var includedDocuments: [UUID] = []
    var omissions: [ExportWarning] = []
    var transformations: [ExportWarning] = []
    var wordCount = 0

    var isEmpty: Bool { includedDocuments.isEmpty }
    var hasConcerns: Bool { !omissions.isEmpty || !transformations.isEmpty }
}

nonisolated struct ExportWarning: Identifiable, Hashable, Sendable {
    let id = UUID()
    let title: String
    let detail: String

    nonisolated init(_ title: String, _ detail: String) {
        self.title = title
        self.detail = detail
    }
}

// MARK: - Provenance

/// What was exported, from what, by what rules. Written beside the project so a
/// file found on a hard drive in two years can be explained.
nonisolated struct ExportRecord: Codable, Sendable {
    var id = UUID()
    var exportedAt = Date.stamp
    var projectID: UUID
    var projectTitle: String
    var format: String
    var destination: String
    var documentIDs: [UUID]
    var wordCount: Int
    var checksum: String
    var rendererVersion: String
}

// MARK: - Service

nonisolated enum ExportService {
    static let rendererVersion = "storyloom-export/1"

    // MARK: Selection

    /// The documents an export will actually contain, in manuscript order.
    static func selection(_ project: StoryProject, profile: ExportProfile) -> [StoryDocument] {
        project.documents.filter { document in
            switch document.kind {
            case .note: return profile.includesNotes
            case .scene: return !(profile.excludesOutlines && document.status == .outline)
            }
        }
    }

    static func preview(_ project: StoryProject, profile: ExportProfile) -> ExportPreview {
        let included = selection(project, profile: profile)
        var preview = ExportPreview(
            includedDocuments: included.map(\.id),
            wordCount: included.reduce(0) { $0 + $1.wordCount }
        )

        let excluded = project.documents.filter { document in
            !included.contains { $0.id == document.id }
        }
        for document in excluded {
            let reason = document.kind == .note
                ? "Notes are excluded by this profile."
                : "Status is Outline, and this profile excludes outlines."
            preview.omissions.append(ExportWarning("“\(document.displayTitle)” will not be exported", reason))
        }

        for document in included where document.isEmpty {
            preview.omissions.append(ExportWarning(
                "“\(document.displayTitle)” is empty",
                "It is included but contributes no prose."
            ))
        }

        let openComments = project.story.comments.filter { !$0.isResolved }
        if !openComments.isEmpty {
            preview.transformations.append(ExportWarning(
                "\(openComments.count) comment\(openComments.count == 1 ? "" : "s") excluded",
                "Comments never appear in an export."
            ))
        }

        // Named explicitly, because these are the fields that would actually hurt.
        // A story record reaching a reader is embarrassing; the answer to a mystery
        // reaching them is the book. The author should see this sentence every time.
        let answered = project.story.threads.filter { !$0.answer.isEmpty }
        let withheld = included.filter { !$0.withheld.isEmpty }
        if !answered.isEmpty || !withheld.isEmpty {
            preview.transformations.append(ExportWarning(
                "Nothing you wrote in private is in this file",
                "\(answered.count) thread answer\(answered.count == 1 ? "" : "s") and \(withheld.count) note\(withheld.count == 1 ? "" : "s") on what a scene withholds stay in the project — along with every intention, turn, story record, and finding. What leaves is the prose."
            ))
        }

        if profile.format.isRich {
            preview.transformations.append(ExportWarning(
                "Markdown becomes typography",
                "Emphasis, headings, and scene breaks are rendered. The markers themselves are removed."
            ))
        }

        let unsupported = included.filter { hasUnsupportedConstructs($0.text) }
        if !unsupported.isEmpty, profile.format.isRich {
            preview.transformations.append(ExportWarning(
                "Some Markdown will be flattened",
                "\(unsupported.map(\.displayTitle).joined(separator: ", ")) contain images, tables, or links. They will export as their literal text."
            ))
        }

        return preview
    }

    private static func hasUnsupportedConstructs(_ text: String) -> Bool {
        text.contains("![") || text.contains("](") || text.contains("| ---")
    }

    // MARK: Rendering

    static func render(_ project: StoryProject, profile: ExportProfile) throws -> Data {
        let documents = selection(project, profile: profile)

        switch profile.format {
        case .markdown:
            return Data(markdown(project, documents: documents, profile: profile).utf8)
        case .plainText:
            return Data(plainText(project, documents: documents, profile: profile).utf8)
        case .rtf:
            let attributed = attributed(project, documents: documents, profile: profile)
            guard let data = attributed.rtf(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else { throw ExportError.renderFailed(.rtf) }
            return data
        case .docx:
            let attributed = attributed(project, documents: documents, profile: profile)
            do {
                return try attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
                )
            } catch {
                throw ExportError.renderFailed(.docx)
            }
        case .pdf:
            throw ExportError.usePDFWriter
        }
    }

    /// Writes to `url`. Failed output leaves no partial file: everything is
    /// rendered first and only then handed to the disk (16-Export).
    @MainActor
    static func write(_ project: StoryProject, profile: ExportProfile, to url: URL) throws -> ExportRecord {
        let documents = selection(project, profile: profile)
        let checksum: String

        if profile.format == .pdf {
            let attributed = attributed(project, documents: documents, profile: profile)
            try writePDF(attributed, to: url)
            checksum = (try? Data(contentsOf: url)).map(digest) ?? ""
        } else {
            let data = try render(project, profile: profile)
            try data.write(to: url, options: .atomic)
            checksum = digest(data)
        }

        return ExportRecord(
            projectID: project.id,
            projectTitle: project.title,
            format: profile.format.rawValue,
            destination: url.lastPathComponent,
            documentIDs: documents.map(\.id),
            wordCount: documents.reduce(0) { $0 + $1.wordCount },
            checksum: checksum,
            rendererVersion: rendererVersion
        )
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    // MARK: Markdown and plain text

    private static func markdown(_ project: StoryProject, documents: [StoryDocument], profile: ExportProfile) -> String {
        var lines: [String] = []
        if profile.includesTitlePage {
            lines += ["# \(project.title)", ""]
        }

        var chapter: String?
        for (index, document) in documents.enumerated() {
            if profile.includesChapterHeadings, document.chapterTitle != chapter {
                chapter = document.chapterTitle
                lines += ["## \(document.chapterTitle)", ""]
            } else if index > 0, let mark = profile.separator.mark {
                lines += [mark, ""]
            } else if index > 0 {
                lines.append("")
            }

            if profile.includesSceneTitles {
                lines += ["### \(document.displayTitle)", ""]
            }
            if !document.isEmpty {
                lines += [document.text.trimmingCharacters(in: .whitespacesAndNewlines), ""]
            }
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func plainText(_ project: StoryProject, documents: [StoryDocument], profile: ExportProfile) -> String {
        var lines: [String] = []
        if profile.includesTitlePage {
            lines += [project.title.uppercased(), ""]
        }

        var chapter: String?
        for (index, document) in documents.enumerated() {
            if profile.includesChapterHeadings, document.chapterTitle != chapter {
                chapter = document.chapterTitle
                lines += ["", document.chapterTitle.uppercased(), ""]
            } else if index > 0 {
                lines += ["", profile.separator.mark ?? "", ""]
            }

            if profile.includesSceneTitles {
                lines += [document.displayTitle.uppercased(), ""]
            }
            if !document.isEmpty {
                lines += [stripMarkers(document.text), ""]
            }
        }
        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// Plain text should read as prose, not as source. The markers go; the words stay.
    private static func stripMarkers(_ text: String) -> String {
        var output = text
        for pattern in [("\\*\\*(.+?)\\*\\*", "$1"), ("(?<![*\\w])\\*(?!\\s)(.+?)(?<!\\s)\\*(?![*\\w])", "$1"), ("^#{1,6}[ \t]+", "")] {
            output = output.replacingOccurrences(
                of: pattern.0,
                with: pattern.1,
                options: [.regularExpression],
                range: nil
            )
        }
        return output
    }

    // MARK: Rich text

    static func attributed(_ project: StoryProject, documents: [StoryDocument], profile: ExportProfile) -> NSAttributedString {
        let output = NSMutableAttributedString()

        let body = bodyStyle(profile)
        let bodyFont = profile.proseFace.font(size: profile.proseSize)

        if profile.includesTitlePage {
            let title = NSMutableParagraphStyle()
            title.alignment = .center
            title.paragraphSpacing = profile.proseSize * 3
            output.append(NSAttributedString(string: project.title + "\n", attributes: [
                .font: profile.proseFace.font(size: profile.proseSize * 2, weight: .semibold),
                .paragraphStyle: title
            ]))
        }

        var chapter: String?
        for (index, document) in documents.enumerated() {
            if profile.includesChapterHeadings, document.chapterTitle != chapter {
                chapter = document.chapterTitle
                let heading = NSMutableParagraphStyle()
                heading.paragraphSpacingBefore = profile.proseSize * 2
                heading.paragraphSpacing = profile.proseSize * 1.2
                output.append(NSAttributedString(string: document.chapterTitle + "\n", attributes: [
                    .font: profile.proseFace.font(size: profile.proseSize * 1.5, weight: .semibold),
                    .paragraphStyle: heading
                ]))
            } else if index > 0, let mark = profile.separator.mark {
                let separator = NSMutableParagraphStyle()
                separator.alignment = .center
                separator.paragraphSpacingBefore = profile.proseSize
                separator.paragraphSpacing = profile.proseSize
                output.append(NSAttributedString(string: mark + "\n", attributes: [
                    .font: bodyFont,
                    .paragraphStyle: separator
                ]))
            }

            if profile.includesSceneTitles {
                let sceneTitle = NSMutableParagraphStyle()
                sceneTitle.paragraphSpacingBefore = profile.proseSize
                sceneTitle.paragraphSpacing = profile.proseSize * 0.6
                output.append(NSAttributedString(string: document.displayTitle + "\n", attributes: [
                    .font: profile.proseFace.font(size: profile.proseSize * 1.15, weight: .semibold),
                    .paragraphStyle: sceneTitle
                ]))
            }

            guard !document.isEmpty else { continue }
            output.append(prose(document.text, profile: profile, body: body, bodyFont: bodyFont))
        }
        return output
    }

    private static func bodyStyle(_ profile: ExportProfile) -> NSParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineHeightMultiple = profile.doubleSpaced ? 2.0 : 1.35
        paragraph.firstLineHeadIndent = profile.proseSize * 2
        paragraph.paragraphSpacing = 0
        return paragraph
    }

    /// Renders one scene's Markdown into typography, dropping the markers.
    /// Inline parsing is delegated to Foundation so that emphasis, strong, and
    /// code behave the way every other Markdown reader expects.
    private static func prose(
        _ text: String,
        profile: ExportProfile,
        body: NSParagraphStyle,
        bodyFont: NSFont
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()

        for rawParagraph in text.components(separatedBy: "\n\n") {
            let paragraph = rawParagraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !paragraph.isEmpty else { continue }

            if paragraph.hasPrefix("#") {
                let level = paragraph.prefix { $0 == "#" }.count
                let content = paragraph.dropFirst(level).trimmingCharacters(in: .whitespaces)
                let style = NSMutableParagraphStyle()
                style.paragraphSpacingBefore = profile.proseSize * 1.4
                style.paragraphSpacing = profile.proseSize * 0.6
                output.append(NSAttributedString(string: content + "\n", attributes: [
                    .font: profile.proseFace.font(size: profile.proseSize * (level == 1 ? 1.5 : 1.2), weight: .semibold),
                    .paragraphStyle: style
                ]))
                continue
            }

            if paragraph.range(of: "^(\\*\\s?\\*\\s?\\*|---+)$", options: .regularExpression) != nil {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.paragraphSpacingBefore = profile.proseSize
                style.paragraphSpacing = profile.proseSize
                output.append(NSAttributedString(string: (profile.separator.mark ?? "* * *") + "\n", attributes: [
                    .font: bodyFont,
                    .paragraphStyle: style
                ]))
                continue
            }

            let inline = inlineAttributed(paragraph, font: bodyFont)
            let styled = NSMutableAttributedString(attributedString: inline)
            styled.addAttribute(.paragraphStyle, value: body, range: NSRange(location: 0, length: styled.length))
            styled.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont, .paragraphStyle: body]))
            output.append(styled)
        }
        return output
    }

    private static func inlineAttributed(_ markdown: String, font: NSFont) -> NSAttributedString {
        guard let parsed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return NSAttributedString(string: markdown, attributes: [.font: font])
        }

        let converted = NSMutableAttributedString(parsed)
        let full = NSRange(location: 0, length: converted.length)
        converted.addAttribute(.font, value: font, range: full)

        // Foundation records emphasis as an intent rather than a font; turn those
        // intents into the actual face so Word and PDF show them.
        for run in parsed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let range = NSRange(run.range, in: parsed)
            guard range.location != NSNotFound, range.length > 0 else { continue }

            var traits: NSFontTraitMask = []
            if intent.contains(.stronglyEmphasized) { traits.insert(.boldFontMask) }
            if intent.contains(.emphasized) { traits.insert(.italicFontMask) }
            guard !traits.isEmpty else { continue }

            let styled = NSFontManager.shared.convert(font, toHaveTrait: traits)
            converted.addAttribute(.font, value: styled, range: range)
        }
        return converted
    }

    // MARK: PDF

    @MainActor
    private static func writePDF(_ attributed: NSAttributedString, to url: URL) throws {
        let info = NSPrintInfo()
        info.paperSize = NSSize(width: 612, height: 792)   // US Letter
        info.topMargin = 72
        info.bottomMargin = 72
        info.leftMargin = 72
        info.rightMargin = 72
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        info.jobDisposition = .save
        info.dictionary()[NSPrintInfo.AttributeKey.jobSavingURL] = url as NSURL

        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: info.paperSize.height))
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: width, height: .greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.textStorage?.setAttributedString(attributed)
        textView.sizeToFit()

        let operation = NSPrintOperation(view: textView, printInfo: info)
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false
        guard operation.run() else { throw ExportError.renderFailed(.pdf) }
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case renderFailed(ExportFormat)
    case usePDFWriter

    var errorDescription: String? {
        switch self {
        case .renderFailed(let format):
            "The \(format.title) export could not be produced. No file was written."
        case .usePDFWriter:
            "PDF must be written to a destination rather than rendered in memory."
        }
    }
}
