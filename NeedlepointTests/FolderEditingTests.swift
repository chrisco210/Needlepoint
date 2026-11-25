import Foundation
import SwiftData
import Testing
import UIKit
import UniformTypeIdentifiers
@testable import Needlepoint

private func makeImage(width: CGFloat, height: CGFloat, png: Bool) -> Data {
    let format = UIGraphicsImageRendererFormat()
    format.scale = 1
    let renderer = UIGraphicsImageRenderer(size: CGSize(width: width, height: height), format: format)
    let draw: (UIGraphicsImageRendererContext) -> Void = { context in
        UIColor.purple.setFill()
        context.fill(CGRect(x: 0, y: 0, width: width / 2, height: height))
    }
    return png ? renderer.pngData(actions: draw) : renderer.jpegData(withCompressionQuality: 0.9, actions: draw)
}

@MainActor
struct FolderRenameTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func insert(_ name: String, designer: String) -> Pattern {
        let pattern = Pattern(name: name)
        pattern.designer = designer
        context.insert(pattern)
        return pattern
    }

    private func allStyles() throws -> [FolderStyle] {
        try context.fetch(FetchDescriptor<FolderStyle>())
    }

    @Test func renameSetsTheDesignerOnEveryPatternInTheFolder() throws {
        let a = insert("A", designer: "Kirk & Bradley")
        let b = insert("B", designer: "kirk & bradley")
        let other = insert("C", designer: "Melissa Shirley")

        let newKey = try FolderRename.rename(folderKey: "kirk & bradley", to: " K&B Designs ", patterns: [a, b, other], in: context)
        #expect(newKey == "k&b designs")
        #expect(a.designer == "K&B Designs" && b.designer == "K&B Designs")
        #expect(other.designer == "Melissa Shirley")
    }

    @Test func renamingToAnotherFoldersNameMergesThem() throws {
        let a = insert("A", designer: "Kirk")
        let b = insert("B", designer: "Melissa")
        try FolderRename.rename(folderKey: "kirk", to: "melissa", patterns: [a, b], in: context)
        #expect(Set([a, b].map(\.folderKey)) == ["melissa"])
    }

    @Test func theStyleMovesToTheNewName() throws {
        let a = insert("A", designer: "Kirk")
        let style = FolderStyle(key: "kirk")
        style.background = "#7a1f4f"
        context.insert(style)

        try FolderRename.rename(folderKey: "kirk", to: "Kirk & Bradley", patterns: [a], in: context)
        #expect(try allStyles().map(\.key) == ["kirk & bradley"])
        #expect(try FolderStyle.find(key: "kirk & bradley", in: context)?.background == "#7a1f4f")
    }

    @Test func theOldStyleIsDroppedWhenTheTargetHasOne() throws {
        let a = insert("A", designer: "Kirk")
        let b = insert("B", designer: "Melissa")
        let old = FolderStyle(key: "kirk")
        old.background = "#000000"
        let target = FolderStyle(key: "melissa")
        target.background = "#ffffff"
        context.insert(old)
        context.insert(target)

        try FolderRename.rename(folderKey: "kirk", to: "Melissa", patterns: [a, b], in: context)
        let styles = try allStyles()
        #expect(styles.map(\.key) == ["melissa"])
        #expect(styles.first?.background == "#ffffff")
    }

    @Test func changingOnlyTheCaseKeepsTheStyle() throws {
        let a = insert("A", designer: "kirk")
        context.insert(FolderStyle(key: "kirk"))
        try FolderRename.rename(folderKey: "kirk", to: "Kirk", patterns: [a], in: context)
        #expect(a.designer == "Kirk")
        #expect(try allStyles().map(\.key) == ["kirk"])
    }

    @Test func noDesignerCannotBeRenamed() {
        #expect(!FolderRename.canRename(folderKey: ""))
        #expect(FolderRename.canRename(folderKey: "kirk"))
        #expect(throws: FolderRename.RenameError.noDesignerFolder) {
            try FolderRename.rename(folderKey: "", to: "Kirk", patterns: [], in: context)
        }
    }

    @Test func anEmptyNameIsRefused() {
        let a = insert("A", designer: "Kirk")
        #expect(throws: FolderRename.RenameError.emptyName) {
            try FolderRename.rename(folderKey: "kirk", to: "  ", patterns: [a], in: context)
        }
        #expect(a.designer == "Kirk")
    }

    @Test func toast() {
        #expect(FolderRename.toast == "Folder renamed")
    }
}

@MainActor
struct FolderImageDraftTests {
    let container: ModelContainer
    var context: ModelContext { container.mainContext }

    init() throws {
        container = try ModelContainer(
            for: Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    @Test func backgroundChoicesMatchTheReadme() {
        #expect(FolderImageDraft.backgrounds.map(\.hex) == ["#ffffff", "#f6e4ec", "#fbf3e2", "#e3eef6", "#7a1f4f", "#221b26"])
        #expect(Set(FolderImageDraft.backgrounds.map(\.name)).count == 6, "Each swatch needs its own VoiceOver name")
    }

    @Test func newFolderStartsWithWholeImageOnWhite() {
        let draft = FolderImageDraft(style: nil)
        #expect(draft.imageData == nil)
        #expect(draft.fit == .contain)
        #expect(draft.background == "#ffffff")
    }

    @Test func existingStyleIsLoaded() {
        let style = FolderStyle(key: "kirk")
        style.imageData = Data([1])
        style.fit = .cover
        style.background = "#7a1f4f"
        let draft = FolderImageDraft(style: style)
        #expect(draft.imageData == Data([1]))
        #expect(draft.fit == .cover)
        #expect(draft.background == "#7a1f4f")
    }

    @Test(arguments: [(UTType.png, FolderStyle.Fit.contain), (.gif, .contain), (.webP, .contain), (.svg, .contain),
                      (.jpeg, .cover), (.heic, .cover)])
    func defaultFitFollowsTheImageType(type: UTType, fit: FolderStyle.Fit) {
        #expect(FolderImageDraft.defaultFit(for: type) == fit)
    }

    @Test func aPNGKeepsTransparencyAndShowsWhole() throws {
        var draft = FolderImageDraft(style: nil)
        draft.fit = .cover
        try draft.setImage(makeImage(width: 2000, height: 1000, png: true), type: .png)
        let data = try #require(draft.imageData)
        #expect(data.prefix(4) == Data([0x89, 0x50, 0x4e, 0x47]), "Logos stay PNG so transparent areas stay transparent")
        #expect(draft.fit == .contain)
        let image = try #require(UIImage(data: data))
        #expect(max(image.size.width, image.size.height) * image.scale <= FolderImageDraft.maxDimension)
    }

    @Test func aPhotoBecomesAJPEGThatFillsTheTile() throws {
        var draft = FolderImageDraft(style: nil)
        try draft.setImage(makeImage(width: 400, height: 300, png: false), type: .jpeg)
        #expect(draft.imageData?.prefix(2) == Data([0xff, 0xd8]))
        #expect(draft.fit == .cover)
    }

    @Test func unreadableImagesAreRefused() {
        var draft = FolderImageDraft(style: nil)
        #expect(throws: FolderImageDraft.ImageError.unreadable) { try draft.setImage(Data([1, 2, 3]), type: .png) }
        #expect(draft.imageData == nil)
    }

    @Test func saveCreatesOrUpdatesTheFoldersStyle() throws {
        var draft = FolderImageDraft(style: nil)
        draft.background = "#e3eef6"
        try draft.save(folderKey: "kirk", in: context)
        #expect(try FolderStyle.find(key: "kirk", in: context)?.background == "#e3eef6")

        draft.background = "#221b26"
        try draft.save(folderKey: "kirk", in: context)
        #expect(try context.fetch(FetchDescriptor<FolderStyle>()).count == 1)
        #expect(try FolderStyle.find(key: "kirk", in: context)?.background == "#221b26")
    }

    @Test func removingTheImageClearsItOnSave() throws {
        let style = FolderStyle(key: "kirk")
        style.imageData = Data([1])
        context.insert(style)
        var draft = FolderImageDraft(style: style)
        draft.imageData = nil
        try draft.save(folderKey: "kirk", in: context)
        #expect(style.imageData == nil)
    }

    @Test func toast() {
        #expect(FolderImageDraft.toast == "Folder image saved")
    }
}
