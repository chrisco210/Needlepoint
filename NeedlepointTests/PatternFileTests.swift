import Foundation
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Needlepoint

/// A one-page US Letter PDF with a red box on it.
private func makePDF(pages: Int = 1) -> Data {
    let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
    return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
        for _ in 0..<pages {
            context.beginPage()
            UIColor.red.setFill()
            context.fill(CGRect(x: 100, y: 100, width: 200, height: 200))
        }
    }
}

private func makePNG(width: CGFloat, height: CGFloat) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).pngData { context in
        UIColor.blue.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    }
}

private func pixelSize(of jpeg: Data) throws -> CGSize {
    let image = try #require(UIImage(data: jpeg))
    return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
}

struct AttachedFileTests {
    @Test(arguments: [UTType.pdf, .jpeg, .png, .heic])
    func acceptsPDFsAndImages(type: UTType) throws {
        let file = try AttachedFile.make(data: Data([1, 2, 3]), name: "pattern", type: type)
        #expect(file.data == Data([1, 2, 3]))
        #expect(file.name == "pattern")
        #expect(file.type == type)
    }

    @Test func acceptsExactlyTwentyMegabytes() throws {
        let data = Data(count: AttachedFile.maxBytes)
        #expect(throws: Never.self) { try AttachedFile.make(data: data, name: "big.pdf", type: .pdf) }
    }

    @Test func rejectsFilesOverTwentyMegabytes() {
        let data = Data(count: AttachedFile.maxBytes + 1)
        #expect(throws: AttachedFile.Problem.tooLarge) { try AttachedFile.make(data: data, name: "big.pdf", type: .pdf) }
    }

    @Test func rejectsOtherFileTypes() {
        #expect(throws: AttachedFile.Problem.unsupportedType) {
            try AttachedFile.make(data: Data([1]), name: "notes.txt", type: .plainText)
        }
    }

    @Test func isPDFOnlyForPDFs() throws {
        #expect(try AttachedFile.make(data: Data([1]), name: "a.pdf", type: .pdf).isPDF)
        #expect(try !AttachedFile.make(data: Data([1]), name: "a.jpg", type: .jpeg).isPDF)
    }

    @Test func problemMessagesMatchTheWebApp() {
        #expect(AttachedFile.Problem.tooLarge.message == "That file is over 20 MB. Try a smaller export.")
        #expect(AttachedFile.Problem.unsupportedType.message == "Choose a PDF or an image.")
    }
}

struct CoverRendererTests {
    @Test func firstPageOfAPDFBecomesAJPEG() throws {
        let jpeg = try #require(CoverRenderer.firstPageJPEG(fromPDF: makePDF(pages: 3)))
        #expect(jpeg.prefix(2) == Data([0xff, 0xd8]), "Not a JPEG")
        let size = try pixelSize(of: jpeg)
        #expect(max(size.width, size.height) <= CoverRenderer.maxDimension)
        #expect(size.height > size.width, "A portrait page should stay portrait")
    }

    @Test func unreadablePDFHasNoCover() {
        #expect(CoverRenderer.firstPageJPEG(fromPDF: Data("not a pdf".utf8)) == nil)
    }

    @Test func largePhotosAreScaledDown() throws {
        let jpeg = try #require(CoverRenderer.jpeg(fromImage: makePNG(width: 4000, height: 3000)))
        let size = try pixelSize(of: jpeg)
        #expect(size.width == CoverRenderer.maxDimension)
        #expect(size.height == 1200)
    }

    @Test func smallPhotosAreNotEnlarged() throws {
        let jpeg = try #require(CoverRenderer.jpeg(fromImage: makePNG(width: 100, height: 50)))
        #expect(try pixelSize(of: jpeg) == CGSize(width: 100, height: 50))
    }

    @Test func unreadableImageHasNoCover() {
        #expect(CoverRenderer.jpeg(fromImage: Data([1, 2, 3])) == nil)
    }
}

@MainActor
struct PatternDraftFileTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func editingDraftLoadsTheFileAndCover() {
        let pattern = Pattern(name: "Strawberry")
        pattern.fileData = Data([1])
        pattern.fileName = "strawberry.pdf"
        pattern.fileType = .pdf
        pattern.coverData = Data([2])

        let draft = PatternDraft(editing: pattern)
        #expect(draft.file == AttachedFile(data: Data([1]), name: "strawberry.pdf", type: .pdf))
        #expect(draft.cover == Data([2]))
    }

    @Test func pageOneOptionIsOfferedOnlyForAPDF() throws {
        var draft = PatternDraft()
        #expect(!draft.canUseFirstPageAsCover)
        draft.file = try AttachedFile.make(data: Data([1]), name: "a.jpg", type: .jpeg)
        #expect(!draft.canUseFirstPageAsCover)
        draft.file = try AttachedFile.make(data: Data([1]), name: "a.pdf", type: .pdf)
        #expect(draft.canUseFirstPageAsCover)
    }

    @Test func useFirstPageSetsTheCover() throws {
        var draft = PatternDraft()
        draft.file = try AttachedFile.make(data: makePDF(), name: "a.pdf", type: .pdf)
        // #expect can't call a mutating method, because it captures `draft` as a constant.
        let used = draft.useFirstPageAsCover()
        #expect(used)
        #expect(draft.cover?.prefix(2) == Data([0xff, 0xd8]))
    }

    @Test func useFirstPageFailsWithoutAPDF() throws {
        var draft = PatternDraft()
        draft.file = try AttachedFile.make(data: Data([1]), name: "a.jpg", type: .jpeg)
        let used = draft.useFirstPageAsCover()
        #expect(!used)
        #expect(draft.cover == nil)
    }

    @Test func savingWritesTheFileAndCover() throws {
        var draft = PatternDraft()
        draft.name = "Strawberry"
        draft.file = try AttachedFile.make(data: Data([1, 2]), name: "strawberry.pdf", type: .pdf)
        draft.cover = Data([0xff, 0xd8])

        let saved = try draft.save(to: nil, in: context)
        #expect(saved.fileData == Data([1, 2]))
        #expect(saved.fileName == "strawberry.pdf")
        #expect(saved.fileType == .pdf)
        #expect(saved.coverData == Data([0xff, 0xd8]))
    }

    @Test func replacingTheFileOverwritesTheOldOne() throws {
        let pattern = Pattern(name: "Strawberry")
        pattern.fileData = Data([1])
        pattern.fileName = "old.pdf"
        pattern.fileType = .pdf
        context.insert(pattern)

        var draft = PatternDraft(editing: pattern)
        draft.file = try AttachedFile.make(data: Data([9]), name: "new.jpg", type: .jpeg)
        try draft.save(to: pattern, in: context)

        #expect(pattern.fileData == Data([9]))
        #expect(pattern.fileName == "new.jpg")
        #expect(pattern.fileType == .jpeg)
    }

    @Test func removingTheCoverClearsItOnSave() throws {
        let pattern = Pattern(name: "Strawberry")
        pattern.coverData = Data([2])
        context.insert(pattern)

        var draft = PatternDraft(editing: pattern)
        draft.cover = nil
        try draft.save(to: pattern, in: context)
        #expect(pattern.coverData == nil)
    }
}

@MainActor
struct CameraCoverTests {
    private func photo(width: CGFloat, height: CGFloat) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        }
    }

    @Test func aCameraPhotoBecomesAScaledJPEGCover() throws {
        var draft = PatternDraft()
        let used = draft.useCameraPhoto(photo(width: 4032, height: 3024))
        #expect(used)
        let cover = try #require(draft.cover)
        #expect(cover.prefix(2) == Data([0xff, 0xd8]))
        let image = try #require(UIImage(data: cover))
        #expect(image.size.width * image.scale == CoverRenderer.maxDimension)
    }

    @Test func aCameraPhotoReplacesTheCover() {
        var draft = PatternDraft()
        draft.cover = Data([1])
        _ = draft.useCameraPhoto(photo(width: 100, height: 100))
        #expect(draft.cover != Data([1]))
    }

    @Test func theFakeCameraPhotoIsUsable() {
        var draft = PatternDraft()
        let used = draft.useCameraPhoto(CameraPicker.fakePhoto())
        #expect(used)
    }
}

