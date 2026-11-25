import Foundation
import SwiftData
import UIKit
import UniformTypeIdentifiers

/// Reads the launch arguments UI tests pass, and builds the model container
/// and defaults to match. A normal launch passes none of them.
struct AppLaunch {
    /// Gives the app an empty in-memory store and empty defaults, so tests
    /// start clean and never touch data saved in the simulator.
    static let uiTestingArgument = "-ui-testing"
    /// Adds a small known stash. Honored only together with `-ui-testing`.
    static let seedStashArgument = "-ui-testing-seed-stash"
    /// Adds three known patterns in two folders. Honored only together with `-ui-testing`.
    static let seedPatternsArgument = "-ui-testing-seed-patterns"

    private static let uiTestingDefaultsSuite = "ui-testing"

    let usesInMemoryStore: Bool
    let seedsStash: Bool
    let seedsPatterns: Bool
    /// Where `@AppStorage` reads and writes. UI tests get a suite that's
    /// emptied at every launch, so a choice one test makes can't leak into the next.
    let defaults: UserDefaults

    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        usesInMemoryStore = arguments.contains(Self.uiTestingArgument)
        seedsStash = usesInMemoryStore && arguments.contains(Self.seedStashArgument)
        seedsPatterns = usesInMemoryStore && arguments.contains(Self.seedPatternsArgument)
        if usesInMemoryStore, let suite = UserDefaults(suiteName: Self.uiTestingDefaultsSuite) {
            suite.removePersistentDomain(forName: Self.uiTestingDefaultsSuite)
            defaults = suite
        } else {
            defaults = .standard
        }
    }

    func makeContainer() throws -> ModelContainer {
        let container = try ModelContainer(
            for: StashThread.self, Pattern.self, FolderStyle.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: usesInMemoryStore))
        let context = container.mainContext
        if seedsStash {
            context.insert(StashThread(brand: "DMC Floss", code: "310", name: "Black", color: "#000000", qty: 2))
            context.insert(StashThread(brand: "Silk & Ivory", code: "01", name: "Snow", color: "#ffffff", qty: 3))
        }
        if seedsPatterns {
            for pattern in Self.seedPatterns() {
                context.insert(pattern)
            }
        }
        try context.save()
        return container
    }

    private static func seedPatterns() -> [Pattern] {
        let strawberry = Pattern(name: "Strawberry")
        strawberry.designer = "Kirk & Bradley"
        strawberry.status = .inProgress
        strawberry.mesh = .thirteen
        strawberry.threads = [
            PatternThread(brand: "DMC Floss", code: "310", name: "Black", qty: 1),
            PatternThread(brand: "DMC Floss", code: "321", name: "Red", qty: 1),
        ]
        strawberry.fileData = seedPDF(title: "Strawberry")
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

        return [strawberry, lemon, santa]
    }

    /// A one-page US Letter PDF with the title printed on it.
    private static func seedPDF(title: String) -> Data {
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
