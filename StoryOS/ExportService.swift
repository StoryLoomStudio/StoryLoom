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
import SwiftUI
import UniformTypeIdentifiers

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

    var contentType: UTType {
        switch self {
        case .markdown: UTType(filenameExtension: "md") ?? .plainText
        case .plainText: .plainText
        case .rtf: .rtf
        case .docx: UTType(filenameExtension: "docx") ?? .data
        case .pdf: .pdf
        }
    }

    var glyph: Glyph {
        switch self {
        case .markdown: .markdownFile
        case .plainText: .plainTextFile
        case .rtf: .richTextFile
        case .docx: .wordFile
        case .pdf: .pdfFile
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
    var scope: ExportScope = .entireManuscript
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

    var pageSize: PageSize = .letter
    var chapterOnNewPage = false
    var includesPageNumbers = true
}

nonisolated enum ExportScope: String, CaseIterable, Identifiable, Sendable {
    case entireManuscript
    case currentChapter
    case selectedScene

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .entireManuscript: "Entire Manuscript"
        case .currentChapter: "Current Chapter"
        case .selectedScene: "Selected Scene"
        }
    }

    var detail: String {
        switch self {
        case .entireManuscript: "Export all manuscript scenes in binder order."
        case .currentChapter: "Export only scenes belonging to the current chapter."
        case .selectedScene: "Export only the active or selected scene."
        }
    }
}

nonisolated enum PageSize: String, CaseIterable, Identifiable, Sendable {
    case letter
    case a4

    nonisolated var id: String { rawValue }

    var title: String {
        switch self {
        case .letter: "US Letter (8.5 × 11 in)"
        case .a4: "A4 (210 × 297 mm)"
        }
    }

    var shortTitle: String {
        switch self {
        case .letter: "US Letter"
        case .a4: "A4"
        }
    }

    var size: CGSize {
        switch self {
        case .letter: CGSize(width: 612, height: 792)
        case .a4: CGSize(width: 595.28, height: 841.89)
        }
    }
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
    static func selection(
        _ project: StoryProject,
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil
    ) -> [StoryDocument] {
        var orderedProject = project
        orderedProject.applyBinderOrder()
        let baseDocuments = orderedProject.documents.filter { document in
            switch document.kind {
            case .note: return profile.includesNotes
            case .scene: return !(profile.excludesOutlines && document.status == .outline)
            }
        }

        switch profile.scope {
        case .entireManuscript:
            return baseDocuments

        case .currentChapter:
            let targetID = selectedDocumentID ?? baseDocuments.first?.id
            guard let targetID,
                  let targetDoc = orderedProject.documents.first(where: { $0.id == targetID }),
                  let chapter = chapterTitle(for: targetDoc, in: orderedProject) else {
                return baseDocuments
            }
            let chapterDocs = baseDocuments.filter { doc in
                chapterTitle(for: doc, in: orderedProject) == chapter
            }
            return chapterDocs.isEmpty ? baseDocuments : chapterDocs

        case .selectedScene:
            let targetID = selectedDocumentID ?? baseDocuments.first?.id
            if let targetID, let match = baseDocuments.first(where: { $0.id == targetID }) {
                return [match]
            }
            if let first = baseDocuments.first {
                return [first]
            }
            return []
        }
    }

    /// Determines the resolved chapter heading for a document in the project,
    /// preferring binder folder structure over the legacy flat attribute.
    /// Returns nil if the scene has no assigned chapter ("Unassigned" is never emitted).
    static func chapterTitle(for document: StoryDocument, in project: StoryProject) -> String? {
        if let parentID = project.binder.location(of: document.id)?.parent,
           let folder = project.binder.find(parentID) {
            let name = folder.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty && name.lowercased() != "unassigned" {
                return name
            }
        }
        let trimmed = document.chapter.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && trimmed.lowercased() != "unassigned" {
            return trimmed
        }
        return nil
    }

    static func preview(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil
    ) -> ExportPreview {
        let included = selection(project, profile: profile, selectedDocumentID: selectedDocumentID)
        var preview = ExportPreview(
            includedDocuments: included.map(\.id),
            wordCount: included.reduce(0) { $0 + $1.wordCount }
        )

        let excluded = project.documents.filter { document in
            !included.contains { $0.id == document.id }
        }
        for document in excluded {
            let reason: String
            if profile.scope == .selectedScene {
                reason = "Scope is limited to the selected scene."
            } else if profile.scope == .currentChapter {
                reason = "Scene belongs to a different chapter."
            } else if document.kind == .note {
                reason = "Notes are excluded by this profile."
            } else {
                reason = "Status is Outline, and this profile excludes outlines."
            }
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
                "Emphasis, headings, quotes, lists, and scene breaks are rendered. The markers themselves are removed."
            ))
        }

        let styledDocuments = included.filter { presentation[$0.id]?.isEmpty == false }
        if !styledDocuments.isEmpty, !profile.format.isRich {
            preview.transformations.append(ExportWarning(
                "Rich appearance stays in StoryLoom",
                "\(styledDocuments.count) scene\(styledDocuments.count == 1 ? " has" : "s have") underline, alignment, highlight, face, or size styling that \(profile.format.title) cannot carry. The prose is still exported."
            ))
        }

        let unsupported = included.filter { hasLiteralRichConstructs($0.text) }
        if !unsupported.isEmpty, profile.format.isRich {
            preview.transformations.append(ExportWarning(
                "Some source constructs stay literal",
                "\(unsupported.map(\.displayTitle).joined(separator: ", ")) contain images, tables, code blocks, or formulas. Their text is preserved rather than converted into a visual object."
            ))
        }

        return preview
    }

    private static func hasLiteralRichConstructs(_ text: String) -> Bool {
        text.contains("![")
            || text.contains("| ---")
            || text.contains("|---")
            || text.contains("|:---")
            || text.contains("| :---")
            || text.contains("```")
            || text.contains("~~~")
            || text.contains("$$")
    }

    // MARK: Rendering

    static func render(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil
    ) throws -> Data {
        let documents = selection(project, profile: profile, selectedDocumentID: selectedDocumentID)

        switch profile.format {
        case .markdown:
            return Data(markdown(project, documents: documents, profile: profile).utf8)
        case .plainText:
            return Data(plainText(project, documents: documents, profile: profile).utf8)
        case .rtf:
            let attributed = attributed(
                project,
                documents: documents,
                presentation: presentation,
                profile: profile
            )
            guard let data = attributed.rtf(
                from: NSRange(location: 0, length: attributed.length),
                documentAttributes: [.documentType: NSAttributedString.DocumentType.rtf]
            ) else { throw ExportError.renderFailed(.rtf) }
            return data
        case .docx:
            let attributed = attributed(
                project,
                documents: documents,
                presentation: presentation,
                profile: profile
            )
            do {
                return try attributed.data(
                    from: NSRange(location: 0, length: attributed.length),
                    documentAttributes: [.documentType: NSAttributedString.DocumentType.officeOpenXML]
                )
            } catch {
                throw ExportError.renderFailed(.docx)
            }
        case .pdf:
            let attributed = attributed(
                project,
                documents: documents,
                presentation: presentation,
                profile: profile
            )
            if Thread.isMainThread {
                return try MainActor.assumeIsolated {
                    try renderPDF(attributed, profile: profile, projectTitle: project.title)
                }
            } else {
                return try DispatchQueue.main.sync {
                    try MainActor.assumeIsolated {
                        try renderPDF(attributed, profile: profile, projectTitle: project.title)
                    }
                }
            }
        }
    }

    /// Generates preview text for the current export profile and scope.
    static func previewText(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil
    ) -> String {
        let documents = selection(project, profile: profile, selectedDocumentID: selectedDocumentID)
        switch profile.format {
        case .markdown:
            return markdown(project, documents: documents, profile: profile)
        case .plainText:
            return plainText(project, documents: documents, profile: profile)
        case .rtf, .docx, .pdf:
            return attributed(project, documents: documents, presentation: presentation, profile: profile).string
        }
    }

    /// Generates attributed text for rich preview in the export panel.
    static func previewAttributed(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil
    ) -> NSAttributedString {
        let documents = selection(project, profile: profile, selectedDocumentID: selectedDocumentID)
        return attributed(project, documents: documents, presentation: presentation, profile: profile)
    }

    /// Writes to `url`. Failed output leaves no partial file: everything is
    /// rendered first and only then handed to the disk (16-Export).
    @MainActor
    static func write(
        _ project: StoryProject,
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile,
        selectedDocumentID: UUID? = nil,
        to url: URL
    ) throws -> ExportRecord {
        let documents = selection(project, profile: profile, selectedDocumentID: selectedDocumentID)
        let data = try render(project, presentation: presentation, profile: profile, selectedDocumentID: selectedDocumentID)
        try data.write(to: url, options: .atomic)
        let checksum = digest(data)

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

        var currentChapter: String?
        var pendingSeparator = false

        for document in documents {
            let docChapter = chapterTitle(for: document, in: project)
            let isNewChapter = profile.includesChapterHeadings && docChapter != nil && docChapter != currentChapter
            if isNewChapter {
                currentChapter = docChapter
                pendingSeparator = false
                lines += ["## \(docChapter!)", ""]
            }

            let hasSceneTitle = profile.includesSceneTitles
            let hasProse = !document.isEmpty
            guard hasSceneTitle || hasProse else { continue }

            if pendingSeparator {
                if let mark = profile.separator.mark {
                    lines += [mark, ""]
                } else {
                    lines.append("")
                }
                pendingSeparator = false
            }

            if hasSceneTitle {
                lines += ["### \(document.displayTitle)", ""]
            }
            if hasProse {
                lines += [document.text.trimmingCharacters(in: .whitespacesAndNewlines), ""]
            }
            pendingSeparator = true
        }
        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    private static func plainText(_ project: StoryProject, documents: [StoryDocument], profile: ExportProfile) -> String {
        var lines: [String] = []
        if profile.includesTitlePage {
            lines += [project.title.uppercased(), ""]
        }

        var currentChapter: String?
        var pendingSeparator = false

        for document in documents {
            let docChapter = chapterTitle(for: document, in: project)
            let isNewChapter = profile.includesChapterHeadings && docChapter != nil && docChapter != currentChapter
            if isNewChapter {
                currentChapter = docChapter
                pendingSeparator = false
                lines += ["", docChapter!.uppercased(), ""]
            }

            let hasSceneTitle = profile.includesSceneTitles
            let hasProse = !document.isEmpty
            guard hasSceneTitle || hasProse else { continue }

            if pendingSeparator {
                if let mark = profile.separator.mark {
                    lines += ["", mark, ""]
                } else {
                    lines.append("")
                }
                pendingSeparator = false
            }

            if hasSceneTitle {
                lines += [document.displayTitle.uppercased(), ""]
            }
            if hasProse {
                lines += [stripMarkers(document.text), ""]
            }
            pendingSeparator = true
        }
        return lines.joined(separator: "\n")
            .replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines) + "\n"
    }

    /// Plain text should read as prose, not as source. The markers go; the words stay.
    private static func stripMarkers(_ text: String) -> String {
        var output = text
        let replacements = [
            ("!\\[([^]]*)\\]\\([^)]+\\)", "$1"),
            ("\\[([^]]+)\\]\\([^)]+\\)", "$1"),
            ("\\*\\*(.+?)\\*\\*", "$1"),
            ("__([^_]+)__", "$1"),
            ("(?<![*\\w])\\*([^*\\s](?:[^*]*?[^*\\s])?)\\*(?![*\\w])", "$1"),
            ("(?<![\\w_])_([^_\\s](?:[^_]*?[^_\\s])?)_(?![\\w_])", "$1"),
            ("~~([^~\\s](?:[\\s\\S]*?[^~\\s])?)~~", "$1"),
            ("==([^=\\s](?:[\\s\\S]*?[^=\\s])?)==", "$1"),
            ("`([^`]+)`", "$1"),
            ("(?m)^[ \\t]{0,3}#{1,6}[ \\t]+", ""),
            ("(?m)^[ \\t]{0,3}>[ \\t]?", ""),
            ("(?m)^([ \\t]*(?:[-+*]|\\d+[.)])[ \\t]+)\\[[ xX]\\][ \\t]+", "$1"),
            ("(?m)^[ \\t]*[-+*][ \\t]+(?![*+\\-\\s])", "")
        ]
        for pattern in replacements {
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

    static func attributed(
        _ project: StoryProject,
        documents: [StoryDocument],
        presentation: [UUID: PresentationLayer] = [:],
        profile: ExportProfile
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()

        let body = bodyStyle(profile)
        let bodyFont = profile.proseFace.font(size: profile.proseSize)

        if profile.includesTitlePage {
            let title = NSMutableParagraphStyle()
            title.alignment = .center
            title.paragraphSpacing = profile.proseSize * 3
            output.append(NSAttributedString(string: project.title + "\n", attributes: [
                .font: profile.proseFace.font(size: profile.proseSize * 2, weight: .semibold),
                .foregroundColor: NSColor.black,
                .paragraphStyle: title
            ]))
            if profile.chapterOnNewPage {
                output.append(NSAttributedString(string: "\u{000C}"))
            }
        }

        var currentChapter: String?
        var pendingSeparator = false

        for document in documents {
            let docChapter = chapterTitle(for: document, in: project)
            let isNewChapter = profile.includesChapterHeadings && docChapter != nil && docChapter != currentChapter
            if isNewChapter {
                if profile.chapterOnNewPage && output.length > 0 && !output.string.hasSuffix("\u{000C}") {
                    output.append(NSAttributedString(string: "\u{000C}"))
                }
                currentChapter = docChapter
                pendingSeparator = false
                let heading = NSMutableParagraphStyle()
                heading.paragraphSpacingBefore = profile.proseSize * 2
                heading.paragraphSpacing = profile.proseSize * 1.2
                output.append(NSAttributedString(string: docChapter! + "\n", attributes: [
                    .font: profile.proseFace.font(size: profile.proseSize * 1.5, weight: .semibold),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: heading
                ]))
            }

            let hasSceneTitle = profile.includesSceneTitles
            let hasProse = !document.isEmpty
            guard hasSceneTitle || hasProse else { continue }

            if pendingSeparator {
                if let mark = profile.separator.mark {
                    let separator = NSMutableParagraphStyle()
                    separator.alignment = .center
                    separator.paragraphSpacingBefore = profile.proseSize
                    separator.paragraphSpacing = profile.proseSize
                    output.append(NSAttributedString(string: mark + "\n", attributes: [
                        .font: bodyFont,
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: separator
                    ]))
                }
                pendingSeparator = false
            }

            if hasSceneTitle {
                let sceneTitle = NSMutableParagraphStyle()
                sceneTitle.paragraphSpacingBefore = profile.proseSize
                sceneTitle.paragraphSpacing = profile.proseSize * 0.6
                output.append(NSAttributedString(string: document.displayTitle + "\n", attributes: [
                    .font: profile.proseFace.font(size: profile.proseSize * 1.15, weight: .semibold),
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: sceneTitle
                ]))
            }

            if hasProse {
                let rendered = NSMutableAttributedString(attributedString: prose(
                    document.text,
                    profile: profile,
                    body: body,
                    bodyFont: bodyFont
                ))
                apply(
                    presentation: presentation[document.id] ?? PresentationLayer(),
                    source: document.text,
                    to: rendered
                )
                output.append(rendered)
            }
            pendingSeparator = true
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

    /// Renders one scene's Markdown into typography, dropping the markers while
    /// retaining block structure. Inline parsing is delegated to Foundation so
    /// emphasis, strong, links, and code behave like other Markdown readers.
    private static func prose(
        _ text: String,
        profile: ExportProfile,
        body: NSParagraphStyle,
        bodyFont: NSFont
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()

        let source = text as NSString
        for block in DocumentAST.parse(text, registry: .manuscript) {
            switch block {
            case .blank:
                continue

            case .paragraph(let range, _):
                appendInline(source.substring(with: range), to: output, font: bodyFont, style: body)

            case .heading(let level, let range, _, _):
                let raw = source.substring(with: range)
                let content = raw.replacingOccurrences(
                    of: "^[ \\t]{0,3}#{1,6}[ \\t]+",
                    with: "",
                    options: .regularExpression
                ).trimmingCharacters(in: .whitespacesAndNewlines)
                let style = NSMutableParagraphStyle()
                style.paragraphSpacingBefore = profile.proseSize * 1.4
                style.paragraphSpacing = profile.proseSize * 0.6
                appendInline(
                    content,
                    to: output,
                    font: profile.proseFace.font(
                        size: profile.proseSize * (level == 1 ? 1.5 : 1.2),
                        weight: .semibold
                    ),
                    style: style
                )

            case .blockquote(let range, _):
                let quote = source.substring(with: range)
                    .components(separatedBy: .newlines)
                    .map {
                        $0.replacingOccurrences(
                            of: "^[ \\t]{0,3}>[ \\t]?",
                            with: "",
                            options: .regularExpression
                        )
                    }
                    .joined(separator: "\n")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                let style = body.mutableCopy() as! NSMutableParagraphStyle
                style.firstLineHeadIndent = profile.proseSize * 2
                style.headIndent = profile.proseSize * 2
                style.tailIndent = -profile.proseSize * 2
                style.paragraphSpacingBefore = profile.proseSize * 0.5
                style.paragraphSpacing = profile.proseSize * 0.5
                appendInline(
                    quote,
                    to: output,
                    font: NSFontManager.shared.convert(bodyFont, toHaveTrait: .italicFontMask),
                    style: style
                )

            case .list(_, let items):
                for item in items {
                    let content = source.substring(with: item.contentRange)
                    let marker: String
                    if item.checkbox != nil {
                        marker = item.checked ? "☑" : "☐"
                    } else if item.ordered {
                        marker = "\(item.number ?? 1)."
                    } else {
                        marker = "•"
                    }
                    let depth = CGFloat(min(item.indent, 8))
                    let step = CGFloat(profile.proseSize * 1.5)
                    let style = body.mutableCopy() as! NSMutableParagraphStyle
                    style.firstLineHeadIndent = step * depth
                    style.headIndent = step * depth + step
                    style.paragraphSpacing = 0

                    let line = NSMutableAttributedString(string: marker + "\t", attributes: [
                        .font: bodyFont,
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: style
                    ])
                    line.append(inlineAttributed(content, font: bodyFont))
                    line.addAttributes([
                        .paragraphStyle: style,
                        .foregroundColor: NSColor.black
                    ], range: NSRange(location: 0, length: line.length))
                    line.append(NSAttributedString(string: "\n", attributes: [
                        .font: bodyFont,
                        .foregroundColor: NSColor.black,
                        .paragraphStyle: style
                    ]))
                    output.append(line)
                }

            case .thematicBreak:
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                style.paragraphSpacingBefore = profile.proseSize
                style.paragraphSpacing = profile.proseSize
                output.append(NSAttributedString(string: (profile.separator.mark ?? "* * *") + "\n", attributes: [
                    .font: bodyFont,
                    .foregroundColor: NSColor.black,
                    .paragraphStyle: style
                ]))

            case .codeBlock(let range):
                var lines = source.substring(with: range).components(separatedBy: .newlines)
                if lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true
                    || lines.first?.trimmingCharacters(in: .whitespaces).hasPrefix("~~~") == true {
                    lines.removeFirst()
                }
                if lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("```") == true
                    || lines.last?.trimmingCharacters(in: .whitespaces).hasPrefix("~~~") == true {
                    lines.removeLast()
                }
                appendLiteral(lines.joined(separator: "\n"), to: output, profile: profile)

            case .table(let range), .blockLatex(let range):
                appendLiteral(source.substring(with: range), to: output, profile: profile)

            case .ext(let node):
                appendLiteral(source.substring(with: node.contentRange), to: output, profile: profile)
            }
        }
        return output
    }

    private static func appendInline(
        _ source: String,
        to output: NSMutableAttributedString,
        font: NSFont,
        style: NSParagraphStyle
    ) {
        let content = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let rendered = NSMutableAttributedString(attributedString: inlineAttributed(content, font: font))
        rendered.addAttributes([
            .paragraphStyle: style,
            .foregroundColor: NSColor.black
        ], range: NSRange(location: 0, length: rendered.length))
        rendered.append(NSAttributedString(string: "\n", attributes: [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: style
        ]))
        output.append(rendered)
    }

    private static func appendLiteral(
        _ source: String,
        to output: NSMutableAttributedString,
        profile: ExportProfile
    ) {
        let content = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        let style = NSMutableParagraphStyle()
        style.lineHeightMultiple = profile.doubleSpaced ? 2.0 : 1.2
        style.paragraphSpacingBefore = profile.proseSize * 0.5
        style.paragraphSpacing = profile.proseSize * 0.5
        let font = NSFont.monospacedSystemFont(ofSize: profile.proseSize * 0.9, weight: .regular)
        output.append(NSAttributedString(string: content + "\n", attributes: [
            .font: font,
            .foregroundColor: NSColor.black,
            .paragraphStyle: style
        ]))
    }

    private static func inlineAttributed(_ markdown: String, font: NSFont) -> NSAttributedString {
        guard let parsed = try? AttributedString(
            markdown: markdown,
            options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        ) else {
            return NSAttributedString(string: markdown, attributes: [
                .font: font,
                .foregroundColor: NSColor.black
            ])
        }

        let converted = NSMutableAttributedString(parsed)
        let full = NSRange(location: 0, length: converted.length)
        converted.addAttributes([
            .font: font,
            .foregroundColor: NSColor.black
        ], range: full)

        // Foundation records emphasis as an intent rather than a font; turn those
        // intents into the actual face so Word and PDF show them.
        for run in parsed.runs {
            guard let intent = run.inlinePresentationIntent else { continue }
            let range = NSRange(run.range, in: parsed)
            guard range.location != NSNotFound, range.length > 0 else { continue }

            var traits: NSFontTraitMask = []
            if intent.contains(.stronglyEmphasized) { traits.insert(.boldFontMask) }
            if intent.contains(.emphasized) { traits.insert(.italicFontMask) }
            if !traits.isEmpty {
                let styled = NSFontManager.shared.convert(font, toHaveTrait: traits)
                converted.addAttribute(.font, value: styled, range: range)
            }
            if intent.contains(.strikethrough) {
                converted.addAttributes([
                    .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                    .strikethroughColor: NSColor(white: 0.35, alpha: 1.0)
                ], range: range)
            }
            if intent.contains(.code) {
                converted.addAttribute(
                    .font,
                    value: NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.92, weight: .regular),
                    range: range
                )
            }
        }

        applyDelimitedMarkup(
            "==",
            attributes: [.backgroundColor: NSColor(hex: 0xF2C14E).withAlphaComponent(0.38)],
            to: converted
        )
        applyDelimitedMarkup(
            "~~",
            attributes: [
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
                .strikethroughColor: NSColor(white: 0.35, alpha: 1.0)
            ],
            to: converted
        )
        return converted
    }

    /// Foundation intentionally implements CommonMark, while StoryLoom also
    /// supports the two broadly-used extensions authors can type in the editor.
    private static func applyDelimitedMarkup(
        _ delimiter: String,
        attributes: [NSAttributedString.Key: Any],
        to text: NSMutableAttributedString
    ) {
        let escaped = NSRegularExpression.escapedPattern(for: delimiter)
        guard let expression = try? NSRegularExpression(
            pattern: "\(escaped)([^\\s\(escaped)](?:[\\s\\S]*?[^\\s\(escaped)])?)\(escaped)"
        ) else { return }

        while true {
            let full = NSRange(location: 0, length: text.length)
            guard let match = expression.firstMatch(in: text.string, range: full), match.numberOfRanges == 2 else {
                return
            }
            let content = match.range(at: 1)
            text.addAttributes(attributes, range: content)
            let close = NSRange(location: NSMaxRange(content), length: delimiter.utf16.count)
            text.deleteCharacters(in: close)
            text.deleteCharacters(in: NSRange(location: match.range.location, length: delimiter.utf16.count))
        }
    }

    /// Applies appearance that is intentionally stored outside Markdown. Anchors
    /// are resolved against the rendered prose so removing source markers cannot
    /// shift a highlight onto the wrong words.
    private static func apply(
        presentation: PresentationLayer,
        source: String,
        to output: NSMutableAttributedString
    ) {
        guard !presentation.isEmpty, output.length > 0 else { return }

        for block in presentation.blocks {
            guard let resolved = resolve(block.anchor, source: source, rendered: output.string) else { continue }
            let paragraph = (output.string as NSString).paragraphRange(for: resolved.clamped(to: output.length))
            output.enumerateAttribute(.paragraphStyle, in: paragraph) { value, range, _ in
                let style = ((value as? NSParagraphStyle)?.mutableCopy() as? NSMutableParagraphStyle)
                    ?? NSMutableParagraphStyle()
                style.alignment = block.alignment.nsAlignment
                if block.alignment != .natural && block.alignment != .justified {
                    style.firstLineHeadIndent = 0
                }
                output.addAttribute(.paragraphStyle, value: style, range: range)
            }
        }

        for run in presentation.runs {
            guard let resolved = resolve(run.anchor, source: source, rendered: output.string) else { continue }
            let target = resolved.clamped(to: output.length)
            guard target.length > 0 else { continue }

            if run.underline {
                output.addAttributes([
                    .underlineStyle: NSUnderlineStyle.single.rawValue,
                    .underlineColor: NSColor.black.withAlphaComponent(0.6)
                ], range: target)
            }
            if let highlight = run.highlight {
                output.addAttribute(.backgroundColor, value: highlight.wash(for: .light), range: target)
            }
            if run.fontName != nil || run.fontSize != nil {
                output.enumerateAttribute(.font, in: target) { value, range, _ in
                    let current = (value as? NSFont) ?? NSFont.systemFont(ofSize: 12)
                    let size = run.fontSize.map { CGFloat($0) } ?? current.pointSize
                    let traits = NSFontManager.shared.traits(of: current)
                    let resized: NSFont
                    if let name = run.fontName, let named = NSFont(name: name, size: size) {
                        resized = NSFontManager.shared.convert(named, toHaveTrait: traits)
                    } else {
                        resized = NSFontManager.shared.convert(current, toSize: size)
                    }
                    output.addAttribute(.font, value: resized, range: range)
                }
            }
        }
    }

    private static func resolve(_ anchor: TextAnchor, source: String, rendered: String) -> NSRange? {
        if let exact = anchor.resolve(in: rendered) { return exact }

        let plain = TextAnchor(
            quote: stripMarkers(anchor.quote).trimmingCharacters(in: .whitespacesAndNewlines),
            prefix: stripMarkers(anchor.prefix),
            suffix: stripMarkers(anchor.suffix),
            offsetHint: min(anchor.offsetHint, (rendered as NSString).length)
        )
        if let resolved = plain.resolve(in: rendered) { return resolved }

        // A paragraph-alignment anchor commonly includes the Markdown marker at
        // its beginning. Resolve against the corresponding source slice as a
        // final conservative fallback, never by raw offset alone.
        if let sourceRange = anchor.resolve(in: source) {
            let fragment = (source as NSString).substring(with: sourceRange)
            let readable = stripMarkers(fragment).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !readable.isEmpty else { return nil }
            let candidateAnchor = TextAnchor(
                quote: readable,
                prefix: "",
                suffix: "",
                offsetHint: min(sourceRange.location, (rendered as NSString).length)
            )
            return candidateAnchor.resolve(in: rendered)
        }
        return nil
    }

    // MARK: PDF

    /// Renders publication-grade PDF data directly in memory via CoreGraphics
    /// and NSLayoutManager pagination, bypassing CUPS/NSPrintOperation spooler delays.
    @MainActor
    static func renderPDF(
        _ attributed: NSAttributedString,
        profile: ExportProfile = ExportProfile(),
        projectTitle: String = ""
    ) throws -> Data {
        let pdfData = NSMutableData()
        guard let consumer = CGDataConsumer(data: pdfData as CFMutableData) else {
            throw ExportError.renderFailed(.pdf)
        }
        var mediaBox = CGRect(origin: .zero, size: profile.pageSize.size)
        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else {
            throw ExportError.renderFailed(.pdf)
        }

        let margin: CGFloat = 72
        let pageWidth = profile.pageSize.size.width
        let pageHeight = profile.pageSize.size.height
        let contentWidth = max(100, pageWidth - (margin * 2))
        let contentHeight = max(100, pageHeight - (margin * 2))

        let textStorage = NSTextStorage(attributedString: attributed)
        let layoutManager = NSLayoutManager()
        textStorage.addLayoutManager(layoutManager)

        var containers: [NSTextContainer] = []
        var lastGlyph = 0

        while lastGlyph < layoutManager.numberOfGlyphs {
            let container = NSTextContainer(size: CGSize(width: contentWidth, height: contentHeight))
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
            let range = layoutManager.glyphRange(for: container)
            if range.length == 0 { break }
            lastGlyph = NSMaxRange(range)
        }

        if containers.isEmpty {
            let container = NSTextContainer(size: CGSize(width: contentWidth, height: contentHeight))
            container.lineFragmentPadding = 0
            layoutManager.addTextContainer(container)
            containers.append(container)
        }

        let totalPages = containers.count
        let headerFont = NSFont.systemFont(ofSize: 9, weight: .regular)
        let headerColor = NSColor(white: 0.45, alpha: 1.0)
        let pageNumberFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .regular)

        for (index, container) in containers.enumerated() {
            let pageNumber = index + 1
            context.beginPDFPage(nil)

            let nsContext = NSGraphicsContext(cgContext: context, flipped: false)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = nsContext

            // 1. Running header (omitted on title page if title page is present)
            let showHeader = (index > 0 || !profile.includesTitlePage) && !projectTitle.isEmpty
            if showHeader {
                let headerParagraph = NSMutableParagraphStyle()
                headerParagraph.alignment = .center
                let headerAttr: [NSAttributedString.Key: Any] = [
                    .font: headerFont,
                    .foregroundColor: headerColor,
                    .paragraphStyle: headerParagraph
                ]
                let headerRect = CGRect(x: margin, y: pageHeight - margin + 14, width: contentWidth, height: 18)
                (projectTitle as NSString).draw(in: headerRect, withAttributes: headerAttr)
            }

            // 2. Page number footer
            if profile.includesPageNumbers {
                let showPageNumber = !(index == 0 && profile.includesTitlePage && totalPages > 1)
                if showPageNumber {
                    let footerParagraph = NSMutableParagraphStyle()
                    footerParagraph.alignment = .center
                    let footerAttr: [NSAttributedString.Key: Any] = [
                        .font: pageNumberFont,
                        .foregroundColor: headerColor,
                        .paragraphStyle: footerParagraph
                    ]
                    let footerRect = CGRect(x: margin, y: margin - 32, width: contentWidth, height: 18)
                    ("\(pageNumber)" as NSString).draw(in: footerRect, withAttributes: footerAttr)
                }
            }

            // 3. Body text
            context.saveGState()
            context.translateBy(x: margin, y: pageHeight - margin)
            context.scaleBy(x: 1.0, y: -1.0)

            let glyphRange = layoutManager.glyphRange(for: container)
            if glyphRange.length > 0 {
                layoutManager.drawBackground(forGlyphRange: glyphRange, at: .zero)
                layoutManager.drawGlyphs(forGlyphRange: glyphRange, at: .zero)
            }

            context.restoreGState()

            NSGraphicsContext.restoreGraphicsState()
            context.endPDFPage()
        }

        context.closePDF()
        return pdfData as Data
    }

    @MainActor
    static func writePDF(
        _ attributed: NSAttributedString,
        profile: ExportProfile = ExportProfile(),
        projectTitle: String = "",
        to url: URL
    ) throws {
        let parentDir = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        let data = try renderPDF(attributed, profile: profile, projectTitle: projectTitle)
        try data.write(to: url, options: .atomic)
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
