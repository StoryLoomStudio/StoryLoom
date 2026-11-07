import Foundation
import AppKit
import PDFKit
import Testing
@testable import StoryLoom

@Suite("Export service tests", .serialized)
struct ExportServiceTests {
    @Test("Markdown export formatting and chapter handling")
    func markdownExport() {
        let doc1 = StoryDocument(
            title: "Scene 1",
            chapter: "Chapter One",
            kind: .scene,
            text: "First scene prose."
        )
        let doc2 = StoryDocument(
            title: "Scene 2",
            chapter: "Chapter One",
            kind: .scene,
            text: "Second scene prose."
        )
        let project = StoryProject(title: "Test Novel", documents: [doc1, doc2])
        var profile = ExportProfile()
        profile.format = .markdown
        profile.includesTitlePage = true
        profile.includesChapterHeadings = true
        profile.includesSceneTitles = false
        profile.separator = .asterisks

        let data = try! ExportService.render(project, profile: profile)
        let text = String(data: data, encoding: .utf8)!
        #expect(text.contains("# Test Novel"))
        #expect(text.contains("## Chapter One"))
        #expect(text.contains("* * *"))
        #expect(text.contains("First scene prose."))
        #expect(text.contains("Second scene prose."))
    }

    @Test("Unassigned chapter is not printed as heading")
    func unassignedChapterNotPrinted() {
        let doc1 = StoryDocument(
            title: "Scene 1",
            chapter: "",
            kind: .scene,
            text: "Only scene."
        )
        let project = StoryProject(title: "Short Story", documents: [doc1])
        var profile = ExportProfile()
        profile.format = .markdown
        profile.includesChapterHeadings = true

        let data = try! ExportService.render(project, profile: profile)
        let text = String(data: data, encoding: .utf8)!
        #expect(!text.contains("## Unassigned"))
        #expect(!text.contains("Unassigned"))
    }

    @Test("Empty document between scenes does not produce double scene breaks")
    func emptyDocumentSeparators() {
        let doc1 = StoryDocument(title: "S1", chapter: "Ch", kind: .scene, text: "Scene one.")
        let doc2 = StoryDocument(title: "S2", chapter: "Ch", kind: .scene, text: "   \n\n  ")
        let doc3 = StoryDocument(title: "S3", chapter: "Ch", kind: .scene, text: "Scene three.")
        let project = StoryProject(title: "Test", documents: [doc1, doc2, doc3])
        var profile = ExportProfile()
        profile.format = .markdown
        profile.includesTitlePage = false
        profile.includesChapterHeadings = false
        profile.includesSceneTitles = false
        profile.separator = .asterisks

        let data = try! ExportService.render(project, profile: profile)
        let text = String(data: data, encoding: .utf8)!
        #expect(!text.contains("* * *\n\n* * *"))
        #expect(!text.contains("* * *\n* * *"))
    }

    @Test("Plain text strips markers without corrupting scene breaks or numbers")
    func plainTextMarkerStripping() {
        let markdown = """
        # Chapter Title

        1. First item
        2. Second item

        * * *

        _Italic whisper_ and __bold shout__.
        """
        let doc = StoryDocument(title: "Scene", chapter: "", kind: .scene, text: markdown)
        let project = StoryProject(title: "Book", documents: [doc])
        var profile = ExportProfile()
        profile.format = .plainText
        profile.includesTitlePage = false
        profile.includesChapterHeadings = false
        profile.includesSceneTitles = false

        let data = try! ExportService.render(project, profile: profile)
        let text = String(data: data, encoding: .utf8)!
        // Should not corrupt thematic break into `* *`
        #expect(!text.contains("\n* *\n"))
        // Underscores should be stripped in plain text
        #expect(!text.contains("_Italic whisper_"))
        #expect(!text.contains("__bold shout__"))
        #expect(text.contains("Italic whisper"))
        #expect(text.contains("bold shout"))
    }

    @Test("Delimited markup handles multiline and does not match equations")
    func delimitedMarkupMultilineAndEquations() {
        let text = """
        Here is ==multiline
        highlight== text.

        The test if a == b && c == d should stay intact.
        """
        let doc = StoryDocument(title: "Scene", chapter: "Ch", kind: .scene, text: text)
        let project = StoryProject(title: "Test", documents: [doc])
        var profile = ExportProfile()
        profile.format = .rtf
        profile.includesTitlePage = false
        profile.includesChapterHeadings = false

        let rendered = ExportService.attributed(project, documents: [doc], profile: profile)
        #expect(!rendered.string.contains("==multiline"))
        #expect(rendered.string.contains("multiline\nhighlight"))
        #expect(rendered.string.contains("a == b && c == d"))
    }

    @Test("Centered presentation block removes first line indent")
    func centeredPresentationIndent() {
        let text = "Centered verse line."
        let doc = StoryDocument(title: "Poem", chapter: "Ch", kind: .scene, text: text)
        let range = NSRange(location: 0, length: (text as NSString).length)
        let layer = PresentationLayer(blocks: [
            PresentationBlock(
                location: 0,
                length: range.length,
                anchor: TextAnchor.make(in: text, range: range),
                alignment: .centre
            )
        ])
        let project = StoryProject(title: "Verses", documents: [doc])
        var profile = ExportProfile()
        profile.format = .rtf
        profile.includesTitlePage = false
        profile.includesChapterHeadings = false

        let rendered = ExportService.attributed(
            project,
            documents: [doc],
            presentation: [doc.id: layer],
            profile: profile
        )
        let style = rendered.attribute(.paragraphStyle, at: 0, effectiveRange: nil) as? NSParagraphStyle
        #expect(style?.alignment == .center)
        #expect(style?.firstLineHeadIndent == 0)
    }

    @MainActor
    @Test("PDF export can render in memory directly")
    func pdfDirectRender() throws {
        let doc = StoryDocument(title: "Scene", chapter: "Ch", kind: .scene, text: "Prose in PDF.")
        let project = StoryProject(title: "PDF Book", documents: [doc])
        var profile = ExportProfile()
        profile.format = .pdf

        let data = try ExportService.render(project, profile: profile)
        #expect(data.prefix(4) == Data("%PDF".utf8))
    }

    @Test("Selection preserves binder order over raw document array order")
    func selectionPreservesBinderOrder() {
        let docA = StoryDocument(title: "A", chapter: "Ch", kind: .scene, text: "Prose A")
        let docB = StoryDocument(title: "B", chapter: "Ch", kind: .scene, text: "Prose B")
        let docC = StoryDocument(title: "C", chapter: "Ch", kind: .scene, text: "Prose C")
        var project = StoryProject(title: "Novel", documents: [docA, docB, docC])
        project.binder = [
            .document(docC.id),
            .document(docA.id),
            .document(docB.id)
        ]
        let profile = ExportProfile()
        let selected = ExportService.selection(project, profile: profile)
        #expect(selected.map(\.id) == [docC.id, docA.id, docB.id])
    }

    @Test("Chapter title resolves from parent binder folder")
    func chapterTitleResolvesFromBinderFolder() throws {
        let doc = StoryDocument(title: "Scene", chapter: "", kind: .scene, text: "Prose in chapter.")
        let folderID = UUID()
        let chapterFolder = BinderItem(
            id: folderID,
            kind: .folder,
            group: .chapter,
            name: "Chapter 4: The Castle",
            children: [.document(doc.id)]
        )
        let project = StoryProject(
            title: "Novel",
            documents: [doc],
            binder: [chapterFolder]
        )
        var profile = ExportProfile()
        profile.format = .markdown
        profile.includesChapterHeadings = true
        profile.includesTitlePage = false

        let data = try ExportService.render(project, profile: profile)
        let text = try #require(String(data: data, encoding: .utf8))
        #expect(text.contains("## Chapter 4: The Castle"))
    }

    @Test("Preview reports accurate omissions and warnings")
    func previewOmissionsAndWarnings() {
        let draftScene = StoryDocument(title: "Draft", chapter: "Ch", kind: .scene, text: "Draft text.", status: .draft)
        let outlineScene = StoryDocument(title: "Outline", chapter: "Ch", kind: .scene, text: "Outline notes.", status: .outline)
        let emptyScene = StoryDocument(title: "Empty", chapter: "Ch", kind: .scene, text: "   ", status: .draft)
        let noteDoc = StoryDocument(title: "Ideas", chapter: "", kind: .note, text: "Worldbuilding notes.")
        let project = StoryProject(title: "Warnings Test", documents: [draftScene, outlineScene, emptyScene, noteDoc])

        var profile = ExportProfile()
        profile.excludesOutlines = true
        profile.includesNotes = false

        let preview = ExportService.preview(project, profile: profile)
        #expect(preview.includedDocuments.contains(draftScene.id))
        #expect(preview.includedDocuments.contains(emptyScene.id))
        #expect(!preview.includedDocuments.contains(outlineScene.id))
        #expect(!preview.includedDocuments.contains(noteDoc.id))

        let omissionTitles = preview.omissions.map(\.title)
        #expect(omissionTitles.contains("“Outline” will not be exported"))
        #expect(omissionTitles.contains("“Ideas” will not be exported"))
        #expect(omissionTitles.contains("“Empty” is empty"))
    }

    @MainActor
    @Test("PDF export produces valid PDF data")
    func pdfExport() throws {
        let doc = StoryDocument(
            title: "Scene 1",
            chapter: "Chapter One",
            kind: .scene,
            text: "A line of prose for PDF."
        )
        let project = StoryProject(title: "PDF Book", documents: [doc])
        var profile = ExportProfile()
        profile.format = .pdf

        let tempURL = FileManager.default.temporaryDirectory.appending(path: "test-\(UUID().uuidString).pdf")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        let record = try ExportService.write(project, profile: profile, to: tempURL)
        #expect(record.destination == tempURL.lastPathComponent)
        let data = try Data(contentsOf: tempURL)
        #expect(data.count > 0)
        // PDF magic bytes %PDF
        let header = String(data: data.prefix(4), encoding: .ascii)
        #expect(header == "%PDF")
    }

    @Test("DOCX export produces valid Office Open XML data")
    func docxExport() throws {
        let doc = StoryDocument(
            title: "Scene 1",
            chapter: "Chapter One",
            kind: .scene,
            text: "A line of prose for DOCX with **bold** and *italic*."
        )
        let project = StoryProject(title: "DOCX Book", documents: [doc])
        var profile = ExportProfile()
        profile.format = .docx

        let data = try ExportService.render(project, profile: profile)
        #expect(data.count > 0)
        // DOCX is a zip file (magic bytes PK\x03\x04)
        #expect(data.prefix(2) == Data([0x50, 0x4B]))
    }

    @Test("Export scope: selected scene, current chapter, and entire manuscript")
    func exportScopes() {
        let doc1 = StoryDocument(title: "Scene 1", chapter: "Chapter One", kind: .scene, text: "Scene one prose.")
        let doc2 = StoryDocument(title: "Scene 2", chapter: "Chapter One", kind: .scene, text: "Scene two prose.")
        let doc3 = StoryDocument(title: "Scene 3", chapter: "Chapter Two", kind: .scene, text: "Scene three prose.")
        let project = StoryProject(title: "Scoped Novel", documents: [doc1, doc2, doc3])

        // 1. Selected scene
        var sceneProfile = ExportProfile()
        sceneProfile.scope = .selectedScene
        let sceneDocs = ExportService.selection(project, profile: sceneProfile, selectedDocumentID: doc2.id)
        #expect(sceneDocs.map(\.id) == [doc2.id])

        // 2. Current chapter
        var chapterProfile = ExportProfile()
        chapterProfile.scope = .currentChapter
        let chapterDocs = ExportService.selection(project, profile: chapterProfile, selectedDocumentID: doc2.id)
        #expect(chapterDocs.map(\.id) == [doc1.id, doc2.id])

        let chapterTwoDocs = ExportService.selection(project, profile: chapterProfile, selectedDocumentID: doc3.id)
        #expect(chapterTwoDocs.map(\.id) == [doc3.id])

        // 3. Entire manuscript
        var fullProfile = ExportProfile()
        fullProfile.scope = .entireManuscript
        let fullDocs = ExportService.selection(project, profile: fullProfile)
        #expect(fullDocs.map(\.id) == [doc1.id, doc2.id, doc3.id])
    }

    @MainActor
    @Test("PDF page size configuration (Letter vs A4)")
    func pdfPageSizes() throws {
        let doc = StoryDocument(title: "Scene", chapter: "Chapter One", kind: .scene, text: "Prose line.")
        let project = StoryProject(title: "Sized Book", documents: [doc])

        var letterProfile = ExportProfile()
        letterProfile.format = .pdf
        letterProfile.pageSize = .letter
        let letterData = try ExportService.render(project, profile: letterProfile)
        let letterPDF = PDFDocument(data: letterData)
        let letterBounds = letterPDF?.page(at: 0)?.bounds(for: .mediaBox)
        #expect(letterBounds?.width == 612)
        #expect(letterBounds?.height == 792)

        var a4Profile = ExportProfile()
        a4Profile.format = .pdf
        a4Profile.pageSize = .a4
        let a4Data = try ExportService.render(project, profile: a4Profile)
        let a4PDF = PDFDocument(data: a4Data)
        let a4Bounds = a4PDF?.page(at: 0)?.bounds(for: .mediaBox)
        #expect(abs((a4Bounds?.width ?? 0) - 595.28) < 1.0)
        #expect(abs((a4Bounds?.height ?? 0) - 841.89) < 1.0)
    }

    @MainActor
    @Test("PDF chapter on new page forces page break between chapters")
    func pdfChapterOnNewPage() throws {
        let doc1 = StoryDocument(title: "Scene 1", chapter: "Chapter One", kind: .scene, text: "Short text in chapter one.")
        let doc2 = StoryDocument(title: "Scene 2", chapter: "Chapter Two", kind: .scene, text: "Short text in chapter two.")
        let project = StoryProject(title: "Multi-chapter Book", documents: [doc1, doc2])

        var profileWithoutBreaks = ExportProfile()
        profileWithoutBreaks.format = .pdf
        profileWithoutBreaks.chapterOnNewPage = false
        let dataWithoutBreaks = try ExportService.render(project, profile: profileWithoutBreaks)
        let pdfWithoutBreaks = PDFDocument(data: dataWithoutBreaks)
        // With short text and no break, both chapters easily fit on page 1
        #expect(pdfWithoutBreaks?.pageCount == 1)

        var profileWithBreaks = ExportProfile()
        profileWithBreaks.format = .pdf
        profileWithBreaks.chapterOnNewPage = true
        let dataWithBreaks = try ExportService.render(project, profile: profileWithBreaks)
        let pdfWithBreaks = PDFDocument(data: dataWithBreaks)
        // Title page is page 1, Chapter One is page 2, Chapter Two is page 3
        #expect(pdfWithBreaks?.pageCount == 3)
    }

    @MainActor
    @Test("PDF generation performance benchmark (<150ms for multi-page document)")
    func pdfHighPerformanceBenchmark() throws {
        // Generate a 10-paragraph document
        let longProse = (1...15).map { "Paragraph \($0): " + String(repeating: "StoryLoom exports books with fidelity and care. ", count: 12) }.joined(separator: "\n\n")
        let doc = StoryDocument(title: "Long Scene", chapter: "Chapter One", kind: .scene, text: longProse)
        let project = StoryProject(title: "Benchmark Novel", documents: [doc])

        var profile = ExportProfile()
        profile.format = .pdf
        profile.includesPageNumbers = true

        let startTime = DispatchTime.now()
        let data = try ExportService.render(project, profile: profile)
        let endTime = DispatchTime.now()

        let elapsedMs = Double(endTime.uptimeNanoseconds - startTime.uptimeNanoseconds) / 1_000_000.0
        #expect(data.count > 0)
        let pdf = PDFDocument(data: data)
        #expect((pdf?.pageCount ?? 0) >= 2)
        // The render should be well under 150ms (typical run is 5-20ms)
        #expect(elapsedMs < 150.0)
    }

    @Test("Preview text and attributed helpers")
    func previewHelpers() {
        let doc = StoryDocument(title: "Scene 1", chapter: "Chapter One", kind: .scene, text: "Hello **world**.")
        let project = StoryProject(title: "Helper Project", documents: [doc])

        var mdProfile = ExportProfile()
        mdProfile.format = .markdown
        let mdText = ExportService.previewText(project, profile: mdProfile)
        #expect(mdText.contains("# Helper Project"))
        #expect(mdText.contains("Hello **world**."))

        var txtProfile = ExportProfile()
        txtProfile.format = .plainText
        let txtText = ExportService.previewText(project, profile: txtProfile)
        #expect(txtText.contains("Hello world."))
        #expect(!txtText.contains("**"))

        var rtfProfile = ExportProfile()
        rtfProfile.format = .rtf
        let attr = ExportService.previewAttributed(project, profile: rtfProfile)
        #expect(attr.string.contains("Hello world."))
    }
}
