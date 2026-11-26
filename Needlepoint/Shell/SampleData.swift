import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// A small known library: two stash threads and three patterns in two
/// folders. UI tests seed it, and SwiftUI previews show it.
enum SampleData {
    /// Every model the app stores.
    static let models: [any PersistentModel.Type] = [StashThread.self, Pattern.self, FolderStyle.self]

    /// A new in-memory store, holding the sample library unless `seeded` is false.
    static func container(seeded: Bool = true) throws -> ModelContainer {
        let container = try ModelContainer(
            for: Schema(models), configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        if seeded {
            insertStash(into: container.mainContext)
            insertPatterns(into: container.mainContext)
            try container.mainContext.save()
        }
        return container
    }

    /// DMC Floss 310 (2) and Silk & Ivory 01 (3).
    static func insertStash(into context: ModelContext) {
        context.insert(StashThread(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2))
        context.insert(StashThread(brand: "Silk & Ivory", code: "01", name: "Snow", color: "#ffffff", qty: 3))
    }

    /// Strawberry (in progress, with a PDF) and Lemon by Kirk & Bradley, and
    /// Mystery Santa on the wishlist with no designer.
    static func insertPatterns(into context: ModelContext) {
        let strawberry = Pattern(name: "Strawberry")
        strawberry.designer = "Kirk & Bradley"
        strawberry.status = .inProgress
        strawberry.mesh = .thirteen
        strawberry.threads = [
            PatternThread(brand: "DMC Floss", code: "310", name: "Black", qty: 1),
            PatternThread(brand: "DMC Floss", code: "321", name: "Red", qty: 1),
        ]
        strawberry.fileData = pdf(title: "Strawberry")
        strawberry.fileName = "strawberry.pdf"
        strawberry.fileType = .pdf

        // Different case from Strawberry's designer, so it shares the folder.
        let lemon = Pattern(name: "Lemon")
        lemon.designer = "kirk & bradley"
        lemon.created = strawberry.created.addingTimeInterval(1)

        let santa = Pattern(name: "Mystery Santa")
        santa.status = .wishlist
        santa.notes = "Gift for Mom"
        santa.threads = [PatternThread(brand: "Silk & Ivory", code: "01", name: "Snow", qty: 1)]

        for pattern in [strawberry, lemon, santa] {
            context.insert(pattern)
        }
    }

    /// A one-page US Letter PDF with the title printed on it.
    private static func pdf(title: String) -> Data {
        let bounds = CGRect(x: 0, y: 0, width: 612, height: 792)
        return UIGraphicsPDFRenderer(bounds: bounds).pdfData { context in
            context.beginPage()
            UIColor(red: 0.48, green: 0.12, blue: 0.31, alpha: 1).setFill()
            context.fill(CGRect(x: 72, y: 72, width: 468, height: 200))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 36),
                .foregroundColor: UIColor.white,
            ]
            (title as NSString).draw(at: CGPoint(x: 96, y: 150), withAttributes: attributes)
        }
    }
}
